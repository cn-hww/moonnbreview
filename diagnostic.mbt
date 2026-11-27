///|
/// Stable notebook rejection code, JSON Pointer (empty = root), and repair hint.
/// JSON syntax errors also retain the parser's one-based line/column when known.
#derive(Debug, Eq)
pub struct Diagnostic {
  code : String
  path : String
  message : String
  hint : String
  line : Int32?
  column : Int32?
}

///|
pub fn Diagnostic::to_json(self : Diagnostic) -> String {
  canonical({
    "format": "moonnbreview/diagnostic-1",
    "code": Json(self.code),
    "path": Json(self.path),
    "message": Json(self.message),
    "hint": Json(self.hint),
    "line": self.line.map(n => Json(n)).unwrap_or(Json::null()),
    "column": self.column.map(n => Json(n)).unwrap_or(Json::null()),
  })
}

///|
pub fn Diagnostic::render(self : Diagnostic) -> String {
  self.code +
  " at " +
  (if self.path.is_empty() { "<root>" } else { self.path }) +
  ": " +
  self.message +
  "; hint: " +
  self.hint
}

///|
priv suberror DiagnosticError {
  Rejected(Diagnostic)
}

///|
fn reject(
  code : String,
  path : String,
  message : String,
  hint : String,
) -> DiagnosticError {
  Rejected({ code, path, message, hint, line: None, column: None, })
}

///|
fn diagnostic_tree(
  value : Json,
  path : String,
  depth : Int32,
) -> Unit raise DiagnosticError {
  guard depth <= 64 else {
    raise reject(
      "NB_DEPTH", path, "JSON exceeds depth 64", "Reduce nesting to at most 64; no input was changed",
    )
  }
  match value {
    String(s) =>
      unicode(s) catch {
        _ =>
          raise reject(
            "NB_UNICODE", path, "unpaired Unicode surrogate", "Replace the invalid surrogate with a valid Unicode scalar",
          )
      }
    Number(n, ..) => {
      guard n == n && n <= 9007199254740991.0 && n >= -9007199254740991.0 else {
        raise reject(
          "NB_NUMBER", path, "number outside supported finite safe range", "Represent an exact large value as a string in your producer; do not round it",
        )
      }
    }
    Array(items) =>
      for i, item in items {
        diagnostic_tree(item, pointer(path, i.to_string()), depth + 1)
      }
    Object(fields) => {
      let keys = fields.keys().to_array()
      keys.sort()
      for key in keys {
        unicode(key) catch {
          _ =>
            raise reject(
              "NB_UNICODE", path, "object key contains an unpaired Unicode surrogate",
              "Repair the invalid key in the producing application",
            )
        }
        diagnostic_tree(fields[key], pointer(path, key), depth + 1)
      }
    }
    _ => ()
  }
}

///|
fn diagnostic_json(text : String) -> Json raise DiagnosticError {
  guard text.length() <= 2000000 else {
    raise reject(
      "NB_SIZE", "", "input exceeds 2000000 UTF-16 units", "Split the notebook or remove unwanted payloads explicitly in your producer",
    )
  }
  unicode(text) catch {
    _ =>
      raise reject(
        "NB_UNICODE", "", "input contains an unpaired Unicode surrogate", "Save valid Unicode text before validation",
      )
  }
  let raw = @json.parse(
    text[:],
    max_nesting_depth=64,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    e => {
      let (code, position, hint) = match e {
        @json.DuplicateKey(p, _) =>
          (
            "NB_JSON_DUPLICATE_KEY",
            Some(p),
            "Resolve the duplicate keys explicitly; neither value was selected",
          )
        @json.DepthLimitExceeded =>
          ("NB_DEPTH", None, "Reduce JSON nesting to at most 64")
        @json.InvalidChar(p, _)
        | @json.InvalidNumber(p, _)
        | @json.InvalidIdentEscape(p) =>
          (
            "NB_JSON_SYNTAX",
            Some(p),
            "Repair the JSON at the reported line and column",
          )
        @json.InvalidEof =>
          ("NB_JSON_SYNTAX", None, "Complete the truncated JSON document")
      }
      raise Rejected({
        code,
        path: "",
        message: e.to_string(),
        hint,
        line: position.map(p => p.line),
        column: position.map(p => p.column),
      })
    }
  }
  diagnostic_tree(raw, "", 0)
  raw
}

///|
// Resolve typed upstream logical paths against actual keys, including keys with
// dots/brackets. Ambiguous upstream paths retain their spelling in the message
// and use the root pointer rather than inventing a misleading precise location.
fn codec_locations(
  value : Json,
  logical : String,
  path : String,
  target : String,
  found : Array[String],
) -> Unit {
  if target == logical {
    found.push(path)
    return
  }
  match value {
    Object(fields) => {
      for key, item in fields {
        let next = logical + "." + key
        if target == next ||
          target.has_prefix(next + ".") ||
          target.has_prefix(next + "[") {
          codec_locations(item, next, pointer(path, key), target, found)
        }
      }
      if target.has_prefix(logical + ".") {
        let rest = target[logical.length() + 1:].to_owned()
        if !rest.contains(".") && !rest.contains("[") && !fields.contains(rest) {
          found.push(pointer(path, rest))
        }
      }
    }
    Array(items) =>
      for i, item in items {
        let next = logical + "[" + i.to_string() + "]"
        if target == next ||
          target.has_prefix(next + ".") ||
          target.has_prefix(next + "[") {
          codec_locations(
            item,
            next,
            pointer(path, i.to_string()),
            target,
            found,
          )
        }
      }
    _ => ()
  }
}

///|
fn codec_diagnostic(
  raw : Json,
  error : @nbformat.FormatError,
) -> DiagnosticError {
  match error {
    @nbformat.InvalidField(path~, expected~) => {
      let locations = []
      codec_locations(raw, "$", "", path, locations)
      reject(
        "NB_FIELD",
        if locations.length() == 1 {
          locations[0]
        } else {
          ""
        },
        path + ": expected " + expected,
        "Supply the required field/type in the producer; preserve existing payloads",
      )
    }
    @nbformat.DuplicateCellId(id) | @nbformat.DuplicateCellName(id) => {
      let is_id = error is @nbformat.DuplicateCellId(_)
      let mut seen = false
      let mut location = "/cells"
      if raw is Object(root) && root.get("cells") is Some(Array(cells)) {
        for i, cell in cells {
          if cell is Object(fields) {
            let value = if is_id {
              fields.get("id")
            } else {
              match fields.get("metadata") {
                Some(Object(m)) => m.get("name")
                _ => None
              }
            }
            if value == Some(Json(id)) {
              if seen {
                location = "/cells/" +
                  i.to_string() +
                  (if is_id { "/id" } else { "/metadata/name" })
                break
              }
              seen = true
            }
          }
        }
      }
      reject(
        if is_id {
          "NB_CELL_ID_DUPLICATE"
        } else {
          "NB_CELL_NAME_DUPLICATE"
        },
        location,
        "duplicate cell identity " + Json(id).stringify(),
        "Assign a unique stable identity in the producer; automatic ID generation is disabled",
      )
    }
    @nbformat.UnsupportedVersion(..) =>
      reject(
        "NB_VERSION", "/nbformat", "require nbformat 4.5", "Convert explicitly and assign stable cell IDs before review",
      )
    @nbformat.InvalidJson(message) =>
      reject("NB_JSON_SYNTAX", "", message, "Repair JSON before review")
  }
}

///|
// First differing path after the explicitly permitted multiline normalization.
fn preservation_path(a : Json, b : Json, path : String) -> String? {
  if canonical(a) == canonical(b) {
    return None
  }
  match (a, b) {
    (Object(old), Object(new)) => {
      let keys = old.keys().to_array()
      for key in new.keys() {
        if !old.contains(key) {
          keys.push(key)
        }
      }
      keys.sort()
      for key in keys {
        let next = pointer(path, key)
        match (old.get(key), new.get(key)) {
          (Some(x), Some(y)) =>
            if preservation_path(x, y, next) is Some(p) {
              return Some(p)
            }
          _ => return Some(next)
        }
      }
    }
    (Array(old), Array(new)) => {
      for i in 0..<old.length().min(new.length()) {
        if preservation_path(old[i], new[i], pointer(path, i.to_string()))
          is Some(p) {
          return Some(p)
        }
      }
      if old.length() != new.length() {
        return Some(pointer(path, old.length().min(new.length()).to_string()))
      }
    }
    _ => ()
  }
  Some(path)
}

///|
fn validate_document(text : String) -> Document raise DiagnosticError {
  let raw = diagnostic_json(text)
  guard raw is Object(fields) else {
    raise reject(
      "NB_ROOT", "", "expected notebook object", "Supply a complete .ipynb JSON object",
    )
  }
  for (key, expected) in [("nbformat", 4), ("nbformat_minor", 5)] {
    guard fields.get(key) == Some(Json(expected)) else {
      raise reject(
        "NB_VERSION",
        pointer("", key),
        "require nbformat 4.5",
        "Convert older files explicitly and assign stable IDs; newer versions require separate compatibility review",
      )
    }
  }
  guard fields.get("cells") is Some(Array(cells)) else {
    raise reject(
      "NB_CELLS", "/cells", "expected cell array", "Supply a cells array; an empty notebook uses []",
    )
  }
  guard cells.length() <= 5000 else {
    raise reject(
      "NB_CELLS", "/cells", "more than 5000 cells", "Split the notebook into smaller reviewable documents",
    )
  }
  let book = @nbformat.Notebook::from_json(raw) catch {
    e => raise codec_diagnostic(raw, e)
  }
  normalize_text(raw) catch {
    _ =>
      raise reject(
        "NB_NORMALIZATION", "", "cannot normalize notebook", "Use explicit supported multiline fields; no data was discarded",
      )
  }
  let exported = book.to_json() catch { e => raise codec_diagnostic(raw, e) }
  if preservation_path(raw, exported, "") is Some(path) {
    raise reject(
      "NB_PRESERVATION", path, "unsupported normalization would change data", "Use exact representable numbers and explicit fields; retain the original file and inspect this field in the producer",
    )
  }
  { book, }
}

///|
/// Validate without exceptions. Does not rewrite files, repair IDs or migrate
/// versions. Error codes are generated at validation sites, not from text matching.
pub fn Document::validate(text : String) -> Result[Document, Diagnostic] {
  Ok(validate_document(text)) catch {
    Rejected(diagnostic) => Err(diagnostic)
  }
}

///|
/// Invalid, unsupported or over-budget input. Paths use JSON Pointer syntax.
#derive(Debug, Eq)
pub suberror ReviewError {
  Invalid(String)
}

///|
/// A validated immutable notebook. Only nbformat 4.5 is accepted.
pub struct Document {
  priv book : @nbformat.Notebook
}

///|
fn pointer(path : String, key : String) -> String {
  path + "/" + key.replace_all(old="~", new="~0").replace_all(old="/", new="~1")
}

///|
fn unicode(text : String) -> Unit raise ReviewError {
  let mut i = 0
  while i < text.length() {
    let unit = text[i].to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      guard i + 1 < text.length() else {
        raise Invalid("unpaired Unicode surrogate")
      }
      let next = text[i + 1].to_int()
      guard next >= 0xDC00 && next <= 0xDFFF else {
        raise Invalid("unpaired Unicode surrogate")
      }
      i += 2
    } else {
      guard unit < 0xDC00 || unit > 0xDFFF else {
        raise Invalid("unpaired Unicode surrogate")
      }
      i += 1
    }
  }
}

///|
fn validate_tree(value : Json, depth : Int32) -> Unit raise ReviewError {
  guard depth <= 64 else { raise Invalid("JSON exceeds depth 64") }
  match value {
    String(s) => unicode(s)
    Array(items) =>
      for item in items {
        validate_tree(item, depth + 1)
      }
    Object(fields) =>
      for key, item in fields {
        unicode(key)
        validate_tree(item, depth + 1)
      }
    Number(n, ..) => {
      guard n == n && n <= 9007199254740991.0 && n >= -9007199254740991.0 else {
        raise Invalid("number outside supported finite safe range")
      }
    }
    _ => ()
  }
}

///|
fn checked_json(text : String) -> Json raise ReviewError {
  guard text.length() <= 2000000 else {
    raise Invalid("input exceeds 2000000 UTF-16 units")
  }
  unicode(text)
  let value = @json.parse(
    text[:],
    max_nesting_depth=64,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    e => raise Invalid("invalid JSON: " + e.to_string())
  }
  validate_tree(value, 0)
  value
}

///|
fn canonical(value : Json) -> String {
  match value {
    Object(fields) => {
      let keys = fields.keys().to_array()
      keys.sort()
      "{" +
      keys
      .map(key => Json(key).stringify() + ":" + canonical(fields[key]))
      .join(",") +
      "}"
    }
    Array(items) => "[" + items.map(canonical).join(",") + "]"
    _ => value.stringify()
  }
}

///|
fn object(value : Json) -> Map[String, Json] raise ReviewError {
  guard value is Object(fields) else { raise Invalid("expected JSON object") }
  fields
}

///|
fn multiline(value : Json) -> Json {
  match value {
    Array(parts) => {
      let out = StringBuilder()
      for part in parts {
        guard part is String(s) else { return value }
        out.write_string(s)
      }
      Json(out.to_string())
    }
    _ => value
  }
}

///|
fn normalize_mime(value : Json) -> Unit {
  if value is Object(fields) {
    for key in fields.keys().to_array() {
      if key != "application/json" && !key.has_suffix("+json") {
        fields[key] = multiline(fields[key])
      }
    }
  }
}

///|
fn normalize_text(value : Json) -> Unit raise ReviewError {
  let root = object(value)
  guard root.get("cells") is Some(Array(cells)) else {
    raise Invalid("/cells: expected array")
  }
  for cell in cells {
    let c = object(cell)
    match c.get("cell_type") {
      Some(String("code" | "markdown" | "raw")) =>
        if c.get("source") is Some(source) {
          c["source"] = multiline(source)
        }
      _ => ()
    }
    if c.get("cell_type") == Some(Json("code")) &&
      c.get("outputs") is Some(Array(outputs)) {
      for output in outputs {
        let o = object(output)
        match o.get("output_type") {
          Some(String("stream")) =>
            if o.get("text") is Some(text) {
              o["text"] = multiline(text)
            }
          Some(String("display_data" | "execute_result")) =>
            if o.get("data") is Some(data) {
              normalize_mime(data)
            }
          _ => ()
        }
      }
    }
    if c.get("cell_type") is Some(String("markdown" | "raw")) &&
      c.get("attachments") is Some(Object(attachments)) {
      for _, bundle in attachments {
        normalize_mime(bundle)
      }
    }
  }
}

///|
/// Parse without silently discarding duplicate keys, extension fields or numbers.
/// String arrays in defined multiline fields are the only permitted normalization.
pub fn Document::parse(text : String) -> Document raise ReviewError {
  let raw = checked_json(text)
  let fields = object(raw)
  guard fields.get("nbformat") == Some(Json(4)) &&
    fields.get("nbformat_minor") == Some(Json(5)) else {
    raise Invalid(
      "/nbformat: require format 4.5; convert older files explicitly and assign stable IDs",
    )
  }
  guard fields.get("cells") is Some(Array(cells)) && cells.length() <= 5000 else {
    raise Invalid("/cells: require an array with at most 5000 cells")
  }
  let book = @nbformat.Notebook::from_json(raw) catch {
    e => raise Invalid("notebook: \{Repr(e)}")
  }
  normalize_text(raw)
  let exported = book.to_json() catch {
    e => raise Invalid("notebook export: \{Repr(e)}")
  }
  guard canonical(raw) == canonical(exported) else {
    raise Invalid(
      "unsupported normalization would change data; use exact representable numeric values and explicit fields",
    )
  }
  { book, }
}

///|
/// Canonical JSON retaining all accepted payloads; original formatting is not retained.
pub fn Document::to_string(self : Document) -> String raise ReviewError {
  canonical(self.book.to_json() catch { e => raise Invalid("\{Repr(e)}") })
}

///|
/// Return the immutable upstream model for integration with notebook consumers.
pub fn Document::notebook(self : Document) -> @nbformat.Notebook {
  self.book
}

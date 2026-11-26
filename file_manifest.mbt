///|
/// A file pair with explicit absence. None is intentional, never a read fallback.
#derive(Debug, Eq)
pub(all) struct FilePair {
  id : String
  old_path : String?
  new_path : String?
}

///|
pub struct FileManifest {
  priv items : Array[FilePair]
  priv legacy : Bool
}

///|
fn file_pair(pair : ReviewPair) -> FilePair {
  { id: pair.id, old_path: Some(pair.old_path), new_path: Some(pair.new_path), }
}

///|
fn file_path(value : Json) -> String? raise ReviewError {
  match value {
    Null => None
    String(path) => Some(path)
    _ => raise Invalid("file path must be a string or explicit null")
  }
}

///|
/// 0..64 unique IDs; each pair has at least one present path. Existing path/ID
/// limits apply. Arrays are copied. New manifests emit manifest-2/batch-2.
pub fn FileManifest::new(
  pairs : Array[FilePair],
) -> FileManifest raise ReviewError {
  guard pairs.length() <= 64 else {
    raise Invalid("manifest permits at most 64 pairs")
  }
  let validation = pairs.map(pair => {
    let fallback = match (pair.old_path, pair.new_path) {
      (Some(path), _) | (_, Some(path)) => path
      _ =>
        raise Invalid(
          "file pair requires at least one present path: " + pair.id,
        )
    }
    ReviewPair::{
      id: pair.id,
      old_path: pair.old_path.unwrap_or(fallback),
      new_path: pair.new_path.unwrap_or(fallback),
    }
  })
  ignore(Manifest::new(validation))
  { items: pairs.copy(), legacy: false, }
}

///|
/// Upgrade the API without changing the legacy wire formats or report bytes.
pub fn FileManifest::from_manifest(manifest : Manifest) -> FileManifest {
  { items: manifest.pairs().map(file_pair), legacy: true, }
}

///|
pub fn FileManifest::pairs(self : FileManifest) -> Array[FilePair] {
  self.items.copy()
}

///|
pub fn FileManifest::to_json(self : FileManifest) -> String {
  canonical({
    "format": Json(
      if self.legacy {
        "moonnbreview/manifest-1"
      } else {
        "moonnbreview/manifest-2"
      },
    ),
    "pairs": Json(self.items.map(pair => batch_context(pair))),
  })
}

///|
/// Strict manifest-2 uses explicit JSON null for an intentionally absent path.
/// Also accepts strict manifest-1, preserving its v1 output compatibility.
pub fn FileManifest::from_json(text : String) -> FileManifest raise ReviewError {
  let fields = object(checked_json(text))
  if fields.get("format") == Some(Json("moonnbreview/manifest-1")) {
    return FileManifest::from_manifest(Manifest::from_json(text))
  }
  guard fields.length() == 2 &&
    fields.get("format") == Some(Json("moonnbreview/manifest-2")) &&
    fields.get("pairs") is Some(Array(pairs)) else {
    raise Invalid(
      "expected manifest-1 or manifest-2 fields format and pairs only",
    )
  }
  guard pairs.length() <= 64 else {
    raise Invalid("manifest permits at most 64 pairs")
  }
  FileManifest::new(
    pairs.mapi((i, value) => {
      let pair = object(value)
      guard pair.length() == 3 &&
        pair.get("id") is Some(String(id)) &&
        pair.contains("old") &&
        pair.contains("new") else {
        raise Invalid(
          "/pairs/" +
          i.to_string() +
          ": expected id, old and new; absent paths must be explicit null",
        )
      }
      FilePair::{
        id,
        old_path: file_path(pair["old"]),
        new_path: file_path(pair["new"]),
      }
    }),
  )
}

///|
pub fn FileManifest::review(
  self : FileManifest,
  read : (String) -> String raise,
  policy~ : Policy = Policy::{ counts: false, metadata_keys: [], },
  gate~ : Gate = Gate::new(),
  retain_inputs~ : Bool = false,
) -> BatchReview raise ReviewError {
  self.review_sides(read, read, policy~, gate~, retain_inputs~)
}

///|
/// Absent sides never invoke loaders. Present read/parse errors remain errors;
/// later pairs continue. Whole-file changes are unsuppressed Structure witnesses.
pub fn FileManifest::review_sides(
  self : FileManifest,
  read_old : (String) -> String raise,
  read_new : (String) -> String raise,
  policy~ : Policy = Policy::{ counts: false, metadata_keys: [], },
  gate~ : Gate = Gate::new(),
  retain_inputs~ : Bool = false,
) -> BatchReview raise ReviewError {
  let writer = batch_writer(policy, gate, retain_inputs, file_mode=!self.legacy)
  for pair in self.items {
    let mut phase = "read_old"
    let (status, detail, saved) = try {
      let old = match pair.old_path {
        Some(path) => {
          let text = read_old(path)
          phase = "parse_old"
          Some(Document::parse(text))
        }
        None => None
      }
      phase = "read_new"
      let new = match pair.new_path {
        Some(path) => {
          let text = read_new(path)
          phase = "parse_new"
          Some(Document::parse(text))
        }
        None => None
      }
      phase = "compare"
      let c = compare_files(old, new, policy~)
      phase = "serialize"
      batch_serialization(c, gate, retain_inputs)
    } catch {
      e => batch_diagnostic(phase, "\{Repr(e)}")
    }
    writer.push_file(pair, status, detail, saved)
  }
  writer.finish()
}

///|
/// Serial asynchronous counterpart with the same explicit presence and phases.
pub async fn FileManifest::review_sides_async(
  self : FileManifest,
  read_old : async (String) -> String,
  read_new : async (String) -> String,
  policy~ : Policy = Policy::{ counts: false, metadata_keys: [], },
  gate~ : Gate = Gate::new(),
  retain_inputs~ : Bool = false,
) -> BatchReview {
  let writer = batch_writer(policy, gate, retain_inputs, file_mode=!self.legacy)
  for pair in self.items {
    let mut phase = "read_old"
    let (status, detail, saved) = try {
      let old = match pair.old_path {
        Some(path) => {
          let text = read_old(path)
          phase = "parse_old"
          Some(Document::parse(text))
        }
        None => None
      }
      phase = "read_new"
      let new = match pair.new_path {
        Some(path) => {
          let text = read_new(path)
          phase = "parse_new"
          Some(Document::parse(text))
        }
        None => None
      }
      phase = "compare"
      let c = compare_files(old, new, policy~)
      phase = "serialize"
      batch_serialization(c, gate, retain_inputs)
    } catch {
      e => batch_diagnostic(phase, "\{Repr(e)}")
    }
    writer.push_file(pair, status, detail, saved)
  }
  writer.finish()
}

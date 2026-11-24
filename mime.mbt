///|
/// A presentation hint from the literal data key, not payload validation.
#derive(Debug, Eq)
pub(all) enum MimeCategory {
  Text
  StructuredJson
  Image
  Opaque
}

///|
pub struct MimeGroup {
  key : String
  category : MimeCategory
  changes : Array[Change]
}

///|
/// Return the exact decoded data key only for recognized output-data witnesses.
/// Whole output/cell replacements, stream fields, metadata and unknown output
/// extensions return None. JSON Pointer escapes are decoded exactly once.
pub fn Change::mime_key(self : Change) -> String? {
  guard self.kind == Output && self.cell_id is Some(_) else { return None }
  let parts = self.path.split("/").collect()
  guard parts.length() >= 5 &&
    parts[0] == "" &&
    parts[1] == "outputs" &&
    parts[3] == "data" &&
    !parts[2].is_empty() &&
    parts[2].to_owned().iter().all(c => c >= '0' && c <= '9') else {
    return None
  }
  Some(
    parts[4]
    .to_owned()
    .replace_all(old="~1", new="/")
    .replace_all(old="~0", new="~"),
  )
}

///|
fn mime_category(key : String) -> MimeCategory {
  if key.has_prefix("text/") && key.length() > 5 {
    Text
  } else if key == "application/json" ||
    (
      key.has_prefix("application/") &&
      key.has_suffix("+json") &&
      key.length() > 17
    ) {
    StructuredJson
  } else if key.has_prefix("image/") && key.length() > 6 {
    Image
  } else {
    Opaque
  }
}

///|
pub fn Change::mime_category(self : Change) -> MimeCategory? {
  self.mime_key().map(mime_category)
}

///|
fn MimeCategory::label(self : MimeCategory) -> String {
  match self {
    Text => "text"
    StructuredJson => "structured JSON"
    Image => "image data"
    Opaque => "opaque data"
  }
}

///|
fn mime_groups(items : Array[Change]) -> Array[MimeGroup] {
  let groups : Map[String, Array[Change]] = Map([])
  for change in items {
    if change.mime_key() is Some(key) {
      if !groups.contains(key) {
        groups[key] = []
      }
      groups[key].push(change)
    }
  }
  let keys = groups.keys().to_array()
  keys.sort()
  keys.map(key => MimeGroup::{
    key,
    category: mime_category(key),
    changes: groups[key].map(Change::copy),
  })
}

///|
/// Group just MIME-addressed witnesses by exact key in deterministic key order.
/// Members preserve comparison order and are independent deep copies. This is
/// a query view: changes()/suppressed()/to_json() retain every other witness.
/// No renderer is selected, and no binary/HTML content is decoded or executed.
pub fn Comparison::mime_changes(self : Comparison) -> Array[MimeGroup] {
  mime_groups(self.items)
}

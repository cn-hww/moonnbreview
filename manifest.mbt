///|
/// One explicitly named pair of notebook files; paths are loader-defined.
#derive(Debug, Eq)
pub(all) struct ReviewPair {
  id : String
  old_path : String
  new_path : String
}

///|
pub struct Manifest {
  priv inputs : Array[ReviewPair]
}

///|
fn manifest_text(
  text : String,
  label : String,
  limit : Int32,
) -> Unit raise ReviewError {
  unicode(text)
  guard !text.is_empty() &&
    text.length() <= limit &&
    text.iter().all(c => c.to_int() >= 32 && c.to_int() != 127) else {
    raise Invalid(
      label +
      ": expected 1.." +
      limit.to_string() +
      " UTF-16 units without ASCII controls",
    )
  }
}

///|
/// A bounded, ordered manifest. Empty manifests are valid. IDs must be unique;
/// input arrays are copied. Paths are explicit, never globbed or inferred.
pub fn Manifest::new(pairs : Array[ReviewPair]) -> Manifest raise ReviewError {
  guard pairs.length() <= 64 else {
    raise Invalid("manifest permits at most 64 pairs")
  }
  let seen : Map[String, Unit] = Map([])
  for pair in pairs {
    manifest_text(pair.id, "pair ID", 128)
    manifest_text(pair.old_path, "old path", 4096)
    manifest_text(pair.new_path, "new path", 4096)
    guard !seen.contains(pair.id) else {
      raise Invalid("duplicate pair ID: " + pair.id)
    }
    seen[pair.id] = ()
  }
  { inputs: pairs.copy(), }
}

///|
pub fn Manifest::pairs(self : Manifest) -> Array[ReviewPair] {
  self.inputs.copy()
}

///|
pub fn Manifest::to_json(self : Manifest) -> String {
  canonical({
    "format": "moonnbreview/manifest-1",
    "pairs": Json(
      self.inputs.map(pair => {
        "id": Json(pair.id),
        "old": Json(pair.old_path),
        "new": Json(pair.new_path),
      }),
    ),
  })
}

///|
/// Strict manifest-1; unknown, duplicate or missing fields refuse atomically.
/// Existing strict JSON/Unicode checks and the 2M input limit apply.
pub fn Manifest::from_json(text : String) -> Manifest raise ReviewError {
  let fields = object(checked_json(text))
  guard fields.length() == 2 &&
    fields.get("format") == Some(Json("moonnbreview/manifest-1")) &&
    fields.get("pairs") is Some(Array(pairs)) else {
    raise Invalid("expected manifest-1 fields format and pairs only")
  }
  guard pairs.length() <= 64 else {
    raise Invalid("manifest permits at most 64 pairs")
  }
  let inputs = pairs.mapi((i, pair) => {
    let fields = object(pair)
    guard fields.length() == 3 &&
      fields.get("id") is Some(String(id)) &&
      fields.get("old") is Some(String(old_path)) &&
      fields.get("new") is Some(String(new_path)) else {
      raise Invalid(
        "/pairs/" + i.to_string() + ": expected id, old and new strings only",
      )
    }
    ReviewPair::{ id, old_path, new_path, }
  })
  Manifest::new(inputs)
}

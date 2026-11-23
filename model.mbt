///|
/// Domain categories. Order records relative order of retained IDs, not index shifts.
#derive(Debug, Eq)
pub(all) enum ChangeKind {
  Structure
  Order
  Source
  Output
  Attachment
  Metadata
  ExecutionCount
  Extension
}

///|
/// Explicit noise policy. Nothing is suppressed by default.
pub struct Policy {
  priv counts : Bool
  priv metadata_keys : Array[String]
}

///|
/// Construct an explicit policy. Metadata names match immediate keys exactly.
pub fn Policy::new(
  ignore_execution_counts~ : Bool = false,
  ignored_metadata_keys~ : Array[String] = [],
) -> Policy raise ReviewError {
  guard ignored_metadata_keys.length() <= 64 else {
    raise Invalid("at most 64 metadata keys may be ignored")
  }
  let keys = ignored_metadata_keys.copy()
  keys.sort()
  for i, key in keys {
    unicode(key)
    guard key.length() > 0 && key.length() <= 128 else {
      raise Invalid("metadata keys must contain 1..128 UTF-16 units")
    }
    guard i == 0 || keys[i - 1] != key else {
      raise Invalid("duplicate ignored metadata key")
    }
  }
  { counts: ignore_execution_counts, metadata_keys: keys, }
}

///|
/// A complete change witness. None means absent, distinct from Some(Json::Null).
#derive(Debug)
pub struct Change {
  kind : ChangeKind
  cell_id : String?
  path : String
  before : Json?
  after : Json?
  suppressed_by : String?
}

///|
pub struct Comparison {
  priv old : Document
  priv new : Document
  priv policy : Policy
  priv items : Array[Change]
}

///|
fn ChangeKind::label(self : ChangeKind) -> String {
  match self {
    Structure => "structure"
    Order => "order"
    Source => "source"
    Output => "output"
    Attachment => "attachment"
    Metadata => "metadata"
    ExecutionCount => "execution_count"
    Extension => "extension"
  }
}

///|
fn clone(value : Json) -> Json {
  match value {
    Object(fields) => {
      let out = Map([])
      for k, v in fields {
        out[k] = clone(v)
      }
      Json(out)
    }
    Array(items) => Json(items.map(clone))
    _ => value
  }
}

///|
fn Change::copy(self : Change) -> Change {
  { ..self, before: self.before.map(clone), after: self.after.map(clone), }
}

///|
/// Return active evidence with independently copied JSON payloads.
pub fn Comparison::changes(self : Comparison) -> Array[Change] {
  self.items.filter(c => c.suppressed_by is None).map(Change::copy)
}

///|
/// Return all suppressed evidence and the exact matching policy reason.
pub fn Comparison::suppressed(self : Comparison) -> Array[Change] {
  self.items.filter(c => c.suppressed_by is Some(_)).map(Change::copy)
}

///|
/// True when no unsuppressed change belongs to a blocked category.
/// Omit blocked to block every unsuppressed change.
pub fn Comparison::passes(
  self : Comparison,
  blocked~ : Array[ChangeKind] = [
    Structure,
    Order,
    Source,
    Output,
    Attachment,
    Metadata,
    ExecutionCount,
    Extension,
  ],
) -> Bool {
  !self.items
  .iter()
  .any(c => c.suppressed_by is None && blocked.contains(c.kind))
}

///|
fn Policy::json(self : Policy) -> Json {
  {
    "ignore_execution_counts": Json(self.counts),
    "ignored_metadata_keys": Json(self.metadata_keys),
  }
}

///|
fn Change::json(self : Change) -> Json {
  let fields : Map[String, Json] = {
    "kind": Json(self.kind.label()),
    "cell_id": self.cell_id.map(Json::string).unwrap_or(Json::null()),
    "path": Json(self.path),
    "suppressed_by": self.suppressed_by
    .map(Json::string)
    .unwrap_or(Json::null()),
  }
  if self.before is Some(v) {
    fields["before"] = clone(v)
  }
  if self.after is Some(v) {
    fields["after"] = clone(v)
  }
  Json(fields)
}

///|
/// Full report; rich payloads are retained. Reject oversize reports, never truncate.
pub fn Comparison::to_json(self : Comparison) -> String raise ReviewError {
  let report : Json = {
    "format": "moonnbreview/report-1",
    "policy": self.policy.json(),
    "changes": Json(
      self.items.filter(c => c.suppressed_by is None).map(Change::json),
    ),
    "suppressed": Json(
      self.items.filter(c => c.suppressed_by is Some(_)).map(Change::json),
    ),
  }
  let text = canonical(report)
  guard text.length() <= 8000000 else {
    raise Invalid("report exceeds 8000000 UTF-16 units; reduce input")
  }
  text
}

///|
/// Portable replay bundle binding both complete inputs and the exact policy.
pub fn Comparison::to_bundle(self : Comparison) -> String raise ReviewError {
  let old = checked_json(self.old.to_string())
  let new = checked_json(self.new.to_string())
  let text = canonical({
    "format": "moonnbreview/bundle-1",
    "old": old,
    "new": new,
    "policy": self.policy.json(),
  })
  guard text.length() <= 8000000 else {
    raise Invalid("bundle exceeds 8000000 UTF-16 units")
  }
  text
}

///|
/// Strictly reload a bundle and recompute all evidence. No cached verdict is trusted.
pub fn Comparison::from_bundle(text : String) -> Comparison raise ReviewError {
  guard text.length() <= 8000000 else {
    raise Invalid("bundle exceeds 8000000 UTF-16 units")
  }
  let raw = @json.parse(
    text[:],
    max_nesting_depth=68,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    e => raise Invalid(e.to_string())
  }
  validate_tree(raw, -4)
  let f = object(raw)
  guard f.length() == 4 &&
    f.get("format") == Some(Json("moonnbreview/bundle-1")) &&
    f.contains("old") &&
    f.contains("new") &&
    f.contains("policy") else {
    raise Invalid("expected bundle-1 fields format, old, new, policy only")
  }
  let p = object(f["policy"])
  guard p.length() == 2 &&
    p.get("ignore_execution_counts") is Some(flag) &&
    p.get("ignored_metadata_keys") is Some(Array(keys)) else {
    raise Invalid("invalid bundle policy")
  }
  let counts = match flag {
    True => true
    False => false
    _ => raise Invalid("expected boolean execution count policy")
  }
  let names = keys.map(k => {
    guard k is String(s) else { raise Invalid("expected metadata key string") }
    s
  })
  compare(
    Document::parse(canonical(f["old"])),
    Document::parse(canonical(f["new"])),
    policy=Policy::new(
      ignore_execution_counts=counts,
      ignored_metadata_keys=names,
    ),
  )
}

///|
/// Categories that block CI. This does not suppress or remove change evidence.
pub struct Gate {
  priv kinds : Array[ChangeKind]
}

///|
/// Omission blocks all categories. An explicitly empty array blocks none.
/// Duplicate categories are errors; the caller's array is copied.
pub fn Gate::new(
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
) -> Gate raise ReviewError {
  guard blocked.length() <= 8 else {
    raise Invalid("at most eight gate categories")
  }
  let names = blocked.map(ChangeKind::label)
  names.sort()
  let kinds = []
  for i, name in names {
    guard i == 0 || names[i - 1] != name else {
      raise Invalid("duplicate gate category: " + name)
    }
    kinds.push(gate_kind(name))
  }
  { kinds, }
}

///|
fn gate_kind(name : String) -> ChangeKind raise ReviewError {
  match name {
    "structure" => Structure
    "order" => Order
    "source" => Source
    "output" => Output
    "attachment" => Attachment
    "metadata" => Metadata
    "execution_count" => ExecutionCount
    "extension" => Extension
    _ => raise Invalid("unknown gate category: " + name)
  }
}

///|
/// An independent array suitable for Comparison::passes(blocked=...).
pub fn Gate::blocked(self : Gate) -> Array[ChangeKind] {
  self.kinds.copy()
}

///|
pub fn Gate::to_json(self : Gate) -> String {
  canonical({
    "format": "moonnbreview/gate-1",
    "blocked": Json(self.kinds.map(ChangeKind::label)),
  })
}

///|
/// Strict gate-1: both fields required; unknown/duplicate fields or categories
/// refuse. Input is capped at 8192 UTF-16 units before parsing.
pub fn Gate::from_json(text : String) -> Gate raise ReviewError {
  guard text.length() <= 8192 else {
    raise Invalid("gate file exceeds 8192 UTF-16 units")
  }
  let fields = object(checked_json(text))
  guard fields.length() == 2 &&
    fields.get("format") == Some(Json("moonnbreview/gate-1")) &&
    fields.get("blocked") is Some(Array(names)) else {
    raise Invalid("expected gate-1 fields format and blocked only")
  }
  guard names.length() <= 8 else {
    raise Invalid("at most eight gate categories")
  }
  let kinds = names.mapi((i, name) => {
    guard name is String(name) else {
      raise Invalid("/blocked/\{i}: expected category string")
    }
    gate_kind(name)
  })
  Gate::new(blocked=kinds)
}

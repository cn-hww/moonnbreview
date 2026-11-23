///|
/// Export a complete, versioned policy file for source control and CI.
/// This does not change the policy object embedded in report-1 and bundle-1.
pub fn Policy::to_json(self : Policy) -> String {
  canonical({
    "format": "moonnbreview/policy-1",
    "ignore_execution_counts": Json(self.counts),
    "ignored_metadata_keys": Json(self.metadata_keys),
  })
}

///|
/// Load policy-1 strictly. Unknown fields, duplicate keys, omitted fields,
/// incorrect types and unknown versions are errors, never implicit defaults.
pub fn Policy::from_json(text : String) -> Policy raise ReviewError {
  let fields = object(checked_json(text))
  guard fields.length() == 3 &&
    fields.get("format") == Some(Json("moonnbreview/policy-1")) &&
    fields.get("ignore_execution_counts") is Some(flag) &&
    fields.get("ignored_metadata_keys") is Some(Array(keys)) else {
    raise Invalid(
      "expected policy-1 fields format, ignore_execution_counts, ignored_metadata_keys only",
    )
  }
  let counts = match flag {
    True => true
    False => false
    _ => raise Invalid("/ignore_execution_counts: expected boolean")
  }
  let names = keys.mapi((i, key) => {
    guard key is String(name) else {
      raise Invalid("/ignored_metadata_keys/\{i}: expected string")
    }
    name
  })
  Policy::new(ignore_execution_counts=counts, ignored_metadata_keys=names)
}

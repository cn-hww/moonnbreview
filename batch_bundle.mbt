///|
/// Export retained inputs. Ordinary reviews do not retain them unless requested.
pub fn BatchReview::to_bundle(self : BatchReview) -> String raise ReviewError {
  guard self.bundle is Some(bundle) else {
    raise Invalid(
      "batch inputs were not retained; review with retain_inputs=true",
    )
  }
  bundle
}

///|
/// Recompute every successful comparison and gate from a strict batch-bundle-1.
/// Archived external/parse failures remain errors; they cannot produce a pass.
/// No filesystem reads and no cached report/status/verdict are trusted.
pub fn BatchReview::from_bundle(text : String) -> BatchReview raise ReviewError {
  guard text.length() <= 8000000 else {
    raise Invalid("batch bundle exceeds 8000000 UTF-16 units")
  }
  unicode(text)
  let value = @json.parse(
    text[:],
    max_nesting_depth=74,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    e => raise Invalid("invalid batch bundle JSON: " + e.to_string())
  }
  validate_tree(value, -10)
  let root = object(value)
  guard root.length() == 4 &&
    (
      root.get("format") == Some(Json("moonnbreview/batch-bundle-1")) ||
      root.get("format") == Some(Json("moonnbreview/batch-bundle-2"))
    ) &&
    root.contains("policy") &&
    root.contains("gate") &&
    root.get("entries") is Some(Array(entries)) else {
    raise Invalid(
      "expected batch-bundle-1/2 fields format, policy, gate and entries only",
    )
  }
  guard entries.length() <= 64 else {
    raise Invalid("batch bundle permits at most 64 entries")
  }
  let policy = Policy::from_json(canonical(root["policy"]))
  let file_mode = root["format"] == Json("moonnbreview/batch-bundle-2")
  let gate = Gate::from_json(canonical(root["gate"]))
  let pairs = entries.mapi((i, entry) => {
    let fields = object(entry)
    guard fields.length() == 4 &&
      fields.get("id") is Some(String(id)) &&
      fields.contains("old") &&
      fields.contains("new") &&
      fields.contains("comparison") != fields.contains("diagnostic") else {
      raise Invalid(
        "/entries/" +
        i.to_string() +
        ": expected id, old, new and exactly one comparison or diagnostic",
      )
    }
    let old_path = file_path(fields["old"])
    let new_path = file_path(fields["new"])
    guard file_mode || (old_path is Some(_) && new_path is Some(_)) else {
      raise Invalid("batch-bundle-1 requires two present paths")
    }
    FilePair::{ id, old_path, new_path, }
  })
  let manifest = FileManifest::new(pairs)
  let writer = batch_writer(policy, gate, true, file_mode~)
  for i, pair in manifest.items {
    let fields = object(entries[i])
    if fields.get("comparison") is Some(bundle) {
      let c = Comparison::from_bundle(canonical(bundle))
      guard (pair.old_path is Some(_)) == (c.old is Some(_)) &&
        (pair.new_path is Some(_)) == (c.new is Some(_)) else {
        raise Invalid(
          "/entries/" +
          i.to_string() +
          ": retained comparison presence disagrees with file paths",
        )
      }
      guard c.policy.to_json() == policy.to_json() else {
        raise Invalid(
          "/entries/" +
          i.to_string() +
          ": comparison policy differs from batch policy",
        )
      }
      let status = if c.passes(blocked=gate.blocked()) {
        "passed"
      } else {
        "blocked"
      }
      writer.push_file(
        pair,
        status,
        "\"report\":" + c.to_json(),
        "\"comparison\":" + c.to_bundle(),
      )
    } else {
      let diagnostic = object(fields["diagnostic"])
      guard diagnostic.length() == 2 &&
        diagnostic.get("phase") is Some(String(phase)) &&
        diagnostic.get("message") is Some(String(_)) &&
        [
          "read_old", "parse_old", "read_new", "parse_new", "compare", "serialize",
        ].contains(phase) else {
        raise Invalid(
          "/entries/" + i.to_string() + ": invalid recorded diagnostic",
        )
      }
      let detail = "\"diagnostic\":" + canonical(Json(diagnostic))
      guard (
          !["read_old", "parse_old"].contains(phase) || pair.old_path is Some(_)
        ) &&
        (!["read_new", "parse_new"].contains(phase) || pair.new_path is Some(_)) else {
        raise Invalid(
          "/entries/" +
          i.to_string() +
          ": diagnostic cannot read an explicitly absent side",
        )
      }
      writer.push_file(pair, "error", detail, detail)
    }
  }
  writer.finish()
}

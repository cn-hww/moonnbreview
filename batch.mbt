///|
/// An immutable complete batch report. Any per-pair failure takes precedence
/// over gate failures. This type cannot import/trust a saved verdict.
pub struct BatchReview {
  priv report : String
  priv code : Int32
}

///|
pub fn BatchReview::to_json(self : BatchReview) -> String {
  self.report
}

///|
/// 0: all pairs passed; 1: active blocked changes; 2: at least one pair failed.
pub fn BatchReview::exit_code(self : BatchReview) -> Int32 {
  self.code
}

///|
/// Review every explicit pair, in manifest order. Loader/parse/compare errors
/// become per-pair diagnostics and processing continues. No failed input is
/// treated as empty or silently skipped. Aggregate output above 8M UTF-16 units
/// raises instead of returning partial evidence. Loader memory is caller-owned.
pub fn Manifest::review(
  self : Manifest,
  read : (String) -> String raise,
  policy~ : Policy = Policy::{ counts: false, metadata_keys: [], },
  gate~ : Gate = Gate::new(),
) -> BatchReview raise ReviewError {
  let entries = []
  let mut size = 0
  let mut passed = 0
  let mut blocked = 0
  let mut failed = 0
  for pair in self.inputs {
    let mut phase = "read_old"
    let (status, detail) = try {
      let old_text = read(pair.old_path)
      phase = "parse_old"
      let old = Document::parse(old_text)
      phase = "read_new"
      let new_text = read(pair.new_path)
      phase = "parse_new"
      let new = Document::parse(new_text)
      phase = "compare"
      let c = compare(old, new, policy~)
      phase = "serialize"
      let report = c.to_json()
      (
        if c.passes(blocked=gate.blocked()) {
          "passed"
        } else {
          "blocked"
        },
        "\"report\":" + report,
      )
    } catch {
      e =>
        (
          "error",
          "\"diagnostic\":" +
          canonical({ "phase": Json(phase), "message": Json("\{Repr(e)}") }),
        )
    }
    match status {
      "passed" => passed += 1
      "blocked" => blocked += 1
      _ => failed += 1
    }
    let context = canonical({
      "id": Json(pair.id),
      "old": Json(pair.old_path),
      "new": Json(pair.new_path),
      "status": Json(status),
    })
    let entry = context[:context.length() - 1].to_owned() + "," + detail + "}"
    guard entry.length() <= 8000000 - size else {
      raise Invalid(
        "batch report exceeds 8000000 UTF-16 units; split the manifest",
      )
    }
    size += entry.length()
    entries.push(entry)
  }
  let header = canonical({
    "format": "moonnbreview/batch-1",
    "policy": checked_json(policy.to_json()),
    "gate": checked_json(gate.to_json()),
    "summary": {
      "total": Json(self.inputs.length()),
      "passed": Json(passed),
      "blocked": Json(blocked),
      "failed": Json(failed),
    },
  })
  let tail = ",\"results\":[" + entries.join(",") + "]}"
  guard tail.length() <= 8000000 - header.length() + 1 else {
    raise Invalid(
      "batch report exceeds 8000000 UTF-16 units; split the manifest",
    )
  }
  {
    report: header[:header.length() - 1].to_owned() + tail,
    code: if failed > 0 {
      2
    } else if blocked > 0 {
      1
    } else {
      0
    },
  }
}

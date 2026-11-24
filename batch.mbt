///|
/// An immutable complete batch report. Any per-pair failure takes precedence
/// over gate failures. This type cannot import/trust a saved verdict.
pub struct BatchReview {
  priv report : String
  priv code : Int32
  priv bundle : String?
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
priv struct BatchWriter {
  policy : Policy
  gate : Gate
  retain : Bool
  entries : Array[String]
  saved : Array[String]
  mut size : Int32
  mut saved_size : Int32
  mut passed : Int32
  mut blocked : Int32
  mut failed : Int32
}

///|
fn batch_writer(policy : Policy, gate : Gate, retain : Bool) -> BatchWriter {
  {
    policy,
    gate,
    retain,
    entries: [],
    saved: [],
    size: 0,
    saved_size: 0,
    passed: 0,
    blocked: 0,
    failed: 0,
  }
}

///|
fn batch_context(pair : ReviewPair) -> Json {
  {
    "id": Json(pair.id),
    "old": Json(pair.old_path),
    "new": Json(pair.new_path),
  }
}

///|
fn with_detail(context : String, detail : String) -> String {
  context[:context.length() - 1].to_owned() + "," + detail + "}"
}

///|
fn BatchWriter::push(
  self : BatchWriter,
  pair : ReviewPair,
  status : String,
  detail : String,
  saved_detail : String,
) -> Unit raise ReviewError {
  let entry = with_detail(
    canonical({
      "id": Json(pair.id),
      "old": Json(pair.old_path),
      "new": Json(pair.new_path),
      "status": Json(status),
    }),
    detail,
  )
  guard entry.length() <= 8000000 - self.size else {
    raise Invalid(
      "batch report exceeds 8000000 UTF-16 units; split the manifest",
    )
  }
  self.size += entry.length()
  self.entries.push(entry)
  if self.retain {
    let saved = with_detail(canonical(batch_context(pair)), saved_detail)
    guard saved.length() <= 8000000 - self.saved_size else {
      raise Invalid(
        "batch bundle exceeds 8000000 UTF-16 units; split the manifest",
      )
    }
    self.saved_size += saved.length()
    self.saved.push(saved)
  }
  match status {
    "passed" => self.passed += 1
    "blocked" => self.blocked += 1
    _ => self.failed += 1
  }
}

///|
fn BatchWriter::finish(self : BatchWriter) -> BatchReview raise ReviewError {
  let header = canonical({
    "format": "moonnbreview/batch-1",
    "policy": checked_json(self.policy.to_json()),
    "gate": checked_json(self.gate.to_json()),
    "summary": {
      "total": Json(self.entries.length()),
      "passed": Json(self.passed),
      "blocked": Json(self.blocked),
      "failed": Json(self.failed),
    },
  })
  let report = with_detail(
    header,
    "\"results\":[" + self.entries.join(",") + "]",
  )
  guard report.length() <= 8000000 else {
    raise Invalid(
      "batch report exceeds 8000000 UTF-16 units; split the manifest",
    )
  }
  let bundle = if self.retain {
    let header = canonical({
      "format": "moonnbreview/batch-bundle-1",
      "policy": checked_json(self.policy.to_json()),
      "gate": checked_json(self.gate.to_json()),
    })
    let saved = with_detail(
      header,
      "\"entries\":[" + self.saved.join(",") + "]",
    )
    guard saved.length() <= 8000000 else {
      raise Invalid(
        "batch bundle exceeds 8000000 UTF-16 units; split the manifest",
      )
    }
    Some(saved)
  } else {
    None
  }
  {
    report,
    bundle,
    code: if self.failed > 0 {
      2
    } else if self.blocked > 0 {
      1
    } else {
      0
    },
  }
}

///|
fn batch_serialization(
  c : Comparison,
  gate : Gate,
  retain : Bool,
) -> (String, String, String) raise ReviewError {
  let report = c.to_json()
  (
    if c.passes(blocked=gate.blocked()) {
      "passed"
    } else {
      "blocked"
    },
    "\"report\":" + report,
    if retain {
      "\"comparison\":" + c.to_bundle()
    } else {
      ""
    },
  )
}

///|
fn batch_diagnostic(
  phase : String,
  message : String,
) -> (String, String, String) {
  let diagnostic = "\"diagnostic\":" +
    canonical({ "phase": Json(phase), "message": Json(message) })
  ("error", diagnostic, diagnostic)
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
  retain_inputs~ : Bool = false,
) -> BatchReview raise ReviewError {
  self.review_sides(read, read, policy~, gate~, retain_inputs~)
}

///|
/// Compare two independent namespaces, allowing the same literal path to name
/// different revisions. Each pair loads/parses old before loading/parsing new;
/// errors retain their side and phase and later pairs still run. No caching or
/// path rewriting is performed. Retention, budgets and gate semantics match review.
pub fn Manifest::review_sides(
  self : Manifest,
  read_old : (String) -> String raise,
  read_new : (String) -> String raise,
  policy~ : Policy = Policy::{ counts: false, metadata_keys: [], },
  gate~ : Gate = Gate::new(),
  retain_inputs~ : Bool = false,
) -> BatchReview raise ReviewError {
  let writer = batch_writer(policy, gate, retain_inputs)
  for pair in self.inputs {
    let mut phase = "read_old"
    let (status, detail, saved) = try {
      let old_text = read_old(pair.old_path)
      phase = "parse_old"
      let old = Document::parse(old_text)
      phase = "read_new"
      let new_text = read_new(pair.new_path)
      phase = "parse_new"
      let new = Document::parse(new_text)
      phase = "compare"
      let c = compare(old, new, policy~)
      phase = "serialize"
      batch_serialization(c, gate, retain_inputs)
    } catch {
      e => batch_diagnostic(phase, "\{Repr(e)}")
    }
    writer.push(pair, status, detail, saved)
  }
  writer.finish()
}

///|
/// Serial, asynchronous counterpart of review_sides. Callbacks may perform IO
/// without preloading the batch. Each pair keeps the same phase/error semantics,
/// complete evidence and aggregate limits as the synchronous workflow.
pub async fn Manifest::review_sides_async(
  self : Manifest,
  read_old : async (String) -> String,
  read_new : async (String) -> String,
  policy~ : Policy = Policy::{ counts: false, metadata_keys: [], },
  gate~ : Gate = Gate::new(),
  retain_inputs~ : Bool = false,
) -> BatchReview {
  let writer = batch_writer(policy, gate, retain_inputs)
  for pair in self.inputs {
    let mut phase = "read_old"
    let (status, detail, saved) = try {
      let old_text = read_old(pair.old_path)
      phase = "parse_old"
      let old = Document::parse(old_text)
      phase = "read_new"
      let new_text = read_new(pair.new_path)
      phase = "parse_new"
      let new = Document::parse(new_text)
      phase = "compare"
      let c = compare(old, new, policy~)
      phase = "serialize"
      batch_serialization(c, gate, retain_inputs)
    } catch {
      e => batch_diagnostic(phase, "\{Repr(e)}")
    }
    writer.push(pair, status, detail, saved)
  }
  writer.finish()
}

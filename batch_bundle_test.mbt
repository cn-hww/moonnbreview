///|
fn batch_bundle_refused(text : String) -> Bool {
  try {
    ignore(@review.BatchReview::from_bundle(text))
    false
  } catch {
    _ => true
  }
}

///|
fn saved_batch() -> String raise {
  @review.Manifest::new([pair("source")])
  .review(load_pair, retain_inputs=true)
  .to_bundle()
}

///|
test "retained batch round trips preserve report bytes policies gates and verdicts" {
  let m = @review.Manifest::new([pair("changed"), pair("same", new_path="old")])
  let p = @review.Policy::new(ignore_execution_counts=true)
  let g = @review.Gate::new(blocked=[@review.Source])
  let ordinary = m.review(load_pair, policy=p, gate=g)
  let retained = m.review(load_pair, policy=p, gate=g, retain_inputs=true)
  assert_eq(retained.to_json(), ordinary.to_json())
  let bundle = retained.to_bundle()
  let replay = @review.BatchReview::from_bundle(bundle)
  assert_eq(replay.to_json(), retained.to_json())
  assert_eq(replay.exit_code(), 1)
  assert_eq(replay.to_bundle(), bundle)
  assert_eq(
    m.review(load_pair, policy=p, gate=g, retain_inputs=true).to_bundle(),
    bundle,
  )
  let no_capture = try {
    ignore(ordinary.to_bundle())
    false
  } catch {
    _ => true
  }
  assert_true(no_capture)
}

///|
test "recorded failures survive replay after storage disappears and cannot become passes" {
  let files : Map[String, String] = Map([])
  files["old"] = load_pair("old")
  files["new"] = load_pair("new")
  let m = @review.Manifest::new([
    pair("missing", old_path="gone"),
    pair("valid"),
  ])
  let original = m.review(
    path => {
      guard files.get(path) is Some(text) else { fail("missing " + path) }
      text
    },
    retain_inputs=true,
  )
  let bundle = original.to_bundle()
  files.clear()
  let replay = @review.BatchReview::from_bundle(bundle)
  assert_eq(replay.exit_code(), 2)
  assert_eq(replay.to_json(), original.to_json())
  assert_eq(replay.to_bundle(), bundle)
  assert_eq(
    @review.BatchReview::from_bundle(
      bundle.replace(old="missing gone", new="passed"),
    ).exit_code(),
    2,
  )
}

///|
test "batch replay recomputes gate evaluation and rejects cached verdict injection" {
  let bundle = saved_batch()
  guard @json.parse(bundle) is Object(root) &&
    root["gate"] is Object(gate) &&
    root["entries"] is Array(entries) &&
    entries[0] is Object(first) else {
    abort("bad bundle")
  }
  gate["blocked"] = Json::array([])
  let replay = @review.BatchReview::from_bundle(Json(root).stringify())
  assert_eq(replay.exit_code(), 0)
  assert_true(replay.to_json().contains("\"changes\":[{"))
  first["status"] = Json("passed")
  assert_true(batch_bundle_refused(Json(root).stringify()))
}

///|
test "batch bundle policy must match every embedded comparison policy" {
  guard @json.parse(saved_batch()) is Object(root) &&
    root["entries"] is Array(entries) &&
    entries[0] is Object(first) &&
    first["comparison"] is Object(comparison) &&
    comparison["policy"] is Object(policy) else {
    abort("bad comparison")
  }
  policy["ignore_execution_counts"] = Json(true)
  assert_true(batch_bundle_refused(Json(root).stringify()))
}

///|
test "bundle fields versions diagnostic shapes duplicates and malformed text are closed" {
  let valid = saved_batch()
  for
    text in [
      "{",
      "{}",
      "[]",
      valid.replace(old="batch-bundle-1", new="batch-bundle-2"),
      valid.replace(old="\"entries\":", new="\"summary\":{},\"entries\":"),
      valid.replace(old="\"entries\":", new="\"\\u0065ntries\":[],\"entries\":"),
      valid.replace(old="\"id\":\"source\"", new="\"id\":\"\\ud800\""),
      " ".repeat(8000001),
    ] {
    assert_true(batch_bundle_refused(text))
  }
  let error = @review.Manifest::new([pair("bad", old_path="gone")])
    .review(load_pair, retain_inputs=true)
    .to_bundle()
  for
    text in [
      error.replace(old="read_old", new="unknown_phase"),
      error.replace(old="\"phase\":", new="\"extra\":0,\"phase\":"),
      error.replace(
        old="\"diagnostic\":",
        new="\"comparison\":{},\"diagnostic\":",
      ),
    ] {
    assert_true(batch_bundle_refused(text))
  }
  assert_eq(@review.BatchReview::from_bundle(valid).exit_code(), 1)
}

///|
test "batch bundle duplicate IDs and pair-count limits refuse without partial results" {
  guard @json.parse(saved_batch()) is Object(root) &&
    root["entries"] is Array(entries) else {
    abort("bad entries")
  }
  entries.push(entries[0])
  assert_true(batch_bundle_refused(Json(root).stringify()))
  let large = @review.Manifest::new(Array::makei(64, i => pair(i.to_string()))).review(
    load_pair,
    retain_inputs=true,
  )
  assert_eq(
    @review.BatchReview::from_bundle(large.to_bundle()).to_json(),
    large.to_json(),
  )
  guard @json.parse(large.to_bundle()) is Object(lr) &&
    lr["entries"] is Array(le) else {
    abort("bad large bundle")
  }
  le.push(le[0])
  assert_true(batch_bundle_refused(Json(lr).stringify()))
  let empty = @review.Manifest::new([]).review(load_pair, retain_inputs=true)
  assert_eq(
    @review.BatchReview::from_bundle(empty.to_bundle()).to_json(),
    empty.to_json(),
  )
}

///|
test "retained-input budget refuses large unchanged batches rather than dropping inputs" {
  let big = notebook([cell("a", source="x".repeat(1100000))])
  let m = @review.Manifest::new(Array::makei(4, i => pair(i.to_string())))
  assert_eq(m.review(_ => big).exit_code(), 0)
  let refused = try {
    ignore(m.review(_ => big, retain_inputs=true))
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  assert_eq(@review.BatchReview::from_bundle(saved_batch()).exit_code(), 1)
}

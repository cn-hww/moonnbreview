///|
test "independent namespaces compare identical paths without aliasing" {
  let m = @review.Manifest::new([
    pair("lesson", old_path="same", new_path="same"),
  ])
  let old = notebook([cell("a")])
  let new = notebook([cell("a", source="revised")])
  let batch = m.review_sides(_ => old, _ => new, retain_inputs=true)
  assert_eq(batch.exit_code(), 1)
  let replay = @review.BatchReview::from_bundle(batch.to_bundle())
  assert_eq(replay.to_json(), batch.to_json())
  guard @json.parse(batch.to_json()) is Object(root) &&
    root["results"] is Array(entries) &&
    entries[0] is Object(entry) else {
    abort("missing pair")
  }
  assert_eq(entry["report"], @json.parse(compare(old, new).to_json()))
}

///|
test "split loaders preserve existing report and bundle bytes" {
  let m = @review.Manifest::new([pair("change"), pair("same", new_path="old")])
  let policy = @review.Policy::new(ignore_execution_counts=true)
  let gate = @review.Gate::new(blocked=[@review.Output])
  let before = m.review(load_pair, policy~, gate~, retain_inputs=true)
  let after = m.review_sides(
    load_pair,
    load_pair,
    policy~,
    gate~,
    retain_inputs=true,
  )
  assert_eq(after.to_json(), before.to_json())
  assert_eq(after.to_bundle(), before.to_bundle())
  assert_eq(after.exit_code(), before.exit_code())
}

///|
test "load order is old then new and failed old never reads new" {
  let calls : Array[String] = []
  let m = @review.Manifest::new([
    pair("fail", old_path="gone", new_path="skip"),
    pair("ok", old_path="old", new_path="new"),
  ])
  let b = m.review_sides(
    path => {
      calls.push("old:" + path)
      load_pair(path)
    },
    path => {
      calls.push("new:" + path)
      load_pair(path)
    },
  )
  assert_eq(calls, ["old:gone", "old:old", "new:new"])
  assert_eq(b.exit_code(), 2)
  assert_true(b.to_json().contains("read_old"))
  assert_true(b.to_json().contains("\"status\":\"blocked\""))
}

///|
test "new loader errors and both parse errors retain exact side phases" {
  let m = @review.Manifest::new([
    pair("old-format", old_path="invalid"),
    pair("new-read", new_path="gone"),
    pair("new-format", new_path="invalid"),
    pair("recovery", new_path="old"),
  ])
  let b = m.review_sides(load_pair, load_pair, retain_inputs=true)
  assert_eq(b.exit_code(), 2)
  guard @json.parse(b.to_json()) is Object(root) &&
    root["results"] is Array(entries) else {
    abort("missing results")
  }
  for i, phase in ["parse_old", "read_new", "parse_new"] {
    guard entries[i] is Object(entry) &&
      entry["diagnostic"] is Object(diagnostic) else {
      abort("missing diagnostic")
    }
    assert_eq(diagnostic["phase"], Json(phase))
  }
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
  let expected : Json = { "total": 4, "passed": 1, "blocked": 0, "failed": 3 }
  assert_eq(root["summary"], expected)
}

///|
test "split loaders honor suppression and gate without dropping evidence" {
  let m = @review.Manifest::new([pair("rerun")])
  let b = m.review_sides(
    _ => notebook([cell("a", count=1)]),
    _ => notebook([cell("a", count=2, source="revised")]),
    policy=@review.Policy::new(ignore_execution_counts=true),
    gate=@review.Gate::new(blocked=[@review.Output]),
  )
  assert_eq(b.exit_code(), 0)
  assert_true(b.to_json().contains("\"suppressed\":[{"))
  assert_true(b.to_json().contains("\"kind\":\"source\""))
}

///|
test "empty split batch invokes neither loader and retains replay" {
  let b = @review.Manifest::new([]).review_sides(
    _ => fail("unexpected old"),
    _ => fail("unexpected new"),
    retain_inputs=true,
  )
  assert_eq(b.exit_code(), 0)
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
}

///|
fn pair(
  id : String,
  old_path~ : String = "old",
  new_path~ : String = "new",
) -> @review.ReviewPair {
  { id, old_path, new_path, }
}

///|
fn load_pair(path : String) -> String raise {
  match path {
    "old" => notebook([cell("a")])
    "new" => notebook([cell("a", source="changed")])
    "invalid" => "{broken"
    _ => fail("missing file: " + path)
  }
}

///|
fn manifest_refused(text : String) -> Bool {
  try {
    ignore(@review.Manifest::from_json(text))
    false
  } catch {
    _ => true
  }
}

///|
test "manifest round trips preserve order and defensive array boundaries" {
  let pairs = [pair("b"), pair("a")]
  let m = @review.Manifest::new(pairs)
  pairs.clear()
  m.pairs().clear()
  assert_eq(m.pairs().map(p => p.id), ["b", "a"])
  assert_eq(@review.Manifest::from_json(m.to_json()).to_json(), m.to_json())
  assert_eq(@review.Manifest::from_json(m.to_json()).pairs(), m.pairs())
}

///|
test "batch evidence matches single comparisons and deterministic gate evaluation" {
  let m = @review.Manifest::new([pair("source")])
  let batch = m.review(load_pair)
  assert_eq(batch.exit_code(), 1)
  guard @json.parse(batch.to_json()) is Object(root) &&
    root["results"] is Array(results) &&
    results[0] is Object(item) else {
    abort("bad batch")
  }
  let c = compare(load_pair("old"), load_pair("new"))
  assert_eq(item["report"], @json.parse(c.to_json()))
  assert_eq(batch.to_json(), m.review(load_pair).to_json())
  let allowed = m.review(
    load_pair,
    gate=@review.Gate::new(blocked=[@review.Output]),
  )
  assert_eq(allowed.exit_code(), 0)
  guard @json.parse(allowed.to_json()) is Object(a) &&
    a["results"] is Array(items) &&
    items[0] is Object(first) else {
    abort("bad gate result")
  }
  assert_eq(first["report"], item["report"])
}

///|
test "per-file failures never skip later pairs and take precedence over blocked changes" {
  let m = @review.Manifest::new([
    pair("missing", old_path="gone"),
    pair("malformed", new_path="invalid"),
    pair("blocked"),
    pair("same", new_path="old"),
  ])
  let batch = m.review(load_pair)
  assert_eq(batch.exit_code(), 2)
  guard @json.parse(batch.to_json()) is Object(root) &&
    root["results"] is Array(items) else {
    abort("bad report")
  }
  assert_eq(items.length(), 4)
  let expected : Json = { "total": 4, "passed": 1, "blocked": 1, "failed": 2 }
  assert_eq(root["summary"], expected)
  assert_true(batch.to_json().contains("read_old"))
  assert_true(batch.to_json().contains("parse_new"))
  assert_true(batch.to_json().contains("missing file: gone"))
}

///|
test "explicit empty manifests succeed without calling the loader" {
  let m = @review.Manifest::new([])
  let batch = m.review(_ => fail("must not load"))
  assert_eq(batch.exit_code(), 0)
  assert_true(batch.to_json().contains("\"results\":[]"))
}

///|
test "manifest rejects unknown missing duplicate and mistyped fields" {
  let valid = @review.Manifest::new([pair("a")]).to_json()
  for
    text in [
      "{",
      "{}",
      "[]",
      valid.replace(old="manifest-1", new="manifest-2"),
      valid.replace(old="\"pairs\":", new="\"extra\":true,\"pairs\":"),
      valid.replace(old="\"old\":\"old\"", new="\"old\":1"),
      valid.replace(
        old="\"old\":\"old\"",
        new="\"old\":\"old\",\"\\u006fld\":\"new\"",
      ),
      valid.replace(old="\"id\":\"a\"", new="\"typo\":\"a\""),
      valid.replace(old="\"new\":\"new\"", new="\"new\":\"new\",\"extra\":0"),
      valid.replace(old="\"new\":\"new\"", new="\"new\":\"\\ud800\""),
    ] {
    assert_true(manifest_refused(text))
  }
}

///|
test "pair limits empty strings controls Unicode and duplicate identities are explicit" {
  let pairs = Array::makei(64, i => pair(i.to_string()))
  assert_eq(@review.Manifest::new(pairs).pairs().length(), 64)
  pairs.push(pair("overflow"))
  for
    inputs in [
      pairs,
      [pair("same"), pair("same")],
      [pair("")],
      [pair("a", old_path="")],
      [pair("a", new_path="x\u0000")],
      [pair("a\n")],
      [pair("x".repeat(129))],
      [pair("a", new_path="x".repeat(4097))],
    ] {
    let bad = try {
      ignore(@review.Manifest::new(inputs))
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
  ignore(
    @review.Manifest::new([
      pair("课😀", old_path="x".repeat(4096), new_path="C:/课/lesson.ipynb"),
    ]),
  )
}

///|
test "policy suppression remains recorded inside complete per-pair reports" {
  let m = @review.Manifest::new([pair("rerun")])
  let batch = m.review(
    path => notebook([cell("a", count=if path == "old" { 1 } else { 2 })]),
    policy=@review.Policy::new(ignore_execution_counts=true),
  )
  assert_eq(batch.exit_code(), 0)
  assert_true(batch.to_json().contains("ignore_execution_counts"))
  assert_true(batch.to_json().contains("\"suppressed\":[{"))
}

///|
test "aggregate budget refuses complete batch rather than dropping evidence and recovers" {
  let m = @review.Manifest::new(Array::makei(6, i => pair(i.to_string())))
  let big = notebook([cell("a", source="x".repeat(1600000))])
  let bad = try {
    ignore(m.review(path => if path == "new" { big } else { load_pair(path) }))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  assert_eq(
    @review.Manifest::new([pair("recovery", new_path="old")])
    .review(load_pair)
    .exit_code(),
    0,
  )
}

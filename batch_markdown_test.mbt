///|
test "batch Markdown works without retention and includes every outcome and exact configuration" {
  let m = @review.Manifest::new([
    pair("missing", old_path="gone"),
    pair("blocked"),
    pair("same", new_path="old"),
  ])
  let b = m.review(load_pair)
  let json = b.to_json()
  let md = b.to_markdown()
  for
    text in [
      "Exit code: 2", "## Summary", "## Configuration", "moonnbreview/policy-1",
      "moonnbreview/gate-1", "## Notebook 1: error", "## Notebook 2: blocked", "## Notebook 3: passed",
      "read_old", "missing file: gone", "\"id\":\"missing\"", "\"old\":\"old\"",
      "\"new\":\"new\"", "#### 1. source", "### Active changes: 0",
    ] {
    assert_true(md.contains(text))
  }
  assert_eq(b.to_json(), json)
  assert_eq(b.exit_code(), 2)
  assert_eq(b.to_markdown(), md)
}

///|
test "batch Markdown equals retained replay and preserves all archive bytes" {
  let b = @review.Manifest::new([
    pair("change"),
    pair("error", new_path="invalid"),
  ]).review(load_pair, retain_inputs=true)
  let json = b.to_json()
  let bundle = b.to_bundle()
  let replay = @review.BatchReview::from_bundle(bundle)
  for focus in [false, true] {
    assert_eq(
      replay.to_markdown(focus_changes=focus),
      b.to_markdown(focus_changes=focus),
    )
  }
  assert_eq(b.to_json(), json)
  assert_eq(b.to_bundle(), bundle)
}

///|
test "passed gates still display active witnesses and explicit suppressed reasons" {
  let b = @review.Manifest::new([pair("rerun")]).review_sides(
    _ => notebook([cell("a", count=1)]),
    _ => notebook([cell("a", count=2, source="revised")]),
    policy=@review.Policy::new(ignore_execution_counts=true),
    gate=@review.Gate::new(blocked=[@review.Output]),
  )
  let md = b.to_markdown()
  assert_true(md.contains("## Notebook 1: passed"))
  assert_true(md.contains("### Active changes: 1"))
  assert_true(md.contains("### Suppressed changes: 1"))
  assert_true(md.contains("#### 1. source"))
  assert_true(md.contains("ignore_execution_counts"))
}

///|
test "hostile identifiers paths values and diagnostics stay in adaptive literal fences" {
  let hostile = "~~~~\n# injected\n<script>alert(1)</script>\n![x](https://example.invalid)\r\u001b"
  let b = @review.Manifest::new([
    pair("<tag>~~~~", old_path="[old](url)", new_path="<script>"),
  ]).review_sides(_ => notebook([cell("a")]), _ => {
    notebook([cell("a", source=hostile)])
  })
  let md = b.to_markdown()
  assert_true(
    md.contains(
      "~~~~~text\n" +
      hostile
      .replace_all(old="\r", new="\\u000d")
      .replace_all(old="\u001b", new="\\u001b") +
      "\n~~~~~",
    ),
  )
  assert_true(md.contains("\"id\":\"<tag>~~~~\""))
  let error = @review.Manifest::new([pair("error")])
    .review(_ => fail(hostile))
    .to_markdown()
  assert_true(error.contains("### Diagnostic"))
  assert_false(error.contains("\n# injected\n"))
}

///|
test "batch previews respect Unicode bounds focus on late edits and validate budgets" {
  let m = @review.Manifest::new([pair("long")])
  let b = m.review_sides(
    _ => notebook([cell("a", source="a".repeat(31) + "😀x")]),
    _ => notebook([cell("a", source="a".repeat(31) + "😀y")]),
  )
  let short = b.to_markdown(preview_chars=32)
  assert_true(short.contains("Preview omitted 3 UTF-16 units"))
  assert_false(short.contains("😀"))
  let focused = b.to_markdown(preview_chars=32, focus_changes=true)
  assert_true(focused.contains("😀x"))
  assert_true(focused.contains("😀y"))
  assert_true(focused.contains("Preview range:"))
  assert_true(focused.contains("later edits may be omitted"))
  ignore(b.to_markdown(preview_chars=4096))
  for budget in [0, 31, 4097] {
    assert_true(
      try {
        ignore(b.to_markdown(preview_chars=budget))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "batch Markdown distinguishes absent values from JSON null and handles zero pairs" {
  let old = notebook([])
  guard @json.parse(old) is Object(root) else { abort("bad fixture") }
  root["vendor"] = Json::null()
  let b = @review.Manifest::new([pair("null")]).review_sides(_ => old, _ => {
    Json(root).stringify()
  })
  let md = b.to_markdown()
  assert_true(md.contains("Before:\n\nAbsent."))
  assert_true(md.contains("After:\n\n~~~json\nnull\n~~~"))
  let empty = @review.Manifest::new([]).review(_ => fail("no IO")).to_markdown()
  assert_true(empty.contains("Exit code: 0"))
  assert_true(empty.contains("No notebook pairs."))
}

///|
test "batch Markdown refuses aggregate overflow without dropping diagnostics and recovers" {
  let m = @review.Manifest::new(Array::makei(64, i => pair(i.to_string())))
  let b = m.review(_ => fail("diagnostic".repeat(2000)))
  let json = b.to_json()
  assert_true(
    try {
      ignore(b.to_markdown())
      false
    } catch {
      _ => true
    },
  )
  assert_eq(b.to_json(), json)
  assert_eq(b.exit_code(), 2)
  assert_true(
    @review.Manifest::new([pair("ok", new_path="old")])
    .review(load_pair)
    .to_markdown()
    .contains("## Notebook 1: passed"),
  )
}

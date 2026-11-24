///|
test "focus is opt in and leaves complete evidence and default presentation unchanged" {
  let prefix = "line\n".repeat(300)
  let c = compare(
    notebook([cell("a", source=prefix + "old")]),
    notebook([cell("a", source=prefix + "new")]),
  )
  let json = c.to_json()
  let bundle = c.to_bundle()
  let plain = c.to_markdown()
  assert_eq(plain, c.to_markdown(focus_changes=false))
  assert_false(plain.contains("new"))
  let focused = c.to_markdown(focus_changes=true)
  assert_true(focused.contains("old"))
  assert_true(focused.contains("new"))
  assert_eq(focused, c.to_markdown(focus_changes=true))
  assert_eq(
    focused,
    @review.Comparison::from_bundle(bundle).to_markdown(focus_changes=true),
  )
  assert_eq(c.to_json(), json)
  assert_eq(c.to_bundle(), bundle)
}

///|
test "late differences retain shared context and exact two-sided omitted counts" {
  let prefix = "x".repeat(1000)
  let suffix = "y".repeat(1000)
  let c = compare(
    notebook([cell("a", source=prefix + "OLD" + suffix)]),
    notebook([cell("a", source=prefix + "NEW" + suffix)]),
  )
  let md = c.to_markdown(preview_chars=32, focus_changes=true)
  assert_true(md.contains("xxxxxxxxOLD"))
  assert_true(md.contains("xxxxxxxxNEW"))
  assert_true(md.contains("UTF-16 [992, 1024)"))
  assert_true(md.contains("line 1, column 993"))
  assert_true(md.contains("992 UTF-16 units before and 979 after"))
}

///|
test "multiline locations use original LF and UTF16 columns before control escaping" {
  let prefix = "unchanged line\n".repeat(80)
  let c = compare(
    notebook([cell("a", source=prefix + "old\r\n\u001b[31m")]),
    notebook([cell("a", source=prefix + "new\r\n\u001b[31m")]),
  )
  let md = c.to_markdown(preview_chars=32, focus_changes=true)
  assert_true(md.contains("UTF-16 [1192, 1210)"))
  assert_true(md.contains("line 80, column 8"))
  assert_true(md.contains("old\\u000d\n\\u001b[31m"))
  assert_false(md.contains("\u001b"))
}

///|
test "append deletion and empty sides remain visible with correct ranges" {
  let prefix = "x".repeat(1000)
  for
    (a, b) in [
      (prefix, prefix + "tail"),
      (prefix + "tail", prefix),
      ("", "added"),
      ("removed", ""),
    ] {
    let c = compare(
      notebook([cell("a", source=a)]),
      notebook([cell("a", source=b)]),
    )
    let md = c.to_markdown(preview_chars=32, focus_changes=true)
    assert_false(md.contains("Absent."))
    if a.length() > 100 {
      assert_true(md.contains("UTF-16 [992, 1000)"))
      assert_true(md.contains("UTF-16 [992, 1004)"))
      assert_true(md.contains("tail"))
    } else {
      assert_true(md.contains("UTF-16 [0, 0)"))
      assert_true(md.contains("line 1, column 1"))
    }
  }
}

///|
test "focus never starts or ends inside a surrogate pair including shared high halves" {
  let prefix = "x".repeat(100)
  let c = compare(
    notebook([cell("a", source=prefix + "😀" + "y".repeat(60))]),
    notebook([cell("a", source=prefix + "😁" + "y".repeat(60))]),
  )
  let md = c.to_markdown(preview_chars=32, focus_changes=true)
  assert_true(md.contains("UTF-16 [92, 124)"))
  assert_true(md.contains("😀"))
  assert_true(md.contains("😁"))
  // The nominal context start (92) is the low half of this earlier emoji.
  let prefix2 = "x".repeat(91) + "😀" + "x".repeat(7)
  let c2 = compare(
    notebook([cell("a", source=prefix2 + "A" + "y".repeat(21) + "😀z")]),
    notebook([cell("a", source=prefix2 + "B" + "y".repeat(21) + "😀z")]),
  )
  let md2 = c2.to_markdown(preview_chars=32, focus_changes=true)
  assert_true(md2.contains("UTF-16 [91, 122)"))
  assert_true(md2.contains("~~~text\n😀xxxxxxxA"))
  assert_false(md2.contains("😀z"))
}

///|
test "multiple separated edits are bounded honestly and fences remain literal" {
  let prefix = "x".repeat(500)
  let a = prefix +
    "old\n~~~~~\n<script>x</script>" +
    "y".repeat(1000) +
    "LATER_OLD"
  let b = prefix +
    "new\n~~~~~\n<script>y</script>" +
    "y".repeat(1000) +
    "LATER_NEW"
  let c = compare(
    notebook([cell("a", source=a)]),
    notebook([cell("a", source=b)]),
  )
  let md = c.to_markdown(preview_chars=64, focus_changes=true)
  assert_true(md.contains("later edits may be omitted"))
  assert_true(md.contains("~~~~~~text\n"))
  assert_true(md.contains("<script>y</script>"))
  assert_false(md.contains("LATER_NEW"))
  assert_true(c.to_json().contains("LATER_NEW"))
}

///|
test "nonstring values and absent sides retain their prefix preview contract" {
  let c = compare(
    notebook([]),
    notebook([], metadata={
      "long": Json("x".repeat(100)),
      "null": Json::null(),
    }),
  )
  let md = c.to_markdown(preview_chars=32, focus_changes=true)
  assert_true(md.contains("Absent."))
  assert_true(md.contains("~~~json\nnull\n~~~"))
  assert_true(md.contains("Preview omitted 68 UTF-16 units"))
  assert_false(md.contains("Preview range:"))
}

///|
test "suppressed string changes focus without changing the gate verdict" {
  let prefix = "x".repeat(1000)
  let c = compare(
    notebook([], metadata={ "execution": Json(prefix + "old") }),
    notebook([], metadata={ "execution": Json(prefix + "new") }),
    policy=@review.Policy::new(ignored_metadata_keys=["execution"]),
  )
  let md = c.to_markdown(focus_changes=true)
  assert_true(md.contains("Active changes: 0"))
  assert_true(md.contains("Suppressed changes: 1"))
  assert_true(md.contains("new"))
  assert_true(md.contains("metadata key: execution"))
  assert_true(c.passes())
}

///|
test "Markdown is deterministic and preserves complete JSON and replay output" {
  let c = compare(
    notebook([cell("a")]),
    notebook([cell("a", source="print(2)")]),
  )
  let json = c.to_json()
  let bundle = c.to_bundle()
  let md = c.to_markdown()
  assert_true(md.contains("Active changes: 1"))
  assert_true(md.contains("### 1. source"))
  assert_true(md.contains("print(2)"))
  assert_eq(md, c.to_markdown())
  assert_eq(md, @review.Comparison::from_bundle(bundle).to_markdown())
  assert_eq(c.to_json(), json)
  assert_eq(c.to_bundle(), bundle)
}

///|
test "empty comparison has explicit empty sections" {
  let c = compare(notebook([]), notebook([]))
  let md = c.to_markdown()
  assert_true(md.contains("Active changes: 0"))
  assert_true(md.contains("## Active changes\n\nNone."))
  assert_true(md.contains("## Suppressed changes\n\nNone."))
}

///|
test "suppressed changes remain visible with their exact reason" {
  let c = compare(
    notebook([cell("a")]),
    notebook([cell("a", count=2)]),
    policy=@review.Policy::new(ignore_execution_counts=true),
  )
  let md = c.to_markdown()
  assert_true(md.contains("Active changes: 0"))
  assert_true(md.contains("Suppressed changes: 1"))
  assert_true(md.contains("ignore_execution_counts"))
  assert_true(md.contains("execution_count"))
  assert_true(c.passes())
}

///|
test "absent values stay distinct from JSON null in Markdown" {
  let c = compare(
    notebook([]),
    notebook([], metadata={ "custom": Json::null() }),
  )
  let md = c.to_markdown()
  assert_true(md.contains("Before:\n\nAbsent."))
  assert_true(md.contains("After:\n\n~~~json\nnull\n~~~"))
}

///|
test "multiline notebook Markdown and HTML cannot terminate the chosen fence" {
  let text = "line\n~~~\n# injected\n```\n<script>alert(1)</script>\nend"
  let c = compare(notebook([cell("a")]), notebook([cell("a", source=text)]))
  let md = c.to_markdown()
  assert_true(md.contains("~~~~text\n" + text + "\n~~~~"))
  assert_false(md.contains("\n\n# injected"))
}

///|
test "long values visibly identify omitted units without clipping full evidence" {
  let text = "x".repeat(100)
  let c = compare(notebook([cell("a")]), notebook([cell("a", source=text)]))
  let md = c.to_markdown(preview_chars=32)
  assert_true(md.contains("Preview omitted 68 UTF-16 units"))
  assert_false(md.contains(text))
  assert_true(c.to_json().contains(text))
  assert_true(c.to_bundle().contains(text))
}

///|
test "preview boundaries never split supplementary characters" {
  let c = compare(
    notebook([cell("a")]),
    notebook([cell("a", source="x".repeat(31) + "😀z")]),
  )
  let md = c.to_markdown(preview_chars=32)
  assert_true(md.contains("Preview omitted 3 UTF-16 units"))
  assert_false(md.contains("😀"))
  let longer = c.to_markdown(preview_chars=33)
  assert_true(longer.contains("😀"))
  assert_true(longer.contains("Preview omitted 1 UTF-16 units"))
}

///|
test "controls display as escapes while LF and tab remain readable" {
  let c = compare(
    notebook([cell("a")]),
    notebook([cell("a", source="a\u001b[31m\r\n\tb\u007f")]),
  )
  let md = c.to_markdown()
  assert_false(md.contains("\u001b"))
  assert_false(md.contains("\r"))
  assert_true(md.contains("a\\u001b[31m\\u000d\n\tb\\u007f"))
}

///|
test "invalid preview settings fail without changing comparison behavior" {
  let c = compare(notebook([]), notebook([]))
  for size in [-1, 0, 31, 4097] {
    let bad = try {
      ignore(c.to_markdown(preview_chars=size))
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
  assert_true(c.passes())
  ignore(c.to_markdown(preview_chars=4096))
}

///|
test "oversize context refuses the whole Markdown report and JSON remains usable" {
  let key = "x".repeat(1000000)
  let a : Map[String, Json] = Map([])
  let b : Map[String, Json] = Map([])
  a[key] = Json(1)
  b[key] = Json(2)
  let c = compare(
    notebook([], metadata=Json(a)),
    notebook([], metadata=Json(b)),
  )
  let bad = try {
    ignore(c.to_markdown())
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  assert_true(c.to_json().contains(key))
  assert_false(c.passes())
}

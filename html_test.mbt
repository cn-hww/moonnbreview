///|
fn evidence_from_html(html : String) -> String {
  let marker = "<div class=evidence>\n<pre><code>"
  let parts = html.split(marker).collect()
  guard parts.length() == 2 else { abort("missing unique JSON evidence") }
  let value = parts[1].split("</code></pre>").collect()[0].to_owned()
  value
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&#39;", new="'")
  .replace_all(old="&amp;", new="&")
}

///|
test "HTML contains complete exact evidence and deterministic replay" {
  let c = compare(
    notebook([cell("a")]),
    notebook([cell("a", source="print(2)")]),
  )
  let json = c.to_json()
  let bundle = c.to_bundle()
  let html = c.to_html()
  assert_true(html.has_prefix("<!doctype html>"))
  assert_true(html.has_suffix("</html>\n"))
  assert_true(html.contains("Active changes: 1"))
  assert_eq(evidence_from_html(html), json)
  assert_eq(html, c.to_html())
  assert_eq(html, @review.Comparison::from_bundle(bundle).to_html())
  assert_eq(c.to_json(), json)
  assert_eq(c.to_bundle(), bundle)
}

///|
test "HTML does not turn notebook markup entities or URLs into active content" {
  let payload = "</code></pre><script>alert(1)</script><img src=\"https://example.test/x\" onerror='run()'>&lt;tag&gt;&amp;😀"
  let c = compare(notebook([cell("a")]), notebook([cell("a", source=payload)]))
  let html = c.to_html()
  assert_false(html.contains("<script"))
  assert_false(html.contains("<img"))
  assert_false(html.contains("src=\"https:"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_true(html.contains("&amp;lt;tag&amp;gt;&amp;amp;😀"))
  assert_eq(evidence_from_html(html), c.to_json())
  assert_true(html.contains("default-src 'none'"))
}

///|
test "all dynamic location and suppression context is escaped" {
  let key = "</code><iframe src=x>\"'&"
  let a : Map[String, Json] = Map([])
  let b : Map[String, Json] = Map([])
  a[key] = Json(1)
  b[key] = Json(2)
  let c = compare(
    notebook([], metadata=Json(a)),
    notebook([], metadata=Json(b)),
    policy=@review.Policy::new(ignored_metadata_keys=[key]),
  )
  let html = c.to_html()
  assert_false(html.contains("<iframe"))
  assert_true(html.contains("Suppressed changes: 1"))
  assert_true(html.contains("metadata key:"))
  assert_true(html.contains("&lt;iframe"))
  assert_eq(evidence_from_html(html), c.to_json())
  assert_true(c.passes())
}

///|
test "HTML preserves absent versus null and empty sections" {
  let empty = compare(notebook([]), notebook([])).to_html()
  assert_true(empty.contains("Active changes: 0"))
  assert_true(empty.contains("<h2>Suppressed changes</h2>\n<p>None.</p>"))
  let c = compare(notebook([]), notebook([], metadata={ "x": Json::null() }))
  let html = c.to_html()
  assert_true(html.contains("Absent (field not present)."))
  assert_true(html.contains("<pre><code>null</code></pre>"))
  assert_eq(evidence_from_html(html), c.to_json())
}

///|
test "full long strings and unknown output fields are never previewed away" {
  let text = "x".repeat(10000) + "TAIL_EVIDENCE"
  let c = compare(
    notebook([cell("a")]),
    notebook([
      cell("a", output={
        "output_type": "vendor",
        "opaque": Json(text),
        "html": "<svg onload=run()>",
      }),
    ]),
  )
  let html = c.to_html()
  assert_true(html.contains(text))
  assert_false(html.contains("<svg"))
  assert_eq(evidence_from_html(html), c.to_json())
}

///|
test "literal controls are visible while the JSON evidence preserves original values" {
  let c = compare(
    notebook([cell("a")]),
    notebook([cell("a", source="a\u001b[31m\r\n\tb\u0000")]),
  )
  let html = c.to_html()
  assert_false(html.contains("\u001b"))
  assert_false(html.contains("\r"))
  assert_false(html.contains("\u0000"))
  assert_true(html.contains("a\\u001b[31m\\u000d\n\tb\\u0000"))
  assert_eq(evidence_from_html(html), c.to_json())
}

///|
test "HTML refuses expansion beyond its budget without damaging other evidence" {
  let c = compare(
    notebook([cell("a", source="\"".repeat(900000))]),
    notebook([cell("a", source="'".repeat(900000))]),
  )
  let json = c.to_json()
  let rejected = try {
    ignore(c.to_html())
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(c.to_json(), json)
  assert_true(
    compare(notebook([]), notebook([])).to_html().contains("Active changes: 0"),
  )
}

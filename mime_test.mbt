///|
fn rich(data : Json) -> Json {
  { "output_type": "display_data", "data": data, "metadata": {} }
}

///|
test "MIME grouping preserves exact keys nested JSON evidence and family hints" {
  let c = compare(
    notebook([
      cell(
        "a",
        output=rich({
          "text/plain": "old",
          "application/json": { "result": 1 },
          "image/png": "before",
          "application/vnd.demo+json": { "x": 1 },
          "vendor/key": "old",
        }),
      ),
    ]),
    notebook([
      cell(
        "a",
        output=rich({
          "text/plain": "new",
          "application/json": { "result": 2 },
          "image/png": "after",
          "application/vnd.demo+json": { "x": 2 },
          "vendor/key": "new",
        }),
      ),
    ]),
  )
  let groups = c.mime_changes()
  assert_eq(groups.length(), 5)
  assert_eq(
    groups.map(g => g.changes.length()).fold(init=0, (a, b) => a + b),
    c.changes().length(),
  )
  for group in groups {
    assert_eq(group.changes[0].mime_key(), Some(group.key))
    assert_eq(group.changes[0].mime_category(), Some(group.category))
    match group.key {
      "text/plain" => assert_eq(group.category, @review.Text)
      "application/json" | "application/vnd.demo+json" =>
        assert_eq(group.category, @review.StructuredJson)
      "image/png" => assert_eq(group.category, @review.Image)
      _ => assert_eq(group.category, @review.Opaque)
    }
  }
}

///|
test "MIME keys decode repeated pointer escapes once without interpreting payload keys" {
  let key = "vendor~/x~1/~"
  let old : Map[String, Json] = Map([])
  let new : Map[String, Json] = Map([])
  old[key] = Json("old")
  new[key] = Json("new")
  let c = compare(
    notebook([cell("a", output=rich(Json(old)))]),
    notebook([cell("a", output=rich(Json(new)))]),
  )
  assert_eq(c.mime_changes()[0].key, key)
  let nested = compare(
    notebook([
      cell(
        "a",
        output=rich({ "application/json": { "data": { "text/plain": "old" } } }),
      ),
    ]),
    notebook([
      cell(
        "a",
        output=rich({ "application/json": { "data": { "text/plain": "new" } } }),
      ),
    ]),
  )
  assert_eq(nested.mime_changes()[0].key, "application/json")
}

///|
test "unknown output extensions streams and whole output replacements are not guessed" {
  let unknown = compare(
    notebook([
      cell("a", output={
        "output_type": "vendor",
        "data": { "text/plain": "old" },
      }),
    ]),
    notebook([
      cell("a", output={
        "output_type": "vendor",
        "data": { "text/plain": "new" },
      }),
    ]),
  )
  assert_eq(unknown.mime_changes().length(), 0)
  assert_eq(unknown.changes()[0].kind, @review.Extension)
  assert_eq(unknown.changes()[0].mime_key(), None)
  let stream = compare(
    notebook([cell("a")]),
    notebook([
      cell("a", output={
        "output_type": "stream",
        "name": "stdout",
        "text": "new",
      }),
    ]),
  )
  assert_eq(stream.mime_changes().length(), 0)
  let replaced = compare(
    notebook([cell("a")]),
    notebook([cell("a", output=rich({ "text/plain": "new" }))]),
  )
  assert_eq(replaced.mime_changes().length(), 0)
  assert_true(replaced.to_html(group_mime=true).contains("text/plain"))
}

///|
test "MIME group arrays and nested evidence cannot mutate comparison or future groups" {
  let c = compare(
    notebook([cell("a", output=rich({ "application/json": [1] }))]),
    notebook([cell("a", output=rich({ "application/json": [2] }))]),
  )
  let json = c.to_json()
  let groups = c.mime_changes()
  guard groups[0].changes[0].after is Some(Array(items)) else {
    abort("missing array evidence")
  }
  items.clear()
  groups[0].changes.clear()
  groups.clear()
  assert_eq(c.to_json(), json)
  assert_eq(c.mime_changes()[0].changes.length(), 1)
}

///|
test "opt-in MIME HTML preserves full evidence replay and non-MIME changes" {
  let c = compare(
    notebook([
      cell("a", output=rich({ "text/html": "old", "image/svg+xml": "old" })),
    ]),
    notebook([
      cell(
        "a",
        source="edited",
        output=rich({
          "text/html": "<script>run()</script>",
          "image/svg+xml": "<svg onload=run()>",
        }),
      ),
    ]),
  )
  let plain = c.to_html()
  assert_eq(plain, c.to_html(group_mime=false))
  let grouped = c.to_html(group_mime=true)
  assert_true(grouped.contains("MIME data key"))
  assert_true(grouped.contains("Media category: image data"))
  assert_true(grouped.contains("edited"))
  assert_false(grouped.contains("<script"))
  assert_false(grouped.contains("<svg"))
  assert_eq(evidence_from_html(grouped), c.to_json())
  assert_eq(
    grouped,
    @review.Comparison::from_bundle(c.to_bundle()).to_html(group_mime=true),
  )
  assert_eq(grouped, c.to_html(group_mime=true))
}

///|
test "empty MIME groups and unknown declared keys keep complete evidence" {
  assert_eq(compare(notebook([]), notebook([])).mime_changes().length(), 0)
  let key = "application/x&demo"
  let old : Map[String, Json] = Map([])
  let new : Map[String, Json] = Map([])
  old[key] = Json("old")
  new[key] = Json("new")
  let c = compare(
    notebook([cell("a", output=rich(Json(old)))]),
    notebook([cell("a", output=rich(Json(new)))]),
  )
  assert_eq(c.mime_changes()[0].category, @review.Opaque)
  let html = c.to_html(group_mime=true)
  assert_false(html.contains("<img"))
  assert_true(html.contains("application/x&amp;demo"))
  assert_eq(evidence_from_html(html), c.to_json())
}

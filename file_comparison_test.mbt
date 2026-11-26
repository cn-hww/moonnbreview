///|
test "file addition and deletion preserve whole documents including empty notebooks" {
  for source in [notebook([]), notebook([cell("a", source="payload", count=9)])] {
    let doc = @review.Document::parse(source)
    for added in [true, false] {
      let c = @review.compare_files(
        if added {
          None
        } else {
          Some(doc)
        },
        if added {
          Some(doc)
        } else {
          None
        },
      )
      assert_eq(c.changes().length(), 1)
      let change = c.changes()[0]
      assert_eq(change.kind, @review.Structure)
      assert_eq(change.cell_id, None)
      assert_eq(change.path, "")
      assert_eq(if added { change.before } else { change.after }, None)
      assert_eq(
        if added {
          change.after
        } else {
          change.before
        },
        Some(@json.parse(doc.to_string())),
      )
      assert_false(c.passes())
      assert_true(c.to_json().contains("moonnbreview/file-report-1"))
      assert_true(c.to_markdown().contains("Absent."))
      assert_true(c.to_html().contains("Complete JSON evidence"))
      let replay = @review.Comparison::from_bundle(c.to_bundle())
      assert_eq(replay.to_json(), c.to_json())
      assert_eq(replay.to_bundle(), c.to_bundle())
    }
  }
}

///|
test "file presence is not suppressed by noise policies but obeys explicit structural gates" {
  let doc = @review.Document::parse(notebook([cell("a", count=4)]))
  let c = @review.compare_files(
    None,
    Some(doc),
    policy=@review.Policy::new(ignore_execution_counts=true, ignored_metadata_keys=[
      "execution",
    ]),
  )
  assert_eq(c.suppressed().length(), 0)
  assert_false(c.passes())
  assert_true(c.passes(blocked=[@review.Source]))
  assert_true(c.to_json().contains("\"execution_count\":4"))
}

///|
test "two present files preserve legacy bytes and witness isolation" {
  let a = @review.Document::parse(notebook([cell("a")]))
  let b = @review.Document::parse(notebook([cell("a", source="changed")]))
  let c = @review.compare_files(Some(a), Some(b))
  let original = @review.compare(a, b)
  assert_eq(c.to_json(), original.to_json())
  assert_eq(c.to_bundle(), original.to_bundle())
  assert_eq(c.to_html(), original.to_html())
  assert_eq(c.to_markdown(), original.to_markdown())
  let added = @review.compare_files(None, Some(b))
  let json = added.to_json()
  guard added.changes()[0].after is Some(Object(fields)) else {
    abort("missing whole notebook")
  }
  fields["cells"] = Json::array([])
  assert_eq(added.to_json(), json)
}

///|
test "ambiguous absent files and malformed presence bundles refuse then recover" {
  assert_true(
    try {
      ignore(@review.compare_files(None, None))
      false
    } catch {
      _ => true
    },
  )
  let doc = @review.Document::parse(notebook([]))
  let valid = @review.compare_files(None, Some(doc)).to_bundle()
  for
    text in [
      valid.replace(old="file-bundle-1", new="bundle-1"),
      valid.replace(old="\"old\":null", new="\"old\":{}"),
      valid.replace(old="\"old\":null", new="\"old\":null,\"old\":null"),
      valid.replace(old="\"policy\":", new="\"cached_pass\":true,\"policy\":"),
      "{\"format\":\"moonnbreview/file-bundle-1\",\"old\":null,\"new\":null,\"policy\":{}}",
    ] {
    assert_true(
      try {
        ignore(@review.Comparison::from_bundle(text))
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(@review.Comparison::from_bundle(valid).to_bundle(), valid)
}

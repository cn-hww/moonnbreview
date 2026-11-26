///|
let old_notebook =
  #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[{"id":"a","cell_type":"markdown","metadata":{},"source":"old"}]}

///|
test "JUnit file lifecycle uses surviving path and retains full null context" {
  let m = @review.FileManifest::new([
    { id: "added", old_path: None, new_path: Some("new"), },
    { id: "removed", old_path: Some("old"), new_path: None, },
  ])
  let b = m.review(load, retain_inputs=true)
  let xml = @junit.render(b)
  let suite = @codec.JUnitDocument::from_xml(xml).root
  let cases = suite.elements(name=Some("testcase"))
  assert_eq(cases[0].attribute("file"), Some("new"))
  assert_eq(cases[1].attribute("file"), Some("old"))
  assert_eq(suite.attribute("failures"), Some("2"))
  assert_eq(xml, @junit.render(@review.BatchReview::from_bundle(b.to_bundle())))
}

///|
fn load(path : String) -> String raise {
  match path {
    "old" => old_notebook
    "new" => old_notebook.replace(old="\"old\"", new="\"new\"")
    _ => fail("missing file: " + path)
  }
}

///|
fn mixed() -> @review.BatchReview raise {
  @review.Manifest::new([
    { id: "passed", old_path: "old", new_path: "old", },
    { id: "blocked", old_path: "old", new_path: "new", },
    { id: "error", old_path: "gone", new_path: "new", },
  ]).review(load, retain_inputs=true)
}

///|
test "JUnit maps each Notebook outcome and recomputes exact suite statistics" {
  let batch = mixed()
  let xml = @junit.render(batch)
  let document = @codec.JUnitDocument::from_xml(xml)
  assert_eq(document.root.attribute("tests"), Some("3"))
  assert_eq(document.root.attribute("failures"), Some("1"))
  assert_eq(document.root.attribute("errors"), Some("1"))
  assert_eq(document.root.attribute("skipped"), Some("0"))
  let cases = @codec.parse_report(xml).cases
  assert_eq(cases.length(), 3)
  assert_true(cases[0].is_passed())
  assert_true(cases[1].is_failure())
  assert_true(cases[2].is_error())
  assert_eq(batch.exit_code(), 2)
  assert_false(xml.contains("timestamp="))
  assert_false(xml.contains("time="))
}

///|
test "JUnit system-out retains each complete evidence object and exact configuration" {
  let batch = mixed()
  guard @json.parse(batch.to_json()) is Object(root) &&
    root["results"] is Array(entries) else {
    abort("missing entries")
  }
  let suite = @codec.JUnitDocument::from_xml(@junit.render(batch)).root
  let cases = suite.elements(name=Some("testcase"))
  for i, testcase in cases {
    let logs = testcase.elements(name=Some("system-out"))
    let text = StringBuilder()
    for node in logs[0].content {
      guard node is @codec.Text(value) else { abort("unexpected log node") }
      text.write_string(value)
    }
    assert_eq(@json.parse(text.to_string()), entries[i])
  }
  let properties = suite.elements(name=Some("properties"))[0].elements(
    name=Some("property"),
  )
  assert_eq(properties.length(), 2)
  for property in properties {
    guard property.attribute("name") is Some(name) &&
      property.attribute("value") is Some(value) else {
      abort("missing configuration")
    }
    assert_eq(
      @json.parse(value),
      root[if name == "moonnbreview.policy" { "policy" } else { "gate" }],
    )
  }
}

///|
test "XML escaping preserves hostile Notebook identities paths and content literally" {
  let id = "课😀 <case>&\"'"
  let path = "proposed <x>&\"'.ipynb"
  let payload = "</system-out><failure>injected</failure>&lt;tag&gt;"
  let batch = @review.Manifest::new([{ id, old_path: "old", new_path: path, }]).review(p => {
      if p == "old" {
        old_notebook
      } else {
        guard @json.parse(old_notebook) is Object(root) &&
          root["cells"] is Array(cells) &&
          cells[0] is Object(cell) else {
          abort("invalid fixture")
        }
        cell["source"] = Json(payload)
        Json(root).stringify()
      }
    },
  )
  let xml = @junit.render(batch)
  let suite = @codec.JUnitDocument::from_xml(xml).root
  let testcase = suite.elements(name=Some("testcase"))[0]
  assert_eq(testcase.attribute("name"), Some(id))
  assert_eq(testcase.attribute("file"), Some(path))
  assert_eq(testcase.elements(name=Some("failure")).length(), 1)
  assert_false(xml.contains("<failure>injected"))
  assert_true(xml.contains("&lt;/system-out&gt;"))
}

///|
test "JUnit is deterministic after offline replay and leaves JSON bundle and verdict intact" {
  let batch = mixed()
  let json = batch.to_json()
  let bundle = batch.to_bundle()
  let xml = @junit.render(batch)
  assert_eq(xml, @junit.render(batch))
  assert_eq(xml, @junit.render(@review.BatchReview::from_bundle(bundle)))
  assert_eq(batch.to_json(), json)
  assert_eq(batch.to_bundle(), bundle)
  assert_eq(batch.exit_code(), 2)
}

///|
test "selective gates map allowed active evidence to passed cases without discarding it" {
  let m = @review.Manifest::new([
    { id: "allowed", old_path: "old", new_path: "new", },
  ])
  let batch = m.review(load, gate=@review.Gate::new(blocked=[@review.Output]))
  let xml = @junit.render(batch)
  assert_true(@codec.parse_report(xml).cases[0].is_passed())
  assert_true(xml.contains("&quot;changes&quot;:[{"))
  assert_eq(batch.exit_code(), 0)
}

///|
test "empty batch is a valid zero-case suite" {
  let batch = @review.Manifest::new([]).review(load)
  let xml = @junit.render(batch)
  assert_eq(
    @codec.JUnitDocument::from_xml(xml).root.attribute("tests"),
    Some("0"),
  )
  assert_eq(@codec.parse_report(xml).cases.length(), 0)
}

///|
test "unrepresentable XML characters refuse export while original evidence remains usable" {
  let batch = @review.Manifest::new([
    { id: "bad\uFFFE", old_path: "old", new_path: "new", },
  ]).review(load)
  let json = batch.to_json()
  let bad = try {
    ignore(@junit.render(batch))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  assert_eq(batch.to_json(), json)
  assert_true(@codec.parse_report(@junit.render(mixed())).cases[0].is_passed())
}

///|
test "XML expansion beyond the export limit refuses without clipping full evidence" {
  let m = @review.Manifest::new([
    { id: "large", old_path: "old", new_path: "new", },
  ])
  let batch = m.review(path => {
    guard @json.parse(old_notebook) is Object(root) &&
      root["cells"] is Array(cells) &&
      cells[0] is Object(cell) else {
      abort("bad fixture")
    }
    cell["source"] = Json(
      (if path == "old" { "\"" } else { "'" }).repeat(850000),
    )
    Json(root).stringify()
  })
  let json = batch.to_json()
  let bad = try {
    ignore(@junit.render(batch))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  assert_eq(batch.to_json(), json)
}

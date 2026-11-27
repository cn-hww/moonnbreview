///|
fn source_change(old : String, new : String) -> @review.Change raise {
  compare(notebook([cell("a", source=old)]), notebook([cell("a", source=new)])).changes()[0]
}

///|
test "three separated edits remain exhaustive and replayable" {
  let shared = "same\n".repeat(12)
  let old = "first\n" + shared + "middle\n" + shared + "last"
  let new = "FIRST\n" + shared + "MIDDLE\n" + shared + "LAST\n"
  let c = compare(
    notebook([cell("a", source=old)]),
    notebook([cell("a", source=new)]),
  )
  let json = c.to_json()
  let bundle = c.to_bundle()
  let hunks = c.changes()[0].source_hunks().unwrap()
  assert_eq(hunks.length(), 3)
  assert_eq(hunks[1].lines[3].old_line, Some(14))
  let md = c.to_markdown(source_hunks=true)
  for
    text in [
      "-first", "+FIRST", "-middle", "+MIDDLE", "-last", "+LAST", "\\ No newline at end of file",
    ] {
    assert_true(md.contains(text))
  }
  assert_eq(
    md,
    @review.Comparison::from_bundle(bundle).to_markdown(source_hunks=true),
  )
  assert_eq(c.to_json(), json)
  assert_eq(c.to_bundle(), bundle)
}

///|
test "line evidence reconstructs both inputs without losing LF CR or Unicode" {
  for
    (old, new) in [
      ("", "a\n"),
      ("a\n", ""),
      ("a", "a\n"),
      ("a\r\n", "a\n"),
      ("猫\n😀\n~~~\n", "猫\n😀!\n~~~~\n"),
      ("repeat\nrepeat\n", "repeat\nx\nrepeat\n"),
    ] {
    let hunks = source_change(old, new).source_hunks(context=20).unwrap()
    let a = StringBuilder()
    let b = StringBuilder()
    for hunk in hunks {
      for line in hunk.lines {
        if line.kind != Added {
          a.write_string(line.text)
        }
        if line.kind != Removed {
          b.write_string(line.text)
        }
        assert_eq(line.old_line is Some(_), line.kind != Added)
        assert_eq(line.new_line is Some(_), line.kind != Removed)
      }
    }
    assert_eq(a.to_string(), old)
    assert_eq(b.to_string(), new)
  }
}

///|
test "hunk query is fresh and non-source changes retain previews" {
  let c = source_change("a\n", "b\n")
  let first = c.source_hunks().unwrap()
  first[0].lines.clear()
  assert_true(c.source_hunks().unwrap()[0].lines.length() > 0)
  let counts = compare(notebook([cell("a")]), notebook([cell("a", count=2)]))
  assert_true(counts.changes()[0].source_hunks() is None)
  assert_true(counts.to_markdown(source_hunks=true).contains("Before:"))
}

///|
test "hunk limits refuse rather than truncate and next call recovers" {
  let c = source_change("a", "b")
  assert_true(
    try {
      ignore(c.source_hunks(context=-1))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(c.source_hunks(context=21))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        source_change("a".repeat(100001), "b".repeat(100000)).source_hunks(),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        source_change("x\n".repeat(2001), "y\n".repeat(2000)).source_hunks(),
      )
      false
    } catch {
      _ => true
    },
  )
  let comparison = compare(
    notebook([cell("a")]),
    notebook([cell("a", source="changed")]),
  )
  assert_true(
    try {
      ignore(comparison.to_markdown(source_hunks=true, focus_changes=true))
      false
    } catch {
      _ => true
    },
  )
  assert_true(comparison.to_markdown(source_hunks=true).contains("+changed"))
}

///|
test "batch hunks work without retention and preserve decisions" {
  let manifest = @review.Manifest::from_json(
    "{\"format\":\"moonnbreview/manifest-1\",\"pairs\":[{\"id\":\"one\",\"old\":\"a\",\"new\":\"b\"}]}",
  )
  let batch = manifest.review(path => notebook([cell("a", source=path)]))
  let json = batch.to_json()
  assert_true(batch.to_markdown(source_hunks=true).contains("+b"))
  assert_eq(batch.to_json(), json)
}

///|
test "exact hunk budgets and cutoff edits retain every line" {
  let old = Array::makei(2000, i => "old-" + i.to_string() + "\n").join("")
  let new = Array::makei(2000, i => "new-" + i.to_string() + "\n").join("")
  let hunks = source_change(old, new).source_hunks(context=0).unwrap()
  let a = StringBuilder()
  let b = StringBuilder()
  for hunk in hunks {
    for line in hunk.lines {
      assert_true(line.kind != Context)
      if line.kind == Removed {
        a.write_string(line.text)
      }
      if line.kind == Added {
        b.write_string(line.text)
      }
    }
  }
  assert_eq(a.to_string(), old)
  assert_eq(b.to_string(), new)
  let boundary = source_change("a".repeat(100000), "b".repeat(100000))
    .source_hunks()
    .unwrap()
  assert_eq(boundary.length(), 1)
  assert_eq(boundary[0].lines.length(), 2)
}

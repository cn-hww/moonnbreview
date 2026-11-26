///|
test "NUL discovery preserves literal paths and independent add delete modify type statuses" {
  let m = discovered_manifest(
    "A\u0000课程 [1] $(x).ipynb\u0000D\u0000gone.ipynb\u0000M\u0000edit.ipynb\u0000T\u0000type.ipynb\u0000M\u0000unrelated.txt\u0000",
  )
  assert_eq(m.pairs().length(), 4)
  for pair in m.pairs() {
    match pair.old_path {
      Some("gone.ipynb") => assert_eq(pair.new_path, None)
      Some(path) => assert_eq(pair.new_path, Some(path))
      None => assert_eq(pair.new_path, Some("课程 [1] $(x).ipynb"))
    }
  }
  assert_eq(
    m.to_json(),
    discovered_manifest(
      "T\u0000type.ipynb\u0000M\u0000edit.ipynb\u0000D\u0000gone.ipynb\u0000A\u0000课程 [1] $(x).ipynb\u0000",
    ).to_json(),
  )
}

///|
test "discovery framing unknown statuses selected unsafe paths and duplicates refuse" {
  for
    text in [
      "M\u0000a.ipynb", "M\u0000", "X\u0000a.ipynb\u0000", "R100\u0000a.ipynb\u0000b.ipynb\u0000",
      "A\u0000\u0000", "A\u0000a.ipynb\u0000D\u0000a.ipynb\u0000", "M\u0000../a.ipynb\u0000",
      "A\u0000bad:name.ipynb\u0000", "A\u0000bad\nname.ipynb\u0000",
    ] {
    assert_true(
      try {
        ignore(discovered_manifest(text))
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(discovered_manifest("").pairs().length(), 0)
  assert_eq(
    discovered_manifest("M\u0000ignore.IPYNB\u0000").pairs().length(),
    0,
  )
}

///|
test "discovery 64 limit is exact and failed planning recovers without a partial manifest" {
  let records = Array::makei(64, i => {
    "A\u0000n" + i.to_string() + ".ipynb\u0000"
  }).join("")
  assert_eq(discovered_manifest(records).pairs().length(), 64)
  assert_true(
    try {
      ignore(discovered_manifest(records + "A\u0000overflow.ipynb\u0000"))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(discovered_manifest("A\u0000ok.ipynb\u0000").pairs().length(), 1)
}

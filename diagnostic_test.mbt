///|
fn rejection(text : String) -> @review.Diagnostic raise {
  match @review.Document::validate(text) {
    Err(d) => d
    Ok(_) => fail("expected refusal")
  }
}

///|
test "typed diagnostics identify version cells identities and required fields" {
  for
    (text, code, path) in [
      ("[]", "NB_ROOT", ""),
      ("{}", "NB_VERSION", "/nbformat"),
      (
        notebook([]).replace(
          old="\"nbformat_minor\":5",
          new="\"nbformat_minor\":4",
        ),
        "NB_VERSION",
        "/nbformat_minor",
      ),
      (
        "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":null}", "NB_CELLS",
        "/cells",
      ),
      (
        notebook([cell("dup"), cell("dup")]),
        "NB_CELL_ID_DUPLICATE",
        "/cells/1/id",
      ),
      (notebook([cell("bad id")]), "NB_FIELD", "/cells/0/id"),
      (
        notebook([{ "cell_type": "raw", "metadata": {}, "source": "x" }]),
        "NB_FIELD",
        "/cells/0/id",
      ),
      (
        notebook([
          cell("a", metadata={ "name": "same" }),
          cell("b", metadata={ "name": "same" }),
        ]),
        "NB_CELL_NAME_DUPLICATE",
        "/cells/1/metadata/name",
      ),
    ] {
    let d = rejection(text)
    assert_eq(d.code, code)
    assert_eq(d.path, path)
    assert_true(d.hint.length() > 10)
    assert_eq(d.to_json(), rejection(text).to_json())
    assert_true(d.render().contains(code))
  }
}

///|
test "syntax locations and escaped duplicate keys never pick a winner" {
  let d = rejection("{\n\"a\":1,\n\"\\u0061\":2\n}")
  assert_eq(d.code, "NB_JSON_DUPLICATE_KEY")
  assert_eq(d.line, Some(3))
  assert_true(d.column is Some(_))
  assert_eq(rejection("{\"a\":").code, "NB_JSON_SYNTAX")
  assert_eq(rejection("{ bad }").line, Some(1))
  assert_eq(rejection("[".repeat(65) + "0" + "]".repeat(65)).code, "NB_DEPTH")
}

///|
test "numeric and Unicode errors carry exact escaped pointers" {
  let d = rejection(
    notebook([], metadata={
      "a~/b": { "value": Json::number(9007199254740992.0) },
    }),
  )
  assert_eq(d.code, "NB_NUMBER")
  assert_eq(d.path, "/metadata/a~0~1b/value")
  let unicode = rejection(
    notebook([]).replace(
      old="\"metadata\":{}",
      new="\"metadata\":{\"key\":\"\\ud800\"}",
    ),
  )
  assert_eq(unicode.code, "NB_JSON_SYNTAX")
  assert_eq(unicode.line, Some(1))
  let codec = rejection(
    notebook([cell("a", metadata={ "execution": { "a.b~/c": Json(1) } })]),
  )
  assert_eq(codec.code, "NB_FIELD")
  assert_eq(codec.path, "/cells/0/metadata/execution/a.b~0~1c")
}

///|
test "preservation refusal locates the changed numeric spelling" {
  let raw = notebook([cell("a")]).replace(
    old="\"nbformat\":4",
    new="\"nbformat\":4.0",
  )
  let d = rejection(raw)
  assert_eq(d.code, "NB_PRESERVATION")
  assert_eq(d.path, "/nbformat")
}

///|
test "validation preserves accepted bytes and recovers after every refusal" {
  let text = notebook([cell("a", source="猫\r\n😀\n")], metadata={
    "extension": { "large": "9007199254740992" },
  })
  let before = @review.Document::parse(text).to_string()
  for bad in ["invalid", "x".repeat(2000001), notebook([cell("bad id")])] {
    ignore(rejection(bad))
    match @review.Document::validate(text) {
      Ok(doc) => {
        assert_eq(doc.to_string(), before)
        assert_eq(@review.Document::parse(doc.to_string()).to_string(), before)
      }
      Err(d) => fail(d.render())
    }
  }
  assert_eq(rejection("x".repeat(2000001)).code, "NB_SIZE")
  let cells = Array::makei(5001, i => cell("cell-" + i.to_string()))
  assert_eq(rejection(notebook(cells)).code, "NB_CELLS")
}

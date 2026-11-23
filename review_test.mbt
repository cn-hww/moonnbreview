///|
fn cell(
  id : String,
  source~ : String = "print(1)",
  count~ : Int32 = 1,
  output~ : Json = { "output_type": "stream", "name": "stdout", "text": "1\n" },
  metadata~ : Json = {},
) -> Json {
  {
    "id": Json(id),
    "cell_type": "code",
    "metadata": metadata,
    "source": Json(source),
    "execution_count": Json(count),
    "outputs": [output],
  }
}

///|
fn notebook(cells : Array[Json], metadata~ : Json = {}) -> String {
  let value : Json = {
    "nbformat": 4,
    "nbformat_minor": 5,
    "metadata": metadata,
    "cells": Json(cells),
  }
  value.stringify()
}

///|
fn compare(
  a : String,
  b : String,
  policy~ : @review.Policy = @review.Policy::new(),
) -> @review.Comparison raise {
  @review.compare(
    @review.Document::parse(a),
    @review.Document::parse(b),
    policy~,
  )
}

///|
fn refused(source : String) -> Bool {
  try {
    ignore(@review.Document::parse(source))
    false
  } catch {
    _ => true
  }
}

///|
test "identity and semantic serialization round trip" {
  let doc = @review.Document::parse(notebook([cell("a")]))
  let restored = @review.Document::parse(doc.to_string())
  assert_eq(doc.to_string(), restored.to_string())
  assert_true(@review.compare(doc, restored).passes())
}

///|
test "stable IDs align insertions without reporting index shifts as moves" {
  let c = compare(
    notebook([cell("a"), cell("b")]),
    notebook([cell("x"), cell("a"), cell("b")]),
  )
  assert_eq(c.changes().length(), 1)
  assert_eq(c.changes()[0].kind, @review.Structure)
  assert_eq(c.changes()[0].cell_id, Some("x"))
}

///|
test "retained relative order is distinct from source editing" {
  let c = compare(
    notebook([cell("a"), cell("b")]),
    notebook([cell("b"), cell("a", source="print(2)")]),
  )
  assert_eq(c.changes().length(), 2)
  assert_eq(c.changes()[0].kind, @review.Order)
  assert_eq(c.changes()[1].kind, @review.Source)
  assert_false(c.passes())
  assert_true(c.passes(blocked=[@review.Output]))
}

///|
test "deletion retains complete removed cell evidence" {
  let c = compare(notebook([cell("a")]), notebook([]))
  assert_eq(c.changes()[0].before, Some(cell("a")))
  assert_eq(c.changes()[0].after, None)
}

///|
test "execution count suppression is opt in and visible" {
  let a = notebook([cell("a")])
  let b = notebook([cell("a", count=2)])
  assert_false(compare(a, b).passes())
  let c = compare(
    a,
    b,
    policy=@review.Policy::new(ignore_execution_counts=true),
  )
  assert_true(c.passes())
  assert_eq(c.suppressed().length(), 1)
  assert_eq(c.suppressed()[0].kind, @review.ExecutionCount)
  assert_eq(c.suppressed()[0].suppressed_by, Some("ignore_execution_counts"))
}

///|
test "output payload remains blocking when count noise is suppressed" {
  let result : Json = {
    "output_type": "execute_result",
    "execution_count": 2,
    "metadata": {},
    "data": { "application/json": { "value": 2 } },
  }
  let old : Json = {
    "output_type": "execute_result",
    "execution_count": 1,
    "metadata": {},
    "data": { "application/json": { "value": 1 } },
  }
  let c = compare(
    notebook([cell("a", output=old)]),
    notebook([cell("a", output=result)]),
    policy=@review.Policy::new(ignore_execution_counts=true),
  )
  assert_eq(c.suppressed().length(), 1)
  assert_eq(c.changes().length(), 1)
  assert_eq(c.changes()[0].kind, @review.Output)
  assert_false(c.passes())
}

///|
test "metadata ignores exact immediate keys and records nested evidence" {
  let c = compare(
    notebook([cell("a", metadata={ "execution": { "time": "old" }, "keep": 1 })]),
    notebook([cell("a", metadata={ "execution": { "time": "new" }, "keep": 2 })]),
    policy=@review.Policy::new(ignored_metadata_keys=["execution"]),
  )
  assert_eq(c.suppressed()[0].path, "/metadata/execution/time")
  assert_eq(c.changes()[0].path, "/metadata/keep")
}

///|
test "suppression does not match a same-named nested key" {
  let c = compare(
    notebook([], metadata={ "vendor": { "execution": 1 } }),
    notebook([], metadata={ "vendor": { "execution": 2 } }),
    policy=@review.Policy::new(ignored_metadata_keys=["execution"]),
  )
  assert_eq(c.suppressed().length(), 0)
  assert_false(c.passes())
}

///|
test "unknown output fields are never interpreted as count noise" {
  let a : Json = {
    "output_type": "vendor",
    "execution_count": 1,
    "payload": [1],
  }
  let b : Json = {
    "output_type": "vendor",
    "execution_count": 2,
    "payload": [1],
  }
  let c = compare(
    notebook([cell("a", output=a)]),
    notebook([cell("a", output=b)]),
    policy=@review.Policy::new(ignore_execution_counts=true),
  )
  assert_eq(c.changes()[0].kind, @review.Extension)
  assert_eq(c.suppressed().length(), 0)
}

///|
test "unknown notebook and cell fields survive serialization and comparison" {
  let a =
    #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"vendor":{"x":1},"cells":[{"id":"a","cell_type":"vendor","metadata":{},"data":[1,null]}]}
  let b = a.replace(old="[1,null]", new="[2,null]")
  let c = compare(a, b)
  assert_eq(c.changes().length(), 1)
  assert_eq(c.changes()[0].kind, @review.Extension)
  assert_true(@review.Document::parse(a).to_string().contains("vendor"))
}

///|
test "absent fields differ from explicit null" {
  let c = compare(
    notebook([], metadata={}),
    notebook([], metadata={ "custom": Json::null() }),
  )
  assert_eq(c.changes()[0].before, None)
  assert_eq(c.changes()[0].after, Some(Json::null()))
  let report = @json.parse(c.to_json()[:])
  guard report is Object(f) &&
    f["changes"] is Array(changes) &&
    changes[0] is Object(change) else {
    fail("invalid report")
  }
  assert_false(change.contains("before"))
  assert_true(change.contains("after"))
}

///|
test "valid multiline representations are equivalent only in defined fields" {
  let a = notebook([cell("a")])
  let b = a.replace(old="\"print(1)\"", new="[\"print(\",\"1)\"]")
  assert_true(compare(a, b).passes())
  assert_false(
    compare(
      notebook([], metadata={ "v": ["a", "b"] }),
      notebook([], metadata={ "v": "ab" }),
    ).passes(),
  )
}

///|
test "MIME and attachment changes are identified without executing content" {
  let a =
    #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[{"id":"m","cell_type":"markdown","source":"![x](attachment:x.png)","metadata":{},"attachments":{"x.png":{"image/png":"YQ=="}}}]}
  let c = compare(a, a.replace(old="YQ==", new="Yg=="))
  assert_eq(c.changes()[0].kind, @review.Attachment)
  assert_eq(c.changes()[0].path, "/attachments/x.png/image~1png")
}

///|
test "output errors and output sequence changes are retained" {
  let err : Json = {
    "output_type": "error",
    "ename": "ValueError",
    "evalue": "bad",
    "traceback": ["frame"],
  }
  let c = compare(notebook([cell("a")]), notebook([cell("a", output=err)]))
  assert_eq(c.changes().length(), 1)
  assert_eq(c.changes()[0].kind, @review.Output)
  assert_eq(c.changes()[0].path, "/outputs/0")
}

///|
test "type changes are structural and cannot be hidden as count changes" {
  let a = notebook([cell("a")])
  let b =
    #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[{"id":"a","cell_type":"raw","source":"text","metadata":{}}]}
  let c = compare(
    a,
    b,
    policy=@review.Policy::new(ignore_execution_counts=true),
  )
  assert_eq(c.changes()[0].kind, @review.Structure)
  assert_false(c.passes())
}

///|
test "deterministic reports and replay after key-order changes" {
  let a = notebook([cell("a")])
  let b = notebook([cell("a", source="print(2)")])
  let c = compare(a, b)
  let roundtrip = @review.Comparison::from_bundle(c.to_bundle())
  assert_eq(c.to_json(), roundtrip.to_json())
  assert_eq(c.to_bundle(), roundtrip.to_bundle())
  assert_eq(c.to_json(), compare(a, b).to_json())
}

///|
test "mutating returned evidence cannot change a comparison" {
  let c = compare(notebook([cell("a")]), notebook([]))
  let report = c.to_json()
  guard c.changes()[0].before is Some(Object(fields)) else {
    fail("no evidence")
  }
  fields.clear()
  assert_eq(c.to_json(), report)
}

///|
test "policy snapshots caller arrays" {
  let keys = ["execution"]
  let p = @review.Policy::new(ignored_metadata_keys=keys)
  keys.clear()
  let c = compare(
    notebook([], metadata={ "execution": 1 }),
    notebook([], metadata={ "execution": 2 }),
    policy=p,
  )
  assert_true(c.passes())
}

///|
test "malformed duplicate escaped and unsupported inputs are refused" {
  for
    text in [
      "{",
      "[]",
      "null",
      "{\"x\":1,\"\\u0078\":2}",
      "{\"x\":\"\\ud800\"}",
      notebook([cell("a"), cell("a")]),
      notebook([cell("")]),
      notebook([]).replace(
        old="\"nbformat_minor\":5",
        new="\"nbformat_minor\":4",
      ),
    ] {
    assert_true(refused(text))
  }
}

///|
test "unsafe numbers are refused rather than rounded" {
  for number in ["9007199254740993", "1e400"] {
    let text = "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{\"x\":" +
      number +
      "},\"cells\":[]}"
    assert_true(refused(text))
  }
}

///|
test "precise numeric representations are preserved or explicitly refused" {
  let number = "1.12345678901234567890123456789"
  let text = "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{\"x\":" +
    number +
    "},\"cells\":[]}"
  let accepted = Some(@review.Document::parse(text)) catch { _ => None }
  if accepted is Some(doc) {
    assert_true(doc.to_string().contains(number))
  }
}

///|
test "format errors do not poison later operations" {
  assert_true(refused("{"))
  assert_true(compare(notebook([]), notebook([])).passes())
}

///|
test "resource limits refuse excessive depth text and cells" {
  assert_true(refused("[".repeat(65) + "0" + "]".repeat(65)))
  assert_true(refused(" ".repeat(2000001)))
  assert_true(
    refused(notebook(Array::makei(5001, i => cell("c" + i.to_string())))),
  )
}

///|
test "bundle format and policy validation fail closed" {
  let c = compare(notebook([]), notebook([]))
  for
    text in [
      c.to_bundle().replace(old="bundle-1", new="bundle-99"),
      c.to_bundle().replace(old="\"policy\":", new="\"extra\":0,\"policy\":"),
      c
      .to_bundle()
      .replace(
        old="\"ignore_execution_counts\":false",
        new="\"ignore_execution_counts\":1",
      ),
    ] {
    let failed = try {
      ignore(@review.Comparison::from_bundle(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
test "key order does not affect comparison or report bytes" {
  let a =
    #|{"nbformat":4,"nbformat_minor":5,"metadata":{"z":1,"a":2},"cells":[]}
  let b =
    #|{"cells":[],"metadata":{"a":2,"z":1},"nbformat_minor":5,"nbformat":4}
  assert_true(compare(a, b).passes())
  assert_eq(compare(a, b).to_json(), compare(b, a).to_json())
}

///|
test "valid surrogate pairs and pointer escaping survive replay" {
  let a = notebook([], metadata={ "a~/b": "中文😀" })
  let b = notebook([], metadata={ "a~/b": "中文🌙" })
  let c = compare(a, b)
  assert_eq(c.changes()[0].path, "/metadata/a~0~1b")
  assert_eq(
    @review.Comparison::from_bundle(c.to_bundle()).to_json(),
    c.to_json(),
  )
}

///|
test "exact cell count limit is accepted" {
  let cells = Array::makei(5000, i => cell("cell-" + i.to_string()))
  let text = notebook(cells)
  let doc = @review.Document::parse(text)
  assert_true(@review.compare(doc, doc).passes())
}

///|
test "duplicate and empty suppression keys are invalid" {
  for keys in [["execution", "execution"], [""]] {
    let bad = try {
      ignore(@review.Policy::new(ignored_metadata_keys=keys))
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
}

///|
test "field names from another output type remain extensions" {
  let a : Json = {
    "output_type": "stream",
    "name": "stdout",
    "text": "same",
    "data": 1,
  }
  let b : Json = {
    "output_type": "stream",
    "name": "stdout",
    "text": "same",
    "data": 2,
  }
  let c = compare(
    notebook([cell("a", output=a)]),
    notebook([cell("a", output=b)]),
  )
  assert_eq(c.changes()[0].kind, @review.Extension)
  assert_false(c.passes(blocked=[@review.Extension]))
}

///|
test "report optional identity and suppression reason use strings or null" {
  let c = compare(
    notebook([cell("a")]),
    notebook([cell("a", count=2)]),
    policy=@review.Policy::new(ignore_execution_counts=true),
  )
  guard @json.parse(c.to_json()[:]) is Object(report) &&
    report["suppressed"] is Array(items) &&
    items[0] is Object(witness) else {
    fail("bad report")
  }
  assert_eq(witness["cell_id"], Json("a"))
  assert_eq(witness["suppressed_by"], Json("ignore_execution_counts"))
}

///|
test "pointers escape every slash and tilde including repeated runs" {
  let c = compare(
    notebook([], metadata={ "/a/b//~x~~": 1 }),
    notebook([], metadata={ "/a/b//~x~~": 2 }),
  )
  let expected = "/metadata/~1a~1b~1~1~0x~0~0"
  assert_eq(c.changes()[0].path, expected)
  assert_eq(
    @review.Comparison::from_bundle(c.to_bundle()).changes()[0].path,
    expected,
  )
  assert_true(c.to_markdown().contains(expected))
}

///|
test "literal escape-looking field names remain distinct from slashes" {
  let c = compare(
    notebook([], metadata={ "a/b/c": 1, "a/b~1c": 1 }),
    notebook([], metadata={ "a/b/c": 2, "a/b~1c": 2 }),
  )
  let paths = c.changes().map(item => item.path)
  assert_eq(paths.length(), 2)
  assert_true(paths.contains("/metadata/a~1b~1c"))
  assert_true(paths.contains("/metadata/a~1b~01c"))
}

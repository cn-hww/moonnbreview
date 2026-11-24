///|
fn gate_refused(text : String) -> Bool {
  try {
    ignore(@review.Gate::from_json(text))
    false
  } catch {
    _ => true
  }
}

///|
test "gate canonical round trips are independent of category input order" {
  let a = @review.Gate::new(blocked=[@review.Source, @review.Structure])
  let b = @review.Gate::new(blocked=[@review.Structure, @review.Source])
  assert_eq(a.to_json(), b.to_json())
  assert_eq(@review.Gate::from_json(a.to_json()).to_json(), a.to_json())
  assert_eq(@review.Gate::new().blocked().length(), 8)
}

///|
test "selective gates retain allowed output evidence and block source edits" {
  let old = notebook([cell("a")])
  let new = notebook([
    cell("a", output={
      "output_type": "stream",
      "name": "stdout",
      "text": "changed",
    }),
  ])
  let c = compare(old, new)
  let json = c.to_json()
  let gate = @review.Gate::new(blocked=[@review.Source, @review.Structure])
  assert_false(c.passes())
  assert_true(c.passes(blocked=gate.blocked()))
  assert_eq(c.changes().length(), 1)
  assert_eq(c.suppressed().length(), 0)
  assert_eq(c.to_json(), json)
  let edited = compare(old, notebook([cell("a", source="edited")]))
  assert_false(edited.passes(blocked=gate.blocked()))
}

///|
test "gate arrays cannot mutate configuration and empty selection is explicit" {
  let input = [@review.Source]
  let gate = @review.Gate::new(blocked=input)
  input[0] = @review.Output
  let exported = gate.blocked()
  exported.clear()
  assert_eq(gate.blocked(), [@review.Source])
  let empty = @review.Gate::from_json(@review.Gate::new(blocked=[]).to_json())
  assert_eq(empty.blocked().length(), 0)
  assert_true(
    compare(notebook([]), notebook([cell("a")])).passes(blocked=empty.blocked()),
  )
}

///|
test "gate categories cover all domain kinds and suppression stays independent" {
  let text = "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[\"structure\",\"order\",\"source\",\"output\",\"attachment\",\"metadata\",\"execution_count\",\"extension\"]}"
  assert_eq(
    @review.Gate::from_json(text).to_json(),
    @review.Gate::new().to_json(),
  )
  let c = compare(
    notebook([cell("a")]),
    notebook([cell("a", count=2)]),
    policy=@review.Policy::new(ignore_execution_counts=true),
  )
  assert_true(c.passes(blocked=@review.Gate::new().blocked()))
  assert_eq(c.suppressed().length(), 1)
}

///|
test "gate rejects ambiguous malformed unknown and duplicate configurations" {
  for
    text in [
      "{", "{}", "[]", "{\"format\":\"moonnbreview/gate-2\",\"blocked\":[]}", "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[],\"extra\":true}",
      "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[],\"\\u0062locked\":[\"source\"]}",
      "{\"format\":\"moonnbreview/gate-1\",\"blocked\":null}", "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[null]}",
      "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[\"Source\"]}", "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[\"sources\"]}",
      "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[\"source\",\"source\"]}",
      "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[\"\\ud800\"]}",
    ] {
    assert_true(gate_refused(text))
  }
  let duplicates = try {
    ignore(@review.Gate::new(blocked=[@review.Source, @review.Source]))
    false
  } catch {
    _ => true
  }
  assert_true(duplicates)
}

///|
test "gate text boundaries and failure recovery are deterministic" {
  let valid = @review.Gate::new().to_json()
  let exact = valid + " ".repeat(8192 - valid.length())
  assert_eq(@review.Gate::from_json(exact).to_json(), valid)
  assert_true(gate_refused(exact + " "))
  assert_true(
    gate_refused(
      "{\"format\":\"moonnbreview/gate-1\",\"blocked\":[\"source\",\"source\",\"source\",\"source\",\"source\",\"source\",\"source\",\"source\",\"source\"]}",
    ),
  )
  assert_eq(@review.Gate::from_json(valid).to_json(), valid)
}

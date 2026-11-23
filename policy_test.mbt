///|
fn policy_text(keys : Array[String], counts~ : Bool = false) -> String {
  let value : Json = {
    "format": "moonnbreview/policy-1",
    "ignore_execution_counts": Json(counts),
    "ignored_metadata_keys": Json(keys),
  }
  value.stringify()
}

///|
test "policy files have deterministic canonical round trips" {
  let a = @review.Policy::from_json(
    policy_text(["execution", "volatile"], counts=true),
  )
  let b = @review.Policy::from_json(
    policy_text(["volatile", "execution"], counts=true),
  )
  assert_eq(a.to_json(), b.to_json())
  assert_eq(@review.Policy::from_json(a.to_json()).to_json(), a.to_json())
}

///|
test "default policy file retains strict behavior" {
  let p = @review.Policy::from_json(@review.Policy::new().to_json())
  let old = notebook([cell("a")])
  let new = notebook([cell("a", count=2)])
  assert_false(compare(old, new, policy=p).passes())
}

///|
test "file policy is preserved by existing report and replay formats" {
  let old = notebook([cell("a")], metadata={ "execution": 1 })
  let new = notebook([cell("a", count=2)], metadata={ "execution": 2 })
  let p = @review.Policy::from_json(policy_text(["execution"], counts=true))
  let c = compare(old, new, policy=p)
  assert_true(c.passes())
  assert_eq(c.suppressed().length(), 2)
  assert_eq(
    c.to_json(),
    compare(
      old,
      new,
      policy=@review.Policy::new(ignore_execution_counts=true, ignored_metadata_keys=[
        "execution",
      ]),
    ).to_json(),
  )
  assert_eq(
    @review.Comparison::from_bundle(c.to_bundle()).to_json(),
    c.to_json(),
  )
}

///|
test "policy fields and versions are closed and mandatory" {
  let valid = policy_text([])
  for
    text in [
      "{}",
      valid.replace(old="policy-1", new="policy-2"),
      valid.replace(old="\"format\":", new="\"extra\":true,\"format\":"),
      valid.replace(old="\"ignore_execution_counts\":false,", new=""),
      valid.replace(
        old="\"ignored_metadata_keys\":[]",
        new="\"ignored_metadata_key\":[]",
      ),
    ] {
    let bad = try {
      ignore(@review.Policy::from_json(text))
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
}

///|
test "policy duplicate escaped keys and wrong types are rejected" {
  for
    text in [
      "{\"format\":\"moonnbreview/policy-1\",\"ignore_execution_counts\":false,\"\\u0069gnore_execution_counts\":true,\"ignored_metadata_keys\":[]}",
      policy_text([]).replace(old="false", new="1"),
      policy_text([]).replace(old="[]", new="[null]"),
      policy_text([]).replace(old="[]", new="{}"),
      policy_text(["x", "x"]),
      policy_text([""]),
    ] {
    let bad = try {
      ignore(@review.Policy::from_json(text))
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
}

///|
test "policy key limits and escaped unicode are validated" {
  let sixty_four = Array::makei(64, i => "key-" + i.to_string())
  ignore(@review.Policy::from_json(policy_text(sixty_four)))
  sixty_four.push("overflow")
  for
    text in [
      policy_text(sixty_four),
      policy_text(["x".repeat(129)]),
      policy_text([]).replace(old="[]", new="[\"\\ud800\"]"),
    ] {
    let bad = try {
      ignore(@review.Policy::from_json(text))
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
  ignore(@review.Policy::from_json(policy_text(["x".repeat(128)])))
}

///|
test "an invalid file does not affect later policy loads" {
  let bad = try {
    ignore(@review.Policy::from_json("{"))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  assert_eq(
    @review.Policy::from_json(policy_text([])).to_json(),
    @review.Policy::new().to_json(),
  )
}

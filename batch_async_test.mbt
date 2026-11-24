///|
async test "async sources yield serially and preserve synchronous bytes and replay" {
  let m = @review.Manifest::new([pair("changed"), pair("same", new_path="old")])
  let calls : Array[String] = []
  let policy = @review.Policy::new(ignore_execution_counts=true)
  let gate = @review.Gate::new(blocked=[@review.Output])
  let b = m.review_sides_async(
    path => {
      @async.sleep(1)
      calls.push("old:" + path)
      load_pair(path)
    },
    path => {
      @async.sleep(1)
      calls.push("new:" + path)
      load_pair(path)
    },
    policy~,
    gate~,
    retain_inputs=true,
  )
  let expected = m.review(load_pair, policy~, gate~, retain_inputs=true)
  assert_eq(calls, ["old:old", "new:new", "old:old", "new:old"])
  assert_eq(b.to_json(), expected.to_json())
  assert_eq(b.to_bundle(), expected.to_bundle())
  assert_eq(b.exit_code(), expected.exit_code())
}

///|
async test "async source errors preserve phases recovery and empty no IO behavior" {
  let m = @review.Manifest::new([
    pair("old-read", old_path="gone"),
    pair("old-parse", old_path="invalid"),
    pair("new-read", new_path="gone"),
    pair("new-parse", new_path="invalid"),
    pair("recovery", new_path="old"),
  ])
  let calls : Array[String] = []
  let b = m.review_sides_async(
    path => {
      @async.sleep(1)
      calls.push("old:" + path)
      load_pair(path)
    },
    path => {
      @async.sleep(1)
      calls.push("new:" + path)
      load_pair(path)
    },
    retain_inputs=true,
  )
  assert_eq(b.to_json(), m.review(load_pair, retain_inputs=true).to_json())
  assert_eq(b.exit_code(), 2)
  assert_eq(calls, [
    "old:gone", "old:invalid", "old:old", "new:gone", "old:old", "new:invalid", "old:old",
    "new:old",
  ])
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
  let empty = @review.Manifest::new([]).review_sides_async(
    _ => fail("unexpected old"),
    _ => fail("unexpected new"),
  )
  assert_eq(empty.exit_code(), 0)
}

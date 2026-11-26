///|
fn lifecycle_manifest() -> @review.FileManifest raise {
  @review.FileManifest::new([
    { id: "added", old_path: None, new_path: Some("new"), },
    { id: "removed", old_path: Some("old"), new_path: None, },
    { id: "modified", old_path: Some("old"), new_path: Some("new"), },
  ])
}

///|
test "manifest2 round trips and copies explicit nullable paths" {
  let inputs : Array[@review.FilePair] = [
    { id: "add", old_path: None, new_path: Some("new"), },
  ]
  let manifest = @review.FileManifest::new(inputs)
  inputs.clear()
  manifest.pairs().clear()
  assert_eq(manifest.pairs().length(), 1)
  assert_true(manifest.to_json().contains("\"old\":null"))
  assert_eq(
    @review.FileManifest::from_json(manifest.to_json()).to_json(),
    manifest.to_json(),
  )
  let legacy = @review.Manifest::new([pair("old")])
  let adapted = @review.FileManifest::from_json(legacy.to_json())
  assert_eq(adapted.to_json(), legacy.to_json())
  let expected = legacy.review(load_pair, retain_inputs=true)
  let actual = adapted.review(load_pair, retain_inputs=true)
  assert_eq(actual.to_json(), expected.to_json())
  assert_eq(actual.to_bundle(), expected.to_bundle())
}

///|
test "file batch reviews complete additions deletions and modifications without reading absent sides" {
  let calls : Array[String] = []
  let m = lifecycle_manifest()
  let batch = m.review_sides(
    path => {
      calls.push("old:" + path)
      load_pair(path)
    },
    path => {
      calls.push("new:" + path)
      load_pair(path)
    },
    retain_inputs=true,
  )
  assert_eq(calls, ["new:new", "old:old", "old:old", "new:new"])
  assert_eq(batch.exit_code(), 1)
  guard @json.parse(batch.to_json()) is Object(root) &&
    root["results"] is Array(entries) &&
    entries[0] is Object(added) &&
    entries[1] is Object(removed) &&
    entries[2] is Object(modified) else {
    abort("missing results")
  }
  assert_eq(root["format"], Json("moonnbreview/batch-2"))
  assert_eq(added["old"], Json::null())
  assert_eq(removed["new"], Json::null())
  assert_eq(
    modified["report"],
    @json.parse(compare(load_pair("old"), load_pair("new")).to_json()),
  )
  let bundle = batch.to_bundle()
  assert_true(bundle.contains("moonnbreview/batch-bundle-2"))
  assert_eq(@review.BatchReview::from_bundle(bundle).to_json(), batch.to_json())
  assert_eq(@review.BatchReview::from_bundle(bundle).to_bundle(), bundle)
  assert_eq(m.review(load_pair).to_json(), batch.to_json())
  assert_eq(m.review(load_pair).to_markdown(), batch.to_markdown())
}

///|
test "file batch failures retain exact phases continue and survive offline replay" {
  let m = @review.FileManifest::new([
    { id: "add-missing", old_path: None, new_path: Some("gone"), },
    { id: "delete-malformed", old_path: Some("invalid"), new_path: None, },
    { id: "deleted", old_path: Some("old"), new_path: None, },
  ])
  let b = m.review(load_pair, retain_inputs=true)
  assert_eq(b.exit_code(), 2)
  assert_true(b.to_json().contains("read_new"))
  assert_true(b.to_json().contains("parse_old"))
  assert_true(b.to_markdown().contains("## Notebook 3: blocked"))
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
  let allowed = lifecycle_manifest().review(
    // A selective gate retains complete whole-file witnesses.
    load_pair,
    gate=@review.Gate::new(blocked=[]),
  )
  assert_eq(allowed.exit_code(), 0)
  assert_true(
    batch_bundle_refused(b.to_bundle().replace(old="read_new", new="read_old")),
  )
  assert_true(allowed.to_json().contains("\"kind\":\"structure\""))
}

///|
test "strict manifest2 rejects ambiguity missing unknown duplicate and malformed paths" {
  let valid = lifecycle_manifest().to_json()
  for
    text in [
      valid.replace(old="manifest-2", new="manifest-3"),
      valid.replace(old="\"new\":\"new\"", new="\"new\":null"),
      valid.replace(old="\"old\":null", new="\"old\":false"),
      valid.replace(old="\"old\":null", new="\"old\":null,\"extra\":0"),
      valid.replace(old="\"old\":null", new="\"old\":null,\"old\":null"),
      valid.replace(old="\"old\":null", new="\"omitted\":null"),
      valid.replace(old="\"id\":\"added\"", new="\"id\":\"removed\""),
      valid.replace(old="\"new\":\"new\"", new="\"new\":\"\\ud800\""),
    ] {
    assert_true(
      try {
        ignore(@review.FileManifest::from_json(text))
        false
      } catch {
        _ => true
      },
    )
  }
  for
    pairs in [
      [@review.FilePair::{ id: "absent", old_path: None, new_path: None, }],
      [@review.FilePair::{ id: "empty", old_path: Some(""), new_path: None, }],
      Array::makei(65, i => @review.FilePair::{
        id: i.to_string(),
        old_path: None,
        new_path: Some("new"),
      }),
    ] {
    assert_true(
      try {
        ignore(@review.FileManifest::new(pairs))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "file bundle presence must match context and cannot be disguised as legacy" {
  let batch = lifecycle_manifest().review(load_pair, retain_inputs=true)
  let valid = batch.to_bundle()
  assert_true(
    batch_bundle_refused(
      valid.replace(old="batch-bundle-2", new="batch-bundle-1"),
    ),
  )
  guard @json.parse(valid) is Object(root) &&
    root["entries"] is Array(entries) &&
    entries[0] is Object(added) else {
    abort("bad archive")
  }
  added["old"] = Json("invented-present-path")
  assert_true(batch_bundle_refused(Json(root).stringify()))
  assert_eq(@review.BatchReview::from_bundle(valid).to_json(), batch.to_json())
}

///|
test "empty file batches and exact 64 boundary remain valid and replayable" {
  let empty = @review.FileManifest::new([]).review(
    _ => fail("no IO"),
    retain_inputs=true,
  )
  assert_eq(empty.exit_code(), 0)
  assert_eq(
    @review.BatchReview::from_bundle(empty.to_bundle()).to_json(),
    empty.to_json(),
  )
  let m = @review.FileManifest::new(
    Array::makei(64, i => @review.FilePair::{
      id: i.to_string(),
      old_path: None,
      new_path: Some("old"),
    }),
  )
  assert_eq(m.pairs().length(), 64)
  assert_true(m.review(load_pair).to_json().contains("\"total\":64"))
}

///|
test "whole-file batch aggregate limits refuse without dropping documents and recover" {
  let m = @review.FileManifest::new(
    Array::makei(6, i => @review.FilePair::{
      id: i.to_string(),
      old_path: None,
      new_path: Some("big"),
    }),
  )
  let big = notebook([cell("a", source="x".repeat(1600000))])
  assert_true(
    try {
      ignore(m.review(_ => big, retain_inputs=true))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(lifecycle_manifest().review(load_pair).exit_code(), 1)
}

///|
async test "async file sources agree byte-for-byte and never load absent sides" {
  let m = lifecycle_manifest()
  let calls : Array[String] = []
  let actual = m.review_sides_async(
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
  let expected = m.review(load_pair, retain_inputs=true)
  assert_eq(actual.to_json(), expected.to_json())
  assert_eq(actual.to_bundle(), expected.to_bundle())
  assert_eq(calls, ["new:new", "old:old", "old:old", "new:new"])
}

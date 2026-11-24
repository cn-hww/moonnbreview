# Public library example

This code is compiled and executed as a black-box documentation test.

```mbt check
///|
test "public notebook review workflow" {
  let old =
    #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[{"id":"calculation","cell_type":"code","source":"print(1)","metadata":{},"execution_count":1,"outputs":[]}]}
  let new = old.replace(old="print(1)", new="print(2)")
  let result = @review.compare(
    @review.Document::parse(old),
    @review.Document::parse(new),
  )
  assert_false(result.passes())
  let output_gate = @review.Gate::new(blocked=[@review.Output])
  assert_true(result.passes(blocked=output_gate.blocked()))
  assert_eq(
    @review.Gate::from_json(output_gate.to_json()).to_json(),
    output_gate.to_json(),
  )
  assert_eq(result.changes()[0].cell_id, Some("calculation"))
  assert_eq(result.changes()[0].kind, @review.Source)
  let replay = @review.Comparison::from_bundle(result.to_bundle())
  assert_eq(replay.to_json(), result.to_json())
  let policy_file = @review.Policy::new().to_json()
  let configured = @review.compare(
    @review.Document::parse(old),
    @review.Document::parse(new),
    policy=@review.Policy::from_json(policy_file),
  )
  assert_eq(configured.to_json(), result.to_json())
  assert_true(configured.to_markdown().contains("Active changes: 1"))
  assert_true(configured.to_html().contains("Complete JSON evidence"))
  assert_eq(configured.mime_changes().length(), 0)
  assert_true(
    configured.to_html(group_mime=true).contains("MIME-addressed changes"),
  )
  let manifest = @review.Manifest::new([
    { id: "analysis", old_path: "base", new_path: "proposed", },
  ])
  let batch = manifest.review(path => if path == "base" { old } else { new })
  assert_eq(batch.exit_code(), 1)
  assert_true(batch.to_markdown().contains("## Notebook 1: blocked"))
  assert_true(batch.to_markdown(focus_changes=true).contains("Preview range:"))
  let separate = @review.Manifest::new([
    { id: "analysis", old_path: "lesson.ipynb", new_path: "lesson.ipynb", },
  ]).review_sides(_ => old, _ => new, retain_inputs=true)
  assert_eq(separate.exit_code(), 1)
  assert_eq(
    @review.BatchReview::from_bundle(separate.to_bundle()).to_json(),
    separate.to_json(),
  )
  let captured = manifest.review(
    path => if path == "base" { old } else { new },
    retain_inputs=true,
  )
  assert_eq(
    @review.BatchReview::from_bundle(captured.to_bundle()).to_json(),
    batch.to_json(),
  )
  assert_eq(
    @review.Manifest::from_json(manifest.to_json()).to_json(),
    manifest.to_json(),
  )
  assert_true(
    configured.to_markdown(focus_changes=true).contains("Preview range:"),
  )
}
```

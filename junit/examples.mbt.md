# Notebook batch to JUnit

```mbt check
///|
test "export a Notebook gate result to a CI testcase" {
  let source =
    #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[]}
  let manifest = @review.Manifest::new([
    { id: "tutorial", old_path: "before", new_path: "after", },
  ])
  let batch = manifest.review(_ => source)
  let xml = @junit.render(batch)
  assert_true(@codec.parse_report(xml).cases[0].is_passed())
  assert_eq(batch.exit_code(), 0)
}
```

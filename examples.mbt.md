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
  assert_eq(result.changes()[0].cell_id, Some("calculation"))
  assert_eq(result.changes()[0].kind, @review.Source)
  let replay = @review.Comparison::from_bundle(result.to_bundle())
  assert_eq(replay.to_json(), result.to_json())
}
```

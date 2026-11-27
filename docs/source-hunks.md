# Exhaustive source line hunks

For a cell edited in several distant places, prefix or first-difference previews
can miss later edits. Use this opt-in view in any of the four review CLIs:

```sh
moon run cmd/main --target wasm -- review fixtures/before.ipynb fixtures/after.ipynb --format markdown --source-hunks
moon run cmd/main --target wasm -- bundle fixtures/before.ipynb fixtures/after.ipynb > review.json
moon run cmd/main --target wasm -- replay review.json --format markdown --source-hunks
```

Batch and Git commands accept the same flag with Markdown. It may occur once,
cannot combine with `--focus-changes`, and is invalid for JSON/HTML/JUnit or
bundle creation. Existing default reports, JSON evidence, policies, gates and
replay bundles are unchanged. Added/deleted cells and non-source changes retain
their existing before/after previews; this mode only replaces paired cell
`/source` string previews.

Library callers use `comparison.to_markdown(source_hunks=true)` or
`batch.to_markdown(source_hunks=true)`. For structured evidence, call
`change.source_hunks(context=3)`: it returns `None` for other witness types, or
fresh `SourceHunk` arrays with unified headers and `SourceLine` records. Line
locations are one-based; absent-side locations are `None`. Each line's `text`
includes its original LF if present, including CR before LF. Empty sources have
zero lines; trailing LF never creates a phantom line. Markdown displays CR as
`\u000d` and marks an unterminated line explicitly. Safe fences prevent source
Markdown or HTML from escaping the code block.

All edits are included with three lines of context in Markdown. Each paired
source is limited to 200,000 combined UTF-16 units and 4,000 combined lines;
structured context must be 0..20. The existing complete Markdown cap is 1M units.
Exceeding a budget raises a diagnostic rather than returning partial Markdown;
the complete JSON report/bundle remains available. The implementation reuses
[MoonBit core/diff](https://github.com/moonbitlang/core/tree/main/diff) Myers with
cutoff 1000, which produces complete deterministic edits but does not promise a
minimal edit script. No generic diff engine was copied into this project.

`source_hunks_test.mbt` verifies separated edits, exact input reconstruction,
empty sides, repeated lines, final LF, CRLF, Unicode, fresh arrays, recovery,
budget rejection, batch rendering and replay. The main verifier executes the
documented file/replay workflow on each selected backend.

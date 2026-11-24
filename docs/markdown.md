# Human-readable notebook reviews

Generate a Markdown review of the real, pinned Jupyter-derived fixture:

```text
moon run cmd/main -- review fixtures/before.ipynb fixtures/after.ipynb --policy fixtures/policy.json --format markdown
moon run cmd/main -- check fixtures/before.ipynb fixtures/after.ipynb --policy fixtures/policy.json --format markdown
```

Both outputs start with `# Notebook review`, `Active changes: 3` and
`Suppressed changes: 2`. They contain an order witness, the edited Markdown cell's
source and changed stdout outputs, followed by the suppressed execution metadata
and counter. `review` exits 0; `check` exits 1 for these same changes. The format
never changes the gate verdict. Invalid format names or conflicting options exit 2.

The default CLI format remains JSON. `bundle` remains fixed-format JSON and refuses
`--format`; archive its JSON stdout as UTF-8. To render a saved bundle:

```text
moon run cmd/main -- replay saved-bundle.json --format markdown
```

Replay recomputes the comparison from retained inputs and policy, then renders it.
The verifier compares JSON and Markdown output across four backends (normalizing
only console CRLF), verifies Markdown replay matches a fresh comparison, and
checks that the original fixtures remain unchanged.

## Rendering contract

`Comparison::to_markdown(preview_chars=240)` returns a deterministic presentation.
The limit is 32..4096 UTF-16 units for **each before/after value representation**.
Strings are displayed as multiline text; other values use canonical JSON. A
preview never splits a surrogate pair. Whenever text is omitted, the report states
the exact omitted unit count and directs the reader to full JSON evidence.
Truncation is a presentation choice, not a data transformation or acceptance of
unsupported notebook data. `to_json` and `to_bundle` retain their complete payloads.

Every active and suppressed change has its category, full cell ID, pointer and
suppression reason. Missing evidence is shown as `Absent.`; explicit null is shown
as a JSON `null` block. Locations are not clipped. Markdown output is limited to
1,000,000 UTF-16 units; over-budget output returns a diagnostic without a partial
report. Use JSON when the complete locations or many previews exceed that limit.

Untrusted content appears inside fenced blocks; the tilde fence is chosen longer
than every tilde run in its content. Notebook HTML, images, Markdown links and
headings are presented as data, not rendered as rich content. ASCII/C1 controls
other than LF and tab are shown as escapes, preserving CR differences visibly.
Reports still contain potentially sensitive source and metadata.

This is a textual review renderer, not an image pixel comparison, notebook runner,
browser UI or approval mechanism. No external renderer or fixture is incorporated.

## Focus on changes in long cells

Prefix previews can look identical when a source edit occurs late in a long cell.
Opt into a bounded view around the **first differing character**:

```text
moon run cmd/main -- check fixtures/before.ipynb fixtures/after.ipynb --policy fixtures/policy.json --format markdown --focus-changes
moon run cmd/main -- replay saved-bundle.json --format markdown --focus-changes
moon run cmd/git-review -- review . HEAD HEAD fixtures/before.ipynb --format markdown --focus-changes
```

The corresponding library call is
`comparison.to_markdown(preview_chars=240, focus_changes=true)`. Default output
remains byte-for-byte compatible with prefix mode. The flag requires Markdown,
may occur once, and cannot be used for JSON or bundle output. Exit/gate semantics,
suppression policy, complete JSON and replay bundles are unchanged.

For a before/after **string pair**, focus mode scans their common prefix and
reserves approximately one quarter of the preview budget for shared context
before the first difference. Both windows start at the same original offset;
surrogate boundaries may shift that offset by one unit. Each side states its
half-open original UTF-16 range `[start, end)`, 1-based LF-delimited line and
1-based UTF-16 column, plus exact units omitted before and after the window.
Coordinates are computed before visible control escaping. A character above
U+FFFF occupies two column units. CR is visible data; LF advances the line.

This is **not an exhaustive text diff**: long replacements and later separated
edits may be outside the window. The report states this explicitly. Nonstring
values, additions and removals keep their existing prefix/absence presentation;
suppressed string pairs can also be focused without changing the gate verdict.
All existing preview/report limits, fences and control escaping still apply.

The main verifier derives a long-source case from the real Jupyter fixture by
adding labeled shared context and two different trailing edit markers. It proves
the ordinary preview omits those markers while focus mode shows both, on all four
targets. These synthetic edits are test data, not changes to the upstream fixture.

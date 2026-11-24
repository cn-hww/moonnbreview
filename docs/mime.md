# Organize output evidence by MIME data key

Rich Jupyter outputs can carry several representations of one result. Grouping
their addressed changes makes it easier to inspect JSON, textual and image data
without executing the notebook or rendering arbitrary HTML:

```text
moon run cmd/main -- review fixtures/before.ipynb fixtures/after.ipynb --format html --group-mime
moon run cmd/main -- replay saved-bundle.json --format html --group-mime
moon run cmd/git-review -- review . HEAD HEAD fixtures/before.ipynb --format html --group-mime
```

The flag is opt-in, may occur once, and requires HTML on review/check/replay.
JSON, Markdown and bundle commands refuse the option rather than ignore it.
Default HTML bytes, complete JSON evidence, gate verdicts and bundle formats
remain unchanged. The original fixture changes an entire output array; such
evidence remains a complete ungrouped witness. The verifier also derives two
labeled rich-output variants of the real fixture with paired `text/plain` and
`application/json` changes, and verifies both groups on all four targets.

Library API: `comparison.mime_changes()` returns independent `MimeGroup` values
with `key`, `category`, and complete `changes`. Groups have deterministic key order;
members retain comparison order and full cell IDs/pointers. `Change::mime_key()`
and `mime_category()` expose the same classification for individual witnesses.
Returned arrays and nested JSON evidence can be mutated without affecting the
comparison or future query results. `to_html(group_mime=true)` uses this grouping
within active/suppressed sections, while retaining every other change normally.

Keys come only from `Output` witnesses addressed inside a recognized output's
`/outputs/INDEX/data/KEY/...`. JSON Pointer `~1` and `~0` are decoded once; a slash
inside a MIME key or a similarly named JSON payload field does not change scope.
Unknown output extension fields, streams, metadata, source and whole output/cell
replacements are not guessed into a MIME representation. This method is a **query
view**, not a replacement for `changes`, `suppressed` or the full JSON report.

Classification is a conservative, case-sensitive presentation hint from the exact
key: `text/*` is Text, `application/json` and `application/*+json` are StructuredJson,
`image/*` is Image, other keys are Opaque. It does not validate MIME syntax,
payload JSON schemas, image/base64 bytes or rendering safety. No payload is decoded,
normalized away or dropped by grouping. Unknown accepted keys/values retain their
original evidence. Existing document validation may reject unsupported MIME value
shapes before a comparison can be formed.

HTML group headings are escaped as literal text. Image/SVG, HTML, links and all
other payloads remain data; no script, remote fetch or image renderer is added.
The existing 16M HTML and 8M complete JSON limits still refuse excess output without
partial reports. Grouped replay is deterministic. Browser visual preview remains
unverified because the local-file browser policy previously refused it.

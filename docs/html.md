# Offline HTML review

Use `--format html` on file review/check/replay or Git review/check:

```text
moon run cmd/main -- review fixtures/before.ipynb fixtures/after.ipynb --policy fixtures/policy.json --format html
moon run cmd/main -- replay saved-bundle.json --format html
moon run cmd/git-review -- check . HEAD HEAD fixtures/before.ipynb --format html
```

Save the HTML stdout as a UTF-8 `.html` file and open it in a browser. The output
is a complete document with an inline stylesheet; no server, network, JavaScript,
renderer dependency or private infrastructure is needed. `check` retains its 0/1/2
exit semantics and supports `--gate`. The report shows change counts, **not a gate
verdict**. JSON remains the default. Bundles remain JSON and refuse `--format`.
`--focus-changes` is specific to Markdown and refuses HTML instead of being ignored.

Library API: `comparison.to_html() -> String raise ReviewError`. The public
documentation test compiles and executes this call. Active and suppressed changes
have separate sections; each collapsible change includes complete location/policy
context and before/after values. Active source/structure changes initially expand.
Two columns become one on narrow screens. Empty sections and absent fields are
explicit, distinct from JSON null.

Values are complete, not previews. Strings preserve LF/tab and show other ASCII/C1
controls visibly as escapes. Other values use canonical JSON. A final collapsible
section retains the **exact full report-1 JSON text**, including original string
escapes and unknown extension fields. JSON and bundle serialization are unchanged;
replaying a bundle produces the identical HTML. HTML is presentation, not an
approval-import or notebook execution format.

All dynamic content is HTML-escaped and inserted only in element text, never as
markup, URLs, CSS or attributes. Notebook HTML, image payloads, links, Markdown,
scripts and terminal escapes remain literal text. A restrictive meta CSP disables
scripts and remote content; the page contains no script or remote asset tags.
This is a textual reviewer, not a rich HTML/image renderer or pixel comparator.
Source, outputs and metadata remain potentially sensitive, as in the inputs.

The existing 8,000,000-unit JSON report limit applies first. Complete HTML is capped
at 16,000,000 UTF-16 units, including escaping and embedded evidence. Large expansion
returns a clear error without partial output; use JSON instead. These are output
limits, not a streaming-memory guarantee.

The regular verifier generates HTML from the pinned Jupyter-derived data, writes
and rereads a temporary UTF-8 file, extracts full JSON evidence for exact comparison,
checks byte equality/replay across all four backends, and compares both CLIs on Git's
supported targets. Unit tests include hostile closing tags, entity-looking strings,
quotes, remote URLs, Unicode, controls, unknown outputs, long data, output limits,
error recovery and unchanged full evidence. No external HTML template, assets or
implementation were copied.

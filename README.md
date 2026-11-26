# MoonNBReview

Notebook semantic change review and explicit CI policies, written in MoonBit.

MoonNBReview helps teams review Jupyter notebooks without digging through JSON
formatting, execution counters and rich-output payloads. It aligns cells by ID,
separates source, output, attachment, metadata and extension changes, and records
every policy-suppressed change with its reason. Inputs are never rewritten.

The **initial usable source milestone (0.1.0)** is complete for the documented
review workflow. The package has **not been published to Mooncakes**.
See [release scope and reproducible preflight](docs/release.md),
[change history](CHANGELOG.md) and [contribution guide](CONTRIBUTING.md).

## Try the complete workflow

Use MoonBit `0.10.22+124d61d05`, Node.js 22 for JS, and a C compiler for native
(an MSVC developer environment on Windows).
The CLI also executes with `moonrun` on Wasm and Wasm-GC.
See [installation and downstream use](docs/install.md) for native executables and
source-workspace integration, or `moon run cmd/main -- --help` for command usage.

```text
git clone https://github.com/cn-hww/moonnbreview.git
cd moonnbreview
moon update
moon run cmd/main -- review fixtures/before.ipynb fixtures/after.ipynb
moon run cmd/main -- check fixtures/before.ipynb fixtures/after.ipynb --ignore-execution-counts --ignore-metadata execution
```

The second command prints a complete JSON report and exits **1**: source,
relative cell order and output changes remain. Two noise changes are explicitly
recorded in `suppressed`. A comparison of `before.ipynb` with itself exits **0**.
Malformed input, unsupported data, bad options and resource limits exit **2**.
Errors go to stdout as escaped diagnostic text; success output is one JSON object.
`review`, `bundle` and `replay` exit 0 for a valid result even when changes exist.

```text
moon run cmd/main -- bundle fixtures/before.ipynb fixtures/after.ipynb
moon run cmd/main -- replay saved-bundle.json
moon run --deny-warn scripts/verify.mbtx
```

Save the **JSON stdout** of `bundle` as UTF-8 to use `replay`. A bundle contains
both complete normalized inputs and the exact policy; loading it recomputes all
evidence. `scripts/verify.mbtx` demonstrates this without shell redirection and
executes the tests and CLI on all four backends, including native execution.
Reports and bundles contain full notebook content: handle them like the inputs.

For a human-readable review, add `--format markdown` to `review`, `check` or
`replay`. Markdown retains all change locations and suppression reasons, with
explicit bounded value previews. It does not replace the full JSON evidence.
See [Markdown reports](docs/markdown.md) for limits and a complete real-data workflow.

Use `--format html` for a self-contained browser report with collapsible changes,
complete before/after values and exact JSON evidence. Notebook content remains
literal text. See [offline HTML review](docs/html.md).

Compare committed notebooks directly with the optional Git adapter, without
checkout or index changes:

```text
moon run cmd/git-review -- check . HEAD HEAD fixtures/before.ipynb --policy fixtures/policy.json
```

Use `review|check|bundle REPO OLD_REF NEW_REF PATH` for your own repository.
The [Git workflow](docs/git.md) documents the reusable snapshot API, real-data
end-to-end example and its Wasm/native scope.
For a renamed notebook, append `--new-path PROPOSED_PATH`; the positional path
continues to identify the old commit's file. No rename heuristics are applied.

To choose which active changes block CI, use `check ... --gate fixtures/gate.json`.
The [gate file](docs/gates.md) selects categories without removing evidence;
omitting it preserves the default of blocking every active change.

For several notebook pairs, use `moon run cmd/batch -- check fixtures/manifest.json`.
The [batch workflow](docs/batch.md) retains complete per-file evidence, continues
after individual errors, and reports a deterministic 0/1/2 CI result.
`cmd/batch bundle` and `cmd/batch replay` provide [complete offline replay](docs/batch-replay.md)
of those pairs, with explicit retention and persistent error evidence.
Add `--format junit` to batch review/check/replay for
[per-Notebook CI test results](docs/junit.md), preserving complete evidence and
the original gate/error exit semantics.

`moon run cmd/git-batch -- check . HEAD HEAD fixtures/manifest.json` reviews an
entire explicit manifest directly from pinned Git revisions, including separate
old/new paths. See [Git batch review](docs/git-batch.md) for library APIs and replay.
Add `--format markdown` to file/Git batch review or offline batch replay for
[one human-readable batch report](docs/batch-markdown.md), including all file
outcomes and diagnostics. `--focus-changes` shows the first differing text region.

For a complete CI job, use the [artifact workflow](docs/ci.md). One `.mbtx` command
saves the retained bundle, JSON, Markdown, JUnit and pinned Git IDs, keeps evidence
when the gate fails, and reports any export refusal explicitly.

Whole-file additions and deletions are supported through explicit nullable paths
in [manifest-2 and the file lifecycle API](docs/file-lifecycle.md). Existing v1
manifests/reports remain compatible. Try `moon run cmd/batch -- check fixtures/file-manifest.json`.

## Use the library

Import `"cn-hww/moonnbreview" @review` in `moon.pkg`. For checkout development use
a `moon.work` listing this module and the consuming module. See the compiled
[public API example](examples.mbt.md) and [generated interface](pkg.generated.mbti).

Core review types are `Document`, `Policy`, `Gate`, `Comparison`, `Change` and
`ChangeKind`, with `compare` as the entry point. `ReviewPair`, `Manifest` and
`BatchReview` provide the explicit multi-file workflow.
`Manifest::review_sides` accepts independent baseline and proposed loaders, so the
same path can refer to different revisions without temporary filename rewriting.
See the [batch API workflow](docs/batch.md) and compiled public example.

- `Document::parse` validates text; `to_string` retains accepted semantic data;
  `notebook` returns the immutable `moonrockz/notebooks/nbformat` model.
- `Policy::new` explicitly enables count suppression or exact metadata-key
  suppression. The default suppresses nothing. Caller arrays are copied.
- `Policy::to_json` / `from_json` persist a strict, versioned policy file for CI.
  Use `--policy fixtures/policy.json` with `review`, `check` or `bundle`. A policy
  file cannot be mixed with inline suppression flags; see [policy files](docs/policies.md).
- `compare` aligns stable IDs and returns an immutable comparison.
- `changes` and `suppressed` return independent change witnesses.
- `passes` blocks all active changes by default; callers may select categories.
  `Gate` persists those category selections as a strict, versioned CI file.
- `to_json` emits a full versioned report. `to_bundle` / `from_bundle` provide
  deterministic, recomputed replay. There is no trusted report-import verdict.
- `to_markdown(preview_chars=240)` presents both active and suppressed changes;
  long value previews state exactly how many UTF-16 units were omitted.
  Add `focus_changes=true` or CLI `--format markdown --focus-changes` to show
  the first differing region of paired strings with original offsets and lines.
- `to_html` renders full evidence as an offline, script-free HTML document.
  `--format html --group-mime` (or `group_mime=true`) organizes addressed output
  changes by MIME data key. `mime_changes()` exposes the copied groups to callers;
  see [MIME evidence](docs/mime.md) for exact classification and fallback rules.

Change paths are JSON Pointers **relative to the cell identified by `cell_id`**;
when `cell_id` is null they are relative to the notebook. Added/removed/type-changed
cells use the empty pointer and retain the complete before/after cell. Missing
`before` or `after` means absent, distinct from an explicit JSON null.

Relative order compares only retained IDs. Inserting one new cell does not report
all later cells as moved. Reordering yields one complete retained-ID order witness;
the library does not guess which individual cell a user dragged.

Metadata suppression matches immediate keys of notebook, cell and recognized
rich-output metadata only. It does not match arbitrary nested keys or unknown
output extension fields. An output-count change is suppressible only for an
`execute_result`; unknown output fields remain extension changes. If the number
or type of outputs changes, the complete output witness is retained and not
partially suppressed.

## Three practical uses

1. **Analysis PRs:** compare the base and proposed notebook, inspect source and
   output witnesses, then block changes that require review with the CI exit code.
2. **Dependency upgrades and tutorial reruns:** compare a stored notebook with a
   rerun, explicitly filter approved counter/metadata noise, and inspect changed
   text, JSON, rich payloads and errors. This does not prove execution correctness.
3. **Teaching material edits:** distinguish reordered retained cells from source
   edits and attachment replacements before publishing a course revision.

## Supported inputs and limits

- UTF-8 JSON, exactly **nbformat 4.5**, with legal unique cell IDs.
- Standard cell/output types and unknown extension fields/types preserved as
  opaque data. The existing notebook codec validates domain structure.
- String/list-of-strings equivalence only in defined multiline fields. Whitespace
  inside source text is significant. JSON key order and indentation are not.
- JSON numeric spelling is conservative: representations are compared exactly
  after sorting object keys, not using rounded floating-point equality. Nonfinite
  numbers and values outside +/-9007199254740991 are refused. Any additional codec
  normalization that changes the normalized input is refused with a diagnostic.
- Each input: 2,000,000 UTF-16 units, JSON depth 64, 5,000 cells. Each comparison:
  50,000 change witnesses. Reports and bundles: 8,000,000 UTF-16 units. No truncation
  or partial-success result. CLI file reading occurs before the decoded input limit;
  it is not a streaming, memory-capped file reader.
- Unknown fields cannot disappear through export: input-to-model preservation is
  checked before a `Document` is accepted. Original formatting is not retained.

Not implemented: notebook execution, automatic merge, legacy ID inference, pixel
diffs, base64 image validation, trusted signatures or browser UI.
Rich payloads are compared as data; no HTML, JavaScript or notebook code executes.

## Validation and development

`moon run --deny-warn scripts/verify.mbtx` runs formatting, generated-interface
updates, strict all-target checking, public API tests, real-data CLI checks,
0/1/2 exit behavior and bundle replay on wasm, wasm-gc, js and native. Node and a
C compiler must be on PATH. CI repeats it on Linux, macOS and Windows. It also
checks reproducible fixtures and rejects formatting/interface drift.
Recorded local environments and limits are in [docs/validation.md](docs/validation.md).
`scripts/verify-release.mbtx` additionally audits the actual source ZIP, executes
consumers from its extracted contents and generates API documentation; it needs Python 3's
standard ZIP CLI, with no pip dependencies. CI runs both complete checks.
`scripts/verify.mbtx --portable` explicitly limits local execution to Wasm,
Wasm-GC and JS when a native compiler is unavailable; it does not validate native
execution.
`scripts/verify.mbtx --native` executes only the native tests and CLI checks.

The pinned upstream Jupyter fixture, its full BSD license and the clearly
documented derived examples are under [fixtures](fixtures/README.md).
Implementation, own tests and automation are MIT; see [THIRD_PARTY.md](THIRD_PARTY.md)
for dependencies, external data and design references.

## Direction

This is a complementary review layer over existing notebook models, informed by
nbdime's workflow. It is not a complete nbdime port, a notebook codec replacement
or a claim of ecosystem uniqueness. See [research](docs/research.md).

Further rich-output rendering would require separate validation and isolation.
Legacy files require a separate, explicit
identity/ambiguity design. These capabilities are planned, not implemented.

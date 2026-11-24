# Initial usable source milestone: 0.1.0

The initial project is complete for its stated review workflow: downstream code
can compare accepted notebooks, apply explicit policies/gates, review batches and
Git revisions, retain/recompute evidence and export human/CI reports. Native tools
can be installed from source and run outside the repository. A registry publication,
GitHub release/tag or production support guarantee is a separate event.

| Capability | Current boundary |
| --- | --- |
| Inputs | UTF-8 JSON, exactly nbformat 4.5, legal unique cell IDs; preservation checked |
| File/core review | Wasm, Wasm-GC, JS, native |
| Git adapter/commands | Wasm/native, Git on PATH, explicit literal paths and renames |
| Async storage | Runtime tested on Wasm/JS/native; Wasm-GC async tests are skipped |
| Evidence | Complete JSON and single/batch replay bundles, deterministic recomputation |
| Presentation | Bounded/focused single/batch Markdown, complete literal single HTML, batch JUnit |
| CI | Per-pair recovery, explicit category gate, artifacts retained on failure |
| Adoption | Separate consuming module/workspace and native installation execution |

Supported input limits and refusals are in README. No notebook execution, automatic
merge, legacy cell-ID guessing, pixel validation/diff, trusted signatures or browser
application is provided. Unknown/unsupported transformations are refused rather
than silently discarded. HTML is automatically checked for escaping/full evidence;
browser visual preview remains unverified. JUnit is tested through the reused
codec/parser, not live upload to every CI vendor.

## Reproduce the release preflight

```text
moon run --deny-warn scripts/verify.mbtx
moon run --deny-warn scripts/verify-release.mbtx
```

The second command needs only Python 3's standard ZIP CLI, in addition to the
development toolchain. It reads the formatted module's name/version/license,
checks all four CLI versions against module metadata, runs `moon package --list`,
tests ZIP CRCs, extracts to a new temporary directory, and compares every listed
path and byte against the source. Licenses, generated interfaces, documentation,
real fixtures and consumer verification must be present; `.git`, build output and
dependency caches must be absent. It rejects nonregular entries and unexpected
file-list differences. This audits this project's locally produced archive, not
arbitrary untrusted ZIP inputs. It does not promise byte-reproducible ZIP timestamps.

From the extracted archive, it runs the separate public consumer and installation
checks, pointing Git-only tests to the original fixture repository. It generates
public API member Markdown, metadata and annotated source HTML with `moon doc`,
without starting a server. All temporary copies
and installs are removed afterward; the source package remains under
`_build/publish/cn-hww-moonnbreview-0.1.0.zip`. `--portable`/`--native` limit the
consumer execution targets explicitly. CI runs the full preflight on three OSes.

## Publication is separate

The module is **not published to Mooncakes**. Registry login is absent in this
environment; `moon publish --dry-run` requires `moon login` before it can validate
publication. No registry credentials were changed. Package creation and consumer
tests therefore establish source-distribution readiness, not registry acceptance.

An owner wishing to publish should first review metadata, the exact commit's green
CI and licenses, log in as the intended owner, then run `moon publish --dry-run`.
Only after that succeeds should actual publication/tag/release proceed under the
owner's authorization. Verify the registry package/version after publication and
update README status accordingly. Do not replace an already published version.

Next work should follow adoption feedback: broader real notebook corpora and
diagnostic usability first; legacy-ID handling requires a separate ambiguity design.
Image rendering and notebook execution need their own isolated contracts and are
not prerequisites for this initial review milestone.

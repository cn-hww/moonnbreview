# Command reference

All entries support standalone `--help`/`-h` and `--version` (exit 0). From source,
use `moon run cmd/ENTRY -- ARGUMENTS`. Native installed names are in [installation](install.md).
File entries support Wasm, Wasm-GC, JS and native. Git entries support Wasm/native.

| Entry | Commands and positional arguments |
| --- | --- |
| `main` | `review|check|bundle OLD NEW`; `replay BUNDLE`; `validate NOTEBOOK` |
| `batch` | `review|check|bundle MANIFEST`; `replay BATCH_BUNDLE` |
| `git-review` | `review|check|bundle REPO OLD_REF NEW_REF OLD_PATH` |
| `git-batch` | `review|check|bundle REPO OLD_REF NEW_REF [MANIFEST]`; `discover REPO OLD_REF NEW_REF` |

`--policy FILE` works on review/check/bundle. File-single review also accepts
`--ignore-execution-counts` and repeatable `--ignore-metadata KEY`; these cannot be
mixed with a policy file. Replay uses only its retained policy/configuration.

`--gate FILE` selects blocking categories without suppressing evidence. It is
accepted by check and by **batch** bundle capture; single comparison bundles have
no gate. Review refuses a gate file. `--new-path PATH` is exclusive to Git-single
review/check/bundle and explicitly identifies a proposed path after a rename.

| Output option | Scope |
| --- | --- |
| `--format json` | Default report format; review/check/replay |
| `--format markdown` | Single or batch review/check/replay |
| `--format html` | Single comparison review/check/replay only |
| `--format junit` | Batch review/check/replay only |
| `--focus-changes` | Markdown only, once |
| `--group-mime` | Single HTML only, once |

Git entries do not implement replay; their bundles are consumed by the matching
file entry. Bundles have a fixed JSON schema and refuse `--format`. Flag values,
duplicates and conflicting scopes are checked; unknown arguments are errors.
Git batch discovers changed `.ipynb` paths when MANIFEST is omitted; discovery-only
accepts no report/configuration flags. Explicit file/Git batches accept manifest-1/2.
Single count-suppression flags are idempotent; metadata keys must be unique.

| Operation | Exit 0 | Exit 1 | Exit 2 |
| --- | --- | --- | --- |
| Any check | Passed gate | Blocked changes | Invalid input/operation or batch errors |
| Single review/bundle/replay | Valid comparison | — | Invalid input/operation |
| Batch review/bundle | No pair errors, including blocked changes | — | Pair/operation errors |
| Batch replay | Passed retained gate | Blocked changes | Recorded pair/operation errors |

CLI stdout contains one report, bundle or diagnostic, except explicit help/version.
Diagnostics are escaped text, not a successful report schema. No input is rewritten.
For report files, use the [CI artifact runner](ci.md) to write explicit UTF-8 and
keep valid evidence on failure, rather than depending on shell redirection encoding.

Notebook acceptance, normalization, resource limits, policy semantics and format
limitations remain those documented in [README](../README.md). A passing gate is
not a claim of notebook execution correctness, trust or approval.
# Source hunks

All four CLIs accept `--source-hunks` for Markdown review/check (and file/batch
replay). This exhaustive paired-source view excludes `--focus-changes`. See
[source hunk semantics and limits](source-hunks.md).

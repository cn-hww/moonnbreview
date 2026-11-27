# Public notebook corpus

These are data fixtures, not copied upstream test code. Original bytes remain
unchanged. `expected.json` records the reviewed acceptance result and Git blob
SHA-1 for every file; `git hash-object --no-filters FILE` checks exact bytes.
Hashes detect fixture drift, not authenticity against a malicious source.

**nbformat** sources: [jupyter/nbformat tests at
2b47b4bd5ed70799a2ea8fcf390fa680ee120910](https://github.com/jupyter/nbformat/tree/2b47b4bd5ed70799a2ea8fcf390fa680ee120910/tests).
All ten same-named originals below are BSD-3-Clause; the full pinned license is
retained in [../upstream/LICENSE](../upstream/LICENSE).

**Notebook** sources: [Running Code](https://github.com/jupyter/notebook/blob/5bc2024fa0453ef28039749e8ea036e0dcbb734f/docs/source/examples/Notebook/Running%20Code.ipynb)
and [Working With Markdown Cells](https://github.com/jupyter/notebook/blob/5bc2024fa0453ef28039749e8ea036e0dcbb734f/docs/source/examples/Notebook/Working%20With%20Markdown%20Cells.ipynb),
pinned to `5bc2024fa0453ef28039749e8ea036e0dcbb734f`, downloaded as
`notebook-running-code.ipynb` and `notebook-markdown.ipynb`. BSD-3-Clause; full
license from the same revision is [notebook-LICENSE](notebook-LICENSE).

| Original file | Actual result | Coverage |
| --- | --- | --- |
| `test4.5.ipynb` | Accept | Source arrays, streams, rich text/PNG, execution results |
| `test4custom.ipynb` | Refuse `NB_VERSION` | Old 4.2; custom `+json` MIME and Unicode |
| `test4plus.ipynb` | Refuse `NB_VERSION` | Future 4.99; no compatibility guess |
| `test4jupyter_metadata_timings.ipynb` | Refuse `NB_VERSION` | Old 4.4; execution timing metadata |
| `many_tracebacks.ipynb` | Refuse `NB_VERSION` | Old 4.4; repeated error tracebacks |
| `invalid_cell_id.ipynb` | Refuse `NB_FIELD` | Illegal ID, `/cells/0/id` |
| `invalid_unique_cell_id.ipynb` | Refuse `NB_CELL_ID_DUPLICATE` | Duplicate ID, `/cells/1/id` |
| `v4_5_invalid_metadata.ipynb` | Refuse `NB_FIELD` | First error `/metadata/kernelspec` |
| `v4_5_no_cell_id.ipynb` | Refuse `NB_FIELD` | Missing ID, `/cells/0/id` |
| `test3.ipynb` | Refuse `NB_VERSION` | v3 worksheets; no implicit migration |
| `notebook-running-code.ipynb` | Refuse `NB_VERSION` | Official 4.4 code tutorial |
| `notebook-markdown.ipynb` | Refuse `NB_VERSION` | Official 4.1 Markdown/LaTeX tutorial |

Five `*-prepared.ipynb` derivatives are accepted. They come from `test4custom`,
`test4jupyter_metadata_timings`, `many_tracebacks`, `notebook-running-code`, and
`notebook-markdown`. Their only changes are minor version 5 and explicit
`corpus-demo-N` IDs assigned in original order, plus JSON formatting. All source,
output, MIME and metadata payloads remain. These demo-only identities are not a
general migration policy. Reproduce with `moon run scripts/prepare-corpus.mbtx`;
production `parse`/`validate` never calls this preparation step.

The 17 cases therefore contain **6 accepted / 11 refused**, including only one
unmodified accepted upstream notebook. This deliberately exposes the project's
strict input boundary. It is not a production compatibility survey. Attachments,
unknown cell/output extensions and other boundary cases additionally have authored
unit tests; this corpus does not yet establish real-world coverage for those
categories. See [the executable acceptance workflow](../../docs/acceptance.md).

# Review an explicit notebook batch

A CI job can name multiple before/after files without writing its own comparison
loop or losing the rest of the review when one file is broken:

```text
moon run cmd/batch -- check fixtures/manifest.json --policy fixtures/policy.json
moon run cmd/batch -- review fixtures/manifest.json --policy fixtures/policy.json
```

The committed manifest pairs the real Jupyter-derived revision with an unchanged
control. `check` emits a complete batch-1 JSON report and exits 1 (one blocked, one
passed). `review` emits identical evidence and exits 0 for this valid review.
For **either** command, any file/parse/comparison error produces per-pair diagnostics
and exit 2, after continuing through later pairs. Invalid manifest/options or
aggregate resource exhaustion also exit 2, with an escaped diagnostic instead of
a partial batch. Errors take precedence over blocked changes.

Manifest-1 has exactly `format` and `pairs`. Every pair has exactly string `id`,
`old` and `new` fields. See [the runnable manifest](../fixtures/manifest.json).
Paths are literal and relative to the **caller's working directory**, or absolute;
they are not relative to the manifest file. This explicit file workflow performs
no recursive discovery, glob expansion, Git lookup, rename inference or input write.
It is not a filesystem sandbox: the caller chooses which files to read.

An ordered manifest accepts 0..64 pairs with unique 1..128-unit IDs. Each path has
1..4096 UTF-16 units. Malformed Unicode and ASCII controls are refused. Empty
manifests explicitly succeed without reading any files. Existing strict 2M-unit
JSON rules apply to manifest text; duplicate/unknown/missing fields and wrong types
refuse the whole manifest before any notebook is loaded.

`check` optionally accepts one `--gate FILE`; `--policy FILE` works for both commands.
Inline suppression flags and alternative output formats are not supported by this
entry. Each successful pair keeps its **complete report-1 evidence**, and the batch
also records exact versioned policy/gate configuration. Each failed pair records
its ID/paths and phase (`read_old`, `parse_old`, `read_new`, `parse_new`, `compare`
or `serialize`) with a diagnostic. Summary counts cover every pair in manifest order.
Unlike report/bundle-1, batch-1 contains gate evaluation; no API trusts an imported
batch verdict. Archive the report/configuration as evidence, not a signed approval.

Library users construct `ReviewPair` records, create/load `Manifest`, and call
`manifest.review(loader, policy~, gate~)`. The synchronous loader accepts a literal
path and returns text or raises; it can read files, an in-memory map or application
storage. `BatchReview::to_json()` returns immutable complete evidence, and
`exit_code()` returns 0/1/2. Arrays are copied at manifest boundaries. The compiled
[public example](../examples.mbt.md) demonstrates this workflow.

Each notebook retains existing format, numeric, Unicode and resource restrictions.
Aggregate batch output is limited to 8,000,000 UTF-16 units; exhaustion refuses the
whole result, never truncates values or drops pairs. Split the manifest when this
diagnostic occurs. Pairs are loaded serially; independent files are not an atomic
filesystem snapshot. Filesystem byte reading happens before decoded size checks,
so this is not a streaming-memory guarantee. The loader controls its own IO budget.

The main verifier runs real-data batch review on all four targets, compares full
single-pair evidence and cross-backend bytes, exercises gate verdicts and exits
0/1/2, and proves that later valid files still appear after missing/malformed ones.

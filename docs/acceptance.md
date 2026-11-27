# Reproducible acceptance pack

Run from the repository with the pinned MoonBit toolchain, Git and installed
dependencies. No Jupyter kernel, cloud account, service or private data is needed:

```sh
moon run --deny-warn scripts/verify-acceptance.mbtx _build/my-acceptance
```

The output directory must be new; missing parents are created. The default executes Wasm, Wasm-GC, JS and
native. Node is needed for JS and a C toolchain for native. Use `--portable` for
only the first three, or `--native` for native only. The completion marker lists
only targets actually executed; a partial run cannot claim all-platform success.
An interrupted run may leave incomplete evidence; choose a fresh directory on
retry. Existing directories/files are never overwritten.

The command checks all 17 [pinned public corpus cases](../fixtures/corpus/README.md)
against their reviewed accepted/refused JSON results, including stable codes,
pointers and hints. Every accepted case is serialized through the real CLI's
bundle, re-parsed and bundled again for byte-identical idempotence. A self-review
has zero changes and replays to the same complete report. A valid document after
the refused corpus verifies recovery. Exact original file hashes/bytes are checked
before and after; unsupported data is never trimmed to make a case pass.

The pack also makes two explicitly simulated source revisions of the real
nbformat 4.5 notebook, retaining its payloads. It executes check (exit 1), full JSON,
capture and offline replay, then verifies all three distant edits and missing final
LF in Markdown. Reports and Markdown must match across selected targets.

Artifacts include:

- `README.md`: actual per-target acceptance counts.
- `coverage.json`, `TARGET-N-validation.json`: actual validation results for every case.
- Accepted case canonical notebooks and replay bundles, preserving complete data.
- `TARGET-source-report.json`, `TARGET-source-bundle.json`, `TARGET-source-review.md`:
  the end-to-end review with three separated edits.
- `simulated-old.ipynb`, `simulated-new.ipynb`: reproducible demonstration inputs.
- `run.json`: written last, with `complete: true` and the executed target list.

CI regenerates the five explicitly prepared fixtures, runs this pack on all four
targets on Linux, Windows and macOS, and uploads `_build/acceptance` artifacts even
on failure. Unit/CLI/Git/consumer/release checks remain in `scripts/verify.mbtx`
and `scripts/verify-release.mbtx`. The pack is a reproducible bounded fixture
check, not a claim of universal Notebook, renderer or kernel compatibility.

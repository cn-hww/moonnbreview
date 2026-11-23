# Fixture provenance and reproducible demonstration

`upstream/test4.ipynb` is an unmodified Jupyter nbformat test notebook, downloaded
from:

https://github.com/jupyter/nbformat/blob/2b47b4bd5ed70799a2ea8fcf390fa680ee120910/tests/test4.ipynb

SHA-256: `5dc37eeddb491f410e21ad561c4811425bda0b04920f7e71e40c76bcc756f4be`.
Its BSD-3-Clause license is retained in `upstream/LICENSE` from the same revision.

`before.ipynb` is a derived fixture: only the minor version is set to 5 and stable
`fixture-cell-N` IDs are assigned in original order. This is an explicit sample
preparation step, not a hidden conversion supported by the library. All source,
outputs, metadata and attachment payloads are retained.

`after.ipynb` adds simulated editorial text to the first Markdown cell, adds a
simulated execution timestamp, changes the first code cell's execution counter to
99 and appends a labeled stdout output, then swaps the first two cells. These
edits are artificial review examples, not upstream changes or actual rerun results.

Recreate both derivatives with:

```text
moon run --deny-warn scripts/prepare-fixture.mbtx
```

The end-to-end verifier runs `check before after --ignore-execution-counts
--ignore-metadata execution` on every backend. Expected evidence:

- 3 active changes: retained-cell order, Markdown source, code output sequence.
- 2 suppressed changes: execution metadata and code execution count.
- Exit 1, followed by deterministic bundle replay; self-comparison exits 0.
- Malformed input exits 2; subsequent valid calls succeed; original files remain
  unchanged.

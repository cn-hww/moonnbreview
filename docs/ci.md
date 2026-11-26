# Retain complete CI review artifacts

From the MoonNBReview source checkout, run:

```text
moon run --deny-warn scripts/ci-review.mbtx . HEAD HEAD fixtures/manifest.json output/first-review --policy fixtures/policy.json --gate fixtures/gate.json
```

Create the parent `output` directory first, and choose a new final directory on
each run. The real-data example exits **1** with one blocked pair and one passed
control. Supply full base/proposed SHAs and an explicit manifest for your project:

```text
moon run --deny-warn scripts/ci-review.mbtx REPOSITORY BASE_SHA PROPOSED_SHA MANIFEST NEW_OUTPUT_DIR --policy POLICY --gate GATE
```

Policy/gate are optional. `--target wasm` is the default; `--target native` also
executes the installed native toolchain. This orchestration script itself runs
through Moon's Wasm script runtime. Git, Moon and dependencies must be available.
Replace the manifest argument with `--discover` to select all changed lowercase
`.ipynb` files between the pinned endpoint commits. See [automatic discovery](git-discovery.md).
Repo-relative notebook paths are read from pinned Git objects; the manifest and
configuration files are read from the caller's filesystem. Two symbolic refs are
resolved sequentially before notebook loading; full SHAs avoid caller ambiguity.
There is no fetch or notebook execution. Existing Git/batch/renderer limits apply.
Each Moon subprocess has a five-minute timeout and a 64MB capture cap, with no
claim of constant-memory processing. Git resolution has a 30-second timeout.

The new directory contains UTF-8 files without shell redirection:

| File | Meaning |
| --- | --- |
| `bundle.json` | Complete batch-bundle-1/2, including recorded input failures |
| `manifest.json` | Frozen explicit or discovered manifest-1/2 used for capture |
| `report.json` | Recomputed complete batch-1/2 evidence and gate outcome |
| `review.md` | All pair outcomes and bounded focused value previews |
| `junit.xml` | CI testcase projection retaining complete per-pair evidence |
| `provenance.json` | Resolved old/new commit IDs, manifest filename and backend |
| `run.json` | Completion marker, gate/overall exit codes and renderer outcomes |

Exit 0 means all pairs passed and both renderers succeeded; 1 means blocked
changes with complete artifacts; 2 means recorded input failures, renderer refusal
or operational failure. Renderer refusal preserves JSON/bundle and any successful
format, writes `FORMAT.error.txt`, and raises the overall outcome to 2. Diagnostic
text is never saved under a successful `.xml`/`.md` name. Metadata is descriptive,
not signed provenance or approval. The original manifest path in provenance is a
label; its pairs/configuration are retained in the bundle.

The final directory is created exclusively; an existing directory/file is refused
and never overwritten. Invalid options/refs/capture create no output directory.
An interrupted filesystem write or replay failure may leave a **new incomplete**
directory; require `run.json` with `complete: true` before consuming a run. This is
not a transactional or durable filesystem writer. No source notebooks are written.

[The manual GitHub workflow](../.github/workflows/notebook-review.yml) is runnable
through Actions → notebook-review → Run workflow. Its default `--discover` with
HEAD/HEAD produces an empty passing review; select meaningful base/proposed refs
or an explicit manifest. Blocked/error results still upload artifacts using
`if: always()`. Adapt the
manifest/configuration and revision selection to your project. For untrusted PRs,
run a trusted tool checkout with read-only permissions and pass revisions as data.
This workflow uploads full notebook evidence; use repository-appropriate retention.

`scripts/verify-git.mbtx` runs this pipeline on the real fixture, verifies exact
JSON/bundle/Markdown/JUnit equivalence, pinned IDs, refusal to overwrite, error
continuation, XML export refusal and unchanged Git HEAD/index/worktree. CI executes
that verification on Wasm/native across Linux, Windows and macOS. The manual
workflow itself is a separate opt-in entry, not an automatically scheduled review.

# Review a whole PR without maintaining a manifest

```text
moon run cmd/git-batch -- discover . BASE_SHA PROPOSED_SHA
moon run cmd/git-batch -- check . BASE_SHA PROPOSED_SHA --policy fixtures/policy.json
moon run cmd/git-batch -- bundle . BASE_SHA PROPOSED_SHA --policy fixtures/policy.json
```

`discover REPO OLD_REF NEW_REF` prints a deterministic **manifest-2**, without
loading Notebook contents or accepting policy/gate/format options. Omit the
manifest argument on Git batch review/check/bundle to discover and review directly.
Supplying a manifest retains the explicit workflow and v1 compatibility. Prefix
a manifest filename beginning with `--` with `./` to disambiguate it from options.

The library workflow is `Revisions::resolve(repo, old_ref, new_ref)`,
`revisions.discover()`, then `revisions.review_files(plan, policy~, gate~,
retain_inputs=true)`. Both refs are pinned before discovery; advancing branches
cannot change the selected snapshots. This compares **two endpoint trees**; it
does not infer a PR merge base. Callers select the base SHA appropriate to their
review. No checkout, index/worktree writes or fetch is requested. Existing Git
configuration/environment limitations in [Git snapshots](git.md) still apply.

Selection is case-sensitive: only changed paths ending exactly `.ipynb` are
included. Unchanged notebooks and other file types are outside this selection.
Added/deleted files use explicit null sides; modified/type-changed paths keep both
sides. Type changes to symlinks/submodules and malformed or unsupported notebooks
remain per-pair read/parse errors; later pairs still run. Missing data is never
substituted with an empty Notebook. File mode changes alone do not create Notebook
semantic witnesses; the selected pair can legitimately pass when content is equal.

Git rename inference is disabled explicitly. Moves are represented as **delete +
add**, including moves across the selected suffix (such as `.txt` to `.ipynb`).
This retains every selected side without asserting file identity. For a known
rename, use an explicit old/new manifest pair or existing `--new-path` on Git-single
review. A same-content explicit rename can pass while discovery's file events
block a structural gate. No similarity-based identity claim is made.

The implementation uses Git's
[`--name-status -z`](https://git-scm.com/docs/git-diff) framing, disables relative
path output, external diff and text conversion, and requests submodule changes.
Output is decoded strictly as UTF-8. NUL framing, duplicate paths, unsupported
statuses, unsupported selected paths and overflow refuse the whole discovery,
never return a partial plan. Git capture is capped at 2,000,000 bytes (including
unselected paths), with a 30-second process timeout. At most 64 notebooks can be
selected; use explicit smaller manifests if this bound is exceeded. Existing
4096-unit Git path and no-control/colon/backslash restrictions apply.

Selected paths are sorted using MoonBit's deterministic string order; IDs are
`file-1`, `file-2`, ... in that order. These are per-plan ordinals, not durable
cross-PR identities. They remain byte-identical for the same selected changes.
An empty selection is a valid empty manifest/batch and passes the gate. No claim
is made that it approves unrelated file changes or validates Notebook execution.

## Save all evidence in CI

```text
moon run --deny-warn scripts/ci-review.mbtx REPO BASE_SHA PROPOSED_SHA --discover NEW_OUTPUT_DIR --policy POLICY --gate GATE
```

The artifact runner pins refs, discovers once, snapshots `manifest.json` in a
temporary selection file and captures the batch from that exact plan. Both explicit
and automatic modes now save `manifest.json` beside the bundle/reports/provenance.
No source manifest is rewritten. Existing fresh-directory, completion-marker and
0/1/2 rules apply. Discovery failure produces no completed artifact directory;
Notebook parse failures produce a complete error-bearing batch and replay bundle.

The manual GitHub workflow defaults its manifest input to `--discover`. With
default HEAD/HEAD the selection is empty and passes. Select real base/proposed
refs for a review, or enter a manifest path to retain explicit selection. Artifacts
are still uploaded after blocked/error results. Live workflow dispatch is separate
from the automated cross-platform integration tests.

`scripts/verify-git.mbtx` constructs real Jupyter-derived commits that add, delete
and modify notebooks together, verifies automatic/explicit/replayed evidence and
all report formats, captures the exact plan/provenance, tests empty/error batches
and proves dirty HEAD/index/worktree data remain unaffected. Library tests add
rename/suffix transitions, nested cwd/config overrides, pinned ref movement,
type/UTF-8 failures, malformed framing, deterministic order and 64/65 limits.

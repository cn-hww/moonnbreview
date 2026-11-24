# Batch review between immutable Git revisions

Use a manifest to select files from two commits, including explicit renames,
without checking out either revision or staging any changes:

```text
moon run cmd/git-batch -- check . HEAD HEAD fixtures/manifest.json
```

This real-data repository example reads the old/new paths in the committed
manifest from the same HEAD commit. Its changed pair blocks (exit 1); the unchanged
control passes. To compare a PR, use `BASE_SHA PROPOSED_SHA` and a manifest naming
each side's repository-root-relative paths. Equal old/new paths are normal.
The manifest, policy and gate files themselves are read from the current
filesystem; notebook contents come exclusively from the selected Git objects.

`review|check|bundle REPO OLD_REF NEW_REF MANIFEST` accepts `--policy FILE`.
`check` and `bundle` also accept `--gate FILE`. Review/check accept
`--format json|junit|markdown`; Markdown also supports `--focus-changes`.
See [batch Markdown](batch-markdown.md). Bundles have the fixed batch-bundle-1 JSON format.
Check exits 0/1/2. Review/bundle exit 0 for valid blocked results, 2 for any pair
error. Bundle output can be replayed with the portable `cmd/batch replay FILE`,
including its retained policy/gate and recorded failures, without Git installed.
Replay uses the batch's 0/1/2 gate outcome.

Library users call `@git.Revisions::resolve(repo, old_ref, new_ref)`, then
`revisions.review(manifest, policy~, gate~, retain_inputs=true)` for a `BatchReview`.
`old_commit()` and `new_commit()` expose the full pinned commit IDs. Both symbolic
names are resolved before any notebook is read; subsequent branch movement does
not change the selected inputs. The two resolutions are sequential, not an atomic
multi-ref transaction; use full SHAs for caller-selected identities. Batch/report
formats retain paths and evidence but **do not include Git commit provenance**;
archive these two accessor values separately when required.

Reads are serial per pair, with no whole-batch preloading. Missing paths, symlinks,
invalid paths or invalid UTF-8 become `read_old`/`read_new` errors. Notebook format
errors retain `parse_old`/`parse_new`. Errors never become empty notebooks, and later
pairs still run. Invalid repository/revisions fail before batch processing. An
empty manifest still resolves both revisions but reads no blobs. Existing Git
timeouts, blob capture limits, path rules, process environment limitations and
Wasm/native scope in [Git snapshots](git.md) apply; existing batch limits also apply.
No discovery, rename inference, fetch, checkout or input writes are requested.

The reusable core also exposes `Manifest::review_sides_async(read_old, read_new,
policy~, gate~, retain_inputs~)` for serial asynchronous storage loaders. It keeps
the synchronous workflow's exact report/bundle bytes and phase behavior, including
not calling the new loader when old reading/parsing fails.
Async source runtime tests execute on Wasm, JS and native. Moon's current test
runner skips async tests on Wasm-GC; use the synchronous source API on that backend.

`scripts/verify-git.mbtx wasm|native` constructs an isolated repository using the
real Jupyter-derived fixtures, checks per-pair equivalence, JSON/JUnit offline
replay, 0/1/2, strict options and unchanged dirty index/worktree/HEAD. Unit tests
also advance refs after resolution, exercise explicit renames and malformed files.

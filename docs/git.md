# Review committed notebooks without checkout

The Git adapter reads the same repository-root-relative path at two commit-ish
references. It never checks out a branch or uses working-tree/index notebook data.
Use a complete checkout and Git on PATH. This optional adapter and `cmd/git-review` run
on **Wasm and native**; the core library and file CLI still support all four targets.

From this project's checkout, a runnable comparison with no private infrastructure:

```text
moon run cmd/git-review -- check . HEAD HEAD fixtures/before.ipynb --policy fixtures/policy.json
moon run cmd/git-review -- review . HEAD HEAD fixtures/before.ipynb --format markdown
```

Both succeed with zero changes. For an analysis repository with two revisions:

```text
moon run cmd/git-review -- check /path/to/analysis BASE_COMMIT HEAD notebooks/analysis.ipynb --policy fixtures/policy.json --format markdown
moon run cmd/git-review -- bundle /path/to/analysis BASE_COMMIT HEAD notebooks/analysis.ipynb --policy fixtures/policy.json
```

`review` and `bundle` exit 0 on valid results; `check` exits 0/1 for pass/active
changes. Bad options, unresolved refs, missing files and unsupported inputs exit 2.
Errors are escaped diagnostics on stdout. Policy paths are relative to the CLI's
working directory, not the reviewed repository. Use `--policy` for suppression;
this entry deliberately does not duplicate the file CLI's inline policy flags.
`bundle` refuses `--format`; save its complete JSON stdout as UTF-8 and replay
with `cmd/main`. Reports/bundles keep their existing schemas and full evidence;
they do not include Git provenance. Record full commit IDs separately when
archiving a review. References are resolved once **per snapshot**, not atomically
across two loads; use full commit IDs when concurrent branch updates matter.

## Reusable adapter

Import `"cn-hww/moonnbreview/git"` alongside `"cn-hww/moonnbreview" @review`:

```mbt nocheck
let old = @git.Snapshot::load(repo, base_commit, "notebooks/analysis.ipynb")
let new = @git.Snapshot::load(repo, proposed_commit, "notebooks/analysis.ipynb")
let result = @review.compare(old.document(), new.document(), policy~)
let resolved_base = old.commit()
let reviewed_path = old.path()
```

Call from an async function. The generated [adapter interface](../git/pkg.generated.mbti)
and black-box tests exercise the complete API. A snapshot exposes its resolved
commit hash, path and validated immutable document.

Paths use `/`, are literal (including spaces, Unicode, wildcard and shell
characters), and are limited to 4096 UTF-16 units. Empty/dot components, absolute
paths, backslashes, colons and ASCII controls are refused. Revisions have a 1024
unit limit and cannot contain ASCII controls. Only regular Git modes 100644/100755
are accepted: no symlink following, directories, submodules, implicit empty
notebooks for deleted files, rename detection or Git LFS pointer resolution.

The implementation uses argument-separated processes, `rev-parse --verify
--end-of-options`, exact NUL-framed `ls-tree` records and raw `cat-file blob` bytes.
It does not run textconv, smudge filters or notebook code. Each Git process has a
30-second timeout; captured blobs are capped at 6,000,000 bytes, then decoded with
strict UTF-8 and checked against all existing document limits. Resource exhaustion
raises without a partial comparison. `GIT_NO_LAZY_FETCH=1` requests no lazy fetch
on Git versions supporting that variable. This is a local tool, not a sandbox for
untrusted Git installations, configurations or inherited repository environment
variables. It does not clone, fetch or invoke remote operations itself.

Git command behavior follows the official [rev-parse](https://git-scm.com/docs/git-rev-parse),
[ls-tree](https://git-scm.com/docs/git-ls-tree) and
[cat-file](https://git-scm.com/docs/git-cat-file) documentation; no Git implementation
code is reused.

## Reproduce an actual change review

```text
moon run --deny-warn scripts/verify-git.mbtx wasm
moon run --deny-warn scripts/verify-git.mbtx native
```

The script creates an isolated temporary Git repository, commits the real Jupyter-
derived before/after fixtures at a Unicode path, then leaves staged and unstaged
invalid notebook data. It requires Git review to match file review exactly in JSON
and Markdown (3 active/2 suppressed), exercises bundle replay and exits 0/1/2,
and verifies unchanged HEAD, index bytes and notebook worktree. Its fixture commits
are temporary test data, not project history. The main verifier runs this workflow
on both supported Git adapter targets, and CI repeats it on all three OSes.

The executable package is named `cmd/git-review` so its Windows executable is
`git-review.exe`. Naming it `git.exe` would shadow the real Git during child
process lookup. See Microsoft's [CreateProcess search order](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw).
The native end-to-end workflow is required in CI to guard this integration.

## A renamed or relocated notebook

When the proposed commit moves a file, supply its new path explicitly:

```text
moon run cmd/git-review -- check /path/to/analysis BASE_COMMIT HEAD notebooks/old.ipynb --new-path lessons/new.ipynb --policy fixtures/policy.json
```

The positional path belongs to the old commit; `--new-path` belongs to the new
commit. Omitting it keeps the existing same-path behavior. The flag works with
review, check and bundle, and may occur once. Each path is checked by the same
literal-path and regular-file rules. Missing/unsafe paths refuse with exit 2;
there is no implicit rename detection or synthetic empty notebook.

File location does not change cell identity: a pure rename has no semantic
changes; a renamed notebook with edited source reports source changes against its
retained cell IDs. Bundles still contain complete inputs/policy, not Git path
provenance; record paths and resolved commits separately when auditing. Library
users load two `Snapshot`s with the explicit old/new paths and compare documents.
The Git verifier now tests the real fixture across a committed Unicode rename,
bundle replay, pure-rename exit 0, malformed/repeated flags and untouched dirty
renamed worktree/index/HEAD on Wasm and native.

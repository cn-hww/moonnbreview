# Initial slice validation

Validation date: 2026-11-23 (Asia/Taipei).

Toolchain: official stable `moonc v0.10.22+124d61d05`,
`moon/moonrun 0.1.20261119 (738607b)`.
Windows archive SHA-256 matched the official download checksum:
`8e552848a5c06dcce6bab725687562a689397948b7144e9087e9ffa4c1d38be4`.
Linux archive also matched:
`aeb78ded1d5e25185ed788328cacef5e843a9ab923145523b7652e8d082f74fb`.
Toolchains were installed in isolated development directories.

Executed locally:

| Environment | Checks actually run |
| --- | --- |
| Windows, wasm | 31 public API/doc tests, real fixture CLI, exits 0/1/2, bundle replay |
| Windows, wasm-gc | Same 31 tests and actual CLI workflow |
| Windows, js / Node | Same 31 tests and actual CLI workflow |
| Ubuntu 22.04 under WSL, native | Same 31 tests and actual compiled native CLI workflow |

Strict `moon check --target all --deny-warn`, `moon fmt` and `moon info` passed.
The source fixture was checked against its pinned downloaded original. Derived
fixtures are reproducible with `scripts/prepare-fixture.mbtx`. CLI checks preserve
input files and emit exactly three active and two suppressed changes for the
documented policy. Portable-backend report bytes match after normalizing only
console CRLF; report payload strings are not normalized by that check.

Windows native execution was attempted with MinGW and refused by MoonBit runtime
sources requiring MSVC. There is no local Windows native success claim. CI sets up
an MSVC developer environment and executes the full four-target verifier on each
of Windows, Linux and macOS. The workflow is
[verify](https://github.com/cn-hww/moonnbreview/actions/workflows/verify.yml);
remote results must be read for the exact pushed commit.

Initial verification caught and corrected the Node argv offset and report Option
serialization before publication. Early failed attempts are not counted as passes.
The project's own tests are not an exhaustive notebook-format conformance suite.

Deferred at the initial slice: execution, automatic merge, legacy matching,
browser UI, Git-ref comparison, report-import approval and package publication.

## Versioned policy files

The policy-file capability adds seven public-API test blocks (38 total), including
round trips, exact inline/file report equivalence, bundle compatibility, malformed
and unknown fields, escaped duplicates, Unicode, key limits and recovery. The
four-backend verifier also executes `--policy` against the real fixture, requires
identical JSON bytes, and rejects mixed inline/file choices and invalid files.

## Markdown presentation

Ten additional public-API test blocks (48 total) cover deterministic rendering,
unchanged JSON/bundle evidence, empty and suppressed sections, absent versus null,
literal Markdown/HTML, adaptive code fences, explicit preview counts, surrogate
boundaries, control escaping, invalid limits, and atomic oversize refusal. The
real-data CLI verifier compares Markdown bytes across backends, renders replayed
bundles, preserves check exit 1, and rejects unsupported formats and Markdown bundles.

## Repeated replacement regression

Windows CI for the Markdown commit passed all 48 library tests on all four targets
but exposed an end-to-end comparison bug: `String::replace` replaces only the first
match. Native MSVC writes CRLF throughout multiline console output. The verifier
now normalizes every console CRLF and asserts that JSON-escaped payload CR/LF stays
unchanged. This is confined to the test harness, not notebook values.

The same API mistake in JSON Pointer escaping is corrected for every `/` and `~`.
Two additional public tests (50 total) cover repeated runs, escape-looking field
names, replay and Markdown locations. This changes previously incorrect pointers
for keys with repeated characters; existing normal-key outputs are unchanged.

## Git snapshot workflow (2026-11-24)

Five async black-box integration test blocks add committed-snapshot comparison and
replay, resolved identities, literal Unicode/special-character paths, dirty worktree
and index preservation, nested repository callers, missing/invalid references,
symlink refusal without OS symlink privileges, malformed UTF-8, unsupported formats,
capture limits and recovery. Total: 55 blocks on Wasm/native, 50 core blocks on
Wasm-GC/JS. The optional Git packages explicitly support only Wasm/native.

The real-data [Git verifier](git.md) builds a temporary repository and compares
the committed before/after notebooks while their staged/unstaged copies are
invalid. It checks exact JSON/Markdown equivalence, bundle replay, all exit classes
and unchanged HEAD/index/worktree. Windows cleanup clears read-only Git object
attributes only inside those newly allocated temporary fixtures.

Local verification uses Windows for portable execution and Ubuntu 22.04/WSL for
actual native execution, with the same pinned toolchain above. Remote CI results
must still be checked against the final pushed hash.

## Focused Markdown and Windows executable naming (2026-11-24)

Eight additional core test blocks cover opt-in compatibility, evidence/replay
invariance, late edits, exact two-sided omissions, multiline/control coordinates,
append/delete/empty sides, both surrogate boundaries, separated edits, fencing,
nonstring fallback and suppressed-string verdicts. Totals are now 58 core blocks
on all four targets and 5 additional Git blocks on Wasm/native (63 total there).
The verifier exercises focus mode through both CLIs and replay, compares its
bytes across backends, rejects conflicting flags, and demonstrates a late edit
in a long-source variant of the real fixture. Original fixtures are unchanged.

The first Git push's [CI run](https://github.com/cn-hww/moonnbreview/actions/runs/45311134623)
passed Linux/macOS and all Windows library tests, but failed the Windows native
CLI integration. Its executable was `git.exe`, shadowing the real Git when the
adapter launched a child process. The package is renamed to `cmd/git-review`;
Git process diagnostics now include exit code, stderr and stdout. Local Windows
native execution still requires MSVC; the native CI workflow verifies this fix.

## Explicit CI gates (2026-11-24)

Six new public test blocks validate canonical category round trips, complete
evidence under selective gates, immutable array boundaries, all category names,
suppression independence, empty gates, malformed/unknown/duplicate fields and
categories, Unicode, 8192/8193-unit boundaries and recovery. Totals: 64 core blocks
on four targets, plus five Git blocks on Wasm/native. The CLI verifier checks
identical report bytes despite different gate verdicts, strict command/option
handling, invalid files and file/Git entry equivalence against real data.

## Offline HTML evidence (2026-11-24)

Seven new core test blocks verify full JSON recovery, deterministic output/replay,
hostile tags/entities/URLs, escaped dynamic locations and policy reasons, null versus
absence, long unknown output fields, Unicode/controls, 16M output-budget refusal and
recovery. Totals: 71 core blocks on all four targets, 76 including Git on Wasm/native.
The end-to-end verifier checks real-data HTML, UTF-8 file round trips, exact recovered
JSON, byte equality between targets/CLIs and replay, plus invalid format/focus flags.
HTML has no scripts or rendered notebook markup and includes complete evidence.
Browser visual preview was attempted but the browser URL security policy refused
the local `file://` document. No screenshot/layout-interaction pass is claimed;
the automated evidence, escaping and CLI checks are independent of that attempt.

## Explicit Git rename review (2026-11-24)

One new async Git integration block (77 total on Wasm/native; 71 core blocks
unchanged) verifies explicit old/new paths, Unicode/shell-character filenames,
retained cell identities, source edits, pure-rename equivalence, missing old paths
and bundle replay. The real-data Git verifier additionally checks new-path option
errors and dirty renamed worktree/index/HEAD preservation through the CLI.

## Bounded manifest review (2026-11-24)

Eight new core blocks cover strict manifest round trips/order, immutable arrays,
complete single-pair evidence, gate/suppression independence, failure precedence
and recovery, empty batches, malformed/unknown/duplicate fields, ID/path/64-pair
limits, Unicode and aggregate output refusal. Totals: 79 core blocks, 85 including
the six Git blocks on Wasm/native. CLI checks use the real two-pair fixture and
temporary missing/malformed files to verify continuation, all exit classes, exact
configuration/evidence and deterministic report bytes across all four targets.

## MIME evidence groups (2026-11-24)

Six additional core blocks (85 core, 91 with Git) cover exact key/family grouping,
nested JSON scope, repeated pointer escapes, extension/stream/replacement fallback,
deep-copy isolation, unchanged default HTML, hostile payloads, opaque keys, exact
full evidence and grouped replay. The verifier derives two rich-output versions
from the real fixture, checks text/JSON groups and complete recovered evidence,
compares grouped HTML bytes across targets and CLIs, and rejects conflicting flags.
No images, SVG or notebook HTML execute; browser visual QA remains unverified.

## Complete batch replay (2026-11-24)

Seven new core blocks cover retained/default report equivalence, deterministic
bundle round trips, offline replay after storage removal, persistent archived errors,
recomputed gates, cached-verdict rejection, embedded-policy matching, strict fields,
duplicate IDs, 64/65-entry and output-size limits, empty batches and recovery.
Totals: 92 core blocks, 98 with Git on Wasm/native. The real-data CLI verifier
captures and replays batches, checks exit 1/2, refuses configuration replacement
and replays archived errors after malformed source removal.

## JUnit CI projection (2026-11-24)

The optional adapter adds eight black-box tests and one compiled documentation
example. They parse exported XML through the reused JUnit codec, verify all case
outcomes/statistics, full per-case/configuration evidence, escaping, replay
determinism, unchanged JSON/bundle/verdict, selective gates, empty suites, illegal
XML-character refusal, output expansion limits and recovery. Totals: 92 root-core
blocks + 9 adapter blocks on all targets, plus 6 Git blocks on Wasm/native.
The real-data CLI verifier checks XML/parser counts, file versus offline replay,
error-bearing reports, exact cross-backend bytes and bad options. There is no
claim of live CI-service upload or universal JUnit consumer compatibility.

## Independent batch data sources (2026-11-24)

Six new black-box blocks cover equal paths in separate namespaces, exact backwards
report/bundle bytes, loader ordering and short circuiting, both read/parse sides,
error recovery, suppression/gates and empty retained replay. The compiled public
example uses two sources. Totals: 98 core + 9 JUnit blocks on portable targets,
plus the existing 6 Git blocks on Wasm/native.

## Pinned Git batch review (2026-11-24)

Two core async blocks verify actual yielding, strict serial IO/short circuiting,
all four read/parse error phases, byte equivalence, gates, retention and empty IO.
Five Git blocks verify full IDs, ref movement after pinning, literal/renamed paths,
missing/malformed inputs, later recovery, unchanged dirty repository state, gates
and offline replay. Totals: 100 core + 9 JUnit blocks on JS; 120 including 11 Git
blocks on Wasm/native. Wasm-GC runs 98 core + 9 JUnit blocks: Moon's runner skips
the two async tests on that backend, so no Wasm-GC async execution is claimed.
The Git end-to-end verifier now exercises batch CLI JSON,
JUnit, retained replay, strict options and 0/1/2 on real Jupyter-derived data.

## Human-readable batch evidence (2026-11-24)

Seven new black-box blocks cover every pair status, complete configuration and
diagnostics, default non-retained rendering, replay/determinism, unchanged JSON and
bundles, allowed active/suppressed witnesses, hostile markup/fences, visible controls,
surrogate-safe boundary/focused previews, invalid budgets, absent versus null,
empty batches and whole-report overflow refusal/recovery. Totals: 127 Wasm/native,
116 JS and 114 Wasm-GC (the latter excludes the two async tests).
The real-data verifier checks file/Git/replay Markdown, cross-backend bytes,
focused views, errors after source removal and strict flag handling. The existing
single-comparison Markdown format remains unchanged.

## CI artifact workflow (2026-11-24)

The Git end-to-end verifier also runs `ci-review.mbtx` against real fixture commits,
checking exact saved/replayed report, bundle, focused Markdown and JUnit bytes,
full pinned commit IDs, fresh-directory exclusivity, recorded read failures and
recovery. An XML-illegal manifest ID forces a renderer error: JSON/bundle/Markdown
remain usable, XML is absent, a named diagnostic is saved and overall exit becomes
2 while the original gate remains 1. Existing library test counts are unchanged.
This workflow does not publish packages or treat artifacts as signed approval.

## External consumption and native installation (2026-11-24)

`verify-consumer.mbtx` creates a separate temporary module and workspace outside
this checkout. Its public-only test executes comparison, exact complete evidence,
suppression, retained replay, same-path two-source batch, Markdown and JUnit on all
four targets. A Git consumer executes Snapshot/Revisions APIs on Wasm/native.
Native mode installs all four binaries using the current Moon installer, then
executes each help/version and real-data 0/1 checks from an unrelated working
directory. No global installation paths or user workspace files are changed.
All four source entries now provide help/version, with portable end-to-end checks
for correct exit/flag handling. Full verification includes the isolated consumer.

## Source-distribution preflight (2026-11-24)

`verify-release.mbtx` checks module/license/CLI-version agreement, creates the actual
Moon source ZIP, validates ZIP CRCs using Python's standard CLI and compares every
listed file and byte after extraction. It requires own/upstream licenses, public
interfaces, source, fixtures and adoption docs, and excludes development state.
The extracted module executes isolated downstream/installation checks and builds
API member Markdown, metadata and annotated source HTML. This does not publish to
Mooncakes, prove registry acceptance or
claim timestamp-reproducible ZIP bytes. Registry dry-run requires owner login and
was not completed. No registry credential changes or actual publication occurred.

## Explicit whole-file lifecycle (2026-11-26)

Four comparison blocks cover complete add/delete evidence, empty notebooks, policy
and structural gates, deterministic single replay/renderers, defensive copies,
legacy bytes and strict presence bundles. Eight file-manifest blocks (including
one async) cover nullable round trips, absent-side IO avoidance, phase errors,
recovery, complete batch replay, context/bundle presence agreement, schema/Unicode
refusal, 64-pair and aggregate limits. One JUnit block checks surviving paths and
one Git block executes real committed additions/deletions/modifications. Totals:
141 Wasm/native, 129 JS, 126 Wasm-GC (three async blocks skipped on Wasm-GC).
The real-data file CLI verifier runs JSON, Markdown, JUnit, offline replay and
0/1/2 on all four backends, retaining unchanged fixtures and existing v1 behavior.

## Automatic Git selection (2026-11-26)

Three private parser blocks check NUL framing, A/D/M/T handling, selection scope,
deterministic order, duplicate/unknown/unsafe-path refusal, 64/65 bounds and recovery.
Four actual-Git blocks cover a mixed add/delete/edit PR, Unicode/shell-character
paths, unchanged/unrelated files, nested cwd and diff config overrides, dirty-state
invariants, rename/suffix transitions, pinned refs, malformed new notebooks and
symlink/UTF-8 refusals with later valid evidence. Totals: 148 Wasm/native;
JS 129 and Wasm-GC 126 unchanged (Git is Wasm/native only).
The real-data Git verifier checks discovery-only output, implicit/explicit plans,
full report/bundle/Markdown/JUnit replay, frozen CI selection, empty passing batches,
archived failures and unchanged dirty repository state on both supported backends.

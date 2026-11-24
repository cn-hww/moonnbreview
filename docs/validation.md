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

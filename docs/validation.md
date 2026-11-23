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

Deferred capabilities: execution, automatic merge, legacy matching, browser UI,
Git-ref comparison, report-import approval and package-registry publication.

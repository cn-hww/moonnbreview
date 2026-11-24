# Contributing

MoonNBReview is a semantic notebook review layer over existing notebook models.
Keep additions tied to a repeated review/CI workflow; reuse existing codecs and
avoid introducing competing generic diff, notebook or JUnit/XML APIs.

Use MoonBit `0.10.22+124d61d05` and the current `moon.mod`/`moon.pkg` format. Node 22
is required for JS checks; native checks need a C compiler (MSVC on Windows).
Development automation lives in `.mbtx`. Do not edit generated `.mbti` files.

```text
moon update
moon fmt
moon info
moon check --target all --deny-warn
moon run --deny-warn scripts/verify.mbtx
moon run --deny-warn scripts/verify-release.mbtx
```

The last command additionally needs Python 3's standard `zipfile` CLI (`py -3` on
Windows, `python3` elsewhere). There are no Python implementation/scripts or pip
dependencies in this repository. Use `--portable` only when native execution is
unavailable, and disclose that limitation. `--native` is a separate runtime check.
The isolated consumer and archive preflight are documented in [installation](docs/install.md)
and [release verification](docs/release.md).

Each capability should include implementation, boundary/error/property tests,
an example or workflow document, and `moon info` output if the public API changes.
Preserve deterministic existing report bytes where semantics are unchanged. Keep
every accepted field or refuse the input with an actionable diagnostic; never drop
unknown fields. Distinguish absent JSON from null. Policies suppress evidence
explicitly; category gates do not remove evidence. Recorded external failures must
not replay as passes. Versioned schemas are contracts, not trusted verdict imports.

Record any reused code/data and licenses in THIRD_PARTY.md. The pinned BSD Jupyter
fixture must remain byte-identical; derived inputs must identify simulated edits.
Do not claim execution correctness, performance superiority or ecosystem uniqueness
without evidence. Do not include notebook contents in issue reports unless they
can be shared; minimal synthetic reproductions are normally sufficient.

Before a commit, inspect status, retain unrelated changes, stage explicit files and
review `git diff --cached --check` plus the staged diff. Use the contributor's
configured Git identity, meaningful capability commits and normal review. Verify
CI against the exact pushed SHA. For a release, align module/help version strings,
update CHANGELOG.md, and complete the separate publication steps in the release doc.

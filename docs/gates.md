# Choose which changes block CI

Noise policy and merge criteria answer different questions. `--policy` suppresses
explicitly approved noise, retaining its reason. `--gate` selects which **active**
categories block `check`; allowed changes remain active with their full evidence.
Without `--gate`, every active category still blocks. Review/bundle/replay do not
accept the flag: replay recomputes evidence, not an archived approval decision.

```json
{
  "format": "moonnbreview/gate-1",
  "blocked": ["structure", "source"]
}
```

This example blocks source edits and structural cell changes, while output,
metadata and order changes remain visible for review. All eight exact names:
`structure`, `order`, `source`, `output`, `attachment`, `metadata`,
`execution_count`, `extension`. An explicitly empty list blocks nothing.

```text
moon run cmd/main -- check fixtures/before.ipynb fixtures/after.ipynb --policy fixtures/policy.json --gate fixtures/gate.json
moon run cmd/git-review -- check . HEAD HEAD fixtures/before.ipynb --gate fixtures/gate.json
```

The first exits 1 because the real-data fixture has a source edit. The second
exits 0 for identical committed inputs. Gate paths, like policy paths, are relative
to the caller's working directory. The flag may occur once. Invalid gate files
exit 2, including when the notebooks are otherwise identical.

Library users can persist `Gate::new(blocked=[...]).to_json()`, reload with
`Gate::from_json`, then call `comparison.passes(blocked=gate.blocked())`.
Constructor inputs and exported category arrays are independent copies. Category
order is canonicalized, duplicates refused. Both JSON fields are mandatory;
unknown fields/versions/names, escaped duplicate keys, incorrect types, malformed
Unicode and more than eight categories refuse. Input is limited to 8192 UTF-16
units before parsing. The compiled example and black-box tests exercise this API.

Existing report-1 and bundle-1 schemas are unchanged and **do not store a gate or
approval verdict**. Archive the gate file and CI exit status alongside evidence
when auditing a run. Changing a gate never removes witnesses or rewrites inputs.
`scripts/verify.mbtx` verifies that passing/blocked selective gates produce exactly
the same JSON evidence as the default gate on the real fixture, on all four targets.

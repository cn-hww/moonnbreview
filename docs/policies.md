# Reviewed policy files for CI

Keep the same explicit policy in source control, code review and local runs:

```text
moon run cmd/main -- check fixtures/before.ipynb fixtures/after.ipynb --policy fixtures/policy.json
```

The bundled file enables execution-count suppression and ignores the immediate
`execution` metadata key. The example still exits 1 with three active changes and
two suppressed changes. Its report is byte-identical to the equivalent inline
options (apart from console line endings).

```json
{
  "format": "moonnbreview/policy-1",
  "ignore_execution_counts": true,
  "ignored_metadata_keys": ["execution"]
}
```

All three fields are required. Unknown fields, duplicate/escaped duplicate JSON
keys, unknown versions, wrong types, duplicate or empty metadata keys are rejected.
Keys are exact names, not globs or JSON Pointers: they match immediate notebook,
cell and recognized rich-output metadata keys. There are at most 64 distinct keys
of 1..128 UTF-16 units each. Existing JSON input Unicode/depth/size limits apply.

`Policy::from_json` validates the file; `to_json` emits a canonical, versioned
representation with sorted keys. Caller key order does not change the policy.
`Policy::new()` remains the strict default: suppress nothing.

CLI `--policy FILE` may occur once and cannot be combined with inline suppression
flags. This prevents silent precedence or accidental broadening of an approved
policy. Invalid or unreadable policy files exit 2 before a successful report.
`review`, `check` and `bundle` accept it; `replay` uses the policy already retained
inside its bundle; it accepts presentation options but refuses a replacement policy.

The existing `report-1` and `bundle-1` wire formats remain unchanged. A policy file
is a separate envelope; the exact suppression choices continue to be embedded in
bundles. Reloading a bundle recomputes evidence. A policy file does not grant
approval, configure which change categories block, or execute notebook code.

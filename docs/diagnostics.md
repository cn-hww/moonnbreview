# Notebook validation and repair

```sh
moon run cmd/main --target wasm -- validate fixtures/corpus/test4.5.ipynb
moon run cmd/main --target wasm -- validate fixtures/corpus/v4_5_no_cell_id.ipynb
```

Exit 0 means accepted, exit 2 means refused. A completed validation returns a
`moonnbreview/validation-1` JSON object with `valid` and `diagnostic` (null when
accepted). File I/O/UTF-8 and command usage errors retain the CLI's existing
escaped error output and exit 2, rather than masquerading as notebook validation.
No files are rewritten and no notebook is executed. The second command refuses
at `/cells/0/id` and explains the required stable ID. Older notebooks need an
explicit conversion/identity decision in their producer; no auto-migration exists.

Library integration: `Document::validate(text)` returns `Result[Document,
Diagnostic]`. `Document::parse` retains its exception-based signature and wraps
the same diagnostic in `ReviewError::Invalid`. Accepted canonical JSON, evidence,
policies, gates and bundles retain their prior behavior. Refused-input messages
now contain codes and hints; consumers should use `Diagnostic.code`, not parse
English text. Batch error phases are unchanged and messages carry the diagnostic.

| Code | Meaning / action |
| --- | --- |
| `NB_JSON_SYNTAX` | Repair malformed/truncated JSON or invalid escapes |
| `NB_JSON_DUPLICATE_KEY` | Resolve duplicates explicitly; no last-wins selection |
| `NB_SIZE`, `NB_DEPTH`, `NB_CELLS` | Reduce the documented input budget or repair the cell array |
| `NB_ROOT`, `NB_FIELD` | Supply the required notebook object/field/type |
| `NB_VERSION` | Explicitly prepare nbformat 4.5 with stable cell IDs |
| `NB_CELL_ID_DUPLICATE`, `NB_CELL_NAME_DUPLICATE` | Fix the second duplicate identity at the reported cell |
| `NB_NUMBER` | Encode exact unsupported numeric values as strings in the producer |
| `NB_UNICODE` | Repair unpaired UTF-16 surrogates |
| `NB_PRESERVATION`, `NB_NORMALIZATION` | Inspect the field; keep the original, never accept data loss |

Each `moonnbreview/diagnostic-1` contains `code`, JSON Pointer `path`, `message`,
`hint`, and nullable `line`/`column`. Empty pointer means the root. JSON parsing
reports one-based line/column when available; escaped invalid Unicode can be a
JSON syntax error before field decoding. Logical upstream field locations are
resolved against actual keys, with RFC 6901 escaping. If an upstream dotted path
is ambiguous (keys may themselves contain dots/brackets), the pointer is the root
and the original upstream location remains in `message`; no precise location is
invented. Only the first validation error is returned. Fix it and validate again.

Diagnostics are built from typed errors at validation sites. No text matching is
used to infer codes. Tests cover malformed input, duplicate escaped keys, numeric
and identity boundaries, escaped pointers, deterministic diagnostics, round trips
and recovery after refusal. [Corpus acceptance](acceptance.md) records actual
accepted/refused public notebooks rather than claiming general compatibility.

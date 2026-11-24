# Archive and replay a complete notebook batch

```text
moon run cmd/batch -- bundle fixtures/manifest.json --policy fixtures/policy.json --gate fixtures/gate.json
moon run cmd/batch -- replay saved-batch-bundle.json
```

Save the first command's JSON stdout as UTF-8. A valid bundle command exits 0 even
when changes block the embedded gate. Replay prints a freshly recomputed batch-1
report and exits **0/1/2** using the retained gate: all pass / blocked changes /
recorded failures. This batch replay gate behavior differs from the single-notebook
`cmd/main replay` command. Replay accepts no replacement policy or gate and performs
no filesystem reads of the recorded notebook paths.

In the library, request `manifest.review(loader, retain_inputs=true, policy~, gate~)`
then call `BatchReview::to_bundle()`. Calling `to_bundle` after an ordinary review
raises a diagnostic instead of pretending the inputs were retained. Defaults and
batch-1 report bytes are unchanged. `BatchReview::from_bundle` recomputes each
successful comparison through the existing strict single-notebook bundle codec,
checks its policy against the batch policy, and reapplies the embedded gate.

Batch-bundle-1 has exactly `format`, versioned `policy`, versioned `gate` and ordered
`entries`. Each entry has `id`, `old`, `new` and exactly one `comparison` or
`diagnostic`. Successful entries retain complete normalized old/new documents.
External IO and failed-input diagnostics are archived as `{phase,message}` and
**always remain errors** on replay, regardless of their message. Such errors are
recorded observations, not claims that offline replay re-ran the original IO or
parsed unavailable malformed files. Re-run a manifest to retry those inputs.
Bundle capture still exits 2 when any entry failed, while emitting its error-bearing
artifact so the rest of the batch evidence remains inspectable.

Both report and bundle have separate 8,000,000 UTF-16-unit output limits. Capturing
large unchanged documents can exceed the bundle limit even when the report is
small; this refuses the complete capture with a diagnostic, never drops input data.
Split the manifest or run an ordinary non-capturing review. Existing document limits
and 0..64 unique pair IDs remain enforced. Bundle parsing rejects unknown/duplicate
fields, malformed Unicode, excessive nesting, policy mismatch and injected cached
statuses or reports. Deterministic round trips retain entry order and diagnostics.

Bundles contain full potentially sensitive inputs; they provide reproducibility,
not signatures or proof of origin. No API imports a trusted pass verdict. Callers
must verify the supplied inputs/configuration when deciding whether to approve.
The main verifier captures the real two-file workflow on all four targets, replays
it byte-for-byte, and preserves error precedence after malformed source files have
been removed. No private infrastructure is needed.

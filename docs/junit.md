# Publish Notebook review outcomes as CI test results

```text
moon run cmd/batch -- check fixtures/manifest.json --policy fixtures/policy.json --format junit
moon run cmd/batch -- replay saved-batch-bundle.json --format junit
```

Save XML stdout as UTF-8 `notebook-review.xml`. The real fixture produces two
testcases: one gate failure and one pass, with process exit 1. Input/archived errors
produce `<error>` cases and process exit 2. `review` can also render JUnit; it still
exits 0 for valid evidence with blocked changes, and 2 for input errors. Replay
recomputes retained gate evaluation and preserves its 0/1/2 exit code.

`--format` accepts `json` (the unchanged default) or `junit`, once. Bundles have a
fixed JSON format and reject it. Replay permits its format option but no replacement
policy/gate. Malformed manifests/bundles/options or export-limit/character failures
emit a diagnostic instead of partial XML. Per-file error batches still emit a
complete XML report before exiting 2. Keep the command's exit status in CI.

The optional library adapter is `"cn-hww/moonnbreview/junit"`: call
`@junit.render(batch)` on a genuine immutable `BatchReview`. It exposes no generic
JUnit reader, writer, editor or merge model. The implementation reuses
[junit_delta 0.4.0](https://mooncakes.io/docs/tc-adventureking/junit_delta%400.4.0)
for JUnit construction, statistics and XML validation, and its Apache-2.0 XML
dependency. See the [compiled example](../junit/examples.mbt.md).

Each manifest ID becomes one unique testcase name under class `moonnbreview`;
the proposed path is its `file` attribute. `passed` has no result element,
`blocked` becomes `failure` with type `NotebookGateBlocked`, and `error` becomes
`error` with type `NotebookReviewError` and its recorded phase. Allowed active
changes remain visible in full `system-out` JSON evidence, not silently suppressed.
Every case retains its complete batch entry; suite properties retain exact policy
and gate configuration. Statistics are recomputed from these cases. No invented
execution times, timestamps, skipped cases or execution-correctness claims are added.

All values use the reused codec's XML 1.0 escaping/validation. Unrepresentable XML
characters or output above **10,000,000 UTF-16 units** refuse export; the complete
JSON/bundle and original verdict remain usable. Escaping and repeated failure
evidence may hit this limit before the 8M JSON limit. Nothing is clipped to fit.
The adapter does not read XML into a trusted pass verdict.

JUnit consumers differ. The projection follows the testcase/failure/error/
system-out subset described in [GitLab's official documentation](https://docs.gitlab.com/ci/testing/unit_test_reports/).
For example, a GitLab job can retain the generated file with this job-level fragment:

```yaml
artifacts:
  when: always
  reports:
    junit: notebook-review.xml
```

Use a file-writing mechanism appropriate for your runner that preserves stdout
and the command's nonzero exit code. GitLab's report UI itself does not make a job
fail; the command status does. No live GitLab upload or universal CI compatibility
is claimed. The project CI validates serialization, parser round trips, real-data
counts and deterministic bytes across all four MoonBit targets instead.

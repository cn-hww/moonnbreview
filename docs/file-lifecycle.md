# Review added and deleted Notebook files

```text
moon run cmd/batch -- check fixtures/file-manifest.json --policy fixtures/policy.json
moon run cmd/batch -- bundle fixtures/file-manifest.json --policy fixtures/policy.json
moon run cmd/batch -- replay saved-file-bundle.json --format markdown
```

The real Jupyter-derived inputs represent an added lesson, removed lesson and an
edited lesson. Check exits 1; bundle exits 0 and retains all normalized content.
The manifest intentionally declares presence rather than deriving it from file IO.
Use `cmd/git-batch review|check|bundle REPO OLD_REF NEW_REF MANIFEST` for committed
files, with the same manifest formats and explicit old/new root-relative paths.

Manifest-2 has exactly `format` and `pairs`; every pair has exactly `id`, `old`,
`new`. A path is a nonempty string or **explicit JSON null**. Null means deliberate
absence. Both null is invalid; missing keys are invalid. A present path that fails
to read/parse remains an error, never an empty document or inferred deletion.
Limits remain 64 unique IDs, 128-unit IDs and 4096-unit paths. No absent-side loader
is invoked. An empty Notebook is still a present file and gets a full file event.

`compare_files(Document?, Document?, policy~)` returns the existing Comparison API.
Two present inputs preserve `compare` behavior and report-1/bundle-1 bytes. One
absent side produces one unsuppressed **Structure** witness at notebook root
(`cell_id: null`, empty pointer) carrying the complete present normalized document.
It blocks a structural gate even when the Notebook has no cells. Count/metadata
noise policy never removes data inside a whole-file event. An explicitly selected
gate can allow Structure while retaining this evidence.

Whole-file reports use `file-report-1` with explicit `old_present`/`new_present` and
otherwise the existing policy/change arrays. `file-bundle-1` has exactly format,
old, new, policy; exactly one document is null. Replay revalidates and recomputes.
Single Markdown/HTML rendering works on these comparisons, with absence distinct
from JSON null inside a present Notebook. No new ChangeKind is introduced.

`FilePair` and `FileManifest::new` expose nullable paths. Use `review`, `review_sides`
or serial `review_sides_async`; errors retain their phase and later pairs run.
New FileManifest batches use **batch-2 / batch-bundle-2**. Their shape is the v1
batch shape with nullable old/new paths and supported file comparison bundles.
Successful archived comparisons must agree with their pair's presence and policy;
cached verdicts are not trusted. All existing size caps and failure precedence
apply. Batch Markdown keeps every pair; JUnit uses the proposed path, or the old
path for deletions. JSON/bundles retain complete file evidence; Markdown previews
are explicitly bounded.

Existing `ReviewPair`, `Manifest`, `Revisions.review` and v1 schemas stay available.
`FileManifest::from_json` accepts strict manifest-1 and preserves its v1 bytes and
outcomes; `from_manifest` provides the same compatibility adapter. Its `to_json`
preserves v1 when imported that way. `Revisions.review_files` accepts FileManifest.
The batch CLIs accept either version and replay either batch bundle version.
The CI artifact runner retains both versions. Existing v1 bundles cannot encode
missing documents by changing a path to null. File presence is caller-declared in
explicit manifests, not a signed proof of historical existence.

`scripts/verify-files.mbtx TARGET` executes this real-data workflow on all four
backends, checking full replay, JSON/Markdown/JUnit, structural gates, strict
absence validation, read failures/recovery and unchanged input bytes. The existing
compiled public API example also demonstrates library usage. No external code or
fixtures were added; the new manifest references the existing licensed fixtures.

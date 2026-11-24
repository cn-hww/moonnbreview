# Changelog

## 0.1.0 — initial usable source milestone (2026-11-24)

- Strict, preservation-checked nbformat 4.5 input with unique cell IDs, explicit
  numeric/Unicode/resource rules and no input rewrites or silent field loss.
- Cell-ID semantic comparisons for structure/order/source/output/attachments,
  metadata, execution counts and opaque extensions.
- Versioned explicit noise policies and category gates; suppressed witnesses stay
  available with reasons, independently of the gate outcome.
- Complete single/batch replay bundles, deterministic recomputation, manifest-based
  file/storage review and serial asynchronous loaders with per-pair error recovery.
- Optional Git snapshots and pinned multi-file revision review, explicit rename
  paths, no checkout/index writes and portable offline replay.
- JSON evidence, bounded/focused Markdown, script-free complete single HTML, MIME
  evidence grouping and optional JUnit projection through the existing JUnit codec.
- Four self-documented native-installable commands, CI artifact capture that keeps
  failed review evidence, a manual GitHub workflow and explicit 0/1/2 outcomes.
- Runtime tests on relevant Moon backends and three OSes, isolated downstream
  consumers/install tests, archive content verification and generated API docs.

This version is distributed from Git source. It has not been published to
Mooncakes and no tagged/binary GitHub release is implied by this record.
Git adapters run on Wasm/native; async source tests run on Wasm/JS/native, with
Wasm-GC async tests skipped by the current runner. Browser visual layout, live
JUnit service upload and package-registry publication are not claimed as verified.
Notebook execution, automatic merging, legacy ID inference, pixel diffs and trust
signatures are outside this milestone. See [release scope](docs/release.md).

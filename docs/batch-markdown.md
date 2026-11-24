# Read a complete batch in Markdown

```text
moon run cmd/batch -- check fixtures/manifest.json --policy fixtures/policy.json --format markdown
moon run cmd/git-batch -- check . HEAD HEAD fixtures/manifest.json --policy fixtures/policy.json --format markdown --focus-changes
moon run cmd/batch -- replay saved-batch-bundle.json --format markdown --focus-changes
```

The first two examples use the repository's real Jupyter-derived fixtures, with
one blocked revision and one unchanged control, and exit 1. For a PR, substitute
full baseline/proposed SHAs in the Git command. Save Markdown stdout as UTF-8 for
human review; archive JSON or a retained batch bundle for complete payload evidence.
The replay command requires a bundle previously produced by `cmd/batch bundle` or
`cmd/git-batch bundle`. No private service or notebook execution is required.

`BatchReview::to_markdown(preview_chars=240, focus_changes=false)` works on every
batch, including one created without retained inputs. It includes the 0/1/2
outcome, exact summary, complete policy/gate configuration and every pair in
manifest order. IDs, literal old/new paths and statuses are fenced JSON, so hostile
names cannot inject headings or links. Every successful comparison includes all
active and suppressed witnesses with full category/cell/pointer/suppression reason.
A passed gate may still have active changes; those changes remain visible. Every
failed pair has its complete diagnostic phase/message and later pairs still appear.

Only before/after **values** have bounded previews. As in [single Markdown reviews](markdown.md),
the 32..4096 UTF-16 unit budget is per value representation, surrogate pairs are
not split, and omitted counts are explicit. Missing values remain `Absent.`,
distinct from JSON `null`. Adaptive tilde fences keep notebook markup literal,
and control characters are made visible. Optional first-difference focus retains
offset/line/column coordinates and discloses that later edits may be omitted.
Whole-batch Markdown has a 1,000,000-unit cap; overflow raises without dropping a
pair, location or diagnostic. Split the manifest or use complete JSON evidence.
JSON, bundle bytes and gate outcomes are unchanged by rendering.

File batch review/check/replay and Git batch review/check accept `--format markdown`.
`--focus-changes` may occur once, requires Markdown and may appear before/after
`--format`. Bundles remain fixed JSON; policy/gate cannot be replaced during replay.
Review/check/replay retain their existing documented exit semantics, including
exit 2 for batches with recorded errors. Default JSON and existing JUnit output
remain available; no external Markdown renderer is incorporated.

The verifier checks real-data file/Git/offline replay equivalence, all pair outcomes,
suppressed evidence, cross-target bytes, focused previews and invalid flags.

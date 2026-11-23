# Scope review, 2026-11-23

Independent value: turn Jupyter notebook changes into complete, cell-addressed
semantic review evidence with explicit noise policies and CI checks.

Reviewed sources: Mooncakes live `moon search` / `moon view`, GitHub repositories
and generated interfaces, official MoonBit docs, and the official
[ecosystem list](https://github.com/moonbitlang/awesome-moonbit).

Search terms: notebook, ipynb, notebook diff, nbdime, semantic diff, Myers Patience;
sql lineage, column lineage, SQLGlot; ssrf, DNS rebinding, private address, safe fetch.
Search ranking and unpublished repositories limit discovery. No uniqueness claim.

| Existing MoonBit project | Checked boundary | Decision |
| --- | --- | --- |
| [moonrockz/notebooks 0.11.0](https://mooncakes.io/docs/moonrockz/notebooks) | Parsing, immutable models, traversal, metadata and format conversion | Reuse; no competing codec |
| [core/diff](https://github.com/moonbitlang/core/tree/main/diff) | Generic sequence edits and hunks | No generic diff API added |
| [moon-diff 0.2.3](https://github.com/yuzhiblue/moon-diff) | Text/JSON diff, patch and merge | Domain review is complementary; no generic patch engine |
| [markitdown](https://github.com/ZSeanYves/markitdown) | Notebook content extraction to Markdown | Does not define this comparison/policy workflow |
| [bobzhang/sqlglot](https://github.com/bobzhang/sqlglot.mbt/blob/main/src/lineage/pkg.generated.mbti) | lineage, lineage_all, Node traversal/HTML | Reject proposed SQL-lineage alternative due to overlap |
| [gaato/mttp](https://github.com/gaato/mttp/blob/main/SECURITY_CLASSES.md) | HTTP client; address policy/SSRF defense listed as planned gap | Defer safe-fetch alternative; integration and future-overlap risks |

Demand evidence queried on the review date via PyPI Stats `recent` API:

- [nbdime](https://pypistats.org/api/packages/nbdime/recent): last_month 223,670.
- [sqllineage](https://pypistats.org/api/packages/sqllineage/recent): 935,650.
- [safehttpx](https://pypistats.org/api/packages/safehttpx/recent): 4,929,958.

These are download events, including automated and transitive installs, not user
counts or evidence of MoonBit adoption. nbdime demonstrates an established
notebook-specific review problem; this project makes no originality or performance
claim and does not attempt full nbdime compatibility.

# Sources and licenses

The project's implementation, tests and `.mbtx` automation are authored for this
repository under MIT. No upstream implementation or tests were copied.

Runtime dependencies:

| Dependency | License | Use |
| --- | --- | --- |
| [moonrockz/notebooks 0.11.0](https://github.com/moonrockz/moon-lander/tree/main/pkgs/notebooks) | Apache-2.0 | Notebook model, codec and immutable accessors |
| [moonbitlang/core](https://github.com/moonbitlang/core) | Apache-2.0 | Standard library, JSON, UTF-8, environment |
| [moonbitlang/x 0.5.5](https://github.com/moonbitlang/x) | Apache-2.0 | CLI filesystem adapter |

The notebook module transitively uses moonrockz/ion 0.6.0, moonrockz/expect 0.6.1,
moonbit-community/toml 0.5.0 (Apache-2.0), bobzhang/lexer 0.3.0 (Apache-2.0),
and moonbit-community/yaml 0.0.8 (MIT). The CLI
and development scripts resolve additional transitive packages through the module
graph; `moon tree` shows the exact graph. Their license files remain in dependency
archives. `moonbitlang/async 0.22.4` (Apache-2.0) is used by development automation
and the optional Git snapshot library/CLI. Git is an external process prerequisite,
not bundled source; command behavior references are linked in [Git workflow](docs/git.md).
Dependencies are fetched by Moon and are not vendored into this repository.

External fixture: Jupyter nbformat's `tests/test4.ipynb`, BSD-3-Clause, pinned to
`2b47b4bd5ed70799a2ea8fcf390fa680ee120910`. Full license and modification notes:
[fixtures/README.md](fixtures/README.md). Synthetic unit-test inputs are authored
here, not extracted from another test suite.

Design references: [nbdime](https://github.com/jupyter/nbdime) (BSD-3-Clause),
[Jupyter format specification](https://nbformat.readthedocs.io/en/latest/format_description.html),
and [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901) JSON Pointer escaping.
These inform behavior and naming; no implementation or fixture was taken from
nbdime. GitHub Actions used by CI retain their own upstream licenses.

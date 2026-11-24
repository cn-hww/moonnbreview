# Use MoonNBReview outside this repository

MoonNBReview 0.1.0 is a **source-only** initial version, not a published Mooncakes
package. These instructions use the pinned MoonBit `0.10.22+124d61d05` toolchain.
Node.js 22 is needed for JS execution; native installation requires a C compiler
(MSVC developer environment on Windows). Git-backed commands require Git on PATH.

## Install the four native commands

From a cloned source checkout, use a dedicated installation directory:

```text
moon update
moon install ./cmd/... --bin ./output/bin
```

The current Moon installer uses package directory names:

| Source package | Installed command | Version banner |
| --- | --- | --- |
| `cmd/main` | `main` | `moonnbreview 0.1.0` |
| `cmd/batch` | `batch` | `moonnbreview-batch 0.1.0` |
| `cmd/git-review` | `git-review` | `moonnbreview-git 0.1.0` |
| `cmd/git-batch` | `git-batch` | `moonnbreview-git-batch 0.1.0` |

Run `./output/bin/main --help` on Linux/macOS or
`./output/bin/main.exe --help` on Windows. Use the full executable path from other
working directories and supply absolute input/configuration paths, or paths
relative to that working directory. No source checkout is needed by the installed
executable at runtime. The `.mbtx` orchestration/development scripts still require
the source checkout and Moon toolchain; they are not installed by this command.

Every entry accepts standalone `--help` (or `-h`) and `--version`, exits 0 and does
not read notebooks or resolve Git revisions. Extra arguments are refused rather
than ignored. [CLI reference](cli.md) describes command/gate/exit differences.
Installation behavior was checked with the local toolchain's `moon install --help`
and actual temporary-directory installation, not assumed from another language.

## Develop a downstream library consumer

Use a workspace until the package is published. For sibling directories
`moonnbreview/` and `your-app/`, run from their parent:

```text
moon work init moonnbreview your-app
```

This toolchain writes a `moon.work` with `members = [...]`. In `your-app/moon.mod`,
declare `import { "cn-hww/moonnbreview@0.1.0" }`. In its `moon.pkg`, import
`"cn-hww/moonnbreview" @review` and the optional `/junit` or `/git` packages needed
by the application. Test-only imports belong in an `import { ... } for "test"`
block. Use the [compiled API workflow](../examples.mbt.md) for comparison, batch
construction and replay. Source workspace membership resolves the local module;
this is not evidence that a registry release exists.

The official [workspace guide](https://docs.moonbitlang.com/en/latest/toolchain/moon/workspace.html)
describes membership and module-version alignment. The executable verifier below
tests the exact current syntax and public interfaces:

```text
moon run --deny-warn scripts/verify-consumer.mbtx --portable
moon run --deny-warn scripts/verify-consumer.mbtx --native
```

It creates an independent temporary module/workspace outside the checkout, imports
only public packages, and executes real Jupyter-derived comparisons, full replay,
batch gates, Markdown and JUnit. Git API consumers run on Wasm/native. Native mode
also installs all four commands into a fresh temporary directory and runs help,
version, passing checks and blocked real-data checks from outside the repository.
Full `scripts/verify.mbtx` includes this verification; CI repeats it on all three OSes.

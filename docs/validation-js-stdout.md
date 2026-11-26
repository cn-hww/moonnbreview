# Large JavaScript CLI output (2026-11-26)

CI for commit 05bfede passed on Windows but failed on Linux/macOS while parsing
the real-data whole-file JUnit stdout from the JS CLI. All library tests passed;
the subprocess output ended inside a failure element. Node's forced process exit
can terminate asynchronous pipe writes before completion, as described in the
[official process documentation](https://nodejs.org/api/process.html#processexitcode).

Both JS file CLI entries now set `process.exitCode` and return normally instead of
forcing termination. Batch replay explicitly returns after rendering, so delayed
exit cannot fall through into manifest processing. Wasm/Wasm-GC/native retain their
existing exit implementation. No report format, evidence or gate semantics change.

`verify-files.mbtx js` executes actual subprocesses with full real-data JUnit
reports, plus 160K-character derived source values. It verifies exact complete
single-file JSON at exit 1, full mixed success/error JSON and retained bundles at
exit 2, byte-identical offline replay and complete XML parsed by the reused codec.
These are regression checks for process output integrity, not performance tests.
The existing cross-OS CI executes them on Linux, Windows and macOS.

## Benchmarking:
- `luau tests/miniMax.test.luau --codegen` (codegen nearly doubles performance by applying native luau)
- `luau tests/perft.test.luau --codegen`
For any of the above commands you can add `--profile && python3 tools/perfgraph.py profile.out > profile.svg` to save flamegraph as SVG.
## UCI
Run `rokit add luau-lang/lute@0.1.0-nightly.20260228` to get Lute.
> **NOTE:** With my experience, Lute does not have Native Luau, performance will be worse.

- `lute tools/uci.luau`

You could not use `go depth 5` and get a eval, bestmove, and move sequence.
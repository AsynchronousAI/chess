# TODO:
- Eval function cannot distinguish between a checkmate and a stalemate.
- UI is nasty
- Cannot escape focus on a game
- Thread pool
- Incremental evaluation

# Notes:
- Run a benchmark with `luau src/shared/test.server.luau --codegen -O2 --profile && python3 tools/perfgraph.py profile.out > profile.svg`

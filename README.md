# TODO:
- Eval function cannot distinguish between a checkmate and a stalemate.
- UI is nasty
- Cannot escape focus on a game
- Thread pool
- Incremental evaluation
- Rewrite minimax algorithm

## Benchmarking:
- `luau src/shared/miniMax.test.luau --codegen -O2 --profile && python3 tools/perfgraph.py profile.out > profile.svg`
- `luau src/shared/legalMoveGen.test.luau --codegen -O2 --profile && python3 tools/perfgraph.py profile.out > profile.svg`

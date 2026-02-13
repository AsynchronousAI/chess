# TODO:
- No string keys at all for board object
- Eval function cannot distinguish between a checkmate and a stalemate.
- UI is nasty
- Queenside castling will not work if kingside does cannot
- Cannot escape focus on a game
- Thread pool
- Incremental evaluation
- Increase depth when capturing

# Notes:
- Run a benchmark with `luau src/shared/test.server.luau --profile && python3 tools/perfgraph.py profile.out > profile.svg`

local bitboard = require("../src/shared/engine/bitboard").BitBoard

local fen = ({...})[1]

local board = bitboard.create()
bitboard.from_fen(board, fen)
local moves = bitboard.generate_legal_moves(board)

print(#moves)

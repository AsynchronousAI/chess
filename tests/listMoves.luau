local bitboard = require("../src/shared/engine/bitboard").BitBoard
local Move = require("../src/shared/engine/move").Move

local fen = ({ ... })[1]

local board = bitboard.create()
bitboard.from_fen(board, fen)

local moves = bitboard.generate_legal_moves(board)

for _, move in moves do
	print(Move.toSimpleString(move))
end

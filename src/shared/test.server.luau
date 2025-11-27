local bitboard = require("./engine/bitboard").BitBoard

local board = bitboard.create()
bitboard.set_start_position(board)

print(bitboard.hash(board))

local legal_moves = bitboard.generate_legal_moves(board)
local n = math.random(1,#legal_moves)
bitboard.make_move(board, legal_moves[n])
print(bitboard.hash(board))

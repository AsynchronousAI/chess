local bitboard = require("./engine/bitboard").BitBoard

-- Init
local board = bitboard.create()
bitboard.set_start_position(board)
print("Original hash: ", bitboard.hash(board)) -- hash

-- Legal moves
local legal_moves = bitboard.generate_legal_moves(board)
bitboard.make_move(board, legal_moves[math.random(1,#legal_moves)])

-- Zobrist hashing
local hash = bitboard.hash(board)
print("Move hash: ", hash)

-- FEN
local new1 = bitboard.create()
local fen = bitboard.to_fen(board)
bitboard.from_fen(new1, fen)
print(fen)
assert(bitboard.hash(new1) == hash)

-- Buffers
local new2 = bitboard.create()
bitboard.from_buffer(new2, bitboard.to_buffer(board))
for i, v in new2 do
    print(i, v, board[i])
end
assert(bitboard.hash(new2) == hash)

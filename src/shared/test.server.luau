local bitboard = require("./engine/bitboard").BitBoard

local function chess()
    -- Init
    local board = bitboard.create()
    bitboard.set_start_position(board)
    print("Original hash: ", bitboard.hash(board)) -- hash

    -- Legal moves
    for i = 1, 30 do
        local legal_moves = bitboard.generate_legal_moves(board)
        if #legal_moves == 0 then break end
        bitboard.make_move(board, legal_moves[math.random(1,#legal_moves)])
    end

    -- Zobrist hashing
    local hash = bitboard.hash(board)
    print("Move hash: ", hash)

    -- FEN
    local new1 = bitboard.create()
    local fen = bitboard.to_fen(board)
    bitboard.from_fen(new1, fen)
    print("Move FEN: ", fen)
    assert(bitboard.hash(new1) == hash, "FEN conversion failed")

    -- Buffers
    local new2 = bitboard.create()
    bitboard.from_buffer(new2, bitboard.to_buffer(board))
    assert(bitboard.hash(new2) == hash, "Buffer conversion failed")
end

for i = 1, 50 do
    chess()
end

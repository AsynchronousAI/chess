local bitboard = require("./engine/bitboard").BitBoard
local Move = require("./engine/move").Move

local FEN = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
local DEPTH = 4

local function perft(board, depth)
    if depth == 0 then
        return 1
    end

    local legal_moves = bitboard.generate_legal_moves(board)
    if depth == 1 then
        return #legal_moves
    end

    local nodes = 0
    for _, move in legal_moves do
        local record = bitboard.make_move(board, move)
        nodes += perft(board, depth - 1)
        bitboard.undo_move(board, move, record)
    end

    return nodes
end


local function perft_divide(board, depth)
    local legal_moves = bitboard.generate_legal_moves(board)
    for _, move in legal_moves do
        local record = bitboard.make_move(board, move)
        local nodes = perft(board, depth - 1)
        bitboard.undo_move(board, move, record)
        print(Move.toString(move), nodes)
    end
end

local function run_perft(depth)
    local board = bitboard.create()
    bitboard.from_fen(board, FEN)

    local startTime = os.clock()
    local nodes
    if depth == DEPTH then
        perft_divide(board, depth)
    else
        nodes = perft(board, depth)
    end
    local elapsed = os.clock() - startTime

    print("Perft depth:", depth, "nodes:", nodes, "time:", elapsed)

end

for depth = 1, DEPTH do
    run_perft(depth)
end

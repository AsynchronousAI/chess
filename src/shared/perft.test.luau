local bitboard = require("./engine/bitboard").BitBoard

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

local function run_perft(depth)
    local board = bitboard.create()

    local startTime = os.clock()
    local nodes = perft(board, depth)
    local elapsed = os.clock() - startTime

    print(string.format("Perft depth: %d, nodes: %d, time: %.4fs. %.2f nodes/sec", depth, nodes, elapsed, nodes / elapsed))
end

for depth = 1, DEPTH do
    run_perft(depth)
end

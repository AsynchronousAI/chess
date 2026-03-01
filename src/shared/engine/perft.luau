local bitboard = require("./bitboard").BitBoard

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

return perft

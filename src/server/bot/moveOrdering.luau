local libs = require(script.Parent.import)
local hasPiece = libs.BitBoard.hasPiece
local getPiece = libs.BitBoard.getPiece
local PieceValues = libs.Board.PieceValues

local TT = game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")


return function(board, moves)
    local color = libs.BitBoard.getTurn(board)
    local new = table.clone(moves)

    -- Get hash for the current board
    local hash = libs.BitBoard.hash(board)
    local ttEntry = TT[hash] -- lookup TT entry

    for index, move in ipairs(moves) do
        local isCapture = hasPiece(board, move[2])

        if isCapture then
            local attacker = getPiece(board, move[1])[1]
            local victim = getPiece(board, move[2])[1]
            move[5] = (PieceValues[victim]*10)-PieceValues[attacker]
        else
            move[5] = 1
        end

        -- Check if this move matches the TT best move
        if ttEntry and ttEntry.bestMove then
            local best = ttEntry.bestMove
            if move[1] == best[1] and move[2] == best[2] and move[3] == best[3] then
                move[5] = move[5] + 1000 -- boost TT move to the front
            end
        end

        -- Handle promotions
        local piece = getPiece(board, move[1])[1]
        if move[3] == nil and libs.Board.IsPromotion(move[2], piece, color) then
            table.insert(new, {move[1], move[2], libs.Board.Piece.knight, move[4], 95})
            table.insert(new, {move[1], move[2], libs.Board.Piece.bishop, move[4], 80})
            table.insert(new, {move[1], move[2], libs.Board.Piece.rook, move[4], 85})
            table.insert(new, {move[1], move[2], libs.Board.Piece.queen, move[4], 100})
        end
    end

    -- Sort moves descending by score (higher first)
    table.sort(moves, function(a, b)
        return a[5] > b[5]
    end)

    return moves
end

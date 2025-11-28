local libs = require(script.Parent.import)
local PieceValues = libs.Board.PieceValues

local TT = game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")

return function(board, moves)
    local color = board.side_to_move;
    local new = table.clone(moves)

    -- Get hash for the current board
    local hash = libs.BitBoard.hash(board)
    local ttEntry = TT[hash] -- lookup TT entry

    for index, move in moves do
        local piece = libs.BitBoard.get_piece(board, move.from)[1]
        local victim = libs.BitBoard.get_piece(board, move.to)

        if victim then
            move[5] = (PieceValues[victim[1]]*10)-PieceValues[piece]
        else
            move[5] = 1
        end

        -- Check if this move matches the TT best move
        if ttEntry and ttEntry.bestMove then
            local best = ttEntry.bestMove
            if move.from == best.from and move.to == best.to and move.promotion == best.promotion then
                move[5] = move[5] + 1000 -- boost TT move to the front
            end
        end

        -- Handle promotions
        if move.promotion == nil and libs.Board.IsPromotion(move.to, piece, color) then
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

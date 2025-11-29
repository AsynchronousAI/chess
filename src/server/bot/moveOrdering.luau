--!optimize 2
--!native

local libs = require(script.Parent.import)
local PieceValues = libs.Board.PieceValues

local TT = game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")

return function(board, moves: {number})
    local color = board.side_to_move;
    local new = table.clone(moves)

    -- Get hash for the current board
    local hash = libs.BitBoard.hash(board)
    local ttEntry = TT[hash] -- lookup TT entry

    for index, move in moves do
        -- Extract move data
        local from = libs.Move.getFrom(move);
        local to = libs.Move.getTo(move);
        local promotion = libs.Move.getPromotion(move);

        -- From & to in the board
        local piece = libs.Move.getPieceType(move)
        local victim = libs.BitBoard.get_piece(board, to)

        -- Capture value
        local value = 1
        if victim then
            value = (PieceValues[victim[1]]*10)-PieceValues[piece]
        end

        -- Check if this move matches the TT best move
        if ttEntry and ttEntry.bestMove then
            local best = ttEntry.bestMove

            local best_from = libs.Move.getFrom(best)
            local best_to = libs.Move.getTo(best)
            local best_promotion = libs.Move.getPromotion(best)

            if from == best_from and to == best_to and promotion == best_promotion then
                value += 1000 -- boost TT move to the front
            end
        end

        new[index] = libs.Move.setValue(move, value)

        -- Handle promotions
        if promotion == nil and libs.Board.IsPromotion(to, piece, color) then
            table.insert(new, libs.Move.setValue(libs.Move.setPromotion(move, libs.Board.Piece.bishop), value+17));
            table.insert(new, libs.Move.setValue(libs.Move.setPromotion(move, libs.Board.Piece.knight), value+18));
            table.insert(new, libs.Move.setValue(libs.Move.setPromotion(move, libs.Board.Piece.rook), value+19));
            table.insert(new, libs.Move.setValue(libs.Move.setPromotion(move, libs.Board.Piece.queen), value+20));
        end
    end

    -- Sort moves descending by score (higher first)
    table.sort(new, function(a, b)
        return libs.Move.getValue(a) > libs.Move.getValue(b)
    end)

    return new
end

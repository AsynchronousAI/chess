--!optimize 2
--!native

local bitboard, moveLib
if game then
    local libs = require(script.Parent.import)
    bitboard = libs.BitBoard
    moveLib = libs.Move
else
    bitboard = require("../../shared/engine/bitboard").BitBoard
    moveLib = require("../../shared/engine/move").Move
end

local PieceValues = {
  [-1] = 0, -- none
  [0]  = 5, -- pawn
  [1] = 3, -- knight
  [2] = 3, -- bishop
  [3] = 5, -- rook
  [4] = 100, -- queen
  [5] = 1, -- king
};

local TT = game and game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")

local function isPromotion(loc: number, piece: number, color: number)
    return piece == 0 and (if color == 0 then loc > 55 else loc < 8);
end
return function(board, moves: {number})
    local color = board.side_to_move;
    local new = table.clone(moves)

    -- Get hash for the current board
    local hash = bitboard.hash(board)
    local ttEntry = TT and TT[hash] -- lookup TT entry

    for index, move in moves do
        -- Extract move data
        local from = moveLib.getFrom(move);
        local to = moveLib.getTo(move);
        local promotion = moveLib.getPromotion(move);

        -- From & to in the board
        local piece = moveLib.getPieceType(move)
        local victim = bitboard.get_piece(board, to)

        -- Capture value
        local value = 1
        if victim then
            value = (PieceValues[victim[1]]*10)-PieceValues[piece]
        end

        -- Check if this move matches the TT best move
        if ttEntry and ttEntry.bestMove then
            local best = ttEntry.bestMove

            local best_from = moveLib.getFrom(best)
            local best_to = moveLib.getTo(best)
            local best_promotion = moveLib.getPromotion(best)

            if from == best_from and to == best_to and promotion == best_promotion then
                value += 1000 -- boost TT move to the front
            end
        end

        new[index] = moveLib.setValue(move, value)

        -- Handle promotions
        if promotion == nil and isPromotion(to, piece, color) then
            table.insert(new, moveLib.setValue(moveLib.setPromotion(moveLib, 2), value+17)); -- Bishop
            table.insert(new, moveLib.setValue(moveLib.setPromotion(moveLib, 1), value+18)); -- Knight
            table.insert(new, moveLib.setValue(moveLib.setPromotion(moveLib, 3), value+19)); -- Rook
            table.insert(new, moveLib.setValue(moveLib.setPromotion(moveLib, 4), value+20)); -- Queen
        end
    end

    -- Sort moves descending by score (higher first)
    table.sort(new, function(a, b)
        return moveLib.getValue(a) > moveLib.getValue(b)
    end)

    return new
end

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
return function(board, moves)
    local color = board.side_to_move
    local ttEntry --= TT and TT[bitboard.hash(board)]
    local tt_from, tt_to, tt_promo
    if ttEntry and ttEntry.bestMove then
        tt_from = moveLib.getFrom(ttEntry.bestMove)
        tt_to = moveLib.getTo(ttEntry.bestMove)
        tt_promo = moveLib.getPromotion(ttEntry.bestMove)
    end

    local new = {}

    local promoTypes = {1,2,3,4}
    local promoValues = {18,17,19,20}

    for _, move in ipairs(moves) do
        local from = moveLib.getFrom(move)
        local to = moveLib.getTo(move)
        local promotion = moveLib.getPromotion(move)
        local piece = moveLib.getPieceType(move)
        local victim = bitboard.get_piece(board, to)

        -- Base value
        local value = 1
        if victim then value = (PieceValues[victim[1]]*10)-PieceValues[piece] end

        -- TT boost
        if ttEntry and from==tt_from and to==tt_to and promotion==tt_promo then
            value = value + 1000
        end

        -- Normal move
        table.insert(new, moveLib.setValue(move, value))

        -- Promotions
        if not promotion and piece==0 and ((color==0 and to>55) or (color==1 and to<8)) then
            for i, p in ipairs(promoTypes) do
                table.insert(new, moveLib.setValue(moveLib.setPromotion(move, p), value + promoValues[i]))
            end
        end
    end

    table.sort(new, function(a,b) return moveLib.getValue(a) > moveLib.getValue(b) end)
    return new
end

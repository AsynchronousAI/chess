--!optimize 2
--!native

local bitboard = require("./bitboard").BitBoard
local moveLib = require("./move").Move
local Utils = require("./utils")


local PieceValues = {
  [Utils.NONE]   = 0,
  [Utils.PAWN]   = 100,
  [Utils.KNIGHT] = 320,
  [Utils.BISHOP] = 330,
  [Utils.ROOK]   = 500,
  [Utils.QUEEN]  = 900,
  [Utils.KING]   = 20000,
};

local TT = if game then game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions") else {}

return function(board, moves)
    local ttEntry = TT and TT[bitboard.hash(board)]
    local tt_from, tt_to, tt_promo
    if ttEntry and ttEntry.bestMove then
        tt_from = moveLib.getFrom(ttEntry.bestMove)
        tt_to = moveLib.getTo(ttEntry.bestMove)
        tt_promo = moveLib.getPromotion(ttEntry.bestMove)
    end

    for i, move in moves do
        local from = moveLib.getFrom(move)
        local to = moveLib.getTo(move)
        local promotion = moveLib.getPromotion(move)
        local piece = moveLib.getPieceType(move)
        local victimVal = board.pieceTable[to]
        local victimType = if victimVal then bit32.rshift(victimVal, 6) else nil

        -- Base value
        local value = 1
        if victimType then value = (PieceValues[victimType]*10)-PieceValues[piece] end

        -- TT boost
        if ttEntry and from==tt_from and to==tt_to and promotion==tt_promo then
            value = value + 1000
        end

        -- Normal move
        moves[i] = moveLib.setValue(move, value)
    end
end

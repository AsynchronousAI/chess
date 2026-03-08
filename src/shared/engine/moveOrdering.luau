--!optimize 2
--!native

local bitboard = require("./bitboard").BitBoard
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
        tt_from = bit32.band(bit32.rshift(ttEntry.bestMove, 0), 0x3F) -- inline: moveLib.getFrom(ttEntry.bestMove)
        tt_to = bit32.band(bit32.rshift(ttEntry.bestMove, 6), 0x3F) -- inline: moveLib.getTo(ttEntry.bestMove)
        tt_promo = bit32.band(bit32.rshift(ttEntry.bestMove, 16), 0x7) -- inline: moveLib.getPromotion(ttEntry.bestMove)
    end

    for i, move in moves do
        local from = bit32.band(bit32.rshift(move, 0), 0x3F) -- inline: moveLib.getFrom(move)
        local to = bit32.band(bit32.rshift(move, 6), 0x3F) -- inline: moveLib.getTo(move)
        local promotion = bit32.band(bit32.rshift(move, 16), 0x7) -- inline: moveLib.getPromotion(move)
        local piece = bit32.band(bit32.rshift(move, 12), 0x7) -- inline: moveLib.getPieceType(move)
        local victimVal = board.pieceTable[to]
        local victimType = if victimVal then bit32.rshift(victimVal, 6) else nil

        -- Base value
        local value = 1
        if victimType then value = (PieceValues[victimType]*10)-PieceValues[piece] end

        -- TT boost
        if ttEntry and from==tt_from and to==tt_to and promotion==tt_promo then
            value = value + 1000
        end

        -- inline: moves[i] = moveLib.setValue(move, value)
        moves[i] = bit32.bor(bit32.band(move, bit32.bnot(bit32.lshift(0x7F, 22))), bit32.lshift(value, 22))
    end
end

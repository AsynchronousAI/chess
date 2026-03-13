--!optimize 2
--!native

local Utils = require("./utils")

local PieceValues = {
  [Utils.NONE]   = 0,
  [Utils.PAWN]   = 100,
  [Utils.KNIGHT] = 320,
  [Utils.BISHOP] = 330,
  [Utils.ROOK]   = 500,
  [Utils.QUEEN]  = 900,
  [Utils.KING]   = 20000,
}

local TT: any
if game then
    TT = game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")
else
    TT = {}
end

local VALUE_CLEAR = bit32.bnot(bit32.lshift(0x7F, 22))

return function(board, moves)
    local hash = board.hash
    local ttEntry = hash and TT and TT[hash]
    local tt_from, tt_to, tt_promo
    if ttEntry and ttEntry.bestMove then
        local bm = ttEntry.bestMove
        tt_from  = bit32.band(bm, 0x3F)
        tt_to    = bit32.band(bit32.rshift(bm, 6), 0x3F)
        tt_promo = bit32.band(bit32.rshift(bm, 16), 0x7)
    end

    local pieceTable = board.pieceTable
    for i, move in moves do
        local from      = bit32.band(move, 0x3F)
        local to        = bit32.band(bit32.rshift(move, 6), 0x3F)
        local promotion = bit32.band(bit32.rshift(move, 16), 0x7)
        local piece     = bit32.band(bit32.rshift(move, 12), 0x7)
        local victimVal = pieceTable[to]

        local value = 1
        if victimVal then
            local victimType = bit32.rshift(victimVal, 6)
            value = PieceValues[victimType] * 10 - PieceValues[piece]
        end

        if ttEntry and from == tt_from and to == tt_to and promotion == tt_promo then
            value += 1000
        end

        moves[i] = bit32.bor(bit32.band(move, VALUE_CLEAR), bit32.lshift(value, 22))
    end
end

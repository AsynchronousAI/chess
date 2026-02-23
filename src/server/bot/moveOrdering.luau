--!optimize 2
--!native

local bitboard, moveLib, Utils
if game then
    local libs = require(script.Parent.import)
    bitboard = libs.BitBoard
    moveLib = libs.Move
    Utils = libs.Utils
else
    bitboard = require("../../shared/engine/bitboard").BitBoard
    moveLib = require("../../shared/engine/move").Move
    Utils = require("../../shared/engine/utils")
end

local PieceValues = {
  [Utils.NONE]   = 0,
  [Utils.PAWN]   = 100,
  [Utils.KNIGHT] = 320,
  [Utils.BISHOP] = 330,
  [Utils.ROOK]   = 500,
  [Utils.QUEEN]  = 900,
  [Utils.KING]   = 20000,
};

local TT = game and game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")

return function(board, moves)
    local color = board.side_to_move
    local ttEntry = TT and TT[bitboard.hash(board)]
    local tt_from, tt_to, tt_promo
    if ttEntry and ttEntry.bestMove then
        tt_from = moveLib.getFrom(ttEntry.bestMove)
        tt_to = moveLib.getTo(ttEntry.bestMove)
        tt_promo = moveLib.getPromotion(ttEntry.bestMove)
    end

    local new = table.create(#moves * 2)

    local promoTypes  = {1,  2,  3,  4}
    local promoValues = {18, 17, 19, 20}

    for _, move in moves do
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
        table.insert(new, moveLib.setValue(move, value))

        -- Promotions
        if not promotion and piece==0 and ((color==0 and to>55) or (color==1 and to<8)) then
            for i, p in promoTypes do
                table.insert(new, moveLib.setValue(moveLib.setPromotion(move, p), value + promoValues[i]))
            end
        end
    end

    -- Radix sort (two 4-bit passes over 7-bit values)
    local getValue = moveLib.getValue
    local n = #new
    local tmp = table.create(n)

    local function radix_pass(src, dst, shift)
        local counts = table.create(16, 0)
        for i = 1, n do
            local v = bit32.band(bit32.rshift(getValue(src[i]), shift), 0xF) + 1
            counts[v] += 1
        end
        for i = 2, 16 do
            counts[i] += counts[i - 1]
        end
        for i = n, 1, -1 do
            local v = bit32.band(bit32.rshift(getValue(src[i]), shift), 0xF) + 1
            local pos = counts[v]
            dst[pos] = src[i]
            counts[v] = pos - 1
        end
    end

    radix_pass(new, tmp, 0)
    radix_pass(tmp, new, 4)

    -- Reverse for descending order
    local i, j = 1, n
    while i < j do
        new[i], new[j] = new[j], new[i]
        i += 1
        j -= 1
    end

    return new
end

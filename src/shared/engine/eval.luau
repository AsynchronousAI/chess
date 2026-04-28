--!native
--!optimize 2
--!strict
local Utils = require("./utils")

local PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING

local WHITE, BLACK = Utils.WHITE, Utils.BLACK

local PIECE_STRIDE = 6
local COLOR_STRIDE = 64

local PST = table.create(64 * 6 * 2, 0)

-- Example PST initialization (can be expanded)
for i = 0, 63 do
    -- Simple material values
    PST[WHITE * COLOR_STRIDE + PAWN   * PIECE_STRIDE + i] = 100
    PST[WHITE * COLOR_STRIDE + KNIGHT * PIECE_STRIDE + i] = 320
    PST[WHITE * COLOR_STRIDE + BISHOP * PIECE_STRIDE + i] = 330
    PST[WHITE * COLOR_STRIDE + ROOK   * PIECE_STRIDE + i] = 500
    PST[WHITE * COLOR_STRIDE + QUEEN  * PIECE_STRIDE + i] = 900
    PST[WHITE * COLOR_STRIDE + KING   * PIECE_STRIDE + i] = 20000

    PST[BLACK * COLOR_STRIDE + PAWN   * PIECE_STRIDE + i] = 100
    PST[BLACK * COLOR_STRIDE + KNIGHT * PIECE_STRIDE + i] = 320
    PST[BLACK * COLOR_STRIDE + BISHOP * PIECE_STRIDE + i] = 330
    PST[BLACK * COLOR_STRIDE + ROOK   * PIECE_STRIDE + i] = 500
    PST[BLACK * COLOR_STRIDE + QUEEN  * PIECE_STRIDE + i] = 900
    PST[BLACK * COLOR_STRIDE + KING   * PIECE_STRIDE + i] = 20000
end

local function evaluate(board: Utils.Board): number
    local total_eval = 0
    local pieces = board.pieces

    for color = WHITE, BLACK do
        local multiplier = if color == WHITE then 1 else -1
        local base = color * PIECE_STRIDE
        for pieceType = PAWN, KING do
            local bb = pieces[base + pieceType]
            while bb ~= 0i do
                local sq = integer.tonumber(integer.countrz(bb))
                bb = integer.band(bb, integer.sub(bb, 1i))
                total_eval += multiplier * PST[color * COLOR_STRIDE + pieceType * PIECE_STRIDE + sq]
            end
        end
    end

    return total_eval
end

return {
    evaluate = evaluate,
    PST = PST,
    PIECE_STRIDE = PIECE_STRIDE,
    COLOR_STRIDE = COLOR_STRIDE
}

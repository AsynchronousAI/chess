--!native
--!optimize 2

local u64 = require("./int64")

-- Preimport u64
local band     = u64.band
local bnot     = u64.bnot
local btest    = u64.btest
local bor      = u64.bor
local shl      = u64.lshift
local shr      = u64.rshift
local countrz  = u64.countrz
local ZERO     = u64.ZERO
local ONE      = u64.ONE



-- Constants
local RANK_1 = u64.from_pair(0x00000000, 0x000000FF)
local RANK_2 = u64.from_pair(0x00000000, 0x0000FF00)
local RANK_7 = u64.from_pair(0x00FF0000, 0x00000000)
local RANK_8 = u64.from_pair(0xFF000000, 0x00000000)

local FILE_A = u64.from_pair(0x01010101, 0x01010101)
local FILE_H = u64.from_pair(0x80808080, 0x80808080)

local NOT_FILE_A  = bnot(FILE_A)
local NOT_FILE_H  = bnot(FILE_H)
local NOT_FILE_AB = band(NOT_FILE_A, bnot(shl(FILE_A, 1)))
local NOT_FILE_GH = band(NOT_FILE_H, bnot(shr(FILE_H, 1)))

-- Piece constants
local NONE   = -1
local PAWN   = 0
local KNIGHT = 1
local BISHOP = 2
local ROOK   = 3
local QUEEN  = 4
local KING   = 5

local WHITE = 0
local BLACK = 1

export type Board = {
    pieceTable: {number},
    pieces: {{vector}},
    occupied: {[number]: vector, all: vector},
    attacked: {{[number]: vector, all: vector}},
    side_to_move: number,
    castling_rights: number,
    en_passant_square: number,
    halfmove_clock: number,
    fullmove_number: number,
    eval: number?,
    hash: number?
}

-- Precomputed masks
local BIT_MASKS = table.create(64)
for i = 0, 63 do
    BIT_MASKS[i] = shl(ONE, i)
end
local BIT_MASKS32 = table.create(32)
for i = 0, 31 do
    BIT_MASKS32[i] = bit32.lshift(1, i)
end
local NOT_BIT_MASKS = table.create(64)
for i = 0, 63 do
    NOT_BIT_MASKS[i] = bnot(BIT_MASKS[i])
end
local NOT_BIT_MASKS32 = table.create(32)
for i = 0, 31 do
    NOT_BIT_MASKS32[i] = bit32.bnot(BIT_MASKS32[i])
end

-- 64-bit Helpers
local function unit_board(square: number)
    return BIT_MASKS[square]
end

local function get_bit(bb, square: number)
	return band(bb, BIT_MASKS[square]) ~= u64.ZERO
end

local function set_bit(bb, square: number)
	return bor(bb, BIT_MASKS[square])
end

local function clear_bit(bb, square: number)
    return band(bb, NOT_BIT_MASKS[square])
end

local function pop_lsb(bb)
    local i = countrz(bb)
    return band(bb, NOT_BIT_MASKS[i]), i
end

local function popcount(bb)
	local count = 0
	while bb ~= ZERO do
		bb = band(bb, NOT_BIT_MASKS[countrz(bb)])
		count += 1
	end
	return count
end



-- 32-bit Helpers
local function set_bit32(num: number, index: number)
    return bit32.bor(num, BIT_MASKS32[index])
end

local function clear_bit32(num: number, index: number)
    return bit32.band(num, NOT_BIT_MASKS32[index])
end

local function get_bit32(num: number, index: number)
    return bit32.band(num, BIT_MASKS32[index]) ~= 0
end

-- Square / Encoding Helpers
local function separate_square_index(loc: number)
	return {bit32.band(loc, 7), bit32.arshift(loc, 3)}
end

local function get_square_index(file: number, rank: number)
    return bit32.bor(bit32.lshift(rank, 3), file)
end

local function make_pair(a: number, b: number)
    return bit32.bor(bit32.lshift(a, 6), bit32.band(b, 63))
end

local function split_pair(pair: number)
    return bit32.rshift(pair, 6), bit32.band(pair, 63)
end

------------------------------------------------------------------
-- Module Export
------------------------------------------------------------------

return {

    -- Bitboard constants
    RANK_1 = RANK_1,
    RANK_2 = RANK_2,
    RANK_7 = RANK_7,
    RANK_8 = RANK_8,

    FILE_A = FILE_A,
    FILE_H = FILE_H,
    NOT_FILE_A  = NOT_FILE_A,
    NOT_FILE_H  = NOT_FILE_H,
    NOT_FILE_AB = NOT_FILE_AB,
    NOT_FILE_GH = NOT_FILE_GH,

    -- Castling flags
    WK = 0, WQ = 1, BK = 2, BQ = 3,

    -- Colors
    WHITE = WHITE,
    BLACK = BLACK,

    -- Pieces
    NONE = NONE,
    PAWN = PAWN,
    KNIGHT = KNIGHT,
    BISHOP = BISHOP,
    ROOK = ROOK,
    QUEEN = QUEEN,
    KING = KING,

    -- 64-bit helpers
    get_bit = get_bit,
    set_bit = set_bit,
    clear_bit = clear_bit,
    pop_lsb = pop_lsb,
    popcount = popcount,

    unit_board = unit_board,

    -- 32-bit helpers
    set_bit32 = set_bit32,
    get_bit32 = get_bit32,
    clear_bit32 = clear_bit32,

    -- Pair helpers
    make_pair = make_pair,
    split_pair = split_pair,

    -- Square helpers
    separate_square_index = separate_square_index,
    get_square_index = get_square_index
}

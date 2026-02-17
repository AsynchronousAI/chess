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

-- Preimport bit32
local band32    = bit32.band
local bor32     = bit32.bor
local bnot32    = bit32.bnot
local lshift32  = bit32.lshift
local rshift32  = bit32.rshift
local arshift32 = bit32.arshift

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
    en_passant_square: number?,
    halfmove_clock: number,
    fullmove_number: number
}

-- Precomputed masks
local BIT_MASKS = table.create(64)
for i = 0, 63 do
    BIT_MASKS[i] = shl(ONE, i)
end

local BIT_MASKS32 = table.create(32)
for i = 0, 31 do
    BIT_MASKS32[i] = lshift32(1, i)
end

-- 64-bit Helpers
local function unit_board(square: number)
    return BIT_MASKS[square]
end

local function get_bit(bb, square: number)
	return btest(bb, BIT_MASKS[square])
end

local function set_bit(bb, square: number)
	return bor(bb, BIT_MASKS[square])
end

local function clear_bit(bb, square: number)
    return band(bb, bnot(BIT_MASKS[square]))
end

local function pop_lsb(bb)
    local i = countrz(bb)
    return band(bb, bnot(BIT_MASKS[i])), i
end

local function popcount(bb)
	local count = 0
	while bb ~= ZERO do
		bb = band(bb, bnot(BIT_MASKS[countrz(bb)]))
		count += 1
	end
	return count
end

local function iterate_bits(bb, callback)
    while bb ~= ZERO do
        local index = countrz(bb)
        callback(index)
        bb = band(bb, bnot(BIT_MASKS[index]))
    end
end

-- 32-bit Helpers
local function set_bit32(num: number, index: number)
    return bor32(num, BIT_MASKS32[index])
end

local function clear_bit32(num: number, index: number)
    return band32(num, bnot32(BIT_MASKS32[index]))
end

local function get_bit32(num: number, index: number)
    return band32(num, BIT_MASKS32[index]) ~= 0
end

-- Square / Encoding Helpers
local function separate_square_index(loc: number)
	return {band32(loc, 7), arshift32(loc, 3)}
end

local function get_square_index(file: number, rank: number)
    return bor32(lshift32(rank, 3), file)
end

local function make_pair(a: number, b: number)
    return bor32(lshift32(a, 6), band32(b, 63))
end

local function split_pair(pair: number)
    return rshift32(pair, 6), band32(pair, 63)
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
    iterate_bits = iterate_bits,
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

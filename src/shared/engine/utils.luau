--!native
--!optimize 2

local u64 = require("./int64")

-- Constants
local RANK_1 = u64.from_pair(0x00000000, 0x000000FF)
local RANK_2 = u64.from_pair(0x00000000, 0x0000FF00)
local RANK_7 = u64.from_pair(0x00FF0000, 0x00000000)
local RANK_8 = u64.from_pair(0xFF000000, 0x00000000)

local FILE_A = u64.from_pair(0x01010101, 0x01010101)
local FILE_H = u64.from_pair(0x80808080, 0x80808080)

local NOT_FILE_A = u64.bnot(FILE_A)
local NOT_FILE_H = u64.bnot(FILE_H)
local NOT_FILE_AB = u64.band(NOT_FILE_A, u64.bnot(u64.lshift(FILE_A, 1)))
local NOT_FILE_GH = u64.band(NOT_FILE_H, u64.bnot(u64.rshift(FILE_H, 1)))

-- NOTE: if changing these, also change in shared/board.ts
local NONE = -1
local PAWN = 0
local KNIGHT = 1
local BISHOP = 2
local ROOK = 3
local QUEEN = 4
local KING = 5

local WHITE = 0
local BLACK = 1

-- Binary Helpers
local band    = u64.band
local bnot    = u64.bnot
local btest   = u64.btest
local bor     = u64.bor
local shl     = u64.lshift
local ZERO    = u64.ZERO
local ONE     = u64.ONE
local countrz = u64.countrz

-- Precomputed masks
local BIT_MASKS = {}
do
    for i = 0, 63 do
        BIT_MASKS[i] = shl(ONE, i)
    end
end

local function unit_board(square)
    return BIT_MASKS[square]
end
local function get_bit(bb, square)
	return btest(bb, BIT_MASKS[square])
end
local function set_bit(bb, square)
	return bor(bb, BIT_MASKS[square])
end
local function clear_bit(bb, square)
    return band(bb, bnot(BIT_MASKS[square]))
end
local function pop_lsb(bb)
    local i = countrz(bb)
    bb = band(bb, bnot(BIT_MASKS[i]))
    return bb, i
end
local function popcount(bb)
	local count = 0
	while bb ~= ZERO do
		bb, _ = pop_lsb(bb)
		count += 1
	end
	return count
end
function iterate_bits(bb, callback)
    while bb ~= u64.ZERO do
        local index = u64.countrz(bb)
        callback(index)
        bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, index)))
    end
end


-- Utils
local function separate_square_index(loc: number)
	return { bit32.band(loc, 7), bit32.arshift(loc, 3) }
end
local function get_square_index(file: number, rank: number)
	return bit32.bor(bit32.lshift(rank, 3), file)
end
local function make_pair(a: number, b: number) -- inspired by C++ make_pair
    return bit32.bor(bit32.lshift(a, 6), b)
end
local function split_pair(pair: number)
    return bit32.arshift(pair, 6), bit32.band(pair, 63)
end
local function set_bit32(num: number, index: number)
    return bit32.bor(num, bit32.lshift(1, index))
end
local function clear_bit32(num: number, index: number)
    return bit32.band(num, bit32.bnot(bit32.lshift(1, index)))
end
local function get_bit32(num: number, index: number)
    return bit32.band(num, bit32.lshift(1, index)) ~= 0
end


return {
    -- Constants
    RANK_1 = RANK_1,
    RANK_2 = RANK_2,
    RANK_7 = RANK_7,
    RANK_8 = RANK_8,
    FILE_A = FILE_A,
    FILE_H = FILE_H,
    NOT_FILE_A = NOT_FILE_A,
    NOT_FILE_H = NOT_FILE_H,
    NOT_FILE_AB = NOT_FILE_AB,
    NOT_FILE_GH = NOT_FILE_GH,


    WK = 0, WQ = 1, BK = 2, BQ = 3,

    WHITE = WHITE,
    BLACK = BLACK,
    NONE = NONE,
    ROOK = ROOK,
    KNIGHT = KNIGHT,
    BISHOP = BISHOP,
    QUEEN = QUEEN,
    KING = KING,
    PAWN = PAWN,

    -- Helpers
    get_bit = get_bit,
    set_bit = set_bit,
    clear_bit = clear_bit,
    set_bit32 = set_bit32,
    get_bit32 = get_bit32,
    clear_bit32 = clear_bit32,
    pop_lsb = pop_lsb,
    popcount = popcount,
    iterate_bits = iterate_bits,
    unit_board = unit_board,
    make_pair = make_pair,
    split_pair = split_pair,

    separate_square_index = separate_square_index,
    get_square_index = get_square_index
}

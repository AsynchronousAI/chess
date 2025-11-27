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

-- Helpers
local function get_bit(bb, square)
	return u64.btest(bb, u64.lshift(u64.ONE, square))
end
local function set_bit(bb, square)
	return u64.bor(bb, u64.lshift(u64.ONE, square))
end
local function clear_bit(bb, square)
	return u64.band(bb, u64.bnot(u64.lshift(u64.ONE, square)))
end
local function pop_lsb(bb)
	local lsb_index = u64.countrz(bb)
	return clear_bit(bb, lsb_index), lsb_index
end
local function popcount(bb)
	local count = 0
	while bb ~= u64.ZERO do
		bb, _ = pop_lsb(bb)
		count += 1
	end
	return count
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
    pop_lsb = pop_lsb,
    popcount = popcount,
}

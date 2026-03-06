--!native
--!optimize 2

local function bb_lshift_lo(lo: number, n: number): number
	if n == 0 then return lo
	elseif n < 32 then return bit32.lshift(lo, n)
	else return 0
	end
end
local function bb_lshift_hi(hi: number, lo: number, n: number): number
	if n == 0 then return hi
	elseif n < 32 then return bit32.bor(bit32.lshift(hi, n), bit32.rshift(lo, 32 - n))
	elseif n < 64 then return bit32.lshift(lo, n - 32)
	else return 0
	end
end
local function bb_rshift_hi(hi: number, n: number): number
	if n == 0 then return hi
	elseif n < 32 then return bit32.rshift(hi, n)
	else return 0
	end
end
local function bb_rshift_lo(hi: number, lo: number, n: number): number
	if n == 0 then return lo
	elseif n < 32 then return bit32.bor(bit32.rshift(lo, n), bit32.lshift(hi, 32 - n))
	elseif n < 64 then return bit32.rshift(hi, n - 32)
	else return 0
	end
end
local function bb_countrz(hi: number, lo: number): number
	if lo == 0 then
		return bit32.countrz(hi) + 32
	else
		return bit32.countrz(lo)
	end
end
local function bb_countlz(hi: number, lo: number): number
	if hi == 0 then
		return bit32.countlz(lo) + 32
	else
		return bit32.countlz(hi)
	end
end
local function bb_sub_lo(alo: number, blo: number): number
	return bit32.bor(alo - blo, 0)
end
local function bb_sub_hi(ahi: number, bhi: number, alo: number, blo: number): number
	local borrow = if alo < blo then 1 else 0
	return bit32.bor(ahi - bhi - borrow, 0)
end

-- Rank / file constants as (hi, lo) pairs
local RANK_1_LO, RANK_1_HI = 0x000000FF, 0x00000000
local RANK_2_LO, RANK_2_HI = 0x0000FF00, 0x00000000
local RANK_7_LO, RANK_7_HI = 0x00000000, 0x00FF0000
local RANK_8_LO, RANK_8_HI = 0x00000000, 0xFF000000

local FILE_A_LO, FILE_A_HI = 0x01010101, 0x01010101
local FILE_H_LO, FILE_H_HI = 0x80808080, 0x80808080

local NOT_FILE_A_LO  = bit32.bnot(FILE_A_LO)
local NOT_FILE_A_HI  = bit32.bnot(FILE_A_HI)
local NOT_FILE_H_LO  = bit32.bnot(FILE_H_LO)
local NOT_FILE_H_HI  = bit32.bnot(FILE_H_HI)

-- FILE_AB = FILE_A | (FILE_A << 1)
local FILE_AB_LO = bit32.bor(FILE_A_LO, bb_lshift_lo(FILE_A_LO, 1))
local FILE_AB_HI = bit32.bor(FILE_A_HI, bb_lshift_hi(FILE_A_HI, FILE_A_LO, 1))
local NOT_FILE_AB_LO = bit32.bnot(FILE_AB_LO)
local NOT_FILE_AB_HI = bit32.bnot(FILE_AB_HI)

-- FILE_GH = FILE_H | (FILE_H >> 1)
local FILE_GH_LO = bit32.bor(FILE_H_LO, bb_rshift_lo(FILE_H_HI, FILE_H_LO, 1))
local FILE_GH_HI = bit32.bor(FILE_H_HI, bb_rshift_hi(FILE_H_HI, 1))
local NOT_FILE_GH_LO = bit32.bnot(FILE_GH_LO)
local NOT_FILE_GH_HI = bit32.bnot(FILE_GH_HI)

-- Piece constants
local NONE   = -1
local PAWN   = 0
local KNIGHT = 1
local BISHOP = 2
local ROOK   = 3
local QUEEN  = 4
local KING   = 5

-- Color constants
-- ALL = 2 is used as the integer key for the combined-occupancy slot,
-- replacing the former string key "all". This lets occupied_lo/hi and
-- attacked_lo/hi be created with table.create and treated as arrays.
local WHITE = 0
local BLACK = 1
local ALL   = 2

export type Board = {
	pieceTable: {number},
	pieces_lo: {{number}},
	pieces_hi: {{number}},
	occupied_lo: {number},
	occupied_hi: {number},
	attacked_lo: {{number}},
	attacked_hi: {{number}},
	side_to_move: number,
	castling_rights: number,
	en_passant_square: number,
	halfmove_clock: number,
	fullmove_number: number,
	eval: number,
	hash: number,
}

-- Precomputed single-bit masks
local BIT_LO  = table.create(64)
local BIT_HI  = table.create(64)
local NBIT_LO = table.create(64)
local NBIT_HI = table.create(64)

for i = 0, 63 do
	if i < 32 then
		BIT_LO[i]  = bit32.lshift(1, i)
		BIT_HI[i]  = 0
	else
		BIT_LO[i]  = 0
		BIT_HI[i]  = bit32.lshift(1, i - 32)
	end
	NBIT_LO[i] = bit32.bnot(BIT_LO[i])
	NBIT_HI[i] = bit32.bnot(BIT_HI[i])
end

local BIT_MASKS32 = table.create(32)
for i = 0, 31 do
	BIT_MASKS32[i] = bit32.lshift(1, i)
end
local NOT_BIT_MASKS32 = table.create(32)
for i = 0, 31 do
	NOT_BIT_MASKS32[i] = bit32.bnot(BIT_MASKS32[i])
end

local function unit_board_lo(square: number): number
	return BIT_LO[square]
end
local function unit_board_hi(square: number): number
	return BIT_HI[square]
end
local function unit_board(square: number): number
	return BIT_LO[square]
end

local function get_bit(hi: number, lo: number, square: number): boolean
	return bit32.bor(
		bit32.band(lo, BIT_LO[square]),
		bit32.band(hi, BIT_HI[square])
	) ~= 0
end

local function set_bit_lo(lo: number, square: number): number
	return bit32.bor(lo, BIT_LO[square])
end
local function set_bit_hi(hi: number, square: number): number
	return bit32.bor(hi, BIT_HI[square])
end

local function clear_bit_lo(lo: number, square: number): number
	return bit32.band(lo, NBIT_LO[square])
end
local function clear_bit_hi(hi: number, square: number): number
	return bit32.band(hi, NBIT_HI[square])
end

local function popcount(hi: number, lo: number): number
	local count = 0
	while lo ~= 0 do
		lo = bit32.band(lo, lo - 1)
		count += 1
	end
	while hi ~= 0 do
		hi = bit32.band(hi, hi - 1)
		count += 1
	end
	return count
end

local function set_bit32(num: number, index: number): number
	return bit32.bor(num, BIT_MASKS32[index])
end
local function clear_bit32(num: number, index: number): number
	return bit32.band(num, NOT_BIT_MASKS32[index])
end
local function get_bit32(num: number, index: number): boolean
	return bit32.band(num, BIT_MASKS32[index]) ~= 0
end

local function separate_square_index(loc: number)
	return {bit32.band(loc, 7), bit32.arshift(loc, 3)}
end
local function get_square_index(file: number, rank: number): number
	return bit32.bor(bit32.lshift(rank, 3), file)
end
local function make_pair(a: number, b: number): number
	return bit32.bor(bit32.lshift(a, 6), bit32.band(b, 63))
end
local function split_pair(pair: number): (number, number)
	return bit32.rshift(pair, 6), bit32.band(pair, 63)
end
local function print_matrix(hi: number, lo: number)
    local cols = {}
    for r = 0, 7 do
        local row = {}
        for c = 0, 7 do
            local i = 63 - (r * 8 + c)
            local v = (i >= 32)
                and bit32.band(bit32.rshift(hi, i - 32), 1)
                or  bit32.band(bit32.rshift(lo, i), 1)
            row[#row+1] = v
        end
        table.insert(cols, table.concat(row, " "))
    end
    print(table.concat(cols, "\n"))
end

local ATTACKED_ALL = 6
return {
	bb_lshift_lo  = bb_lshift_lo,
	bb_lshift_hi  = bb_lshift_hi,
	bb_rshift_lo  = bb_rshift_lo,
	bb_rshift_hi  = bb_rshift_hi,
	bb_countrz    = bb_countrz,
	bb_countlz    = bb_countlz,
	bb_sub_lo     = bb_sub_lo,
	bb_sub_hi     = bb_sub_hi,

	BIT_LO  = BIT_LO,
	BIT_HI  = BIT_HI,
	NBIT_LO = NBIT_LO,
	NBIT_HI = NBIT_HI,

	RANK_1_LO = RANK_1_LO, RANK_1_HI = RANK_1_HI,
	RANK_2_LO = RANK_2_LO, RANK_2_HI = RANK_2_HI,
	RANK_7_LO = RANK_7_LO, RANK_7_HI = RANK_7_HI,
	RANK_8_LO = RANK_8_LO, RANK_8_HI = RANK_8_HI,

	FILE_A_LO = FILE_A_LO, FILE_A_HI = FILE_A_HI,
	FILE_H_LO = FILE_H_LO, FILE_H_HI = FILE_H_HI,

	NOT_FILE_A_LO  = NOT_FILE_A_LO,  NOT_FILE_A_HI  = NOT_FILE_A_HI,
	NOT_FILE_H_LO  = NOT_FILE_H_LO,  NOT_FILE_H_HI  = NOT_FILE_H_HI,
	NOT_FILE_AB_LO = NOT_FILE_AB_LO, NOT_FILE_AB_HI = NOT_FILE_AB_HI,
	NOT_FILE_GH_LO = NOT_FILE_GH_LO, NOT_FILE_GH_HI = NOT_FILE_GH_HI,

	-- Castling flags
	WK = 0, WQ = 1, BK = 2, BQ = 3,

	-- Colors
	WHITE = WHITE,
	BLACK = BLACK,
	ALL   = ALL,

	-- Pieces
	NONE   = NONE,
	PAWN   = PAWN,
	KNIGHT = KNIGHT,
	BISHOP = BISHOP,
	ROOK   = ROOK,
	QUEEN  = QUEEN,
	KING   = KING,
	ATTACKED_ALL = ATTACKED_ALL,

	-- 64-bit helpers
	get_bit       = get_bit,
	set_bit_lo    = set_bit_lo,
	set_bit_hi    = set_bit_hi,
	clear_bit_lo  = clear_bit_lo,
	clear_bit_hi  = clear_bit_hi,
	popcount      = popcount,
	unit_board    = unit_board,
	unit_board_lo = unit_board_lo,
	unit_board_hi = unit_board_hi,
	print_matrix = print_matrix,

	-- 32-bit helpers
	set_bit32   = set_bit32,
	get_bit32   = get_bit32,
	clear_bit32 = clear_bit32,

	-- Pair helpers
	make_pair  = make_pair,
	split_pair = split_pair,

	-- Square helpers
	separate_square_index = separate_square_index,
	get_square_index      = get_square_index,
}

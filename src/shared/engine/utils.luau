--!native
--!optimize 2
--!strict

-- Rank constants as 64-bit integers
local RANK_1 = 0x0000_0000_0000_00FFi
local RANK_2 = 0x0000_0000_0000_FF00i
local RANK_7 = 0x0000_0000_00FF_0000i
local RANK_8 = 0x0000_0000_FF00_0000i

local FILE_A = 0x0101_0101_0101_0101i
local FILE_H = 0x8080_8080_8080_8080i

local NOT_FILE_A = integer.bnot(FILE_A)
local NOT_FILE_H = integer.bnot(FILE_H)

-- FILE_AB = FILE_A | (FILE_A << 1)
local FILE_AB = integer.bor(FILE_A, integer.lshift(FILE_A, 1i))
local NOT_FILE_AB = integer.bnot(FILE_AB)

-- FILE_GH = FILE_H | (FILE_H >> 1)
local FILE_GH = integer.bor(FILE_H, integer.rshift(FILE_H, 1i))
local NOT_FILE_GH = integer.bnot(FILE_GH)

-- Piece constants
local NONE   = -1
local PAWN   = 0
local KNIGHT = 1
local BISHOP = 2
local ROOK   = 3
local QUEEN  = 4
local KING   = 5

-- Color constants
local WHITE = 0
local BLACK = 1
local ALL   = 2

-- pieces flat index: color * PIECE_STRIDE + piece   (PIECE_STRIDE = 6, size = 12)
-- attacked flat index: color * ATK_STRIDE   + piece   (ATK_STRIDE   = 7, size = 14, slot 6 = ATTACKED_ALL)
local PIECE_STRIDE = 6
local ATK_STRIDE   = 7

export type Board = {
	pieceTable: {number},
	pieces: {integer},
	occupied: {integer},
	attacked: {integer},
	side_to_move: number,
	castling_rights: number,
	en_passant_square: number?,
	halfmove_clock: number,
	fullmove_number: number,
	eval: number,
	hash: number,
}

-- Precomputed single-bit masks
local BIT = table.create(64)
local NBIT = table.create(64)

for i = 0, 63 do
	BIT[i] = integer.lshift(1i, integer.create(i) :: integer)
	NBIT[i] = integer.bnot(BIT[i])
end

local BIT_MASKS32 = table.create(32)
for i = 0, 31 do
	BIT_MASKS32[i] = bit32.lshift(1, i)
end
local NOT_BIT_MASKS32 = table.create(32)
for i = 0, 31 do
	NOT_BIT_MASKS32[i] = bit32.bnot(BIT_MASKS32[i])
end

local function unit_board(square: number): integer
	return BIT[square]
end

local function get_bit(bb: integer, square: number): boolean
	return integer.band(bb, BIT[square]) ~= 0i
end

local function set_bit(bb: integer, square: number): integer
	return integer.bor(bb, BIT[square])
end

local function clear_bit(bb: integer, square: number): integer
	return integer.band(bb, NBIT[square])
end

local function popcount(bb: integer): number
	local count = 0
	while bb ~= 0i do
		bb = integer.band(bb, integer.sub(bb, 1i))
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
local function make_pair_32(a: number, b: number): number
	return bit32.bor(bit32.lshift(a, 6), bit32.band(b, 63))
end
local function split_pair_32(pair: number): (number, number)
	return bit32.rshift(pair, 6), bit32.band(pair, 63)
end
local function print_matrix(bb: integer)
    local cols = {}
    for r = 0, 7 do
        local row = {}
        for c = 0, 7 do
            local i = 63 - (r * 8 + c)
            local v = if integer.band(integer.rshift(bb, integer.create(i) :: integer), 1i) ~= 0i then 1 else 0
            row[#row+1] = v
        end
        table.insert(cols, table.concat(row, " "))
    end
    print(table.concat(cols, "\n"))
end

local ATTACKED_ALL = 6
return {
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
	ALL   = ALL,

	-- Piece strides for flat pieces and attacked arrays
	PIECE_STRIDE = PIECE_STRIDE,
	ATK_STRIDE   = ATK_STRIDE,

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
	set_bit       = set_bit,
	clear_bit     = clear_bit,
	popcount      = popcount,
	unit_board    = unit_board,
	print_matrix  = print_matrix,

	-- 32-bit helpers
	set_bit32   = set_bit32,
	get_bit32   = get_bit32,
	clear_bit32 = clear_bit32,

	-- Pair helpers (for pieceTable)
	make_pair_32  = make_pair_32,
	split_pair_32 = split_pair_32,

	-- Square helpers
	separate_square_index = separate_square_index,
	get_square_index      = get_square_index,
}

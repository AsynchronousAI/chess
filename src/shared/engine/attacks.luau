--!native
--!optimize 2
local Magics = require("./magics")
local Utils  = require("./utils")

local bb_lshift_lo  = Utils.bb_lshift_lo
local bb_lshift_hi  = Utils.bb_lshift_hi
local bb_rshift_lo  = Utils.bb_rshift_lo
local bb_rshift_hi  = Utils.bb_rshift_hi
local bb_countrz    = Utils.bb_countrz
local bb_sub_lo     = Utils.bb_sub_lo
local bb_sub_hi     = Utils.bb_sub_hi
local BIT_LO        = Utils.BIT_LO
local BIT_HI        = Utils.BIT_HI
local unit_board_lo = Utils.unit_board_lo
local unit_board_hi = Utils.unit_board_hi
local get_bit       = Utils.get_bit
local set_bit_lo    = Utils.set_bit_lo
local set_bit_hi    = Utils.set_bit_hi

local WHITE = Utils.WHITE
local NOT_FILE_A_LO,  NOT_FILE_A_HI  = Utils.NOT_FILE_A_LO,  Utils.NOT_FILE_A_HI
local NOT_FILE_H_LO,  NOT_FILE_H_HI  = Utils.NOT_FILE_H_LO,  Utils.NOT_FILE_H_HI
local NOT_FILE_AB_LO, NOT_FILE_AB_HI = Utils.NOT_FILE_AB_LO, Utils.NOT_FILE_AB_HI
local NOT_FILE_GH_LO, NOT_FILE_GH_HI = Utils.NOT_FILE_GH_LO, Utils.NOT_FILE_GH_HI

local Attacks = {}

local KNIGHT_MOVES_LO = table.create(64)
local KNIGHT_MOVES_HI = table.create(64)
local KING_MOVES_LO   = table.create(64)
local KING_MOVES_HI   = table.create(64)

local RAY_NORTH_LO = table.create(64)
local RAY_NORTH_HI = table.create(64)
local RAY_SOUTH_LO = table.create(64)
local RAY_SOUTH_HI = table.create(64)
local RAY_EAST_LO  = table.create(64)
local RAY_EAST_HI  = table.create(64)
local RAY_WEST_LO  = table.create(64)
local RAY_WEST_HI  = table.create(64)
local RAY_NE_LO    = table.create(64)
local RAY_NE_HI    = table.create(64)
local RAY_NW_LO    = table.create(64)
local RAY_NW_HI    = table.create(64)
local RAY_SE_LO    = table.create(64)
local RAY_SE_HI    = table.create(64)
local RAY_SW_LO    = table.create(64)
local RAY_SW_HI    = table.create(64)

function Attacks.bulk_pawn_attacks_lo(bb_hi: number, bb_lo: number, color: number): number
	if color == WHITE then
		return bit32.bor(
			bit32.band(bb_lshift_lo(bb_lo, 7), NOT_FILE_H_LO),
			bit32.band(bb_lshift_lo(bb_lo, 9), NOT_FILE_A_LO)
		)
	else
		return bit32.bor(
			bit32.band(bb_rshift_lo(bb_hi, bb_lo, 7), NOT_FILE_A_LO),
			bit32.band(bb_rshift_lo(bb_hi, bb_lo, 9), NOT_FILE_H_LO)
		)
	end
end
function Attacks.bulk_pawn_attacks_hi(bb_hi: number, bb_lo: number, color: number): number
	if color == WHITE then
		return bit32.bor(
			bit32.band(bb_lshift_hi(bb_hi, bb_lo, 7), NOT_FILE_H_HI),
			bit32.band(bb_lshift_hi(bb_hi, bb_lo, 9), NOT_FILE_A_HI)
		)
	else
		return bit32.bor(
			bit32.band(bb_rshift_hi(bb_hi, 7), NOT_FILE_A_HI),
			bit32.band(bb_rshift_hi(bb_hi, 9), NOT_FILE_H_HI)
		)
	end
end

function Attacks.bulk_knight_attacks_lo(bb_hi: number, bb_lo: number): number
	return bit32.bor(
		bit32.band(bb_lshift_lo(bb_lo, 17), NOT_FILE_A_LO),
		bit32.band(bb_lshift_lo(bb_lo, 15), NOT_FILE_H_LO),
		bit32.band(bb_lshift_lo(bb_lo, 10), NOT_FILE_AB_LO),
		bit32.band(bb_lshift_lo(bb_lo, 6),  NOT_FILE_GH_LO),
		bit32.band(bb_rshift_lo(bb_hi, bb_lo, 17), NOT_FILE_H_LO),
		bit32.band(bb_rshift_lo(bb_hi, bb_lo, 15), NOT_FILE_A_LO),
		bit32.band(bb_rshift_lo(bb_hi, bb_lo, 10), NOT_FILE_GH_LO),
		bit32.band(bb_rshift_lo(bb_hi, bb_lo, 6),  NOT_FILE_AB_LO)
	)
end
function Attacks.bulk_knight_attacks_hi(bb_hi: number, bb_lo: number): number
	return bit32.bor(
		bit32.band(bb_lshift_hi(bb_hi, bb_lo, 17), NOT_FILE_A_HI),
		bit32.band(bb_lshift_hi(bb_hi, bb_lo, 15), NOT_FILE_H_HI),
		bit32.band(bb_lshift_hi(bb_hi, bb_lo, 10), NOT_FILE_AB_HI),
		bit32.band(bb_lshift_hi(bb_hi, bb_lo, 6),  NOT_FILE_GH_HI),
		bit32.band(bb_rshift_hi(bb_hi, 17), NOT_FILE_H_HI),
		bit32.band(bb_rshift_hi(bb_hi, 15), NOT_FILE_A_HI),
		bit32.band(bb_rshift_hi(bb_hi, 10), NOT_FILE_GH_HI),
		bit32.band(bb_rshift_hi(bb_hi, 6),  NOT_FILE_AB_HI)
	)
end

function Attacks.bulk_king_attacks_lo(bb_hi: number, bb_lo: number): number
	return bit32.bor(
		bit32.band(bb_lshift_lo(bb_lo, 1), NOT_FILE_A_LO),
		bit32.band(bb_rshift_lo(bb_hi, bb_lo, 1), NOT_FILE_H_LO),
		bb_lshift_lo(bb_lo, 8),
		bb_rshift_lo(bb_hi, bb_lo, 8),
		bit32.band(bb_lshift_lo(bb_lo, 9), NOT_FILE_A_LO),
		bit32.band(bb_lshift_lo(bb_lo, 7), NOT_FILE_H_LO),
		bit32.band(bb_rshift_lo(bb_hi, bb_lo, 9), NOT_FILE_H_LO),
		bit32.band(bb_rshift_lo(bb_hi, bb_lo, 7), NOT_FILE_A_LO)
	)
end
function Attacks.bulk_king_attacks_hi(bb_hi: number, bb_lo: number): number
	return bit32.bor(
		bit32.band(bb_lshift_hi(bb_hi, bb_lo, 1), NOT_FILE_A_HI),
		bit32.band(bb_rshift_hi(bb_hi, 1), NOT_FILE_H_HI),
		bb_lshift_hi(bb_hi, bb_lo, 8),
		bb_rshift_hi(bb_hi, 8),
		bit32.band(bb_lshift_hi(bb_hi, bb_lo, 9), NOT_FILE_A_HI),
		bit32.band(bb_lshift_hi(bb_hi, bb_lo, 7), NOT_FILE_H_HI),
		bit32.band(bb_rshift_hi(bb_hi, 9), NOT_FILE_H_HI),
		bit32.band(bb_rshift_hi(bb_hi, 7), NOT_FILE_A_HI)
	)
end

local ROOK_BITS        = Magics.rook.bits
local ROOK_MAGICS_HI   = Magics.rook.hi
local ROOK_MAGICS_LO   = Magics.rook.lo
local BISHOP_BITS      = Magics.bishop.bits
local BISHOP_MAGICS_LO = Magics.bishop.lo

do
	for square = 0, 63 do
		local blo = BIT_LO[square]
		local bhi = BIT_HI[square]

		KNIGHT_MOVES_LO[square] = Attacks.bulk_knight_attacks_lo(bhi, blo)
		KNIGHT_MOVES_HI[square] = Attacks.bulk_knight_attacks_hi(bhi, blo)
		KING_MOVES_LO[square]   = Attacks.bulk_king_attacks_lo(bhi, blo)
		KING_MOVES_HI[square]   = Attacks.bulk_king_attacks_hi(bhi, blo)

		RAY_NORTH_LO[square] = 0; RAY_NORTH_HI[square] = 0
		RAY_SOUTH_LO[square] = 0; RAY_SOUTH_HI[square] = 0
		RAY_EAST_LO[square]  = 0; RAY_EAST_HI[square]  = 0
		RAY_WEST_LO[square]  = 0; RAY_WEST_HI[square]  = 0
		RAY_NE_LO[square]    = 0; RAY_NE_HI[square]    = 0
		RAY_NW_LO[square]    = 0; RAY_NW_HI[square]    = 0
		RAY_SE_LO[square]    = 0; RAY_SE_HI[square]    = 0
		RAY_SW_LO[square]    = 0; RAY_SW_HI[square]    = 0

		local rank = math.floor(square / 8)
		local file  = square % 8

		for r = rank + 1, 7 do
			local s = r*8+file
			RAY_NORTH_LO[square] = set_bit_lo(RAY_NORTH_LO[square], s)
			RAY_NORTH_HI[square] = set_bit_hi(RAY_NORTH_HI[square], s)
		end
		for r = rank - 1, 0, -1 do
			local s = r*8+file
			RAY_SOUTH_LO[square] = set_bit_lo(RAY_SOUTH_LO[square], s)
			RAY_SOUTH_HI[square] = set_bit_hi(RAY_SOUTH_HI[square], s)
		end
		for f = file + 1, 7 do
			local s = rank*8+f
			RAY_EAST_LO[square] = set_bit_lo(RAY_EAST_LO[square], s)
			RAY_EAST_HI[square] = set_bit_hi(RAY_EAST_HI[square], s)
		end
		for f = file - 1, 0, -1 do
			local s = rank*8+f
			RAY_WEST_LO[square] = set_bit_lo(RAY_WEST_LO[square], s)
			RAY_WEST_HI[square] = set_bit_hi(RAY_WEST_HI[square], s)
		end

		local r2, f2
		r2, f2 = rank+1, file+1; while r2<=7 and f2<=7 do local s=r2*8+f2; RAY_NE_LO[square]=set_bit_lo(RAY_NE_LO[square],s); RAY_NE_HI[square]=set_bit_hi(RAY_NE_HI[square],s); r2+=1;f2+=1 end
		r2, f2 = rank+1, file-1; while r2<=7 and f2>=0 do local s=r2*8+f2; RAY_NW_LO[square]=set_bit_lo(RAY_NW_LO[square],s); RAY_NW_HI[square]=set_bit_hi(RAY_NW_HI[square],s); r2+=1;f2-=1 end
		r2, f2 = rank-1, file+1; while r2>=0 and f2<=7 do local s=r2*8+f2; RAY_SE_LO[square]=set_bit_lo(RAY_SE_LO[square],s); RAY_SE_HI[square]=set_bit_hi(RAY_SE_HI[square],s); r2-=1;f2+=1 end
		r2, f2 = rank-1, file-1; while r2>=0 and f2>=0 do local s=r2*8+f2; RAY_SW_LO[square]=set_bit_lo(RAY_SW_LO[square],s); RAY_SW_HI[square]=set_bit_hi(RAY_SW_HI[square],s); r2-=1;f2-=1 end
	end
end

local ROOK_MASK_LO, ROOK_MASK_HI, BISHOP_MASK_LO, BISHOP_MASK_HI,
      ROOK_TABLE_LO, ROOK_TABLE_HI, BISHOP_TABLE_LO, BISHOP_TABLE_HI =
	require("./attacks_init")(
		ROOK_BITS, BISHOP_BITS,
		ROOK_MAGICS_HI, ROOK_MAGICS_LO, BISHOP_MAGICS_LO,
		{
			NORTH_LO = RAY_NORTH_LO, NORTH_HI = RAY_NORTH_HI,
			SOUTH_LO = RAY_SOUTH_LO, SOUTH_HI = RAY_SOUTH_HI,
			EAST_LO  = RAY_EAST_LO,  EAST_HI  = RAY_EAST_HI,
			WEST_LO  = RAY_WEST_LO,  WEST_HI  = RAY_WEST_HI,
			NE_LO    = RAY_NE_LO,    NE_HI    = RAY_NE_HI,
			NW_LO    = RAY_NW_LO,    NW_HI    = RAY_NW_HI,
			SE_LO    = RAY_SE_LO,    SE_HI    = RAY_SE_HI,
			SW_LO    = RAY_SW_LO,    SW_HI    = RAY_SW_HI,
		}
	)

local SHIFT32 = 2 ^ 32

local function rook_magic_index(occ_hi: number, occ_lo: number, magic_hi: number, magic_lo: number, bits: number): number
	local hi32 = (occ_hi * magic_hi) // SHIFT32 + (occ_lo * magic_lo) // SHIFT32
	return bit32.rshift(bit32.band(hi32, 0xFFFFFFFF), 32 - bits)
end
local function bishop_magic_index(occ_hi: number, occ_lo: number, magic_lo: number, bits: number): number
	local folded = bit32.bxor(occ_lo, occ_hi)
	local hi32   = (folded * magic_lo) // SHIFT32
	return bit32.rshift(bit32.band(hi32, 0xFFFFFFFF), 32 - bits)
end

function Attacks.knight_attacks_lo(square: number): number return KNIGHT_MOVES_LO[square] end
function Attacks.knight_attacks_hi(square: number): number return KNIGHT_MOVES_HI[square] end
function Attacks.king_attacks_lo(square: number):   number return KING_MOVES_LO[square]   end
function Attacks.king_attacks_hi(square: number):   number return KING_MOVES_HI[square]   end

local function rook_attacks_occ(square: number, occ_hi: number, occ_lo: number, my_hi: number, my_lo: number): (number, number)
	local s1 = square + 1
	local mask_lo = bit32.band(occ_lo, ROOK_MASK_LO[square])
	local mask_hi = bit32.band(occ_hi, ROOK_MASK_HI[square])
	local idx = rook_magic_index(mask_hi, mask_lo, ROOK_MAGICS_HI[s1], ROOK_MAGICS_LO[s1], ROOK_BITS[s1])
	local t_lo = ROOK_TABLE_LO[square][idx]
	local t_hi = ROOK_TABLE_HI[square][idx]
	return bit32.band(t_hi, bit32.bnot(my_hi)), bit32.band(t_lo, bit32.bnot(my_lo))
end

local function bishop_attacks_occ(square: number, occ_hi: number, occ_lo: number, my_hi: number, my_lo: number): (number, number)
	local s1 = square + 1
	local mask_lo = bit32.band(occ_lo, BISHOP_MASK_LO[square])
	local mask_hi = bit32.band(occ_hi, BISHOP_MASK_HI[square])
	local idx = bishop_magic_index(mask_hi, mask_lo, BISHOP_MAGICS_LO[s1], BISHOP_BITS[s1])
	local t_lo = BISHOP_TABLE_LO[square][idx]
	local t_hi = BISHOP_TABLE_HI[square][idx]
	return bit32.band(t_hi, bit32.bnot(my_hi)), bit32.band(t_lo, bit32.bnot(my_lo))
end

function Attacks.rook_attacks_hi(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): number
	local occ_lo = bit32.bor(my_lo, other_lo)
	local occ_hi = bit32.bor(my_hi, other_hi)
	local hi, _ = rook_attacks_occ(square, occ_hi, occ_lo, my_hi, my_lo)
	return hi
end
function Attacks.rook_attacks_lo(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): number
	local occ_lo = bit32.bor(my_lo, other_lo)
	local occ_hi = bit32.bor(my_hi, other_hi)
	local _, lo = rook_attacks_occ(square, occ_hi, occ_lo, my_hi, my_lo)
	return lo
end

function Attacks.bishop_attacks_hi(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): number
	local occ_lo = bit32.bor(my_lo, other_lo)
	local occ_hi = bit32.bor(my_hi, other_hi)
	local hi, _ = bishop_attacks_occ(square, occ_hi, occ_lo, my_hi, my_lo)
	return hi
end
function Attacks.bishop_attacks_lo(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): number
	local occ_lo = bit32.bor(my_lo, other_lo)
	local occ_hi = bit32.bor(my_hi, other_hi)
	local _, lo = bishop_attacks_occ(square, occ_hi, occ_lo, my_hi, my_lo)
	return lo
end

-- Combined hi+lo versions (returned as two values) for callers that need both
function Attacks.rook_attacks(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): (number, number)
	local occ_lo = bit32.bor(my_lo, other_lo)
	local occ_hi = bit32.bor(my_hi, other_hi)
	return rook_attacks_occ(square, occ_hi, occ_lo, my_hi, my_lo)
end
function Attacks.bishop_attacks(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): (number, number)
	local occ_lo = bit32.bor(my_lo, other_lo)
	local occ_hi = bit32.bor(my_hi, other_hi)
	return bishop_attacks_occ(square, occ_hi, occ_lo, my_hi, my_lo)
end
function Attacks.queen_attacks(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): (number, number)
	local occ_lo = bit32.bor(my_lo, other_lo)
	local occ_hi = bit32.bor(my_hi, other_hi)
	local not_my_lo = bit32.bnot(my_lo)
	local not_my_hi = bit32.bnot(my_hi)
	local s1 = square + 1

	local rm_lo = bit32.band(occ_lo, ROOK_MASK_LO[square])
	local rm_hi = bit32.band(occ_hi, ROOK_MASK_HI[square])
	local ridx  = rook_magic_index(rm_hi, rm_lo, ROOK_MAGICS_HI[s1], ROOK_MAGICS_LO[s1], ROOK_BITS[s1])

	local bm_lo = bit32.band(occ_lo, BISHOP_MASK_LO[square])
	local bm_hi = bit32.band(occ_hi, BISHOP_MASK_HI[square])
	local bidx  = bishop_magic_index(bm_hi, bm_lo, BISHOP_MAGICS_LO[s1], BISHOP_BITS[s1])

	local res_hi = bit32.bor(
		bit32.band(ROOK_TABLE_HI[square][ridx],   not_my_hi),
		bit32.band(BISHOP_TABLE_HI[square][bidx], not_my_hi)
	)
	local res_lo = bit32.bor(
		bit32.band(ROOK_TABLE_LO[square][ridx],   not_my_lo),
		bit32.band(BISHOP_TABLE_LO[square][bidx], not_my_lo)
	)
	return res_hi, res_lo
end

function Attacks.between_squares_rook(a: number, b: number): (number, number)
	if get_bit(RAY_NORTH_HI[a], RAY_NORTH_LO[a], b) then
		return bit32.band(RAY_NORTH_HI[a], RAY_SOUTH_HI[b]), bit32.band(RAY_NORTH_LO[a], RAY_SOUTH_LO[b])
	end
	if get_bit(RAY_SOUTH_HI[a], RAY_SOUTH_LO[a], b) then
		return bit32.band(RAY_SOUTH_HI[a], RAY_NORTH_HI[b]), bit32.band(RAY_SOUTH_LO[a], RAY_NORTH_LO[b])
	end
	if get_bit(RAY_EAST_HI[a], RAY_EAST_LO[a], b) then
		return bit32.band(RAY_EAST_HI[a], RAY_WEST_HI[b]), bit32.band(RAY_EAST_LO[a], RAY_WEST_LO[b])
	end
	if get_bit(RAY_WEST_HI[a], RAY_WEST_LO[a], b) then
		return bit32.band(RAY_WEST_HI[a], RAY_EAST_HI[b]), bit32.band(RAY_WEST_LO[a], RAY_EAST_LO[b])
	end
	return 0, 0
end
function Attacks.between_squares_bishop(a: number, b: number): (number, number)
	if get_bit(RAY_NE_HI[a], RAY_NE_LO[a], b) then
		return bit32.band(RAY_NE_HI[a], RAY_SW_HI[b]), bit32.band(RAY_NE_LO[a], RAY_SW_LO[b])
	end
	if get_bit(RAY_NW_HI[a], RAY_NW_LO[a], b) then
		return bit32.band(RAY_NW_HI[a], RAY_SE_HI[b]), bit32.band(RAY_NW_LO[a], RAY_SE_LO[b])
	end
	if get_bit(RAY_SE_HI[a], RAY_SE_LO[a], b) then
		return bit32.band(RAY_SE_HI[a], RAY_NW_HI[b]), bit32.band(RAY_SE_LO[a], RAY_NW_LO[b])
	end
	if get_bit(RAY_SW_HI[a], RAY_SW_LO[a], b) then
		return bit32.band(RAY_SW_HI[a], RAY_NE_HI[b]), bit32.band(RAY_SW_LO[a], RAY_NE_LO[b])
	end
	return 0, 0
end

local LINE_LO = table.create(64)
local LINE_HI = table.create(64)
for a = 0, 63 do
	LINE_LO[a] = table.create(64, 0)
	LINE_HI[a] = table.create(64, 0)
end
do
	local ray_pairs = {
		{ RAY_NORTH_LO, RAY_NORTH_HI, RAY_SOUTH_LO, RAY_SOUTH_HI },
		{ RAY_SOUTH_LO, RAY_SOUTH_HI, RAY_NORTH_LO, RAY_NORTH_HI },
		{ RAY_EAST_LO,  RAY_EAST_HI,  RAY_WEST_LO,  RAY_WEST_HI  },
		{ RAY_WEST_LO,  RAY_WEST_HI,  RAY_EAST_LO,  RAY_EAST_HI  },
		{ RAY_NE_LO,    RAY_NE_HI,    RAY_SW_LO,    RAY_SW_HI    },
		{ RAY_SW_LO,    RAY_SW_HI,    RAY_NE_LO,    RAY_NE_HI    },
		{ RAY_NW_LO,    RAY_NW_HI,    RAY_SE_LO,    RAY_SE_HI    },
		{ RAY_SE_LO,    RAY_SE_HI,    RAY_NW_LO,    RAY_NW_HI    },
	}

	for a = 0, 63 do
		local a_blo = BIT_LO[a]
		local a_bhi = BIT_HI[a]
		for _, pair in ray_pairs do
			local fwd_lo_t = pair[1]
			local fwd_hi_t = pair[2]
			local bwd_lo_t = pair[3]
			local bwd_hi_t = pair[4]
			local bb_lo = fwd_lo_t[a]
			local bb_hi = fwd_hi_t[a]
			while bb_lo ~= 0 or bb_hi ~= 0 do
				local b = bb_countrz(bb_hi, bb_lo)
				-- clear LSB: bb & (bb - 1)
				local new_lo = bb_sub_lo(bb_lo, 1)
				local new_hi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
				bb_lo = bit32.band(bb_lo, new_lo)
				bb_hi = bit32.band(bb_hi, new_hi)

				LINE_LO[a][b] = bit32.bor(fwd_lo_t[a], bit32.bor(bwd_lo_t[b], a_blo))
				LINE_HI[a][b] = bit32.bor(fwd_hi_t[a], bit32.bor(bwd_hi_t[b], a_bhi))
			end
		end
	end
end

Attacks.LINE_LO = LINE_LO
Attacks.LINE_HI = LINE_HI

Attacks.RAY_NORTH_LO = RAY_NORTH_LO; Attacks.RAY_NORTH_HI = RAY_NORTH_HI
Attacks.RAY_SOUTH_LO = RAY_SOUTH_LO; Attacks.RAY_SOUTH_HI = RAY_SOUTH_HI
Attacks.RAY_EAST_LO  = RAY_EAST_LO;  Attacks.RAY_EAST_HI  = RAY_EAST_HI
Attacks.RAY_WEST_LO  = RAY_WEST_LO;  Attacks.RAY_WEST_HI  = RAY_WEST_HI
Attacks.RAY_NE_LO    = RAY_NE_LO;    Attacks.RAY_NE_HI    = RAY_NE_HI
Attacks.RAY_NW_LO    = RAY_NW_LO;    Attacks.RAY_NW_HI    = RAY_NW_HI
Attacks.RAY_SE_LO    = RAY_SE_LO;    Attacks.RAY_SE_HI    = RAY_SE_HI
Attacks.RAY_SW_LO    = RAY_SW_LO;    Attacks.RAY_SW_HI    = RAY_SW_HI

return Attacks

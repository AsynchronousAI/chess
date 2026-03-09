--!native
--!optimize 2
local Magics = require("./magics")
local Utils  = require("./utils")
local attacks_init = require("./attacks_init")

local WHITE = Utils.WHITE
local get_bit = Utils.get_bit
local set_bit_lo, set_bit_hi = Utils.set_bit_lo, Utils.set_bit_hi

local NOT_FILE_A_LO,  NOT_FILE_A_HI  = Utils.NOT_FILE_A_LO,  Utils.NOT_FILE_A_HI
local NOT_FILE_H_LO,  NOT_FILE_H_HI  = Utils.NOT_FILE_H_LO,  Utils.NOT_FILE_H_HI
local NOT_FILE_AB_LO, NOT_FILE_AB_HI = Utils.NOT_FILE_AB_LO, Utils.NOT_FILE_AB_HI
local NOT_FILE_GH_LO, NOT_FILE_GH_HI = Utils.NOT_FILE_GH_LO, Utils.NOT_FILE_GH_HI

local KNIGHT_MOVES_LO, KNIGHT_MOVES_HI = table.create(64), table.create(64)
local KING_MOVES_LO, KING_MOVES_HI     = table.create(64), table.create(64)

local RAY_NORTH_LO, RAY_NORTH_HI = table.create(64), table.create(64)
local RAY_SOUTH_LO, RAY_SOUTH_HI = table.create(64), table.create(64)
local RAY_EAST_LO,  RAY_EAST_HI  = table.create(64), table.create(64)
local RAY_WEST_LO,  RAY_WEST_HI  = table.create(64), table.create(64)
local RAY_NE_LO,    RAY_NE_HI    = table.create(64), table.create(64)
local RAY_NW_LO,    RAY_NW_HI    = table.create(64), table.create(64)
local RAY_SE_LO,    RAY_SE_HI    = table.create(64), table.create(64)
local RAY_SW_LO,    RAY_SW_HI    = table.create(64), table.create(64)

local Attacks = {}


-- Pawn Attacks
function Attacks.bulk_pawn_attacks_lo(bb_hi: number, bb_lo: number, color: number): number
	if color == WHITE then
		return bit32.bor(
			bit32.band(bit32.lshift(bb_lo, 7), NOT_FILE_H_LO),
			bit32.band(bit32.lshift(bb_lo, 9), NOT_FILE_A_LO)
		)
	else
		return bit32.bor(
			bit32.band(bit32.bor(bit32.rshift(bb_lo, 7), bit32.lshift(bb_hi, 25)), NOT_FILE_A_LO),
			bit32.band(bit32.bor(bit32.rshift(bb_lo, 9), bit32.lshift(bb_hi, 23)), NOT_FILE_H_LO)
		)
	end
end
function Attacks.bulk_pawn_attacks_hi(bb_hi: number, bb_lo: number, color: number): number
	if color == WHITE then
		return bit32.bor(
			bit32.band(bit32.bor(bit32.lshift(bb_hi, 7), bit32.rshift(bb_lo, 25)), NOT_FILE_H_HI),
			bit32.band(bit32.bor(bit32.lshift(bb_hi, 9), bit32.rshift(bb_lo, 23)), NOT_FILE_A_HI)
		)
	else
		return bit32.bor(
			bit32.band(bit32.rshift(bb_hi, 7), NOT_FILE_A_HI),
			bit32.band(bit32.rshift(bb_hi, 9), NOT_FILE_H_HI)
		)
	end
end

-- Knight attacks
function Attacks.bulk_knight_attacks_lo(bb_hi: number, bb_lo: number): number
	return bit32.bor(
		bit32.band(bit32.lshift(bb_lo, 17),                                           NOT_FILE_A_LO),
		bit32.band(bit32.lshift(bb_lo, 15),                                           NOT_FILE_H_LO),
		bit32.band(bit32.lshift(bb_lo, 10),                                           NOT_FILE_AB_LO),
		bit32.band(bit32.lshift(bb_lo, 6),                                            NOT_FILE_GH_LO),
		bit32.band(bit32.bor(bit32.rshift(bb_lo, 17), bit32.lshift(bb_hi, 15)),       NOT_FILE_H_LO),
		bit32.band(bit32.bor(bit32.rshift(bb_lo, 15), bit32.lshift(bb_hi, 17)),       NOT_FILE_A_LO),
		bit32.band(bit32.bor(bit32.rshift(bb_lo, 10), bit32.lshift(bb_hi, 22)),       NOT_FILE_GH_LO),
		bit32.band(bit32.bor(bit32.rshift(bb_lo, 6),  bit32.lshift(bb_hi, 26)),       NOT_FILE_AB_LO)
	)
end
function Attacks.bulk_knight_attacks_hi(bb_hi: number, bb_lo: number): number
	return bit32.bor(
		bit32.band(bit32.bor(bit32.lshift(bb_hi, 17), bit32.rshift(bb_lo, 15)),       NOT_FILE_A_HI),
		bit32.band(bit32.bor(bit32.lshift(bb_hi, 15), bit32.rshift(bb_lo, 17)),       NOT_FILE_H_HI),
		bit32.band(bit32.bor(bit32.lshift(bb_hi, 10), bit32.rshift(bb_lo, 22)),       NOT_FILE_AB_HI),
		bit32.band(bit32.bor(bit32.lshift(bb_hi, 6),  bit32.rshift(bb_lo, 26)),       NOT_FILE_GH_HI),
		bit32.band(bit32.rshift(bb_hi, 17),                                            NOT_FILE_H_HI),
		bit32.band(bit32.rshift(bb_hi, 15),                                            NOT_FILE_A_HI),
		bit32.band(bit32.rshift(bb_hi, 10),                                            NOT_FILE_GH_HI),
		bit32.band(bit32.rshift(bb_hi, 6),                                             NOT_FILE_AB_HI)
	)
end

-- King attacks
function Attacks.bulk_king_attacks_lo(bb_hi: number, bb_lo: number): number
	return bit32.bor(
		bit32.band(bit32.lshift(bb_lo, 1),                                            NOT_FILE_A_LO),
		bit32.band(bit32.bor(bit32.rshift(bb_lo, 1),  bit32.lshift(bb_hi, 31)),       NOT_FILE_H_LO),
		bit32.lshift(bb_lo, 8),
		bit32.bor(bit32.rshift(bb_lo, 8), bit32.lshift(bb_hi, 24)),
		bit32.band(bit32.lshift(bb_lo, 9),                                            NOT_FILE_A_LO),
		bit32.band(bit32.lshift(bb_lo, 7),                                            NOT_FILE_H_LO),
		bit32.band(bit32.bor(bit32.rshift(bb_lo, 9),  bit32.lshift(bb_hi, 23)),       NOT_FILE_H_LO),
		bit32.band(bit32.bor(bit32.rshift(bb_lo, 7),  bit32.lshift(bb_hi, 25)),       NOT_FILE_A_LO)
	)
end
function Attacks.bulk_king_attacks_hi(bb_hi: number, bb_lo: number): number
	return bit32.bor(
		bit32.band(bit32.bor(bit32.lshift(bb_hi, 1),  bit32.rshift(bb_lo, 31)),       NOT_FILE_A_HI),
		bit32.band(bit32.rshift(bb_hi, 1),                                             NOT_FILE_H_HI),
		bit32.bor(bit32.lshift(bb_hi, 8), bit32.rshift(bb_lo, 24)),
		bit32.rshift(bb_hi, 8),
		bit32.band(bit32.bor(bit32.lshift(bb_hi, 9),  bit32.rshift(bb_lo, 23)),       NOT_FILE_A_HI),
		bit32.band(bit32.bor(bit32.lshift(bb_hi, 7),  bit32.rshift(bb_lo, 25)),       NOT_FILE_H_HI),
		bit32.band(bit32.rshift(bb_hi, 9),                                             NOT_FILE_H_HI),
		bit32.band(bit32.rshift(bb_hi, 7),                                             NOT_FILE_A_HI)
	)
end

-- Generate rays, and precompute individual piece attacks
do
	for square = 0, 63 do
		local blo = if square < 32 then bit32.lshift(1, square) else 0
		local bhi = if square < 32 then 0 else bit32.lshift(1, square - 32)

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

-- Individual piece attack getters
function Attacks.knight_attacks_lo(square: number): number return KNIGHT_MOVES_LO[square] end
function Attacks.knight_attacks_hi(square: number): number return KNIGHT_MOVES_HI[square] end
function Attacks.king_attacks_lo(square: number):   number return KING_MOVES_LO[square]   end
function Attacks.king_attacks_hi(square: number):   number return KING_MOVES_HI[square]   end

-- Load precomputed masks & tables
local ROOK_BITS, ROOK_MAGICS_HI, ROOK_MAGICS_LO = Magics.rook.bits, Magics.rook.hi, Magics.rook.lo
local BISHOP_BITS, BISHOP_MAGICS_LO, BISHOP_MAGICS_HI = Magics.bishop.bits, Magics.bishop.lo, Magics.bishop.hi

local ROOK_MASK_LO, ROOK_MASK_HI, BISHOP_MASK_LO, BISHOP_MASK_HI, ROOK_TABLE_LO, ROOK_TABLE_HI, BISHOP_TABLE_LO, BISHOP_TABLE_HI = attacks_init.iniitialize(
	ROOK_BITS, BISHOP_BITS,
	ROOK_MAGICS_HI, ROOK_MAGICS_LO, BISHOP_MAGICS_HI, BISHOP_MAGICS_LO,
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
local rook_magic_index, bishop_magic_index = attacks_init.rook_magic_index, attacks_init.bishop_magic_index

-- Get precomputed attacks
function Attacks.rook_attacks(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): (number, number)
	local occ_hi = bit32.bor(my_hi, other_hi)
	local occ_lo = bit32.bor(my_lo, other_lo)
	local s1 = square + 1

	local idx = rook_magic_index(
		bit32.band(occ_hi, ROOK_MASK_HI[square]),
		bit32.band(occ_lo, ROOK_MASK_LO[square]),
		ROOK_MAGICS_HI[s1],
		ROOK_MAGICS_LO[s1],
		ROOK_BITS[s1]
	)

	return bit32.band(ROOK_TABLE_HI[square][idx], bit32.bnot(my_hi)),
	       bit32.band(ROOK_TABLE_LO[square][idx], bit32.bnot(my_lo))
end
function Attacks.bishop_attacks(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): (number, number)
	local occ_hi = bit32.bor(my_hi, other_hi)
	local occ_lo = bit32.bor(my_lo, other_lo)
	local s1 = square + 1

	local idx = bishop_magic_index(
		bit32.band(occ_hi, BISHOP_MASK_HI[square]),
		bit32.band(occ_lo, BISHOP_MASK_LO[square]),
		BISHOP_MAGICS_HI[s1],
		BISHOP_MAGICS_LO[s1],
		BISHOP_BITS[s1]
	)

	return bit32.band(BISHOP_TABLE_HI[square][idx], bit32.bnot(my_hi)),
	       bit32.band(BISHOP_TABLE_LO[square][idx], bit32.bnot(my_lo))
end
function Attacks.queen_attacks(square: number, my_hi: number, my_lo: number, other_hi: number, other_lo: number): (number, number)
	local rh, rl = Attacks.rook_attacks(square, my_hi, my_lo, other_hi, other_lo)
	local bh, bl = Attacks.bishop_attacks(square, my_hi, my_lo, other_hi, other_lo)
	return bit32.bor(rh, bh), bit32.bor(rl, bl)
end

-- Use rays to see if two pieces are colinear
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

-- Line precomputation to get a ray from LINE[start][end]
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
		local a_blo = if a < 32 then bit32.lshift(1, a) else 0
		local a_bhi = if a < 32 then 0 else bit32.lshift(1, a - 32)
		for _, pair in ray_pairs do
			local fwd_lo_t = pair[1]
			local fwd_hi_t = pair[2]
			local bwd_lo_t = pair[3]
			local bwd_hi_t = pair[4]
			local bb_lo = fwd_lo_t[a]
			local bb_hi = fwd_hi_t[a]
			while bb_lo ~= 0 or bb_hi ~= 0 do
				local b = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
				-- clear LSB: bb & (bb - 1)
				local new_lo = bit32.bor(bb_lo - 1, 0)
				local new_hi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
				bb_lo = bit32.band(bb_lo, new_lo)
				bb_hi = bit32.band(bb_hi, new_hi)

				LINE_LO[a][b] = bit32.bor(fwd_lo_t[a], bit32.bor(bwd_lo_t[b], a_blo))
				LINE_HI[a][b] = bit32.bor(fwd_hi_t[a], bit32.bor(bwd_hi_t[b], a_bhi))
			end
		end
	end
end

-- Exports
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

--!native
--!optimize 2
local Magics = require("./magics")
local Utils  = require("./utils")
local attacks_init = require("./attacks_init")

local WHITE = Utils.WHITE
local get_bit = Utils.get_bit
local set_bit = Utils.set_bit

local NOT_FILE_A = Utils.NOT_FILE_A
local NOT_FILE_H = Utils.NOT_FILE_H
local NOT_FILE_AB = Utils.NOT_FILE_AB
local NOT_FILE_GH = Utils.NOT_FILE_GH

local KNIGHT_MOVES = table.create(64)
local KING_MOVES     = table.create(64)

local RAY_NORTH = table.create(64)
local RAY_SOUTH = table.create(64)
local RAY_EAST  = table.create(64)
local RAY_WEST  = table.create(64)
local RAY_NE    = table.create(64)
local RAY_NW    = table.create(64)
local RAY_SE    = table.create(64)
local RAY_SW    = table.create(64)

local Attacks = {}


-- Pawn Attacks
function Attacks.bulk_pawn_attacks(bb: integer, color: number): integer
	if color == WHITE then
		return integer.bor(
			integer.band(integer.lshift(bb, 7i), NOT_FILE_H),
			integer.band(integer.lshift(bb, 9i), NOT_FILE_A)
		)
	else
		return integer.bor(
			integer.band(integer.rshift(bb, 7i), NOT_FILE_A),
			integer.band(integer.rshift(bb, 9i), NOT_FILE_H)
		)
	end
end

-- Knight attacks
function Attacks.bulk_knight_attacks(bb: integer): integer
	return integer.bor(
		integer.band(integer.lshift(bb, 17i), NOT_FILE_A),
		integer.band(integer.lshift(bb, 15i), NOT_FILE_H),
		integer.band(integer.lshift(bb, 10i), NOT_FILE_AB),
		integer.band(integer.lshift(bb, 6i),  NOT_FILE_GH),
		integer.band(integer.rshift(bb, 17i), NOT_FILE_H),
		integer.band(integer.rshift(bb, 15i), NOT_FILE_A),
		integer.band(integer.rshift(bb, 10i), NOT_FILE_GH),
		integer.band(integer.rshift(bb, 6i),  NOT_FILE_AB)
	)
end

-- King attacks
function Attacks.bulk_king_attacks(bb: integer): integer
	return integer.bor(
		integer.band(integer.lshift(bb, 1i), NOT_FILE_A),
		integer.band(integer.rshift(bb, 1i), NOT_FILE_H),
		integer.lshift(bb, 8i),
		integer.rshift(bb, 8i),
		integer.band(integer.lshift(bb, 9i), NOT_FILE_A),
		integer.band(integer.lshift(bb, 7i), NOT_FILE_H),
		integer.band(integer.rshift(bb, 9i), NOT_FILE_H),
		integer.band(integer.rshift(bb, 7i), NOT_FILE_A)
	)
end

-- Generate rays, and precompute individual piece attacks
do
	for square = 0, 63 do
		local b = Utils.unit_board(square)

		KNIGHT_MOVES[square] = Attacks.bulk_knight_attacks(b)
		KING_MOVES[square]   = Attacks.bulk_king_attacks(b)

		RAY_NORTH[square] = 0i; RAY_SOUTH[square] = 0i
		RAY_EAST[square]  = 0i; RAY_WEST[square]  = 0i
		RAY_NE[square]    = 0i; RAY_NW[square]    = 0i
		RAY_SE[square]    = 0i; RAY_SW[square]    = 0i

		local rank = math.floor(square / 8)
		local file  = square % 8

		for r = rank + 1, 7 do
			local s = r*8+file
			RAY_NORTH[square] = set_bit(RAY_NORTH[square], s)
		end
		for r = rank - 1, 0, -1 do
			local s = r*8+file
			RAY_SOUTH[square] = set_bit(RAY_SOUTH[square], s)
		end
		for f = file + 1, 7 do
			local s = rank*8+f
			RAY_EAST[square] = set_bit(RAY_EAST[square], s)
		end
		for f = file - 1, 0, -1 do
			local s = rank*8+f
			RAY_WEST[square] = set_bit(RAY_WEST[square], s)
		end

		local r2, f2
		r2, f2 = rank+1, file+1; while r2<=7 and f2<=7 do local s=r2*8+f2; RAY_NE[square]=set_bit(RAY_NE[square],s); r2+=1;f2+=1 end
		r2, f2 = rank+1, file-1; while r2<=7 and f2>=0 do local s=r2*8+f2; RAY_NW[square]=set_bit(RAY_NW[square],s); r2+=1;f2-=1 end
		r2, f2 = rank-1, file+1; while r2>=0 and f2<=7 do local s=r2*8+f2; RAY_SE[square]=set_bit(RAY_SE[square],s); r2-=1;f2+=1 end
		r2, f2 = rank-1, file-1; while r2>=0 and f2>=0 do local s=r2*8+f2; RAY_SW[square]=set_bit(RAY_SW[square],s); r2-=1;f2-=1 end
	end
end

-- Individual piece attack getters
function Attacks.knight_attacks(square: number): integer return KNIGHT_MOVES[square] end
function Attacks.king_attacks(square: number):   integer return KING_MOVES[square]   end

-- Load precomputed masks & tables
local ROOK_BITS, ROOK_MAGICS_HI, ROOK_MAGICS_LO = Magics.rook.bits, Magics.rook.hi, Magics.rook.lo
local BISHOP_BITS, BISHOP_MAGICS_LO, BISHOP_MAGICS_HI = Magics.bishop.bits, Magics.bishop.lo, Magics.bishop.hi

local ROOK_MASK_LO, ROOK_MASK_HI, BISHOP_MASK_LO, BISHOP_MASK_HI, ROOK_TABLE_LO, ROOK_TABLE_HI, BISHOP_TABLE_LO, BISHOP_TABLE_HI = attacks_init.iniitialize(
	ROOK_BITS, BISHOP_BITS,
	ROOK_MAGICS_HI, ROOK_MAGICS_LO, BISHOP_MAGICS_HI, BISHOP_MAGICS_LO,
	{
		NORTH_LO = RAY_NORTH, NORTH_HI = RAY_NORTH, -- Hack: we just need it for initial logic which we didn't change yet
		SOUTH_LO = RAY_SOUTH, SOUTH_HI = RAY_SOUTH,
		EAST_LO  = RAY_EAST,  EAST_HI  = RAY_EAST,
		WEST_LO  = RAY_WEST,  WEST_HI  = RAY_WEST,
		NE_LO    = RAY_NE,    NE_HI    = RAY_NE,
		NW_LO    = RAY_NW,    NW_HI    = RAY_NW,
		SE_LO    = RAY_SE,    SE_HI    = RAY_SE,
		SW_LO    = RAY_SW,    SW_HI    = RAY_SW,
	}
)
-- Wait, I need to be careful here. I said magic bitboards will separate the bitboard into two numbers.
-- So I should keep the 32-bit logic for the magic index part.

local rook_magic_index, bishop_magic_index = attacks_init.rook_magic_index, attacks_init.bishop_magic_index

-- Get precomputed attacks
function Attacks.rook_attacks(square: number, my_bb: integer, other_bb: integer): integer
	local occ = integer.bor(my_bb, other_bb)
	local s1 = square + 1

    local occ_lo, occ_hi = Utils.split_pair(integer.band(occ, Utils.make_pair(ROOK_MASK_LO[square], ROOK_MASK_HI[square])))

	local idx = rook_magic_index(
		occ_hi,
		occ_lo,
		ROOK_MAGICS_HI[s1],
		ROOK_MAGICS_LO[s1],
		ROOK_BITS[s1]
	)

	return integer.band(Utils.make_pair(ROOK_TABLE_LO[square][idx], ROOK_TABLE_HI[square][idx]), integer.bnot(my_bb))
end
function Attacks.bishop_attacks(square: number, my_bb: integer, other_bb: integer): integer
	local occ = integer.bor(my_bb, other_bb)
	local s1 = square + 1

    local occ_lo, occ_hi = Utils.split_pair(integer.band(occ, Utils.make_pair(BISHOP_MASK_LO[square], BISHOP_MASK_HI[square])))

	local idx = bishop_magic_index(
		occ_hi,
		occ_lo,
		BISHOP_MAGICS_HI[s1],
		BISHOP_MAGICS_LO[s1],
		BISHOP_BITS[s1]
	)

	return integer.band(Utils.make_pair(BISHOP_TABLE_LO[square][idx], BISHOP_TABLE_HI[square][idx]), integer.bnot(my_bb))
end
function Attacks.queen_attacks(square: number, my_bb: integer, other_bb: integer): integer
	local ra = Attacks.rook_attacks(square, my_bb, other_bb)
	local ba = Attacks.bishop_attacks(square, my_bb, other_bb)
	return integer.bor(ra, ba)
end

-- Use rays to see if two pieces are colinear
function Attacks.between_squares_rook(a: number, b: number): integer
	if get_bit(RAY_NORTH[a], b) then
		return integer.band(RAY_NORTH[a], RAY_SOUTH[b])
	end
	if get_bit(RAY_SOUTH[a], b) then
		return integer.band(RAY_SOUTH[a], RAY_NORTH[b])
	end
	if get_bit(RAY_EAST[a], b) then
		return integer.band(RAY_EAST[a], RAY_WEST[b])
	end
	if get_bit(RAY_WEST[a], b) then
		return integer.band(RAY_WEST[a], RAY_EAST[b])
	end
	return 0i
end
function Attacks.between_squares_bishop(a: number, b: number): integer
	if get_bit(RAY_NE[a], b) then
		return integer.band(RAY_NE[a], RAY_SW[b])
	end
	if get_bit(RAY_NW[a], b) then
		return integer.band(RAY_NW[a], RAY_SE[b])
	end
	if get_bit(RAY_SE[a], b) then
		return integer.band(RAY_SE[a], RAY_NW[b])
	end
	if get_bit(RAY_SW[a], b) then
		return integer.band(RAY_SW[a], RAY_NE[b])
	end
	return 0i
end

-- Line precomputation: LINE[a * 64 + b]
-- gives the full ray through squares a and b (includes both endpoints), or 0 if not collinear.
local LINE = table.create(64 * 64, 0i)
do
	local ray_pairs = {
		{ RAY_NORTH, RAY_SOUTH },
		{ RAY_SOUTH, RAY_NORTH },
		{ RAY_EAST,  RAY_WEST  },
		{ RAY_WEST,  RAY_EAST  },
		{ RAY_NE,    RAY_SW    },
		{ RAY_SW,    RAY_NE    },
		{ RAY_NW,    RAY_SE    },
		{ RAY_SE,    RAY_NW    },
	}

	for a = 0, 63 do
		local a_b = Utils.unit_board(a)
		local a_base = a * 64
		for _, pair in ray_pairs do
			local fwd_t = pair[1]
			local bwd_t = pair[2]
			local bb = fwd_t[a]
			while bb ~= 0i do
                local b = integer.tonumber(integer.countrz(bb))
                bb = integer.band(bb, integer.sub(bb, 1i))
                local b_b = Utils.unit_board(b)
                LINE[a_base + b] = integer.bor(fwd_t[a], bwd_t[b], a_b, b_b)
            end
		end
	end
end

-- Exports
Attacks.LINE = LINE

Attacks.RAY_NORTH = RAY_NORTH; Attacks.RAY_SOUTH = RAY_SOUTH
Attacks.RAY_EAST  = RAY_EAST;  Attacks.RAY_WEST  = RAY_WEST
Attacks.RAY_NE    = RAY_NE;    Attacks.RAY_NW    = RAY_NW
Attacks.RAY_SE    = RAY_SE;    Attacks.RAY_SW    = RAY_SW

return Attacks

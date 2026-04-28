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

-- Generate rays
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

		for r = rank + 1, 7 do RAY_NORTH[square] = set_bit(RAY_NORTH[square], r*8+file) end
		for r = rank - 1, 0, -1 do RAY_SOUTH[square] = set_bit(RAY_SOUTH[square], r*8+file) end
		for f = file + 1, 7 do RAY_EAST[square] = set_bit(RAY_EAST[square], rank*8+f) end
		for f = file - 1, 0, -1 do RAY_WEST[square] = set_bit(RAY_WEST[square], rank*8+f) end

		local r2, f2
		r2, f2 = rank+1, file+1; while r2<=7 and f2<=7 do RAY_NE[square]=set_bit(RAY_NE[square],r2*8+f2); r2+=1;f2+=1 end
		r2, f2 = rank+1, file-1; while r2<=7 and f2>=0 do RAY_NW[square]=set_bit(RAY_NW[square],r2*8+f2); r2+=1;f2-=1 end
		r2, f2 = rank-1, file+1; while r2>=0 and f2<=7 do RAY_SE[square]=set_bit(RAY_SE[square],r2*8+f2); r2-=1;f2+=1 end
		r2, f2 = rank-1, file-1; while r2>=0 and f2>=0 do RAY_SW[square]=set_bit(RAY_SW[square],r2*8+f2); r2-=1;f2-=1 end
	end
end

-- Individual piece attack getters
function Attacks.knight_attacks(square: number): integer return KNIGHT_MOVES[square] end
function Attacks.king_attacks(square: number):   integer return KING_MOVES[square]   end

-- Load precomputed tables
local ROOK_BITS, ROOK_MAGICS = Magics.rook.bits, Magics.rook.magics
local BISHOP_BITS, BISHOP_MAGICS = Magics.bishop.bits, Magics.bishop.magics

local ROOK_MASKS, BISHOP_MASKS, ROOK_TABLES, BISHOP_TABLES = attacks_init.initialize(
	ROOK_BITS, BISHOP_BITS,
	ROOK_MAGICS, BISHOP_MAGICS,
	{
		NORTH = RAY_NORTH, SOUTH = RAY_SOUTH, EAST = RAY_EAST, WEST = RAY_WEST,
		NE = RAY_NE, NW = RAY_NW, SE = RAY_SE, SW = RAY_SW
	}
)

local magic_index = attacks_init.magic_index

-- Get precomputed attacks
function Attacks.rook_attacks(square: number, my_bb: integer, other_bb: integer): integer
	local occ = integer.band(integer.bor(my_bb, other_bb), ROOK_MASKS[square])
	local idx = magic_index(occ, ROOK_MAGICS[square + 1], ROOK_BITS[square + 1])
	return integer.band(ROOK_TABLES[square][idx], integer.bnot(my_bb))
end
function Attacks.bishop_attacks(square: number, my_bb: integer, other_bb: integer): integer
	local occ = integer.band(integer.bor(my_bb, other_bb), BISHOP_MASKS[square])
	local idx = magic_index(occ, BISHOP_MAGICS[square + 1], BISHOP_BITS[square + 1])
	return integer.band(BISHOP_TABLES[square][idx], integer.bnot(my_bb))
end
function Attacks.queen_attacks(square: number, my_bb: integer, other_bb: integer): integer
	return integer.bor(Attacks.rook_attacks(square, my_bb, other_bb), Attacks.bishop_attacks(square, my_bb, other_bb))
end

-- Between squares
function Attacks.between_squares_rook(a: number, b: number): integer
	if get_bit(RAY_NORTH[a], b) then return integer.band(RAY_NORTH[a], RAY_SOUTH[b]) end
	if get_bit(RAY_SOUTH[a], b) then return integer.band(RAY_SOUTH[a], RAY_NORTH[b]) end
	if get_bit(RAY_EAST[a], b) then return integer.band(RAY_EAST[a], RAY_WEST[b]) end
	if get_bit(RAY_WEST[a], b) then return integer.band(RAY_WEST[a], RAY_EAST[b]) end
	return 0i
end
function Attacks.between_squares_bishop(a: number, b: number): integer
	if get_bit(RAY_NE[a], b) then return integer.band(RAY_NE[a], RAY_SW[b]) end
	if get_bit(RAY_NW[a], b) then return integer.band(RAY_NW[a], RAY_SE[b]) end
	if get_bit(RAY_SE[a], b) then return integer.band(RAY_SE[a], RAY_NW[b]) end
	if get_bit(RAY_SW[a], b) then return integer.band(RAY_SW[a], RAY_NE[b]) end
	return 0i
end

-- Line precomputation
local LINE = table.create(64 * 64, 0i)
do
	local ray_pairs = {
		{ RAY_NORTH, RAY_SOUTH }, { RAY_SOUTH, RAY_NORTH },
		{ RAY_EAST,  RAY_WEST  }, { RAY_WEST,  RAY_EAST  },
		{ RAY_NE,    RAY_SW    }, { RAY_SW,    RAY_NE    },
		{ RAY_NW,    RAY_SE    }, { RAY_SE,    RAY_NW    },
	}
	for a = 0, 63 do
		local a_b = Utils.unit_board(a)
		for _, pair in ray_pairs do
			local fwd_t = pair[1]
			local bwd_t = pair[2]
			local bb = fwd_t[a]
			while bb ~= 0i do
                local b = integer.tonumber(integer.countrz(bb))
                bb = integer.band(bb, integer.sub(bb, 1i))
                LINE[a * 64 + b] = integer.bor(fwd_t[a], bwd_t[b], a_b, Utils.unit_board(b))
            end
		end
	end
end

Attacks.LINE = LINE
Attacks.RAY_NORTH = RAY_NORTH; Attacks.RAY_SOUTH = RAY_SOUTH
Attacks.RAY_EAST  = RAY_EAST;  Attacks.RAY_WEST  = RAY_WEST
Attacks.RAY_NE    = RAY_NE;    Attacks.RAY_NW    = RAY_NW
Attacks.RAY_SE    = RAY_SE;    Attacks.RAY_SW    = RAY_SW

return Attacks

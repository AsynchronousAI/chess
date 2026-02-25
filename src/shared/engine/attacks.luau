--!native
--!optimize 2
local Magics = require("./magics")
local u64 = require("./int64")
local ZERO    = u64.ZERO
local bor     = u64.bor
local band    = u64.band
local lshift  = u64.lshift
local rshift  = u64.rshift
local bnot    = u64.bnot
local Utils      = require("./utils")
local unit_board = Utils.unit_board
local WHITE = Utils.WHITE
local BISHOP, ROOK, QUEEN = Utils.BISHOP, Utils.ROOK, Utils.QUEEN
local NOT_FILE_A, NOT_FILE_H, NOT_FILE_AB, NOT_FILE_GH =
	Utils.NOT_FILE_A, Utils.NOT_FILE_H, Utils.NOT_FILE_AB, Utils.NOT_FILE_GH
local get_bit = Utils.get_bit

local Attacks = {}

local KNIGHT_MOVES = table.create(64)
local KING_MOVES   = table.create(64)
local RAY_NORTH = table.create(64)
local RAY_SOUTH = table.create(64)
local RAY_EAST  = table.create(64)
local RAY_WEST  = table.create(64)
local RAY_NE    = table.create(64)
local RAY_NW    = table.create(64)
local RAY_SE    = table.create(64)
local RAY_SW    = table.create(64)

function Attacks.bulk_pawn_attacks(bb: vector, color: number): vector
	if color == WHITE then
		return bor(band(lshift(bb, 7), NOT_FILE_H), band(lshift(bb, 9), NOT_FILE_A))
	else
		return bor(band(rshift(bb, 7), NOT_FILE_A), band(rshift(bb, 9), NOT_FILE_H))
	end
end
function Attacks.bulk_knight_attacks(bb: vector): vector
	local attacks = ZERO
	attacks = bor(attacks, band(lshift(bb, 17), NOT_FILE_A))
	attacks = bor(attacks, band(lshift(bb, 15), NOT_FILE_H))
	attacks = bor(attacks, band(lshift(bb, 10), NOT_FILE_AB))
	attacks = bor(attacks, band(lshift(bb, 6),  NOT_FILE_GH))
	attacks = bor(attacks, band(rshift(bb, 17), NOT_FILE_H))
	attacks = bor(attacks, band(rshift(bb, 15), NOT_FILE_A))
	attacks = bor(attacks, band(rshift(bb, 10), NOT_FILE_GH))
	attacks = bor(attacks, band(rshift(bb, 6),  NOT_FILE_AB))
	return attacks
end
function Attacks.bulk_king_attacks(bb: vector): vector
	local attacks = ZERO
	attacks = bor(attacks, band(lshift(bb, 1), NOT_FILE_A))
	attacks = bor(attacks, band(rshift(bb, 1), NOT_FILE_H))
	attacks = bor(attacks, lshift(bb, 8))
	attacks = bor(attacks, rshift(bb, 8))
	attacks = bor(attacks, band(lshift(bb, 9), NOT_FILE_A))
	attacks = bor(attacks, band(lshift(bb, 7), NOT_FILE_H))
	attacks = bor(attacks, band(rshift(bb, 9), NOT_FILE_H))
	attacks = bor(attacks, band(rshift(bb, 7), NOT_FILE_A))
	return attacks
end

local ROOK_BITS        = Magics.rook.bits
local ROOK_MAGICS_HI   = Magics.rook.hi
local ROOK_MAGICS_LO   = Magics.rook.lo
local BISHOP_BITS      = Magics.bishop.bits
local BISHOP_MAGICS_LO = Magics.bishop.lo

do
	for square = 0, 63 do
		local bb = unit_board(square)
		KNIGHT_MOVES[square] = Attacks.bulk_knight_attacks(bb)
		KING_MOVES[square]   = Attacks.bulk_king_attacks(bb)

		RAY_NORTH[square] = ZERO; RAY_SOUTH[square] = ZERO
		RAY_EAST[square]  = ZERO; RAY_WEST[square]  = ZERO
		RAY_NE[square]    = ZERO; RAY_NW[square]    = ZERO
		RAY_SE[square]    = ZERO; RAY_SW[square]    = ZERO

		local rank = math.floor(square / 8)
		local file  = square % 8

		for r = rank + 1, 7 do RAY_NORTH[square] = Utils.set_bit(RAY_NORTH[square], r*8+file) end
		for r = rank - 1, 0, -1 do RAY_SOUTH[square] = Utils.set_bit(RAY_SOUTH[square], r*8+file) end
		for f = file + 1, 7 do RAY_EAST[square] = Utils.set_bit(RAY_EAST[square], rank*8+f) end
		for f = file - 1, 0, -1 do RAY_WEST[square] = Utils.set_bit(RAY_WEST[square], rank*8+f) end

		local r2, f2
		r2, f2 = rank+1, file+1; while r2<=7 and f2<=7 do RAY_NE[square]=Utils.set_bit(RAY_NE[square],r2*8+f2); r2+=1;f2+=1 end
		r2, f2 = rank+1, file-1; while r2<=7 and f2>=0 do RAY_NW[square]=Utils.set_bit(RAY_NW[square],r2*8+f2); r2+=1;f2-=1 end
		r2, f2 = rank-1, file+1; while r2>=0 and f2<=7 do RAY_SE[square]=Utils.set_bit(RAY_SE[square],r2*8+f2); r2-=1;f2+=1 end
		r2, f2 = rank-1, file-1; while r2>=0 and f2>=0 do RAY_SW[square]=Utils.set_bit(RAY_SW[square],r2*8+f2); r2-=1;f2-=1 end
	end
end
local ROOK_MASK, BISHOP_MASK, ROOK_TABLE, BISHOP_TABLE =
	require("./attacks_init")(
		ROOK_BITS, BISHOP_BITS,
		ROOK_MAGICS_HI, ROOK_MAGICS_LO, BISHOP_MAGICS_LO,
		{
			NORTH = RAY_NORTH, SOUTH = RAY_SOUTH,
			EAST  = RAY_EAST,  WEST  = RAY_WEST,
			NE    = RAY_NE,    NW    = RAY_NW,
			SE    = RAY_SE,    SW    = RAY_SW,
		}
	)


local SHIFT32 = 2 ^ 32
local function rook_magic_index(occ: vector, magic_hi: number, magic_lo: number, bits: number): number
	local occ_hi, occ_lo = u64.to_pair(occ)
	local hi32 = (occ_hi * magic_hi) // SHIFT32 + (occ_lo * magic_lo) // SHIFT32
	return bit32.rshift(bit32.band(hi32, 0xFFFFFFFF), 32 - bits)
end
local function bishop_magic_index(occ: vector, magic_lo: number, bits: number): number
	local occ_hi, occ_lo = u64.to_pair(occ)
	local folded = bit32.bxor(occ_lo, occ_hi)
	local hi32   = (folded * magic_lo) // SHIFT32
	return bit32.rshift(bit32.band(hi32, 0xFFFFFFFF), 32 - bits)
end
function Attacks.knight_attacks(square: number): vector
	return KNIGHT_MOVES[square]
end
function Attacks.king_attacks(square: number): vector
	return KING_MOVES[square]
end
local function rook_attacks_occ(square: number, occ: vector, my_occupied: vector): vector
	local idx = rook_magic_index(
		band(occ, ROOK_MASK[square]),
		ROOK_MAGICS_HI[square + 1],
		ROOK_MAGICS_LO[square + 1],
		ROOK_BITS[square + 1]
	)
	return band(ROOK_TABLE[square][idx], bnot(my_occupied))
end

local function bishop_attacks_occ(square: number, occ: vector, my_occupied: vector): vector
	local idx = bishop_magic_index(
		band(occ, BISHOP_MASK[square]),
		BISHOP_MAGICS_LO[square + 1],
		BISHOP_BITS[square + 1]
	)
	return band(BISHOP_TABLE[square][idx], bnot(my_occupied))
end

function Attacks.rook_attacks(square: number, my_occupied: vector, other_occupied: vector): vector
	return rook_attacks_occ(square, bor(my_occupied, other_occupied), my_occupied)
end

function Attacks.bishop_attacks(square: number, my_occupied: vector, other_occupied: vector): vector
	return bishop_attacks_occ(square, bor(my_occupied, other_occupied), my_occupied)
end

function Attacks.queen_attacks(square: number, my_occupied: vector, other_occupied: vector): vector
	local occ     = bor(my_occupied, other_occupied)
	local not_own = bnot(my_occupied)
	local s1      = square + 1
	local ridx = rook_magic_index(band(occ, ROOK_MASK[square]),   ROOK_MAGICS_HI[s1], ROOK_MAGICS_LO[s1], ROOK_BITS[s1])
	local bidx = bishop_magic_index(band(occ, BISHOP_MASK[square]), BISHOP_MAGICS_LO[s1], BISHOP_BITS[s1])
	return bor(
		band(ROOK_TABLE[square][ridx],   not_own),
		band(BISHOP_TABLE[square][bidx], not_own)
	)
end
function Attacks.between_squares_rook(a: number, b: number): vector
	if get_bit(RAY_NORTH[a], b) then return band(RAY_NORTH[a], RAY_SOUTH[b]) end
	if get_bit(RAY_SOUTH[a], b) then return band(RAY_SOUTH[a], RAY_NORTH[b]) end
	if get_bit(RAY_EAST[a],  b) then return band(RAY_EAST[a],  RAY_WEST[b])  end
	if get_bit(RAY_WEST[a],  b) then return band(RAY_WEST[a],  RAY_EAST[b])  end
	return ZERO
end

function Attacks.between_squares_bishop(a: number, b: number): vector
	if get_bit(RAY_NE[a], b) then return band(RAY_NE[a], RAY_SW[b]) end
	if get_bit(RAY_NW[a], b) then return band(RAY_NW[a], RAY_SE[b]) end
	if get_bit(RAY_SE[a], b) then return band(RAY_SE[a], RAY_NW[b]) end
	if get_bit(RAY_SW[a], b) then return band(RAY_SW[a], RAY_NE[b]) end
	return ZERO
end

function Attacks.between_squares(a: number, b: number, pieceType: number): vector
	if pieceType == ROOK   then return Attacks.between_squares_rook(a, b)   end
	if pieceType == BISHOP then return Attacks.between_squares_bishop(a, b) end
	if pieceType == QUEEN  then
		local r = Attacks.between_squares_rook(a, b)
		return if r ~= ZERO then r else Attacks.between_squares_bishop(a, b)
	end
	return ZERO
end

return Attacks

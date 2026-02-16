--!native
--!optimize 2

local u64 = require("./int64")
local Utils = require("./utils")

local WHITE = Utils.WHITE
local BISHOP, ROOK, QUEEN = Utils.BISHOP, Utils.ROOK, Utils.QUEEN
local NOT_FILE_A, NOT_FILE_H, NOT_FILE_AB, NOT_FILE_GH = Utils.NOT_FILE_A, Utils.NOT_FILE_H, Utils.NOT_FILE_AB, Utils.NOT_FILE_GH

local Attacks = {}

local RAY_NORTH = {}
local RAY_SOUTH = {}
local RAY_EAST = {}
local RAY_WEST = {}
local RAY_NE = {}
local RAY_NW = {}
local RAY_SE = {}
local RAY_SW = {}

local KNIGHT_MOVES = {}
local KING_MOVES = {}

-- Bulk movements
function Attacks.bulk_pawn_attacks(bb: vector, color: number): vector
	local attacks = u64.ZERO

	if color == WHITE then
		attacks = u64.bor(
			u64.band(u64.lshift(bb, 7), NOT_FILE_H),
			u64.band(u64.lshift(bb, 9), NOT_FILE_A)
		)
	else
		attacks = u64.bor(
			u64.band(u64.rshift(bb, 7), NOT_FILE_A),
			u64.band(u64.rshift(bb, 9), NOT_FILE_H)
		)
	end

	return attacks
end
function Attacks.bulk_knight_attacks(bb: vector): vector
    local attacks = u64.ZERO;

    attacks = u64.bor(attacks, u64.band(u64.lshift(bb, 17), NOT_FILE_A))
    attacks = u64.bor(attacks, u64.band(u64.lshift(bb, 15), NOT_FILE_H))
    attacks = u64.bor(attacks, u64.band(u64.lshift(bb, 10), NOT_FILE_AB))
    attacks = u64.bor(attacks, u64.band(u64.lshift(bb, 6), NOT_FILE_GH))
    attacks = u64.bor(attacks, u64.band(u64.rshift(bb, 17), NOT_FILE_H))
    attacks = u64.bor(attacks, u64.band(u64.rshift(bb, 15), NOT_FILE_A))
    attacks = u64.bor(attacks, u64.band(u64.rshift(bb, 10), NOT_FILE_GH))
    attacks = u64.bor(attacks, u64.band(u64.rshift(bb, 6), NOT_FILE_AB))

    return attacks
end
function Attacks.bulk_king_attacks(bb: vector): vector
    local attacks = u64.ZERO;

    attacks = u64.bor(attacks, u64.band(u64.lshift(bb, 1), NOT_FILE_A))
	attacks = u64.bor(attacks, u64.band(u64.rshift(bb, 1), NOT_FILE_H))
	attacks = u64.bor(attacks, u64.lshift(bb, 8))
	attacks = u64.bor(attacks, u64.rshift(bb, 8))
	attacks = u64.bor(attacks, u64.band(u64.lshift(bb, 9), NOT_FILE_A))
	attacks = u64.bor(attacks, u64.band(u64.lshift(bb, 7), NOT_FILE_H))
	attacks = u64.bor(attacks, u64.band(u64.rshift(bb, 9), NOT_FILE_H))
	attacks = u64.bor(attacks, u64.band(u64.rshift(bb, 7), NOT_FILE_A))

	return attacks
end

-- Initialize precomputed rays & knight/king movement
do
	for square = 0, 63 do
		RAY_NORTH[square] = u64.ZERO
		RAY_SOUTH[square] = u64.ZERO
		RAY_EAST[square] = u64.ZERO
		RAY_WEST[square] = u64.ZERO
		RAY_NE[square] = u64.ZERO
		RAY_NW[square] = u64.ZERO
		RAY_SE[square] = u64.ZERO
		RAY_SW[square] = u64.ZERO

		local bb = Utils.unit_board(square)

		local rank = math.floor(square / 8)
		local file = square % 8

		-- Knight & king
		KNIGHT_MOVES[square] = Attacks.bulk_knight_attacks(bb)
		KING_MOVES[square] = Attacks.bulk_king_attacks(bb)

		-- North
		for r = rank + 1, 7 do
			RAY_NORTH[square] = Utils.set_bit(RAY_NORTH[square], r * 8 + file)
		end

		-- South
		for r = rank - 1, 0, -1 do
			RAY_SOUTH[square] = Utils.set_bit(RAY_SOUTH[square], r * 8 + file)
		end

		-- East
		for f = file + 1, 7 do
			RAY_EAST[square] = Utils.set_bit(RAY_EAST[square], rank * 8 + f)
		end

		-- West
		for f = file - 1, 0, -1 do
			RAY_WEST[square] = Utils.set_bit(RAY_WEST[square], rank * 8 + f)
		end

		-- NE
		local r, f = rank + 1, file + 1
		while r <= 7 and f <= 7 do
			RAY_NE[square] = Utils.set_bit(RAY_NE[square], r * 8 + f)
			r = r + 1
			f = f + 1
		end

		-- NW
		r, f = rank + 1, file - 1
		while r <= 7 and f >= 0 do
			RAY_NW[square] = Utils.set_bit(RAY_NW[square], r * 8 + f)
			r = r + 1
			f = f - 1
		end

		-- SE
		r, f = rank - 1, file + 1
		while r >= 0 and f <= 7 do
			RAY_SE[square] = Utils.set_bit(RAY_SE[square], r * 8 + f)
			r = r - 1
			f = f + 1
		end

		-- SW
		r, f = rank - 1, file - 1
		while r >= 0 and f >= 0 do
			RAY_SW[square] = Utils.set_bit(RAY_SW[square], r * 8 + f)
			r = r - 1
			f = f - 1
		end
	end
end

-- Singular attacks (precomputed)
function Attacks.knight_attacks(square: number): vector
    return KNIGHT_MOVES[square]
end
function Attacks.king_attacks(square: number): vector
	return KING_MOVES[square]
end

function Attacks.between_squares(a: number, b: number, pieceType: number): vector
	if pieceType ~= ROOK and pieceType ~= BISHOP and pieceType ~= QUEEN then
		return u64.ZERO
	end

	local between = u64.ZERO
	local allowStraight = pieceType == ROOK or pieceType == QUEEN
	local allowDiagonal = pieceType == BISHOP or pieceType == QUEEN

	if allowStraight and Utils.get_bit(RAY_NORTH[a], b) then
		return u64.band(RAY_NORTH[a], RAY_SOUTH[b])
	elseif allowStraight and Utils.get_bit(RAY_SOUTH[a], b) then
		return u64.band(RAY_SOUTH[a], RAY_NORTH[b])
	elseif allowStraight and Utils.get_bit(RAY_EAST[a], b) then
		return u64.band(RAY_EAST[a], RAY_WEST[b])
	elseif allowStraight and Utils.get_bit(RAY_WEST[a], b) then
		return u64.band(RAY_WEST[a], RAY_EAST[b])
	elseif allowDiagonal and Utils.get_bit(RAY_NE[a], b) then
		return u64.band(RAY_NE[a], RAY_SW[b])
	elseif allowDiagonal and Utils.get_bit(RAY_NW[a], b) then
		return u64.band(RAY_NW[a], RAY_SE[b])
	elseif allowDiagonal and Utils.get_bit(RAY_SE[a], b) then
		return u64.band(RAY_SE[a], RAY_NW[b])
	elseif allowDiagonal and Utils.get_bit(RAY_SW[a], b) then
		return u64.band(RAY_SW[a], RAY_NE[b])
	end

	return between
end

-- Compute attacks in a direction using countlz/countrz
local function ray_attack_positive(ray: vector, occupied: vector, ignoreBlockers: boolean?): vector
    local blockers = u64.band(ray, occupied)
    if blockers == u64.ZERO or ignoreBlockers then
        return ray
    end

    local blocker_square = u64.countrz(blockers)
    if blocker_square == -1 then
        return ray
    end

    local mask = u64.lshift(u64.ONE, blocker_square)
    local attack = u64.band(ray, u64.bor(mask, u64.sub(mask, u64.ONE)))
    return attack, blocker_square
end
local function ray_attack_negative(ray: vector, occupied: vector, ignoreBlockers: boolean?): vector
    local blockers = u64.band(ray, occupied)
    if blockers == u64.ZERO or ignoreBlockers then
        return ray
    end

    local blocker_square = 63 - u64.countlz(blockers)
    if blocker_square == -1 then
        return ray
    end

    local mask = u64.lshift(u64.ONE, blocker_square)
    local attack = u64.band(ray, u64.bnot(u64.sub(mask, u64.ONE)))
    return attack, blocker_square
end

-- Optimized sliding attacks using CLZ/CTZ
function Attacks.rook_attacks(square: number, my_occupied: vector, other_occupied: vector, ignoreBlockers: boolean?): (vector, {number})
	local occupied = u64.bor(my_occupied, other_occupied)
	local attacks = u64.ZERO

	local north, northBlocker = ray_attack_positive(RAY_NORTH[square], occupied, ignoreBlockers)
	local east, eastBlocker = ray_attack_positive(RAY_EAST[square], occupied, ignoreBlockers)
	local south, southBlocker = ray_attack_negative(RAY_SOUTH[square], occupied, ignoreBlockers)
	local west, westBlocker = ray_attack_negative(RAY_WEST[square], occupied, ignoreBlockers)

	attacks = u64.bor(attacks, north)
	attacks = u64.bor(attacks, east)
	attacks = u64.bor(attacks, south)
	attacks = u64.bor(attacks, west)

	local blockers = {}
	if northBlocker then table.insert(blockers, northBlocker) end
	if eastBlocker then table.insert(blockers, eastBlocker) end
	if southBlocker then table.insert(blockers, southBlocker) end
	if westBlocker then table.insert(blockers, westBlocker) end

	return u64.band(attacks, u64.bnot(my_occupied)), blockers
end
function Attacks.bishop_attacks(square: number, my_occupied: vector, other_occupied: vector, ignoreBlockers: boolean?): (vector, {number})
	local occupied = u64.bor(my_occupied, other_occupied)
	local attacks = u64.ZERO

	local northEast, northEastBlocker = ray_attack_positive(RAY_NE[square], occupied, ignoreBlockers)
	local northWest, northWestBlocker = ray_attack_positive(RAY_NW[square], occupied, ignoreBlockers)
	local southEast, southEastBlocker = ray_attack_negative(RAY_SE[square], occupied, ignoreBlockers)
	local southWest, southWestBlocker = ray_attack_negative(RAY_SW[square], occupied, ignoreBlockers)

	attacks = u64.bor(attacks, northEast)
	attacks = u64.bor(attacks, northWest)
	attacks = u64.bor(attacks, southEast)
	attacks = u64.bor(attacks, southWest)

	local blockers = {}
	if northEastBlocker then table.insert(blockers, northEastBlocker) end
	if northWestBlocker then table.insert(blockers, northWestBlocker) end
	if southEastBlocker then table.insert(blockers, southEastBlocker) end
	if southWestBlocker then table.insert(blockers, southWestBlocker) end

	return u64.band(attacks, u64.bnot(my_occupied)), blockers
end
function Attacks.queen_attacks(square: number, my_occupied: vector, other_occupied: vector, ignoreBlockers: boolean?): (vector, {number})
    local rookAttacks, rookBlockers = Attacks.rook_attacks(square, my_occupied, other_occupied, ignoreBlockers)
	local bishopAttacks, bishopBlockers = Attacks.bishop_attacks(square, my_occupied, other_occupied, ignoreBlockers)

	for _, blocker in bishopBlockers do table.insert(rookBlockers, blocker) end

	return u64.bor(rookAttacks, bishopAttacks), rookBlockers
end

return Attacks

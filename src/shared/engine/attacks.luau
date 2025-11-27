--!native
--!optimize 2

-- TODO: Use clz & ctz to compute ray attacks, rather than a loop

local u64 = require("./int64")
local Utils = require("./utils")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local RANK_1, RANK_2, RANK_7, RANK_8, FILE_A, FILE_H, NOT_FILE_A, NOT_FILE_H, NOT_FILE_AB, NOT_FILE_GH = Utils.RANK_1, Utils.RANK_2, Utils.RANK_7, Utils.RANK_8, Utils.FILE_A, Utils.FILE_H, Utils.NOT_FILE_A, Utils.NOT_FILE_H, Utils.NOT_FILE_AB, Utils.NOT_FILE_GH

local Attacks = {}

local function ray_attacks(square, direction, occupied)
	local attacks = u64.ZERO
	local current_square = square

	while true do
		current_square += direction

		-- Check bounds
		if current_square < 0 or current_square > 63 then
			break
		end

		-- Check if we crossed a file boundary for horizontal moves
		local file_diff = math.abs((current_square % 8) - (square % 8))
		if math.abs(direction) == 1 and file_diff > 1 then
			break
		end

		attacks = Utils.set_bit(attacks, current_square)

		-- Stop if we hit a piece
		if Utils.get_bit(occupied, current_square) then
			break
		end
	end

	return attacks
end

-- Static
function Attacks.pawn_attacks(square, color)
	local bb = u64.lshift(u64.ONE, square)
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
function Attacks.knight_attacks(square)
	local bb = u64.lshift(u64.ONE, square)
	local attacks = u64.ZERO

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
function Attacks.king_attacks(square)
	local bb = u64.lshift(u64.ONE, square)
	local attacks = u64.ZERO

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

-- Sliding
function Attacks.rook_attacks(square, occupied)
	local attacks = u64.ZERO
	attacks = u64.bor(attacks, ray_attacks(square, 8, occupied))  -- North
	attacks = u64.bor(attacks, ray_attacks(square, -8, occupied)) -- South
	attacks = u64.bor(attacks, ray_attacks(square, 1, occupied))  -- East
	attacks = u64.bor(attacks, ray_attacks(square, -1, occupied)) -- West
	return attacks
end
function Attacks.bishop_attacks(square, occupied)
	local attacks = u64.ZERO
	attacks = u64.bor(attacks, ray_attacks(square, 9, occupied))   -- NE
	attacks = u64.bor(attacks, ray_attacks(square, 7, occupied))   -- NW
	attacks = u64.bor(attacks, ray_attacks(square, -7, occupied))  -- SE
	attacks = u64.bor(attacks, ray_attacks(square, -9, occupied))  -- SW
	return attacks
end
function Attacks.queen_attacks(square, occupied)
	return u64.bor(Attacks.rook_attacks(square, occupied), Attacks.bishop_attacks(square, occupied))
end

return Attacks

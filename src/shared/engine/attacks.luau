--!native
--!optimize 2

-- TODO: Use clz & ctz to compute ray attacks, rather than a loop

local u64 = require("./int64")
local Utils = require("./utils")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local RANK_1, RANK_2, RANK_7, RANK_8, FILE_A, FILE_H, NOT_FILE_A, NOT_FILE_H, NOT_FILE_AB, NOT_FILE_GH = Utils.RANK_1, Utils.RANK_2, Utils.RANK_7, Utils.RANK_8, Utils.FILE_A, Utils.FILE_H, Utils.NOT_FILE_A, Utils.NOT_FILE_H, Utils.NOT_FILE_AB, Utils.NOT_FILE_GH

local Attacks = {}

local function ray_attacks(square, direction, own, other)
    local attacks = u64.ZERO
    local current = square

    while true do
        -- file guards
        local file = current % 8
        if direction == 1  and file == 7 then break end
        if direction == -1 and file == 0 then break end
        if direction == 9  and file == 7 then break end
        if direction == 7  and file == 0 then break end
        if direction == -7 and file == 7 then break end
        if direction == -9 and file == 0 then break end

        local next_sq = current + direction
        if next_sq < 0 or next_sq > 63 then break end

        if Utils.get_bit(own, next_sq) then
            break
        end

        attacks = Utils.set_bit(attacks, next_sq)

        if Utils.get_bit(other, next_sq) then
            break
        end

        current = next_sq
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
function Attacks.rook_attacks(square, my_occupied, other_occupied)
	local attacks = u64.ZERO
	attacks = u64.bor(attacks, ray_attacks(square, 8, my_occupied, other_occupied))  -- North
	attacks = u64.bor(attacks, ray_attacks(square, -8, my_occupied, other_occupied)) -- South
	attacks = u64.bor(attacks, ray_attacks(square, 1, my_occupied, other_occupied))  -- East
	attacks = u64.bor(attacks, ray_attacks(square, -1, my_occupied, other_occupied)) -- West
	return attacks
end
function Attacks.bishop_attacks(square, my_occupied, other_occupied)
	local attacks = u64.ZERO
	attacks = u64.bor(attacks, ray_attacks(square, 9, my_occupied, other_occupied))   -- NE
	attacks = u64.bor(attacks, ray_attacks(square, 7, my_occupied, other_occupied))   -- NW
	attacks = u64.bor(attacks, ray_attacks(square, -7, my_occupied, other_occupied))  -- SE
	attacks = u64.bor(attacks, ray_attacks(square, -9, my_occupied, other_occupied))  -- SW
	return attacks
end
function Attacks.queen_attacks(square, my_occupied, other_occupied)
	return u64.bor(Attacks.rook_attacks(square, my_occupied, other_occupied), Attacks.bishop_attacks(square, my_occupied, other_occupied))
end

return Attacks

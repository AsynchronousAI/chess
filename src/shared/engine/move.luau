--!native
--!optimize 2

local u64 = require("./int64")

local Move = {}
Move.__index = Move

function Move.new(from, to, piece_type, captured, promotion, flags)
	return {
		from = from,
		to = to,
		piece_type = piece_type,
		captured = captured,
		promotion = promotion,
		flags = flags or {}
	}
end
function Move:to_string()
	local files = "abcdefgh"
	local ranks = "12345678"

	local from_file = files:sub((self.from % 8) + 1, (self.from % 8) + 1)
	local from_rank = ranks:sub(math.floor(self.from / 8) + 1, math.floor(self.from / 8) + 1)
	local to_file = files:sub((self.to % 8) + 1, (self.to % 8) + 1)
	local to_rank = ranks:sub(math.floor(self.to / 8) + 1, math.floor(self.to / 8) + 1)

	local move_str = from_file .. from_rank .. to_file .. to_rank

	if self.promotion then
		local pieces = "nbrq"
		move_str = move_str .. pieces:sub(self.promotion + 1, self.promotion + 1)
	end

	return move_str
end

return Move

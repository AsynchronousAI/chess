--!native
--!optimize 2
--!strict

-- NOTE: value is used for move ordering.

local Move = {}

function Move.create(from: number, to: number, piece_type: number, captured: boolean?, promotion: number?, en_passant: boolean?, castling: boolean?, kingside: boolean?, value: number?)
    local captured_bit = captured and 1 or 0
    local en_passant_bit = en_passant and 1 or 0
    local castle_bits = castling and (kingside and 1 or 2) or 0

    return bit32.bor(
        bit32.lshift(from,        0),
        bit32.lshift(to,          6),
        bit32.lshift(piece_type, 12),
        bit32.lshift(captured_bit, 15),
        bit32.lshift(promotion or 5,  16),
        bit32.lshift(en_passant_bit, 19),
        bit32.lshift(castle_bits, 20),
        bit32.lshift(value or 0, 22)
    )
end

-- Full getter
function Move.toTable(move: number)
    local castling_code = bit32.band(bit32.rshift(move, 20), 0x3) -- inline: Move.getCastling(move)
    local castling = castling_code ~= 0
    local kingside = castling_code == 1

    local promotion_raw = bit32.band(bit32.rshift(move, 16), 0x7) -- inline: Move.getPromotion(move)
    local promotion = if promotion_raw == 5 then nil else promotion_raw

    return {
        from = bit32.band(bit32.rshift(move, 0), 0x3F), -- inline: Move.getFrom(move)
        to = bit32.band(bit32.rshift(move, 6), 0x3F), -- inline: Move.getTo(move)
        piece_type = bit32.band(bit32.rshift(move, 12), 0x7), -- inline: Move.getPieceType(move)
        captured = bit32.band(bit32.rshift(move, 15), 0x1) == 1, -- inline: Move.getCaptured(move)
        promotion = promotion,
        en_passant = bit32.band(bit32.rshift(move, 19), 0x1) == 1, -- inline: Move.getEnPassant(move)
        castling = castling,
        kingside = kingside,
        value = bit32.band(bit32.rshift(move, 22), 0x7F) -- inline: Move.getValue(move)
    }
end

-- Standard notation
function Move.toString(move: number)
    local details = Move.toTable(move)

	local files = "abcdefgh"
	local ranks = "12345678"

	if details.castling then
	    return if details.kingside then "O-O" else "O-O-O"
	end

	local from_file = files:sub((details.from % 8) + 1, (details.from % 8) + 1)
	local from_rank = ranks:sub(math.floor(details.from / 8) + 1, math.floor(details.from / 8) + 1)
	local to_file = files:sub((details.to % 8) + 1, (details.to % 8) + 1)
	local to_rank = ranks:sub(math.floor(details.to / 8) + 1, math.floor(details.to / 8) + 1)

	local move_str = from_file .. from_rank .. to_file .. to_rank

	if details.promotion then
		local pieces = "nbrq"
		move_str = move_str .. "=" .. pieces:sub(details.promotion + 1, details.promotion + 1)
	end

	return move_str
end
function Move.toSimpleString(move: number)
    local details = Move.toTable(move)

    local files = "abcdefgh"
    local ranks = "12345678"

    local from_file = files:sub((details.from % 8) + 1, (details.from % 8) + 1)
    local from_rank = ranks:sub(math.floor(details.from / 8) + 1, math.floor(details.from / 8) + 1)
    local to_file = files:sub((details.to % 8) + 1, (details.to % 8) + 1)
    local to_rank = ranks:sub(math.floor(details.to / 8) + 1, math.floor(details.to / 8) + 1)

    return from_file .. from_rank .. to_file .. to_rank
end

return { Move = Move }

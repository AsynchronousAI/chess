--!native
--!optimize 2
--!strict

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

-- Getters
function Move.getFrom(move: number)
    return bit32.band(bit32.rshift(move, 0), 0x3F)
end
function Move.getTo(move: number)
    return bit32.band(bit32.rshift(move, 6), 0x3F)
end
function Move.getPieceType(move: number)
    return bit32.band(bit32.rshift(move, 12), 0x7)
end
function Move.getCaptured(move: number)
    return bit32.band(bit32.rshift(move, 15), 0x1) == 1
end
function Move.getPromotion(move: number)
    local p = bit32.band(bit32.rshift(move, 16), 0x7)
    return if p == 5 then nil else p
end
function Move.getEnPassant(move: number)
    return bit32.band(bit32.rshift(move, 19), 0x1) == 1
end
function Move.getCastling(move: number): (boolean, boolean) -- returns castling?, kingside?
    local code = bit32.band(bit32.rshift(move, 20), 0x3)
    return code ~= 0, code == 1
end
function Move.getValue(move: number)
    return bit32.band(bit32.rshift(move, 22), 0x7F) -- 7 bits
end

-- Setters
function Move.setFrom(move: number, from: number)
    move = bit32.band(move, bit32.bnot(0x3F))
    return bit32.bor(move, bit32.lshift(bit32.band(from, 0x3F), 0))
end
function Move.setTo(move: number, to: number)
    move = bit32.band(move, bit32.bnot(bit32.lshift(0x3F, 6)))
    return bit32.bor(move, bit32.lshift(bit32.band(to, 0x3F), 6))
end
function Move.setPieceType(move: number, pieceType: number)
    move = bit32.band(move, bit32.bnot(bit32.lshift(0x7, 12)))
    return bit32.bor(move, bit32.lshift(bit32.band(pieceType, 0x7), 12))
end
function Move.setCaptured(move: number, captured: boolean)
    move = bit32.band(move, bit32.bnot(bit32.lshift(0x1, 15)))
    local val = captured and 1 or 0
    return bit32.bor(move, bit32.lshift(val, 15))
end
function Move.setPromotion(move: number, promo: number)
    move = bit32.band(move, bit32.bnot(bit32.lshift(0x7, 16)))
    return bit32.bor(move, bit32.lshift(bit32.band(promo, 0x7), 16))
end
function Move.setEnPassant(move: number, ep: boolean)
    move = bit32.band(move, bit32.bnot(bit32.lshift(0x1, 19)))
    local val = ep and 1 or 0
    return bit32.bor(move, bit32.lshift(val, 19))
end
function Move.setCastling(move: number, castle: boolean, kingside: boolean)
    move = bit32.band(move, bit32.bnot(bit32.lshift(0x3, 20)))
    local code = 0
    if castle then
        code = kingside and 1 or 2
    end
    return bit32.bor(move, bit32.lshift(code, 20))
end
function Move.setValue(move: number, val: number)
    val = math.clamp(val, 0, 100)
    move = bit32.band(move, bit32.bnot(bit32.lshift(0x7F, 22)))
    return bit32.bor(move, bit32.lshift(val, 22))
end

-- Full getter
function Move.toTable(move: number)
    local castling, kingside = Move.getCastling(move)
    return {
        from = Move.getFrom(move),
        to = Move.getTo(move),
        piece_type = Move.getPieceType(move),
        captured = Move.getCaptured(move),
        promotion = Move.getPromotion(move),
        en_passant = Move.getEnPassant(move),
        castling = castling,
        kingside = kingside,
        value = Move.getValue(move)
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

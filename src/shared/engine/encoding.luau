--!native
--!optimize 2
--!strict
local Utils = require("./utils")

local PIECE_STRIDE = Utils.PIECE_STRIDE
local ATK_STRIDE   = Utils.ATK_STRIDE

local WHITE, BLACK, PAWN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KING

local Encoding = {}

function Encoding.to_buffer(board: Utils.Board): buffer
	local b = buffer.create(512) -- Increased size just in case
	local offset = 0

	for i = 0, PIECE_STRIDE * 2 - 1 do
		buffer.writeinteger(b, offset, board.pieces[i])
		offset += 8
	end
	for i = 0, ATK_STRIDE * 2 - 1 do
		buffer.writeinteger(b, offset, board.attacked[i])
		offset += 8
	end
	for i = 0, 2 do
		buffer.writeinteger(b, offset, board.occupied[i])
		offset += 8
	end

	buffer.writeu8(b, offset, board.side_to_move)
	offset += 1
	buffer.writeu8(b, offset, board.castling_rights)
	offset += 1
	buffer.writeu8(b, offset, board.en_passant_square or 255)
	offset += 1
	buffer.writeu8(b, offset, board.halfmove_clock)
	offset += 1
	buffer.writeu16(b, offset, board.fullmove_number)
	offset += 2

	-- pieceTable
	for i = 0, 63 do
		buffer.writeu16(b, offset, board.pieceTable[i] or 0xFFFF)
		offset += 2
	end

	return b
end

function Encoding.from_buffer(b: buffer): Utils.Board
	local board: Utils.Board = {
		pieces   = table.create(PIECE_STRIDE * 2, 0i),
		attacked = table.create(ATK_STRIDE * 2, 0i),
		occupied = table.create(3, 0i),
		pieceTable = table.create(64),
		side_to_move = 0,
		castling_rights = 0,
		en_passant_square = nil,
		halfmove_clock = 0,
		fullmove_number = 1,
		eval = 0,
		hash = 0,
	}

	local offset = 0
	for i = 0, PIECE_STRIDE * 2 - 1 do
		board.pieces[i] = buffer.readinteger(b, offset)
		offset += 8
	end
	for i = 0, ATK_STRIDE * 2 - 1 do
		board.attacked[i] = buffer.readinteger(b, offset)
		offset += 8
	end
	for i = 0, 2 do
		board.occupied[i] = buffer.readinteger(b, offset)
		offset += 8
	end

	board.side_to_move = buffer.readu8(b, offset)
	offset += 1
	board.castling_rights = buffer.readu8(b, offset)
	offset += 1
	local ep = buffer.readu8(b, offset)
	board.en_passant_square = if ep == 255 then nil else ep
	offset += 1
	board.halfmove_clock = buffer.readu8(b, offset)
	offset += 1
	board.fullmove_number = buffer.readu16(b, offset)
	offset += 2

	for i = 0, 63 do
		local val = buffer.readu16(b, offset)
		if val ~= 0xFFFF then
			board.pieceTable[i] = val
		end
		offset += 2
	end

	return board
end

return Encoding

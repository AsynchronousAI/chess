--!native
--!optimize 2
local Utils = require("./utils")
local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

local COLOR_STRIDE = 6 * 64  -- 384
local PIECE_STRIDE = 64

local Zobrist = {}

Zobrist.piece_square = table.create(2 * COLOR_STRIDE, 0)
Zobrist.castling     = table.create(4, 0)
Zobrist.en_passant   = table.create(8, 0)
Zobrist.side_to_move = 0

do
    math.randomseed(2124644030)
    local function random()
        return math.random(0, 0xFFFFFF)
    end

	for color = Utils.WHITE, Utils.BLACK do
		local color_base = color * COLOR_STRIDE
		for piece = Utils.PAWN, Utils.KING do
			local piece_base = color_base + piece * PIECE_STRIDE
			for square = 0, 63 do
				Zobrist.piece_square[piece_base + square] = random()
			end
		end
	end

	for i = 1, 4 do
		Zobrist.castling[i] = random()
	end
	for file = 0, 7 do
		Zobrist.en_passant[file] = random()
	end
	Zobrist.side_to_move = random()
end

local piece_square = Zobrist.piece_square

local function hash_board(board)
	if board.hash ~= nil then
		return board.hash
	end

	local hash = 0

	for pos = 0, 63 do
		local pieceAtPos = board.pieceTable[pos]
		if not pieceAtPos then continue end
		local piece = bit32.rshift(pieceAtPos, 6)
		local color = bit32.band(pieceAtPos, 63)
		hash = bit32.bxor(hash, piece_square[color * COLOR_STRIDE + piece * PIECE_STRIDE + pos])
	end

	if Utils.get_bit32(board.castling_rights, WK) then hash = bit32.bxor(hash, Zobrist.castling[1]) end
	if Utils.get_bit32(board.castling_rights, WQ) then hash = bit32.bxor(hash, Zobrist.castling[2]) end
	if Utils.get_bit32(board.castling_rights, BK) then hash = bit32.bxor(hash, Zobrist.castling[3]) end
	if Utils.get_bit32(board.castling_rights, BQ) then hash = bit32.bxor(hash, Zobrist.castling[4]) end

	if board.en_passant_square then
		local file = board.en_passant_square % 8
		hash = bit32.bxor(hash, Zobrist.en_passant[file])
	end

	if board.side_to_move == Utils.WHITE then
		hash = bit32.bxor(hash, Zobrist.side_to_move)
	end

	board.hash = hash
	return hash
end

local function toggle_piece(hash, color, piece, square)
	return bit32.bxor(hash, piece_square[color * COLOR_STRIDE + piece * PIECE_STRIDE + square])
end

local function toggle_castling(hash, index)
	return bit32.bxor(hash, Zobrist.castling[index])
end

local function toggle_en_passant(hash, file)
	return bit32.bxor(hash, Zobrist.en_passant[file])
end

local function toggle_side(hash)
	return bit32.bxor(hash, Zobrist.side_to_move)
end

return {
	hash              = hash_board,
	toggle_piece      = toggle_piece,
	toggle_castling   = toggle_castling,
	toggle_en_passant = toggle_en_passant,
	toggle_side       = toggle_side,
	piece_square      = piece_square,
	castling          = Zobrist.castling,
	en_passant        = Zobrist.en_passant,
	side_to_move      = Zobrist.side_to_move,
	COLOR_STRIDE      = COLOR_STRIDE,
	PIECE_STRIDE      = PIECE_STRIDE,
}

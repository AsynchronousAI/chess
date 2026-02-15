--!native
--!optimize 2
--!strict

local Utils = require("./utils")
local Move = require("./move").Move

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local make_pair, split_pair = Utils.make_pair, Utils.split_pair
local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

export type Board = {
	pieceTable: { [number]: number },
	pieces: { [number]: { [number]: vector } },
	occupied: { [number]: vector, all: vector },
	attacked: { [number]: { [number]: vector, all: vector } },
	side_to_move: number,
	castling_rights: number,
	en_passant_square: number?,
	halfmove_clock: number,
	fullmove_number: number,
}

export type UndoRecord = {
	move: number,
	captured_piece: number?,
	castling_rights: number,
	en_passant_square: number?,
	halfmove_clock: number,
	fullmove_number: number,
	additionallyMoved: { number }?, -- rook moves for castling or ep captures
}

local CAPTURED_SQUARE_MASK = 0x3F
local CAPTURED_TYPE_SHIFT = 6
local CAPTURED_COLOR_SHIFT = 9

local function pack_captured_piece(cap_type: number, cap_color: number, cap_square: number): number
	return bit32.bor(
		bit32.band(cap_square, CAPTURED_SQUARE_MASK),
		bit32.lshift(bit32.band(cap_type, 0x7), CAPTURED_TYPE_SHIFT),
		bit32.lshift(bit32.band(cap_color, 0x1), CAPTURED_COLOR_SHIFT)
	)
end

local function unpack_captured_piece(packed: number)
	local square = bit32.band(packed, CAPTURED_SQUARE_MASK)
	local cap_type = bit32.band(bit32.rshift(packed, CAPTURED_TYPE_SHIFT), 0x7)
	local cap_color = bit32.band(bit32.rshift(packed, CAPTURED_COLOR_SHIFT), 0x1)
	return cap_type, cap_color, square
end

local function get_captured_piece(board: Board, to: number, en_passant: boolean, color: number): number|nil
	local captured_square = to
	if en_passant then
		captured_square = to - (if color == WHITE then 8 else -8)
	end

	local captured_info = board.pieceTable[captured_square]
	if not captured_info then
		return nil
	end

	local cap_type, cap_color = split_pair(captured_info)
	return pack_captured_piece(cap_type, cap_color, captured_square)
end

local function clear_from_square(board: Board, color: number, piece_type: number, from: number)
	board.pieces[color][piece_type] = Utils.clear_bit(board.pieces[color][piece_type], from)
	board.pieceTable[from] = nil
end

local function place_on_square(board: Board, color: number, piece_type: number, to: number)
	board.pieces[color][piece_type] = Utils.set_bit(board.pieces[color][piece_type], to)
	board.pieceTable[to] = make_pair(piece_type, color)
end

local function handle_capture(
	board: Board,
	opponent: number,
	to: number,
	en_passant: boolean,
	color: number
): { number }?
	-- Remove captured piece on target square
	for p = PAWN, KING do
		if Utils.get_bit(board.pieces[opponent][p], to) then
			board.pieces[opponent][p] = Utils.clear_bit(board.pieces[opponent][p], to)
			board.occupied.all = Utils.clear_bit(board.occupied.all, to)
			board.occupied[opponent] = Utils.clear_bit(board.occupied[opponent], to)
			break
		end
	end

	-- En passant capture: captured pawn is not on target square
	if en_passant then
		local captured_pawn_square = to - (if color == WHITE then 8 else -8)
		board.pieces[opponent][PAWN] = Utils.clear_bit(board.pieces[opponent][PAWN], captured_pawn_square)
		board.pieceTable[captured_pawn_square] = nil

		board.occupied.all = Utils.clear_bit(board.occupied.all, captured_pawn_square)
		board.occupied[opponent] = Utils.clear_bit(board.occupied[opponent], captured_pawn_square)

		return { captured_pawn_square }
	end

	return nil
end

local function update_halfmove_clock(board: Board, piece_type: number, captured: boolean)
	if captured or piece_type == PAWN then
		board.halfmove_clock = 0
	else
		board.halfmove_clock += 1
	end
end

local function update_en_passant_square(board: Board, piece_type: number, color: number, from: number, to: number)
	board.en_passant_square = nil
	if piece_type ~= PAWN then
		return
	end

	local move_distance = math.abs(to - from)
	if move_distance == 16 then
		board.en_passant_square = if color == WHITE then (from + 8) else (from - 8)
	end
end

local function update_castling_rights_for_move(board: Board, piece_type: number, color: number, from: number, to: number, captured: boolean)
	if piece_type == KING then
		if color == WHITE then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, WK)
			board.castling_rights = Utils.clear_bit32(board.castling_rights, WQ)
		else
			board.castling_rights = Utils.clear_bit32(board.castling_rights, BK)
			board.castling_rights = Utils.clear_bit32(board.castling_rights, BQ)
		end
	elseif piece_type == ROOK then
		if color == WHITE then
			if from == 0 then
				board.castling_rights = Utils.clear_bit32(board.castling_rights, WQ)
			elseif from == 7 then
				board.castling_rights = Utils.clear_bit32(board.castling_rights, WK)
			end
		else
			if from == 56 then
				board.castling_rights = Utils.clear_bit32(board.castling_rights, BQ)
			elseif from == 63 then
				board.castling_rights = Utils.clear_bit32(board.castling_rights, BK)
			end
		end
	end

	if captured then
		if to == 0 then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, WQ)
		elseif to == 7 then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, WK)
		elseif to == 56 then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, BQ)
		elseif to == 63 then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, BK)
		end
	end
end

local function handle_castling_rook_move(board: Board, color: number, kingside: boolean): { number }
	local rook_from, rook_to
	if kingside then
		rook_from = if color == WHITE then 7 else 63
		rook_to = if color == WHITE then 5 else 61
	else
		rook_from = if color == WHITE then 0 else 56
		rook_to = if color == WHITE then 3 else 59
	end

	board.pieces[color][ROOK] = Utils.clear_bit(board.pieces[color][ROOK], rook_from)
	board.pieces[color][ROOK] = Utils.set_bit(board.pieces[color][ROOK], rook_to)

	board.pieceTable[rook_from] = nil
	board.pieceTable[rook_to] = make_pair(ROOK, color)

	board.occupied.all = Utils.clear_bit(board.occupied.all, rook_from)
	board.occupied[color] = Utils.clear_bit(board.occupied[color], rook_from)

	board.occupied.all = Utils.set_bit(board.occupied.all, rook_to)
	board.occupied[color] = Utils.set_bit(board.occupied[color], rook_to)

	return { rook_from, rook_to }
end

local function update_occupied_for_basic_move(board: Board, color: number, from: number, to: number)
	board.occupied.all = Utils.clear_bit(board.occupied.all, from)
	board.occupied.all = Utils.set_bit(board.occupied.all, to)

	board.occupied[color] = Utils.clear_bit(board.occupied[color], from)
	board.occupied[color] = Utils.set_bit(board.occupied[color], to)
end

local function restore_captured_piece(board: Board, packed: number)
	local type, color, square = unpack_captured_piece(packed)

	board.pieces[color][type] = Utils.set_bit(board.pieces[color][type], square)
	board.pieceTable[square] = make_pair(type, color)

	board.occupied.all = Utils.set_bit(board.occupied.all, square)
	board.occupied[color] = Utils.set_bit(board.occupied[color], square)
end

local function undo_castling_rook(board: Board, color: number, rook_from: number, rook_to: number)
	board.pieces[color][ROOK] = Utils.clear_bit(board.pieces[color][ROOK], rook_to)
	board.pieces[color][ROOK] = Utils.set_bit(board.pieces[color][ROOK], rook_from)

	board.pieceTable[rook_to] = nil
	board.pieceTable[rook_from] = make_pair(ROOK, color)

	board.occupied.all = Utils.clear_bit(board.occupied.all, rook_to)
	board.occupied[color] = Utils.clear_bit(board.occupied[color], rook_to)

	board.occupied.all = Utils.set_bit(board.occupied.all, rook_from)
	board.occupied[color] = Utils.set_bit(board.occupied[color], rook_from)
end

local function make_move(board: Board, move: number): UndoRecord
	local color = board.side_to_move
	local opponent = 1 - color

	local from = Move.getFrom(move)
	local to = Move.getTo(move)
	local piece_type = Move.getPieceType(move)
	local captured = Move.getCaptured(move)
	local en_passant = Move.getEnPassant(move)
	local promotion = Move.getPromotion(move)
	local castling, kingside = Move.getCastling(move)

	local captured_piece = nil
	if captured then
		captured_piece = get_captured_piece(board, to, en_passant, color)
	end

	local record: UndoRecord = {
		move = move,
		captured_piece = captured_piece,
		castling_rights = board.castling_rights,
		en_passant_square = board.en_passant_square,
		halfmove_clock = board.halfmove_clock,
		fullmove_number = board.fullmove_number,
		additionallyMoved = nil,
	}

	clear_from_square(board, color, piece_type, from)

	-- Place basic piece (promotion handled later)
	board.pieceTable[to] = make_pair(piece_type, color)

	local additionallyMoved = nil
	if captured then
		additionallyMoved = handle_capture(board, opponent, to, en_passant, color)
	end

	local final_piece_type = promotion or piece_type
	place_on_square(board, color, final_piece_type, to)

	update_halfmove_clock(board, piece_type, captured)
	update_en_passant_square(board, piece_type, color, from, to)
	update_castling_rights_for_move(board, piece_type, color, from, to, captured)

	if castling then
		additionallyMoved = handle_castling_rook_move(board, color, kingside)
	end

	update_occupied_for_basic_move(board, color, from, to)

	board.side_to_move = opponent
	if color == BLACK then
		board.fullmove_number += 1
	end

	if additionallyMoved then
		record.additionallyMoved = additionallyMoved
	end

	return record
end

local function undo_move(board: Board, record: UndoRecord)
	local move = record.move
	local from = Move.getFrom(move)
	local to = Move.getTo(move)
	local piece_type = Move.getPieceType(move)
	local promotion = Move.getPromotion(move)

	local color = 1 - board.side_to_move

	board.side_to_move = color
	board.castling_rights = record.castling_rights
	board.en_passant_square = record.en_passant_square
	board.halfmove_clock = record.halfmove_clock
	board.fullmove_number = record.fullmove_number

	local final_piece_type = promotion or piece_type
	board.pieces[color][final_piece_type] = Utils.clear_bit(board.pieces[color][final_piece_type], to)
	board.pieceTable[to] = nil

	board.pieces[color][piece_type] = Utils.set_bit(board.pieces[color][piece_type], from)
	board.pieceTable[from] = make_pair(piece_type, color)

	board.occupied.all = Utils.clear_bit(board.occupied.all, to)
	board.occupied[color] = Utils.clear_bit(board.occupied[color], to)

	board.occupied.all = Utils.set_bit(board.occupied.all, from)
	board.occupied[color] = Utils.set_bit(board.occupied[color], from)

	if record.captured_piece then
		restore_captured_piece(board, record.captured_piece)
	end

	if record.additionallyMoved and #record.additionallyMoved == 2 then
		local rook_from = record.additionallyMoved[1]
		local rook_to = record.additionallyMoved[2]
		undo_castling_rook(board, color, rook_from, rook_to)
	end
end

return {
	make_move = make_move,
	undo_move = undo_move,
}

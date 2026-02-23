--!native
--!optimize 2
--!strict

local Utils = require("./utils")
local Move = require("./move").Move
local Eval = require("./eval")
local Zobrist = require("./zobrist")
local toggle_piece = Zobrist.toggle_piece
local toggle_castling = Zobrist.toggle_castling
local toggle_en_passant = Zobrist.toggle_en_passant
local toggle_side = Zobrist.toggle_side

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local make_pair, split_pair = Utils.make_pair, Utils.split_pair
local pstForColor = Eval.pstForColor
local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

export type Board = Utils.Board

export type UndoRecord = number

local MAX_UNDO = 16

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

local function eval_delta_for_move(
	color: number,
	from: number,
	to: number,
	piece_type: number,
	promotion: number?,
	captured_piece: number?,
	rook_pair_packed: number?
): number
	local final_piece_type = promotion or piece_type
	local delta = pstForColor[color][final_piece_type][to] - pstForColor[color][piece_type][from]

	if captured_piece then
		local cap_type, cap_color, cap_square = unpack_captured_piece(captured_piece)
		delta -= pstForColor[cap_color][cap_type][cap_square]
	end

	if rook_pair_packed then
		local rook_from, rook_to = split_pair(rook_pair_packed)
		delta += pstForColor[color][ROOK][rook_to] - pstForColor[color][ROOK][rook_from]
	end

	return delta
end

local CAPTURED_SENTINEL = 0x3FF
local ROOK_PAIR_SENTINEL = 0xFFF

local undo_top = 0
local undo_captured: { number } = table.create(MAX_UNDO)
local undo_castling: { number } = table.create(MAX_UNDO)
local undo_ep: { number } = table.create(MAX_UNDO)
local undo_halfmove: { number } = table.create(MAX_UNDO)
local undo_fullmove: { number } = table.create(MAX_UNDO)
local undo_rook_pair: { number } = table.create(MAX_UNDO)

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

local function make_move(board: Board, move: number): UndoRecord
	local color = board.side_to_move
	local opponent = 1 - color

	if board.eval == nil then
		board.eval = Eval.evaluate(board)
	end
	if board.hash == nil then
		board.hash = Zobrist.hash(board)
	end
	local hash = board.hash
	local old_castling = board.castling_rights
	local old_ep = board.en_passant_square

	local from = Move.getFrom(move)
	local to = Move.getTo(move)
	local piece_type = Move.getPieceType(move)
	local captured = Move.getCaptured(move)
	local en_passant = Move.getEnPassant(move)
	local promotion = Move.getPromotion(move)
	local castling, kingside = Move.getCastling(move)

	local captured_piece = nil
	if captured then
		local captured_square = to
		if en_passant then
			captured_square = to - (if color == WHITE then 8 else -8)
		end

		local captured_info = board.pieceTable[captured_square]
		if captured_info then
			local cap_type, cap_color = split_pair(captured_info)
			captured_piece = pack_captured_piece(cap_type, cap_color, captured_square)
		end
	end

	-- Save pre-move state
	undo_top += 1
	if undo_top > MAX_UNDO then
		undo_top = MAX_UNDO
	end
	local idx = undo_top
	local rook_pair_packed: number? = nil

	undo_castling[idx] = board.castling_rights
	undo_ep[idx] = board.en_passant_square or -1
	undo_halfmove[idx] = board.halfmove_clock
	undo_fullmove[idx] = board.fullmove_number

	undo_castling[idx] = board.castling_rights
	undo_ep[idx] = board.en_passant_square or -1
	undo_halfmove[idx] = board.halfmove_clock
	undo_fullmove[idx] = board.fullmove_number

	board.pieces[color][piece_type] = Utils.clear_bit(board.pieces[color][piece_type], from)
	board.pieceTable[from] = nil



	if captured then
		for p = PAWN, KING do
			if Utils.get_bit(board.pieces[opponent][p], to) then
				board.pieces[opponent][p] = Utils.clear_bit(board.pieces[opponent][p], to)
				board.occupied.all = Utils.clear_bit(board.occupied.all, to)
				board.occupied[opponent] = Utils.clear_bit(board.occupied[opponent], to)
				break
			end
		end

		if en_passant then
			local captured_pawn_square = to - (if color == WHITE then 8 else -8)
			board.pieces[opponent][PAWN] = Utils.clear_bit(board.pieces[opponent][PAWN], captured_pawn_square)
			board.pieceTable[captured_pawn_square] = nil

			board.occupied.all = Utils.clear_bit(board.occupied.all, captured_pawn_square)
			board.occupied[opponent] = Utils.clear_bit(board.occupied[opponent], captured_pawn_square)
		end
	end

	local final_piece_type = promotion or piece_type
	board.pieces[color][final_piece_type] = Utils.set_bit(board.pieces[color][final_piece_type], to)
	board.pieceTable[to] = make_pair(final_piece_type, color)

	if captured or piece_type == PAWN then
		board.halfmove_clock = 0
	else
		board.halfmove_clock += 1
	end

	board.en_passant_square = nil
	if piece_type == PAWN then
		local move_distance = math.abs(to - from)
		if move_distance == 16 then
			board.en_passant_square = if color == WHITE then (from + 8) else (from - 8)
		end
	end

	update_castling_rights_for_move(board, piece_type, color, from, to, captured)

	if castling then
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

		rook_pair_packed = make_pair(rook_from, rook_to)
	end

	hash = toggle_piece(hash, color, piece_type, from)
	hash = toggle_piece(hash, color, final_piece_type, to)
	if captured_piece then
		local cap_type, cap_color, cap_square = unpack_captured_piece(captured_piece)
		hash = toggle_piece(hash, cap_color, cap_type, cap_square)
	end
	if rook_pair_packed then
		local rook_from, rook_to = split_pair(rook_pair_packed)
		hash = toggle_piece(hash, color, ROOK, rook_from)
		hash = toggle_piece(hash, color, ROOK, rook_to)
	end
	if old_ep then
		hash = toggle_en_passant(hash, old_ep % 8)
	end
	if board.en_passant_square then
		hash = toggle_en_passant(hash, board.en_passant_square % 8)
	end
	if Utils.get_bit32(old_castling, WK) ~= Utils.get_bit32(board.castling_rights, WK) then
		hash = toggle_castling(hash, 1)
	end
	if Utils.get_bit32(old_castling, WQ) ~= Utils.get_bit32(board.castling_rights, WQ) then
		hash = toggle_castling(hash, 2)
	end
	if Utils.get_bit32(old_castling, BK) ~= Utils.get_bit32(board.castling_rights, BK) then
		hash = toggle_castling(hash, 3)
	end
	if Utils.get_bit32(old_castling, BQ) ~= Utils.get_bit32(board.castling_rights, BQ) then
		hash = toggle_castling(hash, 4)
	end
	hash = toggle_side(hash)
	board.hash = hash

	local delta = eval_delta_for_move(color, from, to, piece_type, promotion, captured_piece, rook_pair_packed)
	board.eval += delta

	undo_captured[idx] = captured_piece or CAPTURED_SENTINEL
	undo_rook_pair[idx] = rook_pair_packed or ROOK_PAIR_SENTINEL

	local occupied = board.occupied
	occupied.all = Utils.clear_bit(occupied.all, from)
	occupied.all = Utils.set_bit(occupied.all, to)

	occupied[color] = Utils.clear_bit(occupied[color], from)
	occupied[color] = Utils.set_bit(occupied[color], to)

	board.side_to_move = opponent
	if color == BLACK then
		board.fullmove_number += 1
	end

	return idx
end

local function undo_move(board: Board, move: number, record: UndoRecord?)
	local idx = record or undo_top
	if idx <= 0 then
		return
	end

	local from = Move.getFrom(move)
	local to = Move.getTo(move)
	local piece_type = Move.getPieceType(move)
	local promotion = Move.getPromotion(move)

	local color = 1 - board.side_to_move

	board.side_to_move = color

	local packed_captured = undo_captured[idx]
	local packed_rook_pair = undo_rook_pair[idx]

	local current_castling = board.castling_rights
	local current_ep = board.en_passant_square
	if board.hash == nil then
		board.hash = Zobrist.hash(board)
	end
	local hash = board.hash

	local castling_rights = undo_castling[idx]
	local ep_raw = undo_ep[idx]
	local en_passant_square = if ep_raw >= 0 then ep_raw else nil
	local halfmove_clock = undo_halfmove[idx]
	local fullmove_number = undo_fullmove[idx]

	if current_ep then
		hash = toggle_en_passant(hash, current_ep % 8)
	end
	if en_passant_square then
		hash = toggle_en_passant(hash, en_passant_square % 8)
	end
	if Utils.get_bit32(current_castling, WK) ~= Utils.get_bit32(castling_rights, WK) then
		hash = toggle_castling(hash, 1)
	end
	if Utils.get_bit32(current_castling, WQ) ~= Utils.get_bit32(castling_rights, WQ) then
		hash = toggle_castling(hash, 2)
	end
	if Utils.get_bit32(current_castling, BK) ~= Utils.get_bit32(castling_rights, BK) then
		hash = toggle_castling(hash, 3)
	end
	if Utils.get_bit32(current_castling, BQ) ~= Utils.get_bit32(castling_rights, BQ) then
		hash = toggle_castling(hash, 4)
	end

	board.castling_rights = castling_rights
	board.en_passant_square = en_passant_square
	board.halfmove_clock = halfmove_clock
	board.fullmove_number = fullmove_number

	local captured_piece = if packed_captured ~= CAPTURED_SENTINEL then packed_captured else nil
	local rook_pair = if packed_rook_pair ~= ROOK_PAIR_SENTINEL then packed_rook_pair else nil
	if board.eval == nil then
		board.eval = Eval.evaluate(board)
	end
	local delta = eval_delta_for_move(color, from, to, piece_type, promotion, captured_piece, rook_pair)
	board.eval -= delta

	local final_piece_type = promotion or piece_type

	hash = toggle_piece(hash, color, final_piece_type, to)
	hash = toggle_piece(hash, color, piece_type, from)
	if captured_piece then
		local cap_type, cap_color, cap_square = unpack_captured_piece(captured_piece)
		hash = toggle_piece(hash, cap_color, cap_type, cap_square)
	end
	if rook_pair then
		local rook_from, rook_to = split_pair(rook_pair)
		hash = toggle_piece(hash, color, ROOK, rook_to)
		hash = toggle_piece(hash, color, ROOK, rook_from)
	end
	hash = toggle_side(hash)
	board.hash = hash

	board.pieces[color][final_piece_type] = Utils.clear_bit(board.pieces[color][final_piece_type], to)
	board.pieceTable[to] = nil

	board.pieces[color][piece_type] = Utils.set_bit(board.pieces[color][piece_type], from)
	board.pieceTable[from] = make_pair(piece_type, color)

	board.occupied.all = Utils.clear_bit(board.occupied.all, to)
	board.occupied[color] = Utils.clear_bit(board.occupied[color], to)

	board.occupied.all = Utils.set_bit(board.occupied.all, from)
	board.occupied[color] = Utils.set_bit(board.occupied[color], from)

	if packed_captured ~= CAPTURED_SENTINEL then
		local cap_type, cap_color, square = unpack_captured_piece(packed_captured)

		board.pieces[cap_color][cap_type] = Utils.set_bit(board.pieces[cap_color][cap_type], square)
		board.pieceTable[square] = make_pair(cap_type, cap_color)

		board.occupied.all = Utils.set_bit(board.occupied.all, square)
		board.occupied[cap_color] = Utils.set_bit(board.occupied[cap_color], square)
	end

	if packed_rook_pair ~= ROOK_PAIR_SENTINEL then
		local rook_from, rook_to = split_pair(packed_rook_pair)

		board.pieces[color][ROOK] = Utils.clear_bit(board.pieces[color][ROOK], rook_to)
		board.pieces[color][ROOK] = Utils.set_bit(board.pieces[color][ROOK], rook_from)

		board.pieceTable[rook_to] = nil
		board.pieceTable[rook_from] = make_pair(ROOK, color)

		board.occupied.all = Utils.clear_bit(board.occupied.all, rook_to)
		board.occupied[color] = Utils.clear_bit(board.occupied[color], rook_to)

		board.occupied.all = Utils.set_bit(board.occupied.all, rook_from)
		board.occupied[color] = Utils.set_bit(board.occupied[color], rook_from)
	end

	undo_top = idx - 1
end

local function get_undo_record_data(record: UndoRecord)
	local idx = record
	local captured_piece = undo_captured[idx]
	local rook_pair = undo_rook_pair[idx]

	local castling_rights = undo_castling[idx]
	local ep_raw = undo_ep[idx]
	local en_passant_square = if ep_raw >= 0 then ep_raw else nil
	local halfmove_clock = undo_halfmove[idx]
	local fullmove_number = undo_fullmove[idx]

	return {
		captured_piece = if captured_piece == CAPTURED_SENTINEL then nil else captured_piece,
		castling_rights = castling_rights,
		en_passant_square = en_passant_square,
		halfmove_clock = halfmove_clock,
		fullmove_number = fullmove_number,
		additionallyMoved = if rook_pair ~= ROOK_PAIR_SENTINEL then { split_pair(rook_pair) } else nil,
	}
end

return {
	make_move = make_move,
	undo_move = undo_move,
	get_undo_record_data = get_undo_record_data,
}

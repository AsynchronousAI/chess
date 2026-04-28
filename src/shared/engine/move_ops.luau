--!native
--!optimize 2
--!strict
local Utils   = require("./utils")
local Move    = require("./move").Move
local Eval    = require("./eval")
local Zobrist = require("./zobrist")
local toggle_piece      = Zobrist.toggle_piece
local toggle_castling   = Zobrist.toggle_castling
local toggle_en_passant = Zobrist.toggle_en_passant
local toggle_side       = Zobrist.toggle_side

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local ALL = Utils.ALL
local make_pair_32, split_pair_32 = Utils.make_pair_32, Utils.split_pair_32

local BB_PIECE_STRIDE = Utils.PIECE_STRIDE  -- 6: flat index = color * 6 + piece

local PST          = Eval.PST
local COLOR_STRIDE = Eval.COLOR_STRIDE
local PIECE_STRIDE = Eval.PIECE_STRIDE

local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

local WK_MASK = bit32.lshift(1, WK)
local WQ_MASK = bit32.lshift(1, WQ)
local BK_MASK = bit32.lshift(1, BK)
local BQ_MASK = bit32.lshift(1, BQ)

export type Board = Utils.Board
export type UndoRecord = number

local MAX_UNDO = 256

local CAPTURED_SQUARE_MASK = 0x3F
local CAPTURED_TYPE_SHIFT  = 6
local CAPTURED_COLOR_SHIFT = 9

local function unpack_captured_piece(packed: number)
	local square    = bit32.band(packed, CAPTURED_SQUARE_MASK)
	local cap_type  = bit32.band(bit32.rshift(packed, CAPTURED_TYPE_SHIFT), 0x7)
	local cap_color = bit32.band(bit32.rshift(packed, CAPTURED_COLOR_SHIFT), 0x1)
	return cap_type, cap_color, square
end

local CAPTURED_SENTINEL  = 0x3FF
local ROOK_PAIR_SENTINEL = 0xFFF

local undo_top = 0
local undo_captured:  {number} = table.create(MAX_UNDO)
local undo_castling:  {number} = table.create(MAX_UNDO)
local undo_ep:        {number} = table.create(MAX_UNDO)
local undo_halfmove:  {number} = table.create(MAX_UNDO)
local undo_fullmove:  {number} = table.create(MAX_UNDO)
local undo_rook_pair: {number} = table.create(MAX_UNDO)
local undo_eval:      {number} = table.create(MAX_UNDO)
local undo_hash:      {number} = table.create(MAX_UNDO)

local function make_move(board: Board, move: number): UndoRecord
	local color    = board.side_to_move
	local opponent = 1 - color

	local hash         = board.hash :: number
	local old_castling = board.castling_rights
	local old_ep       = board.en_passant_square

	local from         = bit32.band(move, 0x3F)
	local to           = bit32.band(bit32.rshift(move, 6), 0x3F)
	local piece_type   = bit32.band(bit32.rshift(move, 12), 0x7)
	local captured     = bit32.band(move, 0x8000) ~= 0
	local en_passant   = bit32.band(move, 0x80000) ~= 0
	local promo_raw    = bit32.band(bit32.rshift(move, 16), 0x7)
	local promotion    = if promo_raw == 5 then nil else promo_raw
	local castle_code  = bit32.band(bit32.rshift(move, 20), 0x3)
	local castling     = castle_code ~= 0
	local kingside     = castle_code == 1

	undo_top += 1
	local idx = undo_top
	undo_castling[idx] = old_castling
	undo_ep[idx]       = old_ep or -1
	undo_halfmove[idx] = board.halfmove_clock
	undo_fullmove[idx] = board.fullmove_number
	undo_eval[idx]     = board.eval :: number
	undo_hash[idx]     = hash

	local pieces = board.pieces
	local occ    = board.occupied
	local color_base = color    * BB_PIECE_STRIDE
	local opp_base   = opponent * BB_PIECE_STRIDE

	local captured_piece = CAPTURED_SENTINEL
	if captured then
		if en_passant then
			local cap_sq = if color == WHITE then to - 8 else to + 8
			local cap_info = board.pieceTable[cap_sq]
			if cap_info then
				local ct = bit32.rshift(cap_info, 6)
				local cc = bit32.band(cap_info, 0x3F)
				captured_piece = bit32.bor(
					bit32.band(cap_sq, CAPTURED_SQUARE_MASK),
					bit32.lshift(bit32.band(ct, 0x7), CAPTURED_TYPE_SHIFT),
					bit32.lshift(bit32.band(cc, 0x1), CAPTURED_COLOR_SHIFT)
				)
				pieces[opp_base + PAWN] = Utils.clear_bit(pieces[opp_base + PAWN], cap_sq)
				board.pieceTable[cap_sq] = nil
				occ[ALL]      = Utils.clear_bit(occ[ALL], cap_sq)
				occ[opponent] = Utils.clear_bit(occ[opponent], cap_sq)
			end
		else
			local cap_info = board.pieceTable[to]
			if cap_info then
				local ct = bit32.rshift(cap_info, 6)
				local cc = bit32.band(cap_info, 0x3F)
				captured_piece = bit32.bor(
					bit32.band(to, CAPTURED_SQUARE_MASK),
					bit32.lshift(bit32.band(ct, 0x7), CAPTURED_TYPE_SHIFT),
					bit32.lshift(bit32.band(cc, 0x1), CAPTURED_COLOR_SHIFT)
				)
				local cap_idx = cc * BB_PIECE_STRIDE + ct
				pieces[cap_idx] = Utils.clear_bit(pieces[cap_idx], to)
				occ[ALL]        = Utils.clear_bit(occ[ALL], to)
				occ[opponent]   = Utils.clear_bit(occ[opponent], to)
			end
		end
	end

	local final_piece_type = promotion or piece_type
	pieces[color_base + piece_type] = Utils.clear_bit(pieces[color_base + piece_type], from)
	board.pieceTable[from] = nil
	pieces[color_base + final_piece_type] = Utils.set_bit(pieces[color_base + final_piece_type], to)
	board.pieceTable[to] = make_pair_32(final_piece_type, color)

	occ[ALL]   = Utils.clear_bit(occ[ALL], from)
	occ[ALL]   = Utils.set_bit(occ[ALL], to)
	occ[color] = Utils.clear_bit(occ[color], from)
	occ[color] = Utils.set_bit(occ[color], to)

	board.halfmove_clock = if (captured or piece_type == PAWN) then 0 else board.halfmove_clock + 1

	board.en_passant_square = nil
	if piece_type == PAWN then
		if color == WHITE then
			if to - from == 16 then board.en_passant_square = from + 8 end
		else
			if from - to == 16 then board.en_passant_square = from - 8 end
		end
	end

	local new_castling = old_castling
	if piece_type == KING then
		new_castling = if color == WHITE
			then bit32.band(new_castling, bit32.bnot(bit32.bor(WK_MASK, WQ_MASK)))
			else bit32.band(new_castling, bit32.bnot(bit32.bor(BK_MASK, BQ_MASK)))
	elseif piece_type == ROOK then
		if color == WHITE then
			if     from == 0 then new_castling = bit32.band(new_castling, bit32.bnot(WQ_MASK))
			elseif from == 7 then new_castling = bit32.band(new_castling, bit32.bnot(WK_MASK)) end
		else
			if     from == 56 then new_castling = bit32.band(new_castling, bit32.bnot(BQ_MASK))
			elseif from == 63 then new_castling = bit32.band(new_castling, bit32.bnot(BK_MASK)) end
		end
	end
	if captured then
		if     to == 0  then new_castling = bit32.band(new_castling, bit32.bnot(WQ_MASK))
		elseif to == 7  then new_castling = bit32.band(new_castling, bit32.bnot(WK_MASK))
		elseif to == 56 then new_castling = bit32.band(new_castling, bit32.bnot(BQ_MASK))
		elseif to == 63 then new_castling = bit32.band(new_castling, bit32.bnot(BK_MASK)) end
	end
	board.castling_rights = new_castling

	local rook_pair_packed = ROOK_PAIR_SENTINEL
	if castling then
		local rook_from: number
		local rook_to: number
		if kingside then
			rook_from = if color == WHITE then 7  else 63
			rook_to   = if color == WHITE then 5  else 61
		else
			rook_from = if color == WHITE then 0  else 56
			rook_to   = if color == WHITE then 3  else 59
		end
		pieces[color_base + ROOK] = Utils.clear_bit(pieces[color_base + ROOK], rook_from)
		pieces[color_base + ROOK] = Utils.set_bit(pieces[color_base + ROOK], rook_to)
		board.pieceTable[rook_from] = nil
		board.pieceTable[rook_to]   = make_pair_32(ROOK, color)
		occ[ALL]   = Utils.clear_bit(occ[ALL], rook_from)
		occ[ALL]   = Utils.set_bit(occ[ALL], rook_to)
		occ[color] = Utils.clear_bit(occ[color], rook_from)
		occ[color] = Utils.set_bit(occ[color], rook_to)
		rook_pair_packed = make_pair_32(rook_from, rook_to)
	end

	-- Hash update
	hash = toggle_piece(hash, color, piece_type, from)
	hash = toggle_piece(hash, color, final_piece_type, to)
	if captured_piece ~= CAPTURED_SENTINEL then
		local ct, cc, csq = unpack_captured_piece(captured_piece)
		hash = toggle_piece(hash, cc, ct, csq)
	end
	if rook_pair_packed ~= ROOK_PAIR_SENTINEL then
		local rook_from, rook_to = split_pair_32(rook_pair_packed)
		hash = toggle_piece(hash, color, ROOK, rook_from)
		hash = toggle_piece(hash, color, ROOK, rook_to)
	end
	if old_ep then
		hash = toggle_en_passant(hash, bit32.band(old_ep, 7))
	end
	if board.en_passant_square then
		hash = toggle_en_passant(hash, bit32.band(board.en_passant_square, 7))
	end
	local castling_diff = bit32.bxor(old_castling, new_castling)
	if bit32.band(castling_diff, WK_MASK) ~= 0 then hash = toggle_castling(hash, 1) end
	if bit32.band(castling_diff, WQ_MASK) ~= 0 then hash = toggle_castling(hash, 2) end
	if bit32.band(castling_diff, BK_MASK) ~= 0 then hash = toggle_castling(hash, 3) end
	if bit32.band(castling_diff, BQ_MASK) ~= 0 then hash = toggle_castling(hash, 4) end
	hash = toggle_side(hash)
	board.hash = hash

	-- Eval update
	local color_eval_base = color * COLOR_STRIDE
	local delta = PST[color_eval_base + final_piece_type * PIECE_STRIDE + to]
	            - PST[color_eval_base + piece_type       * PIECE_STRIDE + from]
	if captured_piece ~= CAPTURED_SENTINEL then
		local ct, cc, csq = unpack_captured_piece(captured_piece)
		delta -= PST[cc * COLOR_STRIDE + ct * PIECE_STRIDE + csq]
	end
	if rook_pair_packed ~= ROOK_PAIR_SENTINEL then
		local rook_from, rook_to = split_pair_32(rook_pair_packed)
		delta += PST[color_eval_base + ROOK * PIECE_STRIDE + rook_to]
		       - PST[color_eval_base + ROOK * PIECE_STRIDE + rook_from]
	end
	board.eval = (board.eval :: number) + delta

	undo_captured[idx]  = captured_piece
	undo_rook_pair[idx] = rook_pair_packed

	board.side_to_move = opponent
	if color == BLACK then board.fullmove_number += 1 end

	return idx
end

local function undo_move(board: Board, move: number, record: UndoRecord?)
	local idx = record or undo_top
	if idx <= 0 then return end

	local from         = bit32.band(move, 0x3F)
	local to           = bit32.band(bit32.rshift(move, 6), 0x3F)
	local piece_type   = bit32.band(bit32.rshift(move, 12), 0x7)
	local promo_raw    = bit32.band(bit32.rshift(move, 16), 0x7)
	local promotion    = if promo_raw == 5 then nil else promo_raw

	local color = 1 - board.side_to_move
	board.side_to_move = color

	local packed_captured  = undo_captured[idx]
	local packed_rook_pair = undo_rook_pair[idx]
	local has_capture      = packed_captured ~= CAPTURED_SENTINEL
	local has_rook         = packed_rook_pair ~= ROOK_PAIR_SENTINEL

	board.eval           = undo_eval[idx]
	board.hash           = undo_hash[idx]
	board.castling_rights   = undo_castling[idx]
	local ep_raw            = undo_ep[idx]
	board.en_passant_square = if ep_raw >= 0 then ep_raw else nil
	board.halfmove_clock    = undo_halfmove[idx]
	board.fullmove_number   = undo_fullmove[idx]

	local cap_type: number, cap_color: number, cap_sq: number
	if has_capture then
		cap_type, cap_color, cap_sq = unpack_captured_piece(packed_captured)
	end
	local rook_from: number, rook_to: number
	if has_rook then
		rook_from, rook_to = split_pair_32(packed_rook_pair)
	end

	local final_piece_type = promotion or piece_type

	local pieces = board.pieces
	local occ    = board.occupied
	local color_base = color * BB_PIECE_STRIDE

	pieces[color_base + final_piece_type] = Utils.clear_bit(pieces[color_base + final_piece_type], to)
	board.pieceTable[to] = nil
	pieces[color_base + piece_type] = Utils.set_bit(pieces[color_base + piece_type], from)
	board.pieceTable[from] = make_pair_32(piece_type, color)
	occ[ALL]   = Utils.clear_bit(occ[ALL], to)
	occ[ALL]   = Utils.set_bit(occ[ALL], from)
	occ[color] = Utils.clear_bit(occ[color], to)
	occ[color] = Utils.set_bit(occ[color], from)

	if has_capture then
		local cap_idx = cap_color * BB_PIECE_STRIDE + cap_type
		pieces[cap_idx] = Utils.set_bit(pieces[cap_idx], cap_sq)
		board.pieceTable[cap_sq] = make_pair_32(cap_type, cap_color)
		occ[ALL]       = Utils.set_bit(occ[ALL], cap_sq)
		occ[cap_color] = Utils.set_bit(occ[cap_color], cap_sq)
	end

	if has_rook then
		pieces[color_base + ROOK] = Utils.clear_bit(pieces[color_base + ROOK], rook_to)
		pieces[color_base + ROOK] = Utils.set_bit(pieces[color_base + ROOK], rook_from)
		board.pieceTable[rook_to]   = nil
		board.pieceTable[rook_from] = make_pair_32(ROOK, color)
		occ[ALL]   = Utils.clear_bit(occ[ALL], rook_to)
		occ[ALL]   = Utils.set_bit(occ[ALL], rook_from)
		occ[color] = Utils.clear_bit(occ[color], rook_to)
		occ[color] = Utils.set_bit(occ[color], rook_from)
	end

	undo_top = idx - 1
end

local function get_undo_record_data(record: UndoRecord)
	local idx            = record
	local captured_piece = undo_captured[idx]
	local rook_pair      = undo_rook_pair[idx]
	local ep_raw         = undo_ep[idx]
	return {
		captured_piece    = if captured_piece == CAPTURED_SENTINEL then nil else captured_piece,
		castling_rights   = undo_castling[idx],
		en_passant_square = if ep_raw >= 0 then ep_raw else nil,
		halfmove_clock    = undo_halfmove[idx],
		fullmove_number   = undo_fullmove[idx],
		additionallyMoved = if rook_pair ~= ROOK_PAIR_SENTINEL then { split_pair_32(rook_pair) } else nil,
	}
end

return {
	make_move            = make_move,
	undo_move            = undo_move,
	get_undo_record_data = get_undo_record_data,
}

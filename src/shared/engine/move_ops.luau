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
local clear_bit, set_bit = Utils.clear_bit, Utils.set_bit
local pstForColor = Eval.pstForColor
local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

-- Pre-baked single-bit masks for castling rights — avoids get_bit32 on every move
local WK_MASK = bit32.lshift(1, WK) -- 0x1
local WQ_MASK = bit32.lshift(1, WQ) -- 0x2
local BK_MASK = bit32.lshift(1, BK) -- 0x4
local BQ_MASK = bit32.lshift(1, BQ) -- 0x8

export type Board = Utils.Board
export type UndoRecord = number

local MAX_UNDO = 256

-- captured_piece packing layout: bits[5:0]=square, bits[8:6]=type, bits[9]=color
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
local undo_captured:  { number } = table.create(MAX_UNDO)
local undo_castling:  { number } = table.create(MAX_UNDO)
local undo_ep:        { number } = table.create(MAX_UNDO)
local undo_halfmove:  { number } = table.create(MAX_UNDO)
local undo_fullmove:  { number } = table.create(MAX_UNDO)
local undo_rook_pair: { number } = table.create(MAX_UNDO)

local function make_move(board: Board, move: number): UndoRecord
	local color    = board.side_to_move
	local opponent = 1 - color

	if board.eval == nil then board.eval = Eval.evaluate(board) end
	if board.hash == nil then board.hash = Zobrist.hash(board) end
	local hash         = board.hash :: number
	local old_castling = board.castling_rights
	local old_ep       = board.en_passant_square

	-- Decode all move fields in one inline pass — avoids 7 individual getter calls
	-- Bit layout: from[5:0] | to[11:6] | piece[14:12] | cap[15] | promo[18:16] | ep[19] | castle[21:20]
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

	-- Save pre-move state to undo stack
	undo_top += 1
	local idx = undo_top
	undo_castling[idx] = old_castling
	undo_ep[idx]       = old_ep or -1
	undo_halfmove[idx] = board.halfmove_clock
	undo_fullmove[idx] = board.fullmove_number

	-- Resolve captured piece via pieceTable (O(1)) and remove it from board
	-- Avoids both the old 6-bitboard scan AND the split_pair+repack round-trip:
	-- pieceTable stores (type<<6|color), and our packing is (sq | type<<6 | color<<9),
	-- so we extract the two fields with rshift/band and build the packed int directly.
	local captured_piece = CAPTURED_SENTINEL
	if captured then
		if en_passant then
			local cap_sq   = if color == WHITE then to - 8 else to + 8
			local cap_info = board.pieceTable[cap_sq]
			if cap_info then
				local ct = bit32.rshift(cap_info, 6)
				local cc = bit32.band(cap_info, 0x3F)
				captured_piece = bit32.bor(
					bit32.band(cap_sq, CAPTURED_SQUARE_MASK),
					bit32.lshift(bit32.band(ct, 0x7), CAPTURED_TYPE_SHIFT),
					bit32.lshift(bit32.band(cc, 0x1), CAPTURED_COLOR_SHIFT)
				)
				board.pieces[opponent][PAWN] = clear_bit(board.pieces[opponent][PAWN], cap_sq)
				board.pieceTable[cap_sq]     = nil
				board.occupied.all           = clear_bit(board.occupied.all, cap_sq)
				board.occupied[opponent]     = clear_bit(board.occupied[opponent], cap_sq)
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
				board.pieces[cc][ct]     = clear_bit(board.pieces[cc][ct], to)
				board.occupied.all       = clear_bit(board.occupied.all, to)
				board.occupied[opponent] = clear_bit(board.occupied[opponent], to)
			end
		end
	end

	-- Move the piece on bitboards and pieceTable
	local pieces_color     = board.pieces[color]
	local final_piece_type = promotion or piece_type
	pieces_color[piece_type]       = clear_bit(pieces_color[piece_type], from)
	board.pieceTable[from]         = nil
	pieces_color[final_piece_type] = set_bit(pieces_color[final_piece_type], to)
	board.pieceTable[to]           = make_pair(final_piece_type, color)

	-- Update occupied for the moving piece (capture already cleared `to` above if needed)
	local occ  = board.occupied
	occ.all    = set_bit(clear_bit(occ.all, from), to)
	occ[color] = set_bit(clear_bit(occ[color], from), to)

	-- Halfmove clock
	board.halfmove_clock = if (captured or piece_type == PAWN) then 0 else board.halfmove_clock + 1

	-- En passant square: use signed delta instead of math.abs — avoids function call
	board.en_passant_square = nil
	if piece_type == PAWN then
		if color == WHITE then
			if to - from == 16 then board.en_passant_square = from + 8 end
		else
			if from - to == 16 then board.en_passant_square = from - 8 end
		end
	end

	-- Update castling rights (inlined — avoids out-of-line call and boolean param passing)
	-- Clear both king rights at once with a single band; rook moves clear one at a time
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

	-- Castling rook move
	local rook_pair_packed = ROOK_PAIR_SENTINEL
	if castling then
		local rook_from, rook_to
		if kingside then
			rook_from = if color == WHITE then 7  else 63
			rook_to   = if color == WHITE then 5  else 61
		else
			rook_from = if color == WHITE then 0  else 56
			rook_to   = if color == WHITE then 3  else 59
		end
		pieces_color[ROOK]          = set_bit(clear_bit(pieces_color[ROOK], rook_from), rook_to)
		board.pieceTable[rook_from] = nil
		board.pieceTable[rook_to]   = make_pair(ROOK, color)
		occ.all    = set_bit(clear_bit(occ.all, rook_from), rook_to)
		occ[color] = set_bit(clear_bit(occ[color], rook_from), rook_to)
		rook_pair_packed = make_pair(rook_from, rook_to)
	end

	-- Incremental hash update
	hash = toggle_piece(hash, color, piece_type, from)
	hash = toggle_piece(hash, color, final_piece_type, to)
	if captured_piece ~= CAPTURED_SENTINEL then
		local ct, cc, csq = unpack_captured_piece(captured_piece)
		hash = toggle_piece(hash, cc, ct, csq)
	end
	if rook_pair_packed ~= ROOK_PAIR_SENTINEL then
		local rook_from, rook_to = split_pair(rook_pair_packed)
		hash = toggle_piece(hash, color, ROOK, rook_from)
		hash = toggle_piece(hash, color, ROOK, rook_to)
	end
	if old_ep then
		hash = toggle_en_passant(hash, bit32.band(old_ep, 7))  -- file = sq & 7, avoids % 8
	end
	if board.en_passant_square then
		hash = toggle_en_passant(hash, bit32.band(board.en_passant_square, 7))
	end
	-- Single XOR diff to find changed castling bits — avoids 8 get_bit32 calls
	local castling_diff = bit32.bxor(old_castling, new_castling)
	if bit32.band(castling_diff, WK_MASK) ~= 0 then hash = toggle_castling(hash, 1) end
	if bit32.band(castling_diff, WQ_MASK) ~= 0 then hash = toggle_castling(hash, 2) end
	if bit32.band(castling_diff, BK_MASK) ~= 0 then hash = toggle_castling(hash, 3) end
	if bit32.band(castling_diff, BQ_MASK) ~= 0 then hash = toggle_castling(hash, 4) end
	hash = toggle_side(hash)
	board.hash = hash

	-- Incremental eval update (inlined — avoids out-of-line call, nil checks, re-unpack)
	local pst_color = pstForColor[color]
	local delta = pst_color[final_piece_type][to] - pst_color[piece_type][from]
	if captured_piece ~= CAPTURED_SENTINEL then
		local ct, cc, csq = unpack_captured_piece(captured_piece)
		delta -= pstForColor[cc][ct][csq]
	end
	if rook_pair_packed ~= ROOK_PAIR_SENTINEL then
		local rook_from, rook_to = split_pair(rook_pair_packed)
		delta += pst_color[ROOK][rook_to] - pst_color[ROOK][rook_from]
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

	-- Decode move fields inline — same pattern as make_move
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

	local current_castling = board.castling_rights
	local current_ep       = board.en_passant_square
	if board.hash == nil then board.hash = Zobrist.hash(board) end
	local hash = board.hash :: number

	local castling_rights   = undo_castling[idx]
	local ep_raw            = undo_ep[idx]
	local en_passant_square = if ep_raw >= 0 then ep_raw else nil

	-- Restore saved state
	board.castling_rights   = castling_rights
	board.en_passant_square = en_passant_square
	board.halfmove_clock    = undo_halfmove[idx]
	board.fullmove_number   = undo_fullmove[idx]

	-- Unpack captured and rook once — values reused for hash, eval, and board restoration
	local cap_type: number, cap_color: number, cap_sq: number
	if has_capture then
		cap_type, cap_color, cap_sq = unpack_captured_piece(packed_captured)
	end
	local rook_from: number, rook_to: number
	if has_rook then
		rook_from, rook_to = split_pair(packed_rook_pair)
	end

	local final_piece_type = promotion or piece_type

	-- Hash: undo EP, castling, and piece toggles
	if current_ep then
		hash = toggle_en_passant(hash, bit32.band(current_ep, 7))
	end
	if en_passant_square then
		hash = toggle_en_passant(hash, bit32.band(en_passant_square, 7))
	end
	local castling_diff = bit32.bxor(current_castling, castling_rights)
	if bit32.band(castling_diff, WK_MASK) ~= 0 then hash = toggle_castling(hash, 1) end
	if bit32.band(castling_diff, WQ_MASK) ~= 0 then hash = toggle_castling(hash, 2) end
	if bit32.band(castling_diff, BK_MASK) ~= 0 then hash = toggle_castling(hash, 3) end
	if bit32.band(castling_diff, BQ_MASK) ~= 0 then hash = toggle_castling(hash, 4) end
	hash = toggle_piece(hash, color, final_piece_type, to)
	hash = toggle_piece(hash, color, piece_type, from)
	if has_capture then
		hash = toggle_piece(hash, cap_color, cap_type, cap_sq)
	end
	if has_rook then
		hash = toggle_piece(hash, color, ROOK, rook_to)
		hash = toggle_piece(hash, color, ROOK, rook_from)
	end
	hash = toggle_side(hash)
	board.hash = hash

	-- Incremental eval (inlined — avoids out-of-line call and redundant unpack)
	if board.eval == nil then board.eval = Eval.evaluate(board) end
	local pst_color = pstForColor[color]
	local delta = pst_color[final_piece_type][to] - pst_color[piece_type][from]
	if has_capture then
		delta -= pstForColor[cap_color][cap_type][cap_sq]
	end
	if has_rook then
		delta += pst_color[ROOK][rook_to] - pst_color[ROOK][rook_from]
	end
	board.eval = (board.eval :: number) - delta

	-- Restore board structures
	local pieces_color = board.pieces[color]
	local occ          = board.occupied

	pieces_color[final_piece_type] = clear_bit(pieces_color[final_piece_type], to)
	board.pieceTable[to]           = nil
	pieces_color[piece_type]       = set_bit(pieces_color[piece_type], from)
	board.pieceTable[from]         = make_pair(piece_type, color)
	occ.all    = set_bit(clear_bit(occ.all, to), from)
	occ[color] = set_bit(clear_bit(occ[color], to), from)

	if has_capture then
		board.pieces[cap_color][cap_type] = set_bit(board.pieces[cap_color][cap_type], cap_sq)
		board.pieceTable[cap_sq]          = make_pair(cap_type, cap_color)
		occ.all        = set_bit(occ.all, cap_sq)
		occ[cap_color] = set_bit(occ[cap_color], cap_sq)
	end

	if has_rook then
		pieces_color[ROOK]          = set_bit(clear_bit(pieces_color[ROOK], rook_to), rook_from)
		board.pieceTable[rook_to]   = nil
		board.pieceTable[rook_from] = make_pair(ROOK, color)
		occ.all    = set_bit(clear_bit(occ.all, rook_to), rook_from)
		occ[color] = set_bit(clear_bit(occ[color], rook_to), rook_from)
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
		additionallyMoved = if rook_pair ~= ROOK_PAIR_SENTINEL then { split_pair(rook_pair) } else nil,
	}
end

return {
	make_move            = make_move,
	undo_move            = undo_move,
	get_undo_record_data = get_undo_record_data,
}

--!native
--!optimize 2
--!strict
local Utils   = require("./utils")
local Eval    = require("./eval")
local Zobrist = require("./zobrist")
local toggle_piece      = Zobrist.toggle_piece
local toggle_castling   = Zobrist.toggle_castling
local toggle_en_passant = Zobrist.toggle_en_passant
local toggle_side       = Zobrist.toggle_side

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local ALL = Utils.ALL
local make_pair, split_pair = Utils.make_pair, Utils.split_pair
local BIT_LO  = Utils.BIT_LO
local BIT_HI  = Utils.BIT_HI
local NBIT_LO = Utils.NBIT_LO
local NBIT_HI = Utils.NBIT_HI

local PST          = Eval.PST
local COLOR_STRIDE = Eval.COLOR_STRIDE
local PIECE_STRIDE = Eval.PIECE_STRIDE

local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

local WK_MASK = bit32.lshift(1, WK)
local WQ_MASK = bit32.lshift(1, WQ)
local BK_MASK = bit32.lshift(1, BK)
local BQ_MASK = bit32.lshift(1, BQ)

export type Board = Utils.Board
-- UndoRecord is now a 5-tuple of packed integers:
--   (r_state, captured_piece, rook_pair_packed, eval, hash)
--
-- r_state bit layout (fits in 34 bits, safe as Lua double integer):
--   bits  0– 3 : castling_rights  (4 bits)
--   bits  4–10 : ep_stored = (en_passant_square + 1), 0 means nil  (7 bits, values 0–64)
--   bits 11–17 : halfmove_clock   (7 bits, 0–100)
--   bits 18–33 : fullmove_number  (16 bits)
export type UndoRecord = number -- kept as a single number type alias for the primary return; callers receive all 5

local R_CASTLING_MASK    = 0xF
local R_EP_SHIFT         = 4
local R_EP_MASK          = 0x7F   -- 7 bits
local R_HALFMOVE_SHIFT   = 11
local R_HALFMOVE_MASK    = 0x7F   -- 7 bits
local R_FULLMOVE_SHIFT   = 18     -- remaining 16 bits

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

local function set_lo(tbl, key, sq: number)
	tbl[key] = bit32.bor(tbl[key], BIT_LO[sq])
end
local function set_hi(tbl, key, sq: number)
	tbl[key] = bit32.bor(tbl[key], BIT_HI[sq])
end
local function clr_lo(tbl, key, sq: number)
	tbl[key] = bit32.band(tbl[key], NBIT_LO[sq])
end
local function clr_hi(tbl, key, sq: number)
	tbl[key] = bit32.band(tbl[key], NBIT_HI[sq])
end

-- make_move returns 5 packed integers as a tuple:
--   r_state, captured_piece, rook_pair_packed, saved_eval, saved_hash
local function make_move(board: Board, move: number): (number, number, number, number, number)
	local color    = board.side_to_move
	local opponent = 1 - color

	if board.eval == nil then board.eval = Eval.evaluate(board) end
	if board.hash == nil then board.hash = Zobrist.hash(board) end
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

	-- Save state that will be needed for undo (caller holds these as locals)
	local saved_eval     = board.eval :: number
	local saved_hash     = hash
	local saved_halfmove = board.halfmove_clock
	local saved_fullmove = board.fullmove_number

	local pieces_lo = board.pieces_lo
	local pieces_hi = board.pieces_hi
	local occ_lo    = board.occupied_lo
	local occ_hi    = board.occupied_hi

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
				clr_lo(pieces_lo[opponent], PAWN, cap_sq)
				clr_hi(pieces_hi[opponent], PAWN, cap_sq)
				board.pieceTable[cap_sq] = nil
				clr_lo(occ_lo, ALL, cap_sq); clr_hi(occ_hi, ALL, cap_sq)
				clr_lo(occ_lo, opponent, cap_sq); clr_hi(occ_hi, opponent, cap_sq)
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
				clr_lo(pieces_lo[cc], ct, to); clr_hi(pieces_hi[cc], ct, to)
				clr_lo(occ_lo, ALL, to);       clr_hi(occ_hi, ALL, to)
				clr_lo(occ_lo, opponent, to);  clr_hi(occ_hi, opponent, to)
			end
		end
	end

	local final_piece_type = promotion or piece_type
	clr_lo(pieces_lo[color], piece_type, from); clr_hi(pieces_hi[color], piece_type, from)
	board.pieceTable[from] = nil
	set_lo(pieces_lo[color], final_piece_type, to); set_hi(pieces_hi[color], final_piece_type, to)
	board.pieceTable[to] = make_pair(final_piece_type, color)

	clr_lo(occ_lo, ALL, from);   clr_hi(occ_hi, ALL, from)
	set_lo(occ_lo, ALL, to);     set_hi(occ_hi, ALL, to)
	clr_lo(occ_lo, color, from); clr_hi(occ_hi, color, from)
	set_lo(occ_lo, color, to);   set_hi(occ_hi, color, to)

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
		clr_lo(pieces_lo[color], ROOK, rook_from); clr_hi(pieces_hi[color], ROOK, rook_from)
		set_lo(pieces_lo[color], ROOK, rook_to);   set_hi(pieces_hi[color], ROOK, rook_to)
		board.pieceTable[rook_from] = nil
		board.pieceTable[rook_to]   = make_pair(ROOK, color)
		clr_lo(occ_lo, ALL, rook_from); clr_hi(occ_hi, ALL, rook_from)
		set_lo(occ_lo, ALL, rook_to);   set_hi(occ_hi, ALL, rook_to)
		clr_lo(occ_lo, color, rook_from); clr_hi(occ_hi, color, rook_from)
		set_lo(occ_lo, color, rook_to);   set_hi(occ_hi, color, rook_to)
		rook_pair_packed = make_pair(rook_from, rook_to)
	end

	-- Hash update
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
	local color_base = color * COLOR_STRIDE
	local delta = PST[color_base + final_piece_type * PIECE_STRIDE + to]
	            - PST[color_base + piece_type       * PIECE_STRIDE + from]
	if captured_piece ~= CAPTURED_SENTINEL then
		local ct, cc, csq = unpack_captured_piece(captured_piece)
		delta -= PST[cc * COLOR_STRIDE + ct * PIECE_STRIDE + csq]
	end
	if rook_pair_packed ~= ROOK_PAIR_SENTINEL then
		local rook_from, rook_to = split_pair(rook_pair_packed)
		delta += PST[color_base + ROOK * PIECE_STRIDE + rook_to]
		       - PST[color_base + ROOK * PIECE_STRIDE + rook_from]
	end
	board.eval = (board.eval :: number) + delta

	board.side_to_move = opponent
	if color == BLACK then board.fullmove_number += 1 end

	-- Pack r_state: castling(4) | ep_stored(7) | halfmove(7) | fullmove(16)
	local ep_stored = if old_ep then old_ep + 1 else 0
	local r_state = bit32.bor(
		bit32.band(old_castling, R_CASTLING_MASK),
		bit32.lshift(bit32.band(ep_stored, R_EP_MASK), R_EP_SHIFT),
		bit32.lshift(bit32.band(saved_halfmove, R_HALFMOVE_MASK), R_HALFMOVE_SHIFT)
	) + saved_fullmove * (2 ^ R_FULLMOVE_SHIFT)

	return r_state, captured_piece, rook_pair_packed, saved_eval, saved_hash
end

-- undo_move accepts the 5 packed integers returned by make_move
local function undo_move(board: Board, move: number, r_state: number, captured_piece: number, rook_pair_packed: number, saved_eval: number, saved_hash: number)
	local from         = bit32.band(move, 0x3F)
	local to           = bit32.band(bit32.rshift(move, 6), 0x3F)
	local piece_type   = bit32.band(bit32.rshift(move, 12), 0x7)
	local promo_raw    = bit32.band(bit32.rshift(move, 16), 0x7)
	local promotion    = if promo_raw == 5 then nil else promo_raw

	local color = 1 - board.side_to_move
	board.side_to_move = color

	local has_capture = captured_piece ~= CAPTURED_SENTINEL
	local has_rook    = rook_pair_packed ~= ROOK_PAIR_SENTINEL

	-- Unpack r_state
	local old_castling = bit32.band(r_state, R_CASTLING_MASK)
	local ep_stored    = bit32.band(bit32.rshift(r_state, R_EP_SHIFT), R_EP_MASK)
	local old_halfmove = bit32.band(bit32.rshift(r_state, R_HALFMOVE_SHIFT), R_HALFMOVE_MASK)
	local old_fullmove = math.floor(r_state / (2 ^ R_FULLMOVE_SHIFT))

	board.eval             = saved_eval
	board.hash             = saved_hash
	board.castling_rights  = old_castling
	board.en_passant_square = if ep_stored ~= 0 then ep_stored - 1 else nil
	board.halfmove_clock   = old_halfmove
	board.fullmove_number  = old_fullmove

	local final_piece_type = promotion or piece_type

	local pieces_lo = board.pieces_lo
	local pieces_hi = board.pieces_hi
	local occ_lo    = board.occupied_lo
	local occ_hi    = board.occupied_hi

	clr_lo(pieces_lo[color], final_piece_type, to); clr_hi(pieces_hi[color], final_piece_type, to)
	board.pieceTable[to] = nil
	set_lo(pieces_lo[color], piece_type, from); set_hi(pieces_hi[color], piece_type, from)
	board.pieceTable[from] = make_pair(piece_type, color)
	clr_lo(occ_lo, ALL, to);    clr_hi(occ_hi, ALL, to)
	set_lo(occ_lo, ALL, from);  set_hi(occ_hi, ALL, from)
	clr_lo(occ_lo, color, to);  clr_hi(occ_hi, color, to)
	set_lo(occ_lo, color, from); set_hi(occ_hi, color, from)

	if has_capture then
		local cap_type, cap_color, cap_sq = unpack_captured_piece(captured_piece)
		set_lo(pieces_lo[cap_color], cap_type, cap_sq); set_hi(pieces_hi[cap_color], cap_type, cap_sq)
		board.pieceTable[cap_sq] = make_pair(cap_type, cap_color)
		set_lo(occ_lo, ALL, cap_sq);       set_hi(occ_hi, ALL, cap_sq)
		set_lo(occ_lo, cap_color, cap_sq); set_hi(occ_hi, cap_color, cap_sq)
	end

	if has_rook then
		local rook_from, rook_to = split_pair(rook_pair_packed)
		clr_lo(pieces_lo[color], ROOK, rook_to); clr_hi(pieces_hi[color], ROOK, rook_to)
		set_lo(pieces_lo[color], ROOK, rook_from); set_hi(pieces_hi[color], ROOK, rook_from)
		board.pieceTable[rook_to]   = nil
		board.pieceTable[rook_from] = make_pair(ROOK, color)
		clr_lo(occ_lo, ALL, rook_to);    clr_hi(occ_hi, ALL, rook_to)
		set_lo(occ_lo, ALL, rook_from);  set_hi(occ_hi, ALL, rook_from)
		clr_lo(occ_lo, color, rook_to);  clr_hi(occ_hi, color, rook_to)
		set_lo(occ_lo, color, rook_from); set_hi(occ_hi, color, rook_from)
	end
end

-- get_undo_record_data accepts the same 5 packed integers returned by make_move
local function get_undo_record_data(r_state: number, captured_piece: number, rook_pair_packed: number, _saved_eval: number, _saved_hash: number)
	local old_castling = bit32.band(r_state, R_CASTLING_MASK)
	local ep_stored    = bit32.band(bit32.rshift(r_state, R_EP_SHIFT), R_EP_MASK)
	local old_halfmove = bit32.band(bit32.rshift(r_state, R_HALFMOVE_SHIFT), R_HALFMOVE_MASK)
	local old_fullmove = math.floor(r_state / (2 ^ R_FULLMOVE_SHIFT))
	return {
		captured_piece    = if captured_piece == CAPTURED_SENTINEL then nil else captured_piece,
		castling_rights   = old_castling,
		en_passant_square = if ep_stored ~= 0 then ep_stored - 1 else nil,
		halfmove_clock    = old_halfmove,
		fullmove_number   = old_fullmove,
		additionallyMoved = if rook_pair_packed ~= ROOK_PAIR_SENTINEL then { split_pair(rook_pair_packed) } else nil,
	}
end

return {
	make_move            = make_move,
	undo_move            = undo_move,
	get_undo_record_data = get_undo_record_data,
}

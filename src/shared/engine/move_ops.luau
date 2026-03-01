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
local make_pair, split_pair = Utils.make_pair, Utils.split_pair
local BIT_LO  = Utils.BIT_LO
local BIT_HI  = Utils.BIT_HI
local NBIT_LO = Utils.NBIT_LO
local NBIT_HI = Utils.NBIT_HI
local pstForColor = Eval.pstForColor
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

local function make_move(board: Board, move: number): UndoRecord
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

	undo_top += 1
	local idx = undo_top
	undo_castling[idx] = old_castling
	undo_ep[idx]       = old_ep or -1
	undo_halfmove[idx] = board.halfmove_clock
	undo_fullmove[idx] = board.fullmove_number

	local pieces_lo = board.pieces_lo
	local pieces_hi = board.pieces_hi
	local occ_lo    = board.occupied_lo
	local occ_hi    = board.occupied_hi

	-- Precompute bit masks for from/to once; reused across all board updates.
	local bfrom_lo  = BIT_LO[from];  local bfrom_hi  = BIT_HI[from]
	local bto_lo    = BIT_LO[to];    local bto_hi    = BIT_HI[to]
	local nfrom_lo  = NBIT_LO[from]; local nfrom_hi  = NBIT_HI[from]
	local nto_lo    = NBIT_LO[to];   local nto_hi    = NBIT_HI[to]

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
				-- Inline clr for ep-captured pawn
				local bcap_lo = BIT_LO[cap_sq]; local bcap_hi = BIT_HI[cap_sq]
				local ncap_lo = NBIT_LO[cap_sq]; local ncap_hi = NBIT_HI[cap_sq]
				local opp_plo = pieces_lo[opponent]
				local opp_phi = pieces_hi[opponent]
				opp_plo[PAWN] = bit32.band(opp_plo[PAWN], ncap_lo)
				opp_phi[PAWN] = bit32.band(opp_phi[PAWN], ncap_hi)
				board.pieceTable[cap_sq] = nil
				occ_lo["all"]    = bit32.band(occ_lo["all"],    ncap_lo)
				occ_hi["all"]    = bit32.band(occ_hi["all"],    ncap_hi)
				occ_lo[opponent] = bit32.band(occ_lo[opponent], ncap_lo)
				occ_hi[opponent] = bit32.band(occ_hi[opponent], ncap_hi)
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
				-- Inline clr for normal captured piece (reuse nto masks)
				local cap_plo = pieces_lo[cc]
				local cap_phi = pieces_hi[cc]
				cap_plo[ct]      = bit32.band(cap_plo[ct],      nto_lo)
				cap_phi[ct]      = bit32.band(cap_phi[ct],      nto_hi)
				occ_lo["all"]    = bit32.band(occ_lo["all"],    nto_lo)
				occ_hi["all"]    = bit32.band(occ_hi["all"],    nto_hi)
				occ_lo[opponent] = bit32.band(occ_lo[opponent], nto_lo)
				occ_hi[opponent] = bit32.band(occ_hi[opponent], nto_hi)
			end
		end
	end

	local final_piece_type = promotion or piece_type

	-- Move the piece: inline clr(from) + set(to) for pieces and occupied
	local pc_lo = pieces_lo[color]
	local pc_hi = pieces_hi[color]
	pc_lo[piece_type]       = bit32.band(pc_lo[piece_type],       nfrom_lo)
	pc_hi[piece_type]       = bit32.band(pc_hi[piece_type],       nfrom_hi)
	pc_lo[final_piece_type] = bit32.bor( pc_lo[final_piece_type], bto_lo)
	pc_hi[final_piece_type] = bit32.bor( pc_hi[final_piece_type], bto_hi)
	board.pieceTable[from] = nil
	board.pieceTable[to]   = make_pair(final_piece_type, color)

	-- occupied: clear from, set to
	occ_lo["all"] = bit32.band(occ_lo["all"], nfrom_lo)
	occ_hi["all"] = bit32.band(occ_hi["all"], nfrom_hi)
	occ_lo["all"] = bit32.bor( occ_lo["all"], bto_lo)
	occ_hi["all"] = bit32.bor( occ_hi["all"], bto_hi)
	occ_lo[color] = bit32.band(occ_lo[color], nfrom_lo)
	occ_hi[color] = bit32.band(occ_hi[color], nfrom_hi)
	occ_lo[color] = bit32.bor( occ_lo[color], bto_lo)
	occ_hi[color] = bit32.bor( occ_hi[color], bto_hi)

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
			else bit32.band(new_castling, bit32.bnot(bit32.bor(BK_MASK, BQ_MASK))) end
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
		-- Inline castling rook move
		local brf_lo = BIT_LO[rook_from]; local brf_hi = BIT_HI[rook_from]
		local brt_lo = BIT_LO[rook_to];   local brt_hi = BIT_HI[rook_to]
		local nrf_lo = NBIT_LO[rook_from]; local nrf_hi = NBIT_HI[rook_from]
		pc_lo[ROOK] = bit32.band(pc_lo[ROOK], nrf_lo)
		pc_hi[ROOK] = bit32.band(pc_hi[ROOK], nrf_hi)
		pc_lo[ROOK] = bit32.bor( pc_lo[ROOK], brt_lo)
		pc_hi[ROOK] = bit32.bor( pc_hi[ROOK], brt_hi)
		board.pieceTable[rook_from] = nil
		board.pieceTable[rook_to]   = make_pair(ROOK, color)
		occ_lo["all"] = bit32.band(occ_lo["all"], nrf_lo)
		occ_hi["all"] = bit32.band(occ_hi["all"], nrf_hi)
		occ_lo[color] = bit32.band(occ_lo[color], nrf_lo)
		occ_hi[color] = bit32.band(occ_hi[color], nrf_hi)
		occ_lo[color] = bit32.bor( occ_lo[color], brt_lo)
		occ_hi[color] = bit32.bor( occ_hi[color], brt_hi)
		rook_pair_packed = make_pair(rook_from, rook_to)
	end

	-- Hash update: unpack captured/rook once each, reuse for eval
	local has_capture = captured_piece ~= CAPTURED_SENTINEL
	local cap_ct: number, cap_cc: number, cap_csq: number
	if has_capture then
		cap_ct, cap_cc, cap_csq = unpack_captured_piece(captured_piece)
	end
	local has_rook = rook_pair_packed ~= ROOK_PAIR_SENTINEL
	local rook_from_h: number, rook_to_h: number
	if has_rook then
		rook_from_h, rook_to_h = split_pair(rook_pair_packed)
	end

	hash = toggle_piece(hash, color, piece_type, from)
	hash = toggle_piece(hash, color, final_piece_type, to)
	if has_capture then
		hash = toggle_piece(hash, cap_cc, cap_ct, cap_csq)
	end
	if has_rook then
		hash = toggle_piece(hash, color, ROOK, rook_from_h)
		hash = toggle_piece(hash, color, ROOK, rook_to_h)
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

	-- Eval update: reuse cap_ct/cap_cc/cap_csq and rook_from_h/rook_to_h from above
	local pst_color = pstForColor[color]
	local delta = pst_color[final_piece_type][to] - pst_color[piece_type][from]
	if has_capture then
		delta -= pstForColor[cap_cc][cap_ct][cap_csq]
	end
	if has_rook then
		delta += pst_color[ROOK][rook_to_h] - pst_color[ROOK][rook_from_h]
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

	local current_castling = board.castling_rights
	local current_ep       = board.en_passant_square
	if board.hash == nil then board.hash = Zobrist.hash(board) end
	local hash = board.hash :: number

	local castling_rights   = undo_castling[idx]
	local ep_raw            = undo_ep[idx]
	local en_passant_square = if ep_raw >= 0 then ep_raw else nil

	board.castling_rights   = castling_rights
	board.en_passant_square = en_passant_square
	board.halfmove_clock    = undo_halfmove[idx]
	board.fullmove_number   = undo_fullmove[idx]

	-- Unpack captured/rook once, reuse for both hash and eval
	local cap_type: number, cap_color: number, cap_sq: number
	if has_capture then
		cap_type, cap_color, cap_sq = unpack_captured_piece(packed_captured)
	end
	local rook_from: number, rook_to: number
	if has_rook then
		rook_from, rook_to = split_pair(packed_rook_pair)
	end

	local final_piece_type = promotion or piece_type

	-- Hash undo
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
	if bit32.band(casting_diff, BQ_MASK) ~= 0 then hash = toggle_castling(hash, 4) end
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

	-- Eval undo: reuse cap_type/cap_color/cap_sq and rook_from/rook_to from above
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

	-- Restore board: precompute bit masks for from/to
	local pieces_lo = board.pieces_lo
	local pieces_hi = board.pieces_hi
	local occ_lo    = board.occupied_lo
	local occ_hi    = board.occupied_hi

	local bfrom_lo  = BIT_LO[from];  local bfrom_hi  = BIT_HI[from]
	local bto_lo    = BIT_LO[to];    local bto_hi    = BIT_HI[to]
	local nfrom_lo  = NBIT_LO[from]; local nfrom_hi  = NBIT_HI[from]
	local nto_lo    = NBIT_LO[to];   local nto_hi    = NBIT_HI[to]

	local pc_lo = pieces_lo[color]
	local pc_hi = pieces_hi[color]

	-- Unmove: clear to, set from (reverse of make_move)
	pc_lo[final_piece_type] = bit32.band(pc_lo[final_piece_type], nto_lo)
	pc_hi[final_piece_type] = bit32.band(pc_hi[final_piece_type], nto_hi)
	pc_lo[piece_type]       = bit32.bor( pc_lo[piece_type],       bfrom_lo)
	pc_hi[piece_type]       = bit32.bor( pc_hi[piece_type],       bfrom_hi)
	board.pieceTable[to]   = nil
	board.pieceTable[from] = make_pair(piece_type, color)

	occ_lo["all"] = bit32.band(occ_lo["all"], nto_lo)
	occ_hi["all"] = bit32.band(occ_hi["all"], nto_hi)
	occ_lo["all"] = bit32.bor( occ_lo["all"], bfrom_lo)
	occ_hi["all"] = bit32.bor( occ_hi["all"], bfrom_hi)
	occ_lo[color] = bit32.band(occ_lo[color], nto_lo)
	occ_hi[color] = bit32.band(occ_hi[color], nto_hi)
	occ_lo[color] = bit32.bor( occ_lo[color], bfrom_lo)
	occ_hi[color] = bit32.bor( occ_hi[color], bfrom_hi)

	if has_capture then
		local bcap_lo = BIT_LO[cap_sq]; local bcap_hi = BIT_HI[cap_sq]
		local cap_plo = pieces_lo[cap_color]
		local cap_phi = pieces_hi[cap_color]
		cap_plo[cap_type]   = bit32.bor(cap_plo[cap_type],   bcap_lo)
		cap_phi[cap_type]   = bit32.bor(cap_phi[cap_type],   bcap_hi)
		board.pieceTable[cap_sq] = make_pair(cap_type, cap_color)
		occ_lo["all"]      = bit32.bor(occ_lo["all"],      bcap_lo)
		occ_hi["all"]      = bit32.bor(occ_hi["all"],      bcap_hi)
		occ_lo[cap_color]  = bit32.bor(occ_lo[cap_color],  bcap_lo)
		occ_hi[cap_color]  = bit32.bor(occ_hi[cap_color],  bcap_hi)
	end

	if has_rook then
		local brf_lo = BIT_LO[rook_from]; local brf_hi = BIT_HI[rook_from]
		local brt_lo = BIT_LO[rook_to];   local brt_hi = BIT_HI[rook_to]
		local nrt_lo = NBIT_LO[rook_to];  local nrt_hi = NBIT_HI[rook_to]
		pc_lo[ROOK] = bit32.band(pc_lo[ROOK], nrt_lo)
		pc_hi[ROOK] = bit32.band(pc_hi[ROOK], nrt_hi)
		pc_lo[ROOK] = bit32.bor( pc_lo[ROOK], brf_lo)
		pc_hi[ROOK] = bit32.bor( pc_hi[ROOK], brf_hi)
		board.pieceTable[rook_to]   = nil
		board.pieceTable[rook_from] = make_pair(ROOK, color)
		occ_lo["all"] = bit32.band(occ_lo["all"], nrt_lo)
		occ_hi["all"] = bit32.band(occ_hi["all"], nrt_hi)
		occ_lo[color] = bit32.band(occ_lo[color], nrt_lo)
		occ_hi[color] = bit32.band(occ_hi[color], nrt_hi)
		occ_lo[color] = bit32.bor( occ_lo[color], brf_lo)
		occ_hi[color] = bit32.bor( occ_hi[color], brf_hi)
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
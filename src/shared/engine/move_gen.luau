--!native
--!optimize 2
--!strict

local Utils   = require("./utils")
local Attacks = require("./attacks")
local Move    = require("./move").Move

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING

local ALL          = Utils.ALL
local ATTACKED_ALL = Utils.ATTACKED_ALL

local PIECE_STRIDE = Utils.PIECE_STRIDE  -- 6: flat index = color * 6 + piece
local ATK_STRIDE   = Utils.ATK_STRIDE    -- 7: flat index = color * 7 + piece_or_all

local RANK_1_LO, RANK_1_HI = Utils.RANK_1_LO, Utils.RANK_1_HI
local RANK_2_LO, RANK_2_HI = Utils.RANK_2_LO, Utils.RANK_2_HI
local RANK_7_LO, RANK_7_HI = Utils.RANK_7_LO, Utils.RANK_7_HI
local RANK_8_LO, RANK_8_HI = Utils.RANK_8_LO, Utils.RANK_8_HI
local NOT_FILE_A_LO, NOT_FILE_A_HI = Utils.NOT_FILE_A_LO, Utils.NOT_FILE_A_HI
local NOT_FILE_H_LO, NOT_FILE_H_HI = Utils.NOT_FILE_H_LO, Utils.NOT_FILE_H_HI
local NOT_FILE_AB_LO, NOT_FILE_AB_HI = Utils.NOT_FILE_AB_LO, Utils.NOT_FILE_AB_HI
local NOT_FILE_GH_LO, NOT_FILE_GH_HI = Utils.NOT_FILE_GH_LO, Utils.NOT_FILE_GH_HI

local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

local LINE_LO = Attacks.LINE_LO
local LINE_HI = Attacks.LINE_HI

local bb_lshift_lo = Utils.bb_lshift_lo
local bb_lshift_hi = Utils.bb_lshift_hi
local bb_rshift_lo = Utils.bb_rshift_lo
local bb_rshift_hi = Utils.bb_rshift_hi

local bb_sub_lo    = Utils.bb_sub_lo
local bb_sub_hi    = Utils.bb_sub_hi

local get_bit    = Utils.get_bit
local get_bit32  = Utils.get_bit32
local popcount   = Utils.popcount

export type Board = Utils.Board

local MoveGen = {}

function MoveGen.attacked_occupancy(board: Board, by_color: number)
	local atk_base = by_color * ATK_STRIDE
	board.attacked_lo[atk_base + ATTACKED_ALL] = bit32.bor(board.attacked_lo[atk_base + ROOK], board.attacked_lo[atk_base + BISHOP], board.attacked_lo[atk_base + QUEEN], board.attacked_lo[atk_base + KNIGHT], board.attacked_lo[atk_base + KING], board.attacked_lo[atk_base + PAWN])
	board.attacked_hi[atk_base + ATTACKED_ALL] = bit32.bor(board.attacked_hi[atk_base + ROOK], board.attacked_hi[atk_base + BISHOP], board.attacked_hi[atk_base + QUEEN], board.attacked_hi[atk_base + KNIGHT], board.attacked_hi[atk_base + KING], board.attacked_hi[atk_base + PAWN])
end

local function pawn_attackers_to_square(square: number, enemy_color: number): (number, number)
	local k_lo = if square < 32 then bit32.lshift(1, square) else 0
	local k_hi = if square < 32 then 0 else bit32.lshift(1, square - 32)
	if enemy_color == WHITE then
		local r_lo = bit32.bor(
			bit32.band(bit32.bor(bit32.rshift(k_lo, 7), bit32.lshift(k_hi, 25)), NOT_FILE_A_LO),
			bit32.band(bit32.bor(bit32.rshift(k_lo, 9), bit32.lshift(k_hi, 23)), NOT_FILE_H_LO)
		)
		local r_hi = bit32.bor(
			bit32.band(bit32.rshift(k_hi, 7), NOT_FILE_A_HI),
			bit32.band(bit32.rshift(k_hi, 9), NOT_FILE_H_HI)
		)
		return r_hi, r_lo
	else
		local r_lo = bit32.bor(
			bit32.band(bit32.lshift(k_lo, 7), NOT_FILE_H_LO),
			bit32.band(bit32.lshift(k_lo, 9), NOT_FILE_A_LO)
		)
		local r_hi = bit32.bor(
			bit32.band(bit32.bor(bit32.lshift(k_hi, 7), bit32.rshift(k_lo, 25)), NOT_FILE_H_HI),
			bit32.band(bit32.bor(bit32.lshift(k_hi, 9), bit32.rshift(k_lo, 23)), NOT_FILE_A_HI)
		)
		return r_hi, r_lo
	end
end

local function compute_non_slider_attacks(board: Board, by_color: number): (number, number)
	local kn_lo = board.pieces_lo[by_color * PIECE_STRIDE + KNIGHT]
	local kn_hi = board.pieces_hi[by_color * PIECE_STRIDE + KNIGHT]
	local kg_lo = board.pieces_lo[by_color * PIECE_STRIDE + KING]
	local kg_hi = board.pieces_hi[by_color * PIECE_STRIDE + KING]
	local pw_lo = board.pieces_lo[by_color * PIECE_STRIDE + PAWN]
	local pw_hi = board.pieces_hi[by_color * PIECE_STRIDE + PAWN]

	-- bulk_knight_attacks_lo / _hi inlined, with bb_lshift_lo/hi and bb_rshift_lo/hi inlined
	local kn_atk_lo = bit32.bor(
		bit32.band(bit32.lshift(kn_lo, 17),                                              NOT_FILE_A_LO),
		bit32.band(bit32.lshift(kn_lo, 15),                                              NOT_FILE_H_LO),
		bit32.band(bit32.lshift(kn_lo, 10),                                              NOT_FILE_AB_LO),
		bit32.band(bit32.lshift(kn_lo, 6),                                               NOT_FILE_GH_LO),
		bit32.band(bit32.bor(bit32.rshift(kn_lo, 17), bit32.lshift(kn_hi, 32 - 17)),    NOT_FILE_H_LO),
		bit32.band(bit32.bor(bit32.rshift(kn_lo, 15), bit32.lshift(kn_hi, 32 - 15)),    NOT_FILE_A_LO),
		bit32.band(bit32.bor(bit32.rshift(kn_lo, 10), bit32.lshift(kn_hi, 32 - 10)),    NOT_FILE_GH_LO),
		bit32.band(bit32.bor(bit32.rshift(kn_lo, 6),  bit32.lshift(kn_hi, 32 - 6)),     NOT_FILE_AB_LO)
	)
	local kn_atk_hi = bit32.bor(
		bit32.band(bit32.bor(bit32.lshift(kn_hi, 17), bit32.rshift(kn_lo, 32 - 17)),    NOT_FILE_A_HI),
		bit32.band(bit32.bor(bit32.lshift(kn_hi, 15), bit32.rshift(kn_lo, 32 - 15)),    NOT_FILE_H_HI),
		bit32.band(bit32.bor(bit32.lshift(kn_hi, 10), bit32.rshift(kn_lo, 32 - 10)),    NOT_FILE_AB_HI),
		bit32.band(bit32.bor(bit32.lshift(kn_hi, 6),  bit32.rshift(kn_lo, 32 - 6)),     NOT_FILE_GH_HI),
		bit32.band(bit32.rshift(kn_hi, 17),                                              NOT_FILE_H_HI),
		bit32.band(bit32.rshift(kn_hi, 15),                                              NOT_FILE_A_HI),
		bit32.band(bit32.rshift(kn_hi, 10),                                              NOT_FILE_GH_HI),
		bit32.band(bit32.rshift(kn_hi, 6),                                               NOT_FILE_AB_HI)
	)

	-- bulk_king_attacks_lo / _hi inlined
	local kg_atk_lo = bit32.bor(
		bit32.band(bit32.lshift(kg_lo, 1),                                               NOT_FILE_A_LO),
		bit32.band(bit32.bor(bit32.rshift(kg_lo, 1), bit32.lshift(kg_hi, 32 - 1)),      NOT_FILE_H_LO),
		bit32.lshift(kg_lo, 8),
		bit32.bor(bit32.rshift(kg_lo, 8), bit32.lshift(kg_hi, 32 - 8)),
		bit32.band(bit32.lshift(kg_lo, 9),                                               NOT_FILE_A_LO),
		bit32.band(bit32.lshift(kg_lo, 7),                                               NOT_FILE_H_LO),
		bit32.band(bit32.bor(bit32.rshift(kg_lo, 9), bit32.lshift(kg_hi, 32 - 9)),      NOT_FILE_H_LO),
		bit32.band(bit32.bor(bit32.rshift(kg_lo, 7), bit32.lshift(kg_hi, 32 - 7)),      NOT_FILE_A_LO)
	)
	local kg_atk_hi = bit32.bor(
		bit32.band(bit32.bor(bit32.lshift(kg_hi, 1), bit32.rshift(kg_lo, 32 - 1)),      NOT_FILE_A_HI),
		bit32.band(bit32.rshift(kg_hi, 1),                                               NOT_FILE_H_HI),
		bit32.bor(bit32.lshift(kg_hi, 8), bit32.rshift(kg_lo, 32 - 8)),
		bit32.rshift(kg_hi, 8),
		bit32.band(bit32.bor(bit32.lshift(kg_hi, 9), bit32.rshift(kg_lo, 32 - 9)),      NOT_FILE_A_HI),
		bit32.band(bit32.bor(bit32.lshift(kg_hi, 7), bit32.rshift(kg_lo, 32 - 7)),      NOT_FILE_H_HI),
		bit32.band(bit32.rshift(kg_hi, 9),                                               NOT_FILE_H_HI),
		bit32.band(bit32.rshift(kg_hi, 7),                                               NOT_FILE_A_HI)
	)

	-- bulk_pawn_attacks_lo / _hi inlined
	local pw_atk_lo: number
	local pw_atk_hi: number
	if by_color == WHITE then
		pw_atk_lo = bit32.bor(
			bit32.band(bit32.lshift(pw_lo, 7),                                           NOT_FILE_H_LO),
			bit32.band(bit32.lshift(pw_lo, 9),                                           NOT_FILE_A_LO)
		)
		pw_atk_hi = bit32.bor(
			bit32.band(bit32.bor(bit32.lshift(pw_hi, 7), bit32.rshift(pw_lo, 32 - 7)),  NOT_FILE_H_HI),
			bit32.band(bit32.bor(bit32.lshift(pw_hi, 9), bit32.rshift(pw_lo, 32 - 9)),  NOT_FILE_A_HI)
		)
	else
		pw_atk_lo = bit32.bor(
			bit32.band(bit32.bor(bit32.rshift(pw_lo, 7), bit32.lshift(pw_hi, 32 - 7)),  NOT_FILE_A_LO),
			bit32.band(bit32.bor(bit32.rshift(pw_lo, 9), bit32.lshift(pw_hi, 32 - 9)),  NOT_FILE_H_LO)
		)
		pw_atk_hi = bit32.bor(
			bit32.band(bit32.rshift(pw_hi, 7),                                           NOT_FILE_A_HI),
			bit32.band(bit32.rshift(pw_hi, 9),                                           NOT_FILE_H_HI)
		)
	end

	return bit32.bor(kn_atk_hi, kg_atk_hi, pw_atk_hi),
	       bit32.bor(kn_atk_lo, kg_atk_lo, pw_atk_lo)
end

function MoveGen.is_square_attacked(board: Board, square: number, by_color: number): boolean
	-- Check non-slider pieces directly from board data (no stale cache dependency).
	local pat_hi, pat_lo = pawn_attackers_to_square(square, by_color)
	if bit32.bor(
		bit32.band(board.pieces_lo[by_color * PIECE_STRIDE + PAWN],   pat_lo),
		bit32.band(board.pieces_hi[by_color * PIECE_STRIDE + PAWN],   pat_hi)
	) ~= 0 then return true end

	if bit32.bor(
		bit32.band(board.pieces_lo[by_color * PIECE_STRIDE + KNIGHT], Attacks.knight_attacks_lo(square)),
		bit32.band(board.pieces_hi[by_color * PIECE_STRIDE + KNIGHT], Attacks.knight_attacks_hi(square))
	) ~= 0 then return true end

	if bit32.bor(
		bit32.band(board.pieces_lo[by_color * PIECE_STRIDE + KING],   Attacks.king_attacks_lo(square)),
		bit32.band(board.pieces_hi[by_color * PIECE_STRIDE + KING],   Attacks.king_attacks_hi(square))
	) ~= 0 then return true end

	-- Check sliders using current occupancy.
	local occ_lo = board.occupied_lo[ALL]
	local occ_hi = board.occupied_hi[ALL]

	local ra_hi, ra_lo = Attacks.rook_attacks(square, 0, 0, occ_hi, occ_lo)
	local rq_lo = bit32.bor(board.pieces_lo[by_color * PIECE_STRIDE + ROOK], board.pieces_lo[by_color * PIECE_STRIDE + QUEEN])
	local rq_hi = bit32.bor(board.pieces_hi[by_color * PIECE_STRIDE + ROOK], board.pieces_hi[by_color * PIECE_STRIDE + QUEEN])
	if bit32.bor(bit32.band(ra_lo, rq_lo), bit32.band(ra_hi, rq_hi)) ~= 0 then return true end

	local ba_hi, ba_lo = Attacks.bishop_attacks(square, 0, 0, occ_hi, occ_lo)
	local bq_lo = bit32.bor(board.pieces_lo[by_color * PIECE_STRIDE + BISHOP], board.pieces_lo[by_color * PIECE_STRIDE + QUEEN])
	local bq_hi = bit32.bor(board.pieces_hi[by_color * PIECE_STRIDE + BISHOP], board.pieces_hi[by_color * PIECE_STRIDE + QUEEN])
	if bit32.bor(bit32.band(ba_lo, bq_lo), bit32.band(ba_hi, bq_hi)) ~= 0 then return true end

	return false
end

local CASTLE_MOVE_WK = Move.create(4,  6,  KING, false, nil, false, true, true)
local CASTLE_MOVE_WQ = Move.create(4,  2,  KING, false, nil, false, true, false)
local CASTLE_MOVE_BK = Move.create(60, 62, KING, false, nil, false, true, true)
local CASTLE_MOVE_BQ = Move.create(60, 58, KING, false, nil, false, true, false)

local CM_WK_np_lo, CM_WK_np_hi = 0x60, 0x0
local CM_WQ_np_lo, CM_WQ_np_hi = 0x0E, 0x0
local CM_BK_np_lo, CM_BK_np_hi = 0x0, 0x60000000
local CM_BQ_np_lo, CM_BQ_np_hi = 0x0, 0x0E000000

local function generate_castle_moves(board: Board, moves: {number}, n: number, color: number): number
	local occ_lo = board.occupied_lo[ALL]
	local occ_hi = board.occupied_hi[ALL]
	local enemy = 1 - color

	if color == WHITE then
		if get_bit32(board.castling_rights, WK)
			and bit32.bor(bit32.band(occ_lo, CM_WK_np_lo), bit32.band(occ_hi, CM_WK_np_hi)) == 0
			and not MoveGen.is_square_attacked(board, 4, enemy)
			and not MoveGen.is_square_attacked(board, 5, enemy)
			and not MoveGen.is_square_attacked(board, 6, enemy) then
			n += 1; moves[n] = CASTLE_MOVE_WK
		end
		if get_bit32(board.castling_rights, WQ)
			and bit32.bor(bit32.band(occ_lo, CM_WQ_np_lo), bit32.band(occ_hi, CM_WQ_np_hi)) == 0
			and not MoveGen.is_square_attacked(board, 4, enemy)
			and not MoveGen.is_square_attacked(board, 3, enemy)
			and not MoveGen.is_square_attacked(board, 2, enemy) then
			n += 1; moves[n] = CASTLE_MOVE_WQ
		end
	else
		if get_bit32(board.castling_rights, BK)
			and bit32.bor(bit32.band(occ_lo, CM_BK_np_lo), bit32.band(occ_hi, CM_BK_np_hi)) == 0
			and not MoveGen.is_square_attacked(board, 60, enemy)
			and not MoveGen.is_square_attacked(board, 61, enemy)
			and not MoveGen.is_square_attacked(board, 62, enemy) then
			n += 1; moves[n] = CASTLE_MOVE_BK
		end
		if get_bit32(board.castling_rights, BQ)
			and bit32.bor(bit32.band(occ_lo, CM_BQ_np_lo), bit32.band(occ_hi, CM_BQ_np_hi)) == 0
			and not MoveGen.is_square_attacked(board, 60, enemy)
			and not MoveGen.is_square_attacked(board, 59, enemy)
			and not MoveGen.is_square_attacked(board, 58, enemy) then
			n += 1; moves[n] = CASTLE_MOVE_BQ
		end
	end
	return n
end

local function add_pawn_moves(
	moves: {number}, n: number,
	promo_lo: number, promo_hi: number,
	tgt_lo: number, tgt_hi: number,
	from_offset: number, is_capture: boolean
): number
	local captured_bit   = if is_capture then 0x8000 else 0
	local promo_sentinel = bit32.lshift(5, 16)

	local bb_lo = bit32.band(tgt_lo, bit32.bnot(promo_lo))
	local bb_hi = bit32.band(tgt_hi, bit32.bnot(promo_hi))
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local to_sq = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
		local nlo = bit32.bor(bb_lo - 1, 0)
		local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)
		n += 1
		moves[n] = bit32.bor(to_sq - from_offset, bit32.lshift(to_sq, 6), captured_bit, promo_sentinel)
	end

	bb_lo = bit32.band(tgt_lo, promo_lo)
	bb_hi = bit32.band(tgt_hi, promo_hi)
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local to_sq = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
		local nlo = bit32.bor(bb_lo - 1, 0)
		local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)
		local base = bit32.bor(to_sq - from_offset, bit32.lshift(to_sq, 6), captured_bit)
		moves[n+1] = bit32.bor(base, 0x10000)
		moves[n+2] = bit32.bor(base, 0x20000)
		moves[n+3] = bit32.bor(base, 0x30000)
		moves[n+4] = bit32.bor(base, 0x40000)
		n += 4
	end
	return n
end

local function generate_pawn_moves(board: Board, moves: {number}, n: number, color: number): number
	local pawns_lo = board.pieces_lo[color * PIECE_STRIDE + PAWN]
	local pawns_hi = board.pieces_hi[color * PIECE_STRIDE + PAWN]
	local all_lo   = board.occupied_lo[ALL]
	local all_hi   = board.occupied_hi[ALL]
	local empty_lo = bit32.bnot(all_lo)
	local empty_hi = bit32.bnot(all_hi)
	local enemy_lo = board.occupied_lo[1 - color]
	local enemy_hi = board.occupied_hi[1 - color]

	local push_dir   = if color == WHITE then 8 else -8
	local start_lo   = if color == WHITE then RANK_2_LO else RANK_7_LO
	local start_hi   = if color == WHITE then RANK_2_HI else RANK_7_HI
	local promo_lo   = if color == WHITE then RANK_8_LO else RANK_1_LO
	local promo_hi   = if color == WHITE then RANK_8_HI else RANK_1_HI

	local push_lo: number
	local push_hi: number
	if color == WHITE then
		push_lo = bit32.band(bit32.lshift(pawns_lo, 8), empty_lo)
		push_hi = bit32.band(bit32.bor(bit32.lshift(pawns_hi, 8), bit32.rshift(pawns_lo, 24)), empty_hi)
	else
		push_lo = bit32.band(bit32.bor(bit32.rshift(pawns_lo, 8), bit32.lshift(pawns_hi, 24)), empty_lo)
		push_hi = bit32.band(bit32.rshift(pawns_hi, 8), empty_hi)
	end

	local dbl_lo: number
	local dbl_hi: number
	if color == WHITE then
		dbl_lo = bit32.band(bit32.band(bit32.lshift(push_lo, 8), empty_lo), bit32.lshift(start_lo, 16))
		dbl_hi = bit32.band(bit32.band(bit32.bor(bit32.lshift(push_hi, 8), bit32.rshift(push_lo, 24)), empty_hi), bit32.bor(bit32.lshift(start_hi, 16), bit32.rshift(start_lo, 16)))
	else
		dbl_lo = bit32.band(bit32.band(bit32.bor(bit32.rshift(push_lo, 8), bit32.lshift(push_hi, 24)), empty_lo), bit32.bor(bit32.rshift(start_lo, 16), bit32.lshift(start_hi, 16)))
		dbl_hi = bit32.band(bit32.band(bit32.rshift(push_hi, 8), empty_hi), bit32.rshift(start_hi, 16))
	end

	local lc_lo, lc_hi, rc_lo, rc_hi: number
	if color == WHITE then
		lc_lo = bit32.band(bit32.band(bit32.lshift(pawns_lo, 7), NOT_FILE_H_LO), enemy_lo)
		lc_hi = bit32.band(bit32.band(bit32.bor(bit32.lshift(pawns_hi, 7), bit32.rshift(pawns_lo, 25)), NOT_FILE_H_HI), enemy_hi)
		rc_lo = bit32.band(bit32.band(bit32.lshift(pawns_lo, 9), NOT_FILE_A_LO), enemy_lo)
		rc_hi = bit32.band(bit32.band(bit32.bor(bit32.lshift(pawns_hi, 9), bit32.rshift(pawns_lo, 23)), NOT_FILE_A_HI), enemy_hi)
	else
		lc_lo = bit32.band(bit32.band(bit32.bor(bit32.rshift(pawns_lo, 7), bit32.lshift(pawns_hi, 25)), NOT_FILE_A_LO), enemy_lo)
		lc_hi = bit32.band(bit32.band(bit32.rshift(pawns_hi, 7), NOT_FILE_A_HI), enemy_hi)
		rc_lo = bit32.band(bit32.band(bit32.bor(bit32.rshift(pawns_lo, 9), bit32.lshift(pawns_hi, 23)), NOT_FILE_H_LO), enemy_lo)
		rc_hi = bit32.band(bit32.band(bit32.rshift(pawns_hi, 9), NOT_FILE_H_HI), enemy_hi)
	end

	n = add_pawn_moves(moves, n, promo_lo, promo_hi, push_lo, push_hi, push_dir, false)
	n = add_pawn_moves(moves, n, promo_lo, promo_hi, dbl_lo,  dbl_hi,  push_dir * 2, false)
	n = add_pawn_moves(moves, n, promo_lo, promo_hi, lc_lo, lc_hi, if color == WHITE then 7 else -7, true)
	n = add_pawn_moves(moves, n, promo_lo, promo_hi, rc_lo, rc_hi, if color == WHITE then 9 else -9, true)

	if board.en_passant_square and board.en_passant_square > 0 then
		local ep = board.en_passant_square
		local ep_blo = if ep < 32 then bit32.lshift(1, ep) else 0
		local ep_bhi = if ep < 32 then 0 else bit32.lshift(1, ep - 32)

		local el_lo: number
		local el_hi: number
		local er_lo: number
		local er_hi: number
		if color == WHITE then
			el_lo = bit32.bor(bit32.rshift(ep_blo, 7), bit32.lshift(ep_bhi, 25))
			el_hi = bit32.rshift(ep_bhi, 7)
			er_lo = bit32.bor(bit32.rshift(ep_blo, 9), bit32.lshift(ep_bhi, 23))
			er_hi = bit32.rshift(ep_bhi, 9)
		else
			el_lo = bit32.lshift(ep_blo, 7)
			el_hi = bit32.bor(bit32.lshift(ep_bhi, 7), bit32.rshift(ep_blo, 25))
			er_lo = bit32.lshift(ep_blo, 9)
			er_hi = bit32.bor(bit32.lshift(ep_bhi, 9), bit32.rshift(ep_blo, 23))
		end

		if bit32.bor(bit32.band(pawns_lo, el_lo), bit32.band(pawns_hi, el_hi)) ~= 0 then
			local from = ep - (if color == WHITE then 7 else -7)
			local from_rank = bit32.rshift(from, 3)
			local valid_rank = if color == WHITE then 4 else 3
			if from_rank == valid_rank then
				n += 1
				moves[n] = Move.create(from, ep, PAWN, true, nil, true)
			end
		end
		if bit32.bor(bit32.band(pawns_lo, er_lo), bit32.band(pawns_hi, er_hi)) ~= 0 then
			local from = ep - (if color == WHITE then 9 else -9)
			local from_rank = bit32.rshift(from, 3)
			local valid_rank = if color == WHITE then 4 else 3
			if from_rank == valid_rank then
				n += 1
				moves[n] = Move.create(from, ep, PAWN, true, nil, true)
			end
		end
	end
	return n
end

local function is_square_attacked_with_occupancy(
	board: Board, square: number, by_color: number,
	own_hi: number, own_lo: number,
	enemy_hi: number, enemy_lo: number,
	captured_sq: number?
): boolean
	local cap_inv_lo = 0xFFFFFFFF
	local cap_inv_hi = 0xFFFFFFFF
	if captured_sq then
		cap_inv_lo = if captured_sq < 32 then bit32.bnot(bit32.lshift(1, captured_sq))    else 0xFFFFFFFF
		cap_inv_hi = if captured_sq < 32 then 0xFFFFFFFF                                   else bit32.bnot(bit32.lshift(1, captured_sq - 32))
	end

	-- Pawn attacks
	local pat_hi, pat_lo = pawn_attackers_to_square(square, by_color)
	if bit32.band(board.pieces_lo[by_color * PIECE_STRIDE + PAWN], bit32.band(pat_lo, cap_inv_lo)) ~= 0 or
	   bit32.band(board.pieces_hi[by_color * PIECE_STRIDE + PAWN], bit32.band(pat_hi, cap_inv_hi)) ~= 0 then
		return true
	end

	-- Knight attacks
	if bit32.band(board.pieces_lo[by_color * PIECE_STRIDE + KNIGHT], bit32.band(Attacks.knight_attacks_lo(square), cap_inv_lo)) ~= 0 or
	   bit32.band(board.pieces_hi[by_color * PIECE_STRIDE + KNIGHT], bit32.band(Attacks.knight_attacks_hi(square), cap_inv_hi)) ~= 0 then
		return true
	end

	-- King attacks (the enemy king can never be the captured piece, no masking needed)
	if bit32.band(board.pieces_lo[by_color * PIECE_STRIDE + KING], Attacks.king_attacks_lo(square)) ~= 0 or
	   bit32.band(board.pieces_hi[by_color * PIECE_STRIDE + KING], Attacks.king_attacks_hi(square)) ~= 0 then
		return true
	end

	-- Combined occupancy (captured piece already removed from enemy_lo/hi by caller)
	local occ_lo = bit32.bor(own_lo, enemy_lo)
	local occ_hi = bit32.bor(own_hi, enemy_hi)

	-- Rook + Queen attacks
	local ra_hi, ra_lo = Attacks.rook_attacks(square, 0, 0, occ_hi, occ_lo)
	local rq_lo = bit32.band(bit32.bor(board.pieces_lo[by_color * PIECE_STRIDE + ROOK], board.pieces_lo[by_color * PIECE_STRIDE + QUEEN]), cap_inv_lo)
	local rq_hi = bit32.band(bit32.bor(board.pieces_hi[by_color * PIECE_STRIDE + ROOK], board.pieces_hi[by_color * PIECE_STRIDE + QUEEN]), cap_inv_hi)
	if bit32.band(ra_lo, rq_lo) ~= 0 or bit32.band(ra_hi, rq_hi) ~= 0 then
		return true
	end

	-- Bishop + Queen attacks
	local ba_hi, ba_lo = Attacks.bishop_attacks(square, 0, 0, occ_hi, occ_lo)
	local bq_lo = bit32.band(bit32.bor(board.pieces_lo[by_color * PIECE_STRIDE + BISHOP], board.pieces_lo[by_color * PIECE_STRIDE + QUEEN]), cap_inv_lo)
	local bq_hi = bit32.band(bit32.bor(board.pieces_hi[by_color * PIECE_STRIDE + BISHOP], board.pieces_hi[by_color * PIECE_STRIDE + QUEEN]), cap_inv_hi)
	if bit32.band(ba_lo, bq_lo) ~= 0 or bit32.band(ba_hi, bq_hi) ~= 0 then
		return true
	end

	return false
end

local pin_lo = table.create(64)
local pin_hi = table.create(64)
local function scan_sliders_for_pins_and_checks(
	board: Board, enemy: number, king_square: number,
	pieceType: number,
	occ_hi: number, occ_lo: number,
	own_hi: number, own_lo: number,
	chk_lo: number, chk_hi: number
): (number, number)
	local sl_lo = board.pieces_lo[enemy * PIECE_STRIDE + pieceType]
	local sl_hi = board.pieces_hi[enemy * PIECE_STRIDE + pieceType]

	while sl_lo ~= 0 or sl_hi ~= 0 do
		local slider_sq = if sl_lo == 0 then bit32.countrz(sl_hi) + 32 else bit32.countrz(sl_lo)
		local nlo = bit32.bor(sl_lo - 1, 0)
		local nhi = bit32.bor(sl_hi - (if sl_lo == 0 then 1 else 0), 0)
		sl_lo = bit32.band(sl_lo, nlo)
		sl_hi = bit32.band(sl_hi, nhi)

		local king_file = bit32.band(king_square, 7)
		local king_rank = bit32.rshift(king_square, 3)
		local slider_file = bit32.band(slider_sq, 7)
		local slider_rank = bit32.rshift(slider_sq, 3)

		local aligned = false
		if pieceType == ROOK then
			aligned = (king_file == slider_file) or (king_rank == slider_rank)
		elseif pieceType == BISHOP then
			aligned = (king_rank - king_file == slider_rank - slider_file)
				or (king_rank + king_file == slider_rank + slider_file)
		else
			aligned = (king_file == slider_file) or (king_rank == slider_rank)
				or (king_rank - king_file == slider_rank - slider_file)
				or (king_rank + king_file == slider_rank + slider_file)
		end

		if aligned then
			local btwn_hi: number
			local btwn_lo: number
			if pieceType == ROOK then
				btwn_hi, btwn_lo = Attacks.between_squares_rook(king_square, slider_sq)
			elseif pieceType == BISHOP then
				btwn_hi, btwn_lo = Attacks.between_squares_bishop(king_square, slider_sq)
			else
				btwn_hi, btwn_lo = Attacks.between_squares_rook(king_square, slider_sq)
				if btwn_hi == 0 and btwn_lo == 0 then
					btwn_hi, btwn_lo = Attacks.between_squares_bishop(king_square, slider_sq)
				end
			end
			local bo_lo = bit32.band(occ_lo, btwn_lo)
			local bo_hi = bit32.band(occ_hi, btwn_hi)

			-- Some cool binary math to remove the looped popcount, in favor of O(1) math variant.
			-- popcount(bo_hi, bo_lo) == 1
			-- popcount(bo_hi) + popcount(bo_lo) = 1
			-- (bo_hi == 0 && popcount(bo_lo) == 1) or (bo_lo == 0 && popcount(bo_hi) == 1)
			-- and popcount(x) == 1 means x is a power of 2, can be simplified to (x != 0 && x & (x - 1) == 0)
			local hasOne = (bo_lo == 0 and bo_hi ~= 0 and bit32.band(bo_hi, bo_hi-1) == 0) or
			               (bo_hi == 0 and bo_lo ~= 0 and bit32.band(bo_lo, bo_lo-1) == 0);

			if bo_lo == 0 and bo_hi == 0 then
				chk_lo = bit32.bor(chk_lo, if slider_sq < 32 then bit32.lshift(1, slider_sq) else 0)
				chk_hi = bit32.bor(chk_hi, if slider_sq < 32 then 0 else bit32.lshift(1, slider_sq - 32))
			elseif hasOne and bit32.bor(bit32.band(bo_lo, own_lo), bit32.band(bo_hi, own_hi)) ~= 0 then
				local pinned_sq = if bo_lo == 0 then bit32.countrz(bo_hi) + 32 else bit32.countrz(bo_lo)
				local btwn_hi: number
				local btwn_lo: number
				if pieceType == ROOK then
					btwn_hi, btwn_lo = Attacks.between_squares_rook(king_square, slider_sq)
				elseif pieceType == BISHOP then
					btwn_hi, btwn_lo = Attacks.between_squares_bishop(king_square, slider_sq)
				else
					btwn_hi, btwn_lo = Attacks.between_squares_rook(king_square, slider_sq)
					if btwn_hi == 0 and btwn_lo == 0 then
						btwn_hi, btwn_lo = Attacks.between_squares_bishop(king_square, slider_sq)
					end
				end
				local king_blo = if king_square < 32 then bit32.lshift(1, king_square) else 0
				local king_bhi = if king_square < 32 then 0 else bit32.lshift(1, king_square - 32)
				local slider_blo = if slider_sq < 32 then bit32.lshift(1, slider_sq) else 0
				local slider_bhi = if slider_sq < 32 then 0 else bit32.lshift(1, slider_sq - 32)
				pin_lo[pinned_sq] = bit32.bor(btwn_lo, king_blo, slider_blo)
				pin_hi[pinned_sq] = bit32.bor(btwn_hi, king_bhi, slider_bhi)
			end
		end
	end
	return chk_hi, chk_lo
end

local function compute_check_and_pins(board: Board, color: number, king_square: number)
	local enemy    = 1 - color
	local occ_lo   = board.occupied_lo[ALL]
	local occ_hi   = board.occupied_hi[ALL]
	local own_lo   = board.occupied_lo[color]
	local own_hi   = board.occupied_hi[color]
	table.clear(pin_lo)
	table.clear(pin_hi)

	local pat_hi, pat_lo = pawn_attackers_to_square(king_square, enemy)
	local chk_lo = bit32.bor(
		bit32.band(board.pieces_lo[enemy * PIECE_STRIDE + PAWN],   pat_lo),
		bit32.band(board.pieces_lo[enemy * PIECE_STRIDE + KNIGHT], Attacks.knight_attacks_lo(king_square))
	)
	local chk_hi = bit32.bor(
		bit32.band(board.pieces_hi[enemy * PIECE_STRIDE + PAWN],   pat_hi),
		bit32.band(board.pieces_hi[enemy * PIECE_STRIDE + KNIGHT], Attacks.knight_attacks_hi(king_square))
	)

	chk_hi, chk_lo = scan_sliders_for_pins_and_checks(board, enemy, king_square, ROOK,   occ_hi, occ_lo, own_hi, own_lo, chk_lo, chk_hi)
	chk_hi, chk_lo = scan_sliders_for_pins_and_checks(board, enemy, king_square, BISHOP, occ_hi, occ_lo, own_hi, own_lo, chk_lo, chk_hi)
	chk_hi, chk_lo = scan_sliders_for_pins_and_checks(board, enemy, king_square, QUEEN,  occ_hi, occ_lo, own_hi, own_lo, chk_lo, chk_hi)

	local num_checkers = popcount(chk_hi, chk_lo)

	if num_checkers >= 2 then
		return 0, 0, num_checkers, chk_lo, chk_hi
	elseif num_checkers == 0 then
		return 0xFFFFFFFF, 0xFFFFFFFF, num_checkers, chk_lo, chk_hi
	end

	local checker_sq  = if chk_lo == 0 then bit32.countrz(chk_hi) + 32 else bit32.countrz(chk_lo)
	local checker_bit_lo = if checker_sq < 32 then bit32.lshift(1, checker_sq) else 0
	local checker_bit_hi = if checker_sq < 32 then 0 else bit32.lshift(1, checker_sq - 32)
	local checker_val    = board.pieceTable[checker_sq]
	local cm_lo: number
	local cm_hi: number

	if checker_val then
		local checker_type = bit32.rshift(checker_val, 6)
		if checker_type == BISHOP or checker_type == ROOK or checker_type == QUEEN then
			-- Use between-squares masks for ray blocking.
			local btwn_hi = 0
			local btwn_lo = 0
			if checker_type == ROOK then
				btwn_hi, btwn_lo = Attacks.between_squares_rook(king_square, checker_sq)
			elseif checker_type == BISHOP then
				btwn_hi, btwn_lo = Attacks.between_squares_bishop(king_square, checker_sq)
			else
				btwn_hi, btwn_lo = Attacks.between_squares_rook(king_square, checker_sq)
				if btwn_hi == 0 and btwn_lo == 0 then
					btwn_hi, btwn_lo = Attacks.between_squares_bishop(king_square, checker_sq)
				end
			end
			cm_lo = bit32.bor(btwn_lo, checker_bit_lo)
			cm_hi = bit32.bor(btwn_hi, checker_bit_hi)
		else
			cm_lo = checker_bit_lo
			cm_hi = checker_bit_hi
		end
	else
		cm_lo = checker_bit_lo
		cm_hi = checker_bit_hi
	end

	return cm_hi, cm_lo, num_checkers, chk_lo, chk_hi
end

local function is_en_passant_legal(board: Board, color: number, from: number, to: number, king_square: number): boolean
	local enemy = 1 - color
	local cap_sq = to - (if color == WHITE then 8 else -8)

	local own_lo = bit32.bor(bit32.band(board.occupied_lo[color], if from < 32 then bit32.bnot(bit32.lshift(1, from)) else 0xFFFFFFFF), if to < 32 then bit32.lshift(1, to) else 0)
	local own_hi = bit32.bor(bit32.band(board.occupied_hi[color], if from < 32 then 0xFFFFFFFF else bit32.bnot(bit32.lshift(1, from - 32))), if to < 32 then 0 else bit32.lshift(1, to - 32))
	local enemy_lo = bit32.band(board.occupied_lo[enemy], if cap_sq < 32 then bit32.bnot(bit32.lshift(1, cap_sq)) else 0xFFFFFFFF)
	local enemy_hi = bit32.band(board.occupied_hi[enemy], if cap_sq < 32 then 0xFFFFFFFF else bit32.bnot(bit32.lshift(1, cap_sq - 32)))

	local cap_inv_lo = if cap_sq < 32 then bit32.bnot(bit32.lshift(1, cap_sq)) else 0xFFFFFFFF
	local cap_inv_hi = if cap_sq < 32 then 0xFFFFFFFF else bit32.bnot(bit32.lshift(1, cap_sq - 32))
	local pat_hi, pat_lo = pawn_attackers_to_square(king_square, enemy)
	if bit32.bor(
		bit32.band(board.pieces_lo[enemy * PIECE_STRIDE + PAWN], bit32.band(cap_inv_lo, pat_lo)),
		bit32.band(board.pieces_hi[enemy * PIECE_STRIDE + PAWN], bit32.band(cap_inv_hi, pat_hi))
	) ~= 0 then return false end

	if bit32.bor(
		bit32.band(board.pieces_lo[enemy * PIECE_STRIDE + KNIGHT], Attacks.knight_attacks_lo(king_square)),
		bit32.band(board.pieces_hi[enemy * PIECE_STRIDE + KNIGHT], Attacks.knight_attacks_hi(king_square))
	) ~= 0 then return false end

	if bit32.bor(
		bit32.band(board.pieces_lo[enemy * PIECE_STRIDE + KING], Attacks.king_attacks_lo(king_square)),
		bit32.band(board.pieces_hi[enemy * PIECE_STRIDE + KING], Attacks.king_attacks_hi(king_square))
	) ~= 0 then return false end

	local occ_lo = bit32.bor(own_lo, enemy_lo)
	local occ_hi = bit32.bor(own_hi, enemy_hi)

	local ra_hi, ra_lo = Attacks.rook_attacks(king_square, 0, 0, occ_hi, occ_lo)
	local rq_lo = bit32.bor(board.pieces_lo[enemy * PIECE_STRIDE + ROOK], board.pieces_lo[enemy * PIECE_STRIDE + QUEEN])
	local rq_hi = bit32.bor(board.pieces_hi[enemy * PIECE_STRIDE + ROOK], board.pieces_hi[enemy * PIECE_STRIDE + QUEEN])
	if bit32.bor(bit32.band(ra_lo, rq_lo), bit32.band(ra_hi, rq_hi)) ~= 0 then return false end

	local ba_hi, ba_lo = Attacks.bishop_attacks(king_square, 0, 0, occ_hi, occ_lo)
	local bq_lo = bit32.bor(board.pieces_lo[enemy * PIECE_STRIDE + BISHOP], board.pieces_lo[enemy * PIECE_STRIDE + QUEEN])
	local bq_hi = bit32.bor(board.pieces_hi[enemy * PIECE_STRIDE + BISHOP], board.pieces_hi[enemy * PIECE_STRIDE + QUEEN])
	if bit32.bor(bit32.band(ba_lo, bq_lo), bit32.band(ba_hi, bq_hi)) ~= 0 then return false end

	return true
end

local function add_pawn_moves_masked(
	moves: {number}, n: number,
	promo_lo: number, promo_hi: number,
	tgt_lo: number, tgt_hi: number,
	from_offset: number, is_capture: boolean
): number
	local captured_bit   = if is_capture then 0x8000 else 0
	local promo_sentinel = bit32.lshift(5, 16)

	local bb_lo = bit32.band(tgt_lo, bit32.bnot(promo_lo))
	local bb_hi = bit32.band(tgt_hi, bit32.bnot(promo_hi))
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local to_sq: number
		if bb_lo ~= 0 then
			to_sq = bit32.countrz(bb_lo)
			bb_lo = bit32.band(bb_lo, bb_lo - 1)
		else
			to_sq = bit32.countrz(bb_hi) + 32
			bb_hi = bit32.band(bb_hi, bb_hi - 1)
		end
		local from_sq = to_sq - from_offset
		local pm_lo = pin_lo[from_sq]
		if not pm_lo or get_bit(pin_hi[from_sq], pm_lo, to_sq) then
			n += 1
			moves[n] = bit32.bor(from_sq, bit32.lshift(to_sq, 6), captured_bit, promo_sentinel)
		end
	end

	bb_lo = bit32.band(tgt_lo, promo_lo)
	bb_hi = bit32.band(tgt_hi, promo_hi)
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local to_sq: number
		if bb_lo ~= 0 then
			to_sq = bit32.countrz(bb_lo)
			bb_lo = bit32.band(bb_lo, bb_lo - 1)
		else
			to_sq = bit32.countrz(bb_hi) + 32
			bb_hi = bit32.band(bb_hi, bb_hi - 1)
		end
		local from_sq = to_sq - from_offset
		local pm_lo = pin_lo[from_sq]
		if not pm_lo or get_bit(pin_hi[from_sq], pm_lo, to_sq) then
			local base = bit32.bor(from_sq, bit32.lshift(to_sq, 6), captured_bit)
			moves[n+1] = bit32.bor(base, 0x10000)
			moves[n+2] = bit32.bor(base, 0x20000)
			moves[n+3] = bit32.bor(base, 0x30000)
			moves[n+4] = bit32.bor(base, 0x40000)
			n += 4
		end
	end
	return n
end

local function generate_piece_moves(
	board: Board, moves: {number}, n: number, color: number,
	own_hi: number, own_lo: number,
	other_hi: number, other_lo: number,
	piece_type: number,
	attack_func: (number, number, number, number, number) -> (number, number)
): number
	local bb_lo = board.pieces_lo[color * PIECE_STRIDE + piece_type]
	local bb_hi = board.pieces_hi[color * PIECE_STRIDE + piece_type]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from_sq = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
		local nlo = bit32.bor(bb_lo - 1, 0)
		local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)

		local a_hi, a_lo = attack_func(from_sq, own_hi, own_lo, other_hi, other_lo)
		a_lo = bit32.band(a_lo, bit32.bnot(own_lo))
		a_hi = bit32.band(a_hi, bit32.bnot(own_hi))

		while a_lo ~= 0 or a_hi ~= 0 do
			local to_sq = if a_lo == 0 then bit32.countrz(a_hi) + 32 else bit32.countrz(a_lo)
			local alo2 = bit32.bor(a_lo - 1, 0)
			local ahi2 = bit32.bor(a_hi - (if a_lo == 0 then 1 else 0), 0)
			a_lo = bit32.band(a_lo, alo2)
			a_hi = bit32.band(a_hi, ahi2)
			n += 1
			moves[n] = Move.create(from_sq, to_sq, piece_type, get_bit(other_hi, other_lo, to_sq))
		end
	end
	return n
end

local function emit_sliding_moves(
	moves: {number}, n: number,
	from: number, piece_type: number,
	a_hi: number, a_lo: number,
	enemy_hi: number, enemy_lo: number
): number
	local promo_sentinel = bit32.lshift(5, 16)
	local base_q = bit32.bor(from, bit32.lshift(piece_type, 12), promo_sentinel)
	local base_c = bit32.bor(base_q, 0x8000)

	-- Quiet moves (destinations not occupied by enemy)
	local q_lo = bit32.band(a_lo, bit32.bnot(enemy_lo))
	local q_hi = bit32.band(a_hi, bit32.bnot(enemy_hi))
	while q_lo ~= 0 or q_hi ~= 0 do
		local to = if q_lo == 0 then bit32.countrz(q_hi) + 32 else bit32.countrz(q_lo)
		local nlo = bit32.bor(q_lo - 1, 0)
		local nhi = bit32.bor(q_hi - (if q_lo == 0 then 1 else 0), 0)
		q_lo = bit32.band(q_lo, nlo)
		q_hi = bit32.band(q_hi, nhi)
		n += 1
		moves[n] = bit32.bor(base_q, bit32.lshift(to, 6))
	end

	-- Captures (destinations occupied by enemy)
	local c_lo = bit32.band(a_lo, enemy_lo)
	local c_hi = bit32.band(a_hi, enemy_hi)
	while c_lo ~= 0 or c_hi ~= 0 do
		local to = if c_lo == 0 then bit32.countrz(c_hi) + 32 else bit32.countrz(c_lo)
		local nlo = bit32.bor(c_lo - 1, 0)
		local nhi = bit32.bor(c_hi - (if c_lo == 0 then 1 else 0), 0)
		c_lo = bit32.band(c_lo, nlo)
		c_hi = bit32.band(c_hi, nhi)
		n += 1
		moves[n] = bit32.bor(base_c, bit32.lshift(to, 6))
	end

	return n
end

local function add_knight_moves(
	board: Board, moves: {number}, n: number, color: number,
	own_hi: number, own_lo: number,
	enemy_hi: number, enemy_lo: number,
	cm_hi: number, cm_lo: number
): number
	local bb_lo = board.pieces_lo[color * PIECE_STRIDE + KNIGHT]
	local bb_hi = board.pieces_hi[color * PIECE_STRIDE + KNIGHT]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
		local nlo = bit32.bor(bb_lo - 1, 0)
		local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)
		if pin_lo[from] then continue end

		local a_lo = bit32.band(bit32.band(Attacks.knight_attacks_lo(from), bit32.bnot(own_lo)), cm_lo)
		local a_hi = bit32.band(bit32.band(Attacks.knight_attacks_hi(from), bit32.bnot(own_hi)), cm_hi)
		n = emit_sliding_moves(moves, n, from, KNIGHT, a_hi, a_lo, enemy_hi, enemy_lo)
	end
	return n
end

local function add_bishop_moves(
	board: Board, moves: {number}, n: number, color: number,
	own_hi: number, own_lo: number,
	enemy_hi: number, enemy_lo: number,
	cm_hi: number, cm_lo: number
): number
	local bb_lo = board.pieces_lo[color * PIECE_STRIDE + BISHOP]
	local bb_hi = board.pieces_hi[color * PIECE_STRIDE + BISHOP]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
		local nlo = bit32.bor(bb_lo - 1, 0)
		local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)

		local a_hi, a_lo = Attacks.bishop_attacks(from, own_hi, own_lo, enemy_hi, enemy_lo)
		a_lo = bit32.band(a_lo, cm_lo)
		a_hi = bit32.band(a_hi, cm_hi)
		local pm_lo = pin_lo[from]
		if pm_lo then
			a_lo = bit32.band(a_lo, pm_lo)
			a_hi = bit32.band(a_hi, pin_hi[from])
		end

		n = emit_sliding_moves(moves, n, from, BISHOP, a_hi, a_lo, enemy_hi, enemy_lo)
	end
	return n
end

local function add_rook_moves(
	board: Board, moves: {number}, n: number, color: number,
	own_hi: number, own_lo: number,
	enemy_hi: number, enemy_lo: number,
	cm_hi: number, cm_lo: number
): number
	local bb_lo = board.pieces_lo[color * PIECE_STRIDE + ROOK]
	local bb_hi = board.pieces_hi[color * PIECE_STRIDE + ROOK]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
		local nlo = bit32.bor(bb_lo - 1, 0)
		local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)

		local a_hi, a_lo = Attacks.rook_attacks(from, own_hi, own_lo, enemy_hi, enemy_lo)
		a_lo = bit32.band(a_lo, cm_lo)
		a_hi = bit32.band(a_hi, cm_hi)
		local pm_lo = pin_lo[from]
		if pm_lo then
			a_lo = bit32.band(a_lo, pm_lo)
			a_hi = bit32.band(a_hi, pin_hi[from])
		end

		n = emit_sliding_moves(moves, n, from, ROOK, a_hi, a_lo, enemy_hi, enemy_lo)
	end
	return n
end

local function add_queen_moves(
	board: Board, moves: {number}, n: number, color: number,
	own_hi: number, own_lo: number,
	enemy_hi: number, enemy_lo: number,
	cm_hi: number, cm_lo: number
): number
	local bb_lo = board.pieces_lo[color * PIECE_STRIDE + QUEEN]
	local bb_hi = board.pieces_hi[color * PIECE_STRIDE + QUEEN]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
		local nlo = bit32.bor(bb_lo - 1, 0)
		local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)

		local rh, rl = Attacks.rook_attacks(from, own_hi, own_lo, enemy_hi, enemy_lo)
		local bh, bl = Attacks.bishop_attacks(from, own_hi, own_lo, enemy_hi, enemy_lo)
		local a_lo = bit32.band(bit32.bor(rl, bl), cm_lo)
		local a_hi = bit32.band(bit32.bor(rh, bh), cm_hi)
		local pm_lo = pin_lo[from]
		if pm_lo then
			a_lo = bit32.band(a_lo, pm_lo)
			a_hi = bit32.band(a_hi, pin_hi[from])
		end

		n = emit_sliding_moves(moves, n, from, QUEEN, a_hi, a_lo, enemy_hi, enemy_lo)
	end
	return n
end

local function try_ep_helper(
	board: Board, moves: {number}, n: number,
	from: number,
	num_checkers: number, checker_type: number?, checker_sq: number,
	color: number, king_square: number
): number
	local pm_lo = pin_lo[from]
	if pm_lo and not get_bit(pin_hi[from], pm_lo, board.en_passant_square) then return n end

	if num_checkers == 1 then
		if checker_type ~= PAWN then return n end
		if board.en_passant_square - (if color == WHITE then 8 else -8) ~= checker_sq then return n end
	elseif num_checkers > 1 then
		return n
	end

	if is_en_passant_legal(board, color, from, board.en_passant_square, king_square) then
		n += 1
		moves[n] = Move.create(from, board.en_passant_square, PAWN, true, nil, true)
	end
	return n
end

function MoveGen.generate_legal_moves(board: Board, filePseudoLegal: boolean?, givenColor: number?): {number}
	local color = givenColor or board.side_to_move
	local enemy = 1 - color

	local moves = table.create(30)
	local n = 0

	local king_lo = board.pieces_lo[color * PIECE_STRIDE + KING]
	local king_hi = board.pieces_hi[color * PIECE_STRIDE + KING]
	local king_square = 63 - (if king_hi == 0 then bit32.countlz(king_lo) + 32 else bit32.countlz(king_hi))
	if king_square == -1 then return {} end



	if filePseudoLegal then
		local own_hi   = board.occupied_hi[color]
		local own_lo   = board.occupied_lo[color]
		local other_hi = board.occupied_hi[enemy]
		local other_lo = board.occupied_lo[enemy]
		local function knight_attack_fn(sq, _mh, _ml, _oh, _ol)
			return Attacks.knight_attacks_hi(sq), Attacks.knight_attacks_lo(sq)
		end
		local function king_attack_fn(sq, _mh, _ml, _oh, _ol)
			return Attacks.king_attacks_hi(sq), Attacks.king_attacks_lo(sq)
		end
		n = generate_pawn_moves(board, moves, n, color)
		n = generate_piece_moves(board, moves, n, color, own_hi, own_lo, other_hi, other_lo, KNIGHT, knight_attack_fn)
		n = generate_piece_moves(board, moves, n, color, own_hi, own_lo, other_hi, other_lo, BISHOP, Attacks.bishop_attacks)
		n = generate_piece_moves(board, moves, n, color, own_hi, own_lo, other_hi, other_lo, ROOK,   Attacks.rook_attacks)
		n = generate_piece_moves(board, moves, n, color, own_hi, own_lo, other_hi, other_lo, QUEEN,  Attacks.queen_attacks)
		n = generate_piece_moves(board, moves, n, color, own_hi, own_lo, other_hi, other_lo, KING,   king_attack_fn)
		n = generate_castle_moves(board, moves, n, color)
		return moves
	end

	local cm_hi, cm_lo, num_checkers, chk_lo, chk_hi =
		compute_check_and_pins(board, color, king_square)
	local king_only = num_checkers >= 2

	local own_lo   = board.occupied_lo[color]
	local own_hi   = board.occupied_hi[color]
	local enemy_lo = board.occupied_lo[enemy]
	local enemy_hi = board.occupied_hi[enemy]
	local empty_lo = bit32.bnot(board.occupied_lo[ALL])
	local empty_hi = bit32.bnot(board.occupied_hi[ALL])

	local checker_sq   = if num_checkers == 1 then (if chk_lo == 0 then bit32.countrz(chk_hi) + 32 else bit32.countrz(chk_lo)) else -1
	local checker_val  = if checker_sq >= 0 then board.pieceTable[checker_sq] else nil
	local checker_type = if checker_val then bit32.rshift(checker_val, 6) else nil

	if not king_only then
		local pawns_lo = board.pieces_lo[color * PIECE_STRIDE + PAWN]
		local pawns_hi = board.pieces_hi[color * PIECE_STRIDE + PAWN]
		local push_dir   = if color == WHITE then 8 else -8
		local start_lo   = if color == WHITE then RANK_2_LO else RANK_7_LO
		local start_hi   = if color == WHITE then RANK_2_HI else RANK_7_HI
		local promo_lo   = if color == WHITE then RANK_8_LO else RANK_1_LO
		local promo_hi   = if color == WHITE then RANK_8_HI else RANK_1_HI

		local raw_push_lo: number
		local raw_push_hi: number
		local push_lo: number
		local push_hi: number
		if color == WHITE then
			raw_push_lo = bit32.band(bit32.lshift(pawns_lo, 8), empty_lo)
			raw_push_hi = bit32.band(bit32.bor(bit32.lshift(pawns_hi, 8), bit32.rshift(pawns_lo, 24)), empty_hi)
			push_lo = bit32.band(raw_push_lo, cm_lo)
			push_hi = bit32.band(raw_push_hi, cm_hi)
		else
			raw_push_lo = bit32.band(bit32.bor(bit32.rshift(pawns_lo, 8), bit32.lshift(pawns_hi, 24)), empty_lo)
			raw_push_hi = bit32.band(bit32.rshift(pawns_hi, 8), empty_hi)
			push_lo = bit32.band(raw_push_lo, cm_lo)
			push_hi = bit32.band(raw_push_hi, cm_hi)
		end

		local dbl_lo: number
		local dbl_hi: number
		if color == WHITE then
			dbl_lo = bit32.band(bit32.band(bit32.lshift(raw_push_lo, 8), empty_lo), bit32.lshift(start_lo, 16))
			dbl_hi = bit32.band(bit32.band(bit32.bor(bit32.lshift(raw_push_hi, 8), bit32.rshift(raw_push_lo, 24)), empty_hi), bit32.bor(bit32.lshift(start_hi, 16), bit32.rshift(start_lo, 16)))
		else
			dbl_lo = bit32.band(bit32.band(bit32.bor(bit32.rshift(raw_push_lo, 8), bit32.lshift(raw_push_hi, 24)), empty_lo), bit32.bor(bit32.rshift(start_lo, 16), bit32.lshift(start_hi, 16)))
			dbl_hi = bit32.band(bit32.band(bit32.rshift(raw_push_hi, 8), empty_hi), bit32.rshift(start_hi, 16))
		end
		dbl_lo = bit32.band(dbl_lo, cm_lo)
		dbl_hi = bit32.band(dbl_hi, cm_hi)

		local lc_lo, lc_hi, rc_lo, rc_hi: number
		if color == WHITE then
			lc_lo = bit32.band(bit32.band(bit32.band(bit32.lshift(pawns_lo, 7), NOT_FILE_H_LO), enemy_lo), cm_lo)
			lc_hi = bit32.band(bit32.band(bit32.band(bit32.bor(bit32.lshift(pawns_hi, 7), bit32.rshift(pawns_lo, 25)), NOT_FILE_H_HI), enemy_hi), cm_hi)
			rc_lo = bit32.band(bit32.band(bit32.band(bit32.lshift(pawns_lo, 9), NOT_FILE_A_LO), enemy_lo), cm_lo)
			rc_hi = bit32.band(bit32.band(bit32.band(bit32.bor(bit32.lshift(pawns_hi, 9), bit32.rshift(pawns_lo, 23)), NOT_FILE_A_HI), enemy_hi), cm_hi)
		else
			lc_lo = bit32.band(bit32.band(bit32.band(bit32.bor(bit32.rshift(pawns_lo, 7), bit32.lshift(pawns_hi, 25)), NOT_FILE_A_LO), enemy_lo), cm_lo)
			lc_hi = bit32.band(bit32.band(bit32.band(bit32.rshift(pawns_hi, 7), NOT_FILE_A_HI), enemy_hi), cm_hi)
			rc_lo = bit32.band(bit32.band(bit32.band(bit32.bor(bit32.rshift(pawns_lo, 9), bit32.lshift(pawns_hi, 23)), NOT_FILE_H_LO), enemy_lo), cm_lo)
			rc_hi = bit32.band(bit32.band(bit32.band(bit32.rshift(pawns_hi, 9), NOT_FILE_H_HI), enemy_hi), cm_hi)
		end

		n = add_pawn_moves_masked(moves, n, promo_lo, promo_hi, push_lo, push_hi, push_dir, false)
		n = add_pawn_moves_masked(moves, n, promo_lo, promo_hi, dbl_lo,  dbl_hi,  push_dir * 2, false)
		n = add_pawn_moves_masked(moves, n, promo_lo, promo_hi, lc_lo, lc_hi, if color == WHITE then 7 else -7, true)
		n = add_pawn_moves_masked(moves, n, promo_lo, promo_hi, rc_lo, rc_hi, if color == WHITE then 9 else -9, true)

		if board.en_passant_square and board.en_passant_square > 0 then
			local ep = board.en_passant_square
			local ep_blo = if ep < 32 then bit32.lshift(1, ep) else 0
			local ep_bhi = if ep < 32 then 0 else bit32.lshift(1, ep - 32)

			local el_lo: number
			local el_hi: number
			local er_lo: number
			local er_hi: number
			if color == WHITE then
				el_lo = bit32.bor(bit32.rshift(ep_blo, 7), bit32.lshift(ep_bhi, 25))
				el_hi = bit32.rshift(ep_bhi, 7)
				er_lo = bit32.bor(bit32.rshift(ep_blo, 9), bit32.lshift(ep_bhi, 23))
				er_hi = bit32.rshift(ep_bhi, 9)
			else
				el_lo = bit32.lshift(ep_blo, 7)
				el_hi = bit32.bor(bit32.lshift(ep_bhi, 7), bit32.rshift(ep_blo, 25))
				er_lo = bit32.lshift(ep_blo, 9)
				er_hi = bit32.bor(bit32.lshift(ep_bhi, 9), bit32.rshift(ep_blo, 23))
			end

			if bit32.bor(bit32.band(pawns_lo, el_lo), bit32.band(pawns_hi, el_hi)) ~= 0 then
				local from = ep - (if color == WHITE then 7 else -7)
				local from_rank = bit32.rshift(from, 3)
				local valid_rank = if color == WHITE then 4 else 3
				if from_rank == valid_rank then
					n = try_ep_helper(board, moves, n, from, num_checkers, checker_type, checker_sq, color, king_square)
				end
			end
			if bit32.bor(bit32.band(pawns_lo, er_lo), bit32.band(pawns_hi, er_hi)) ~= 0 then
				local from = ep - (if color == WHITE then 9 else -9)
				local from_rank = bit32.rshift(from, 3)
				local valid_rank = if color == WHITE then 4 else 3
				if from_rank == valid_rank then
					n = try_ep_helper(board, moves, n, from, num_checkers, checker_type, checker_sq, color, king_square)
				end
			end
		end

		n = add_knight_moves(board, moves, n, color, own_hi, own_lo, enemy_hi, enemy_lo, cm_hi, cm_lo)
		n = add_bishop_moves(board, moves, n, color, own_hi, own_lo, enemy_hi, enemy_lo, cm_hi, cm_lo)
		n = add_rook_moves  (board, moves, n, color, own_hi, own_lo, enemy_hi, enemy_lo, cm_hi, cm_lo)
		n = add_queen_moves (board, moves, n, color, own_hi, own_lo, enemy_hi, enemy_lo, cm_hi, cm_lo)
	end

	-- King moves
	do
		local ka_lo = bit32.band(Attacks.king_attacks_lo(king_square), bit32.bnot(own_lo))
		local ka_hi = bit32.band(Attacks.king_attacks_hi(king_square), bit32.bnot(own_hi))
		local bb_lo = ka_lo
		local bb_hi = ka_hi
		while bb_lo ~= 0 or bb_hi ~= 0 do
			local to = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
			local nlo = bit32.bor(bb_lo - 1, 0)
			local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
			bb_lo = bit32.band(bb_lo, nlo)
			bb_hi = bit32.band(bb_hi, nhi)

			local to_blo = if to < 32 then bit32.lshift(1, to) else 0
			local to_bhi = if to < 32 then 0 else bit32.lshift(1, to - 32)
			local new_own_lo = bit32.bor(bit32.band(own_lo, if king_square < 32 then bit32.bnot(bit32.lshift(1, king_square)) else 0xFFFFFFFF), to_blo)
			local new_own_hi = bit32.bor(bit32.band(own_hi, if king_square < 32 then 0xFFFFFFFF else bit32.bnot(bit32.lshift(1, king_square - 32))), to_bhi)
			local captures = get_bit(enemy_hi, enemy_lo, to)
			local new_enemy_lo = if captures then bit32.band(enemy_lo, if to < 32 then bit32.bnot(bit32.lshift(1, to)) else 0xFFFFFFFF) else enemy_lo
			local new_enemy_hi = if captures then bit32.band(enemy_hi, if to < 32 then 0xFFFFFFFF else bit32.bnot(bit32.lshift(1, to - 32))) else enemy_hi

			if not is_square_attacked_with_occupancy(board, to, enemy, new_own_hi, new_own_lo, new_enemy_hi, new_enemy_lo, if captures then to else nil) then
				n += 1
				moves[n] = Move.create(king_square, to, KING, captures)
			end
		end
	end

	if num_checkers == 0 then
		n = generate_castle_moves(board, moves, n, color)
	end

	return moves
end

function MoveGen.generate_legal_moves_from(board: Board, from: number, filePseudoLegal: boolean?, color: number?)
	local allMoves = MoveGen.generate_legal_moves(board, filePseudoLegal, color)
	local moves = {}
	local n = 0
	for _, move in allMoves do
		if bit32.band(bit32.rshift(move, 0), 0x3F) == from then -- inline: Move.getFrom(move)
			n += 1
			moves[n] = move
		end
	end
	return moves
end

return { MoveGen = MoveGen }

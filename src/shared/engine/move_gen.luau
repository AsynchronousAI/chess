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

local RANK_1_LO, RANK_1_HI = Utils.RANK_1_LO, Utils.RANK_1_HI
local RANK_2_LO, RANK_2_HI = Utils.RANK_2_LO, Utils.RANK_2_HI
local RANK_7_LO, RANK_7_HI = Utils.RANK_7_LO, Utils.RANK_7_HI
local RANK_8_LO, RANK_8_HI = Utils.RANK_8_LO, Utils.RANK_8_HI
local NOT_FILE_A_LO, NOT_FILE_A_HI = Utils.NOT_FILE_A_LO, Utils.NOT_FILE_A_HI
local NOT_FILE_H_LO, NOT_FILE_H_HI = Utils.NOT_FILE_H_LO, Utils.NOT_FILE_H_HI
local NOT_FILE_AB_LO, NOT_FILE_AB_HI = Utils.NOT_FILE_AB_LO, Utils.NOT_FILE_AB_HI
local NOT_FILE_GH_LO, NOT_FILE_GH_HI = Utils.NOT_FILE_GH_LO, Utils.NOT_FILE_GH_HI

local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

local BIT_LO  = Utils.BIT_LO
local BIT_HI  = Utils.BIT_HI
local NBIT_LO = Utils.NBIT_LO
local NBIT_HI = Utils.NBIT_HI

local bb_lshift_lo = Utils.bb_lshift_lo
local bb_lshift_hi = Utils.bb_lshift_hi
local bb_rshift_lo = Utils.bb_rshift_lo
local bb_rshift_hi = Utils.bb_rshift_hi
local bb_countrz   = Utils.bb_countrz
local bb_countlz   = Utils.bb_countlz
local bb_sub_lo    = Utils.bb_sub_lo
local bb_sub_hi    = Utils.bb_sub_hi

local get_bit    = Utils.get_bit
local get_bit32  = Utils.get_bit32
local popcount   = Utils.popcount

export type Board = Utils.Board

local MoveGen = {}

function MoveGen.attacked_occupancy(board: Board, by_color: number)
	local atk  = board.attacked_lo[by_color]
	local atkh = board.attacked_hi[by_color]
	board.attacked_lo[by_color][ATTACKED_ALL] = bit32.bor(atk[ROOK], atk[BISHOP], atk[QUEEN], atk[KNIGHT], atk[KING], atk[PAWN])
	board.attacked_hi[by_color][ATTACKED_ALL] = bit32.bor(atkh[ROOK], atkh[BISHOP], atkh[QUEEN], atkh[KNIGHT], atkh[KING], atkh[PAWN])
end

local function pawn_attackers_to_square(square: number, enemy_color: number): (number, number)
	local k_lo = BIT_LO[square]
	local k_hi = BIT_HI[square]
	if enemy_color == WHITE then
		local r_lo = bit32.bor(
			bit32.band(bb_rshift_lo(k_hi, k_lo, 7), NOT_FILE_H_LO),
			bit32.band(bb_rshift_lo(k_hi, k_lo, 9), NOT_FILE_A_LO)
		)
		local r_hi = bit32.bor(
			bit32.band(bb_rshift_hi(k_hi, 7), NOT_FILE_H_HI),
			bit32.band(bb_rshift_hi(k_hi, 9), NOT_FILE_A_HI)
		)
		return r_hi, r_lo
	else
		local r_lo = bit32.bor(
			bit32.band(bb_lshift_lo(k_lo, 7), NOT_FILE_A_LO),
			bit32.band(bb_lshift_lo(k_lo, 9), NOT_FILE_H_LO)
		)
		local r_hi = bit32.bor(
			bit32.band(bb_lshift_hi(k_hi, k_lo, 7), NOT_FILE_A_HI),
			bit32.band(bb_lshift_hi(k_hi, k_lo, 9), NOT_FILE_H_HI)
		)
		return r_hi, r_lo
	end
end

local function compute_non_slider_attacks(board: Board, by_color: number): (number, number)
	local kn_lo = board.pieces_lo[by_color][KNIGHT]
	local kn_hi = board.pieces_hi[by_color][KNIGHT]
	local kg_lo = board.pieces_lo[by_color][KING]
	local kg_hi = board.pieces_hi[by_color][KING]
	local pw_lo = board.pieces_lo[by_color][PAWN]
	local pw_hi = board.pieces_hi[by_color][PAWN]

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
		bit32.band(board.pieces_lo[by_color][PAWN],   pat_lo),
		bit32.band(board.pieces_hi[by_color][PAWN],   pat_hi)
	) ~= 0 then return true end

	if bit32.bor(
		bit32.band(board.pieces_lo[by_color][KNIGHT], Attacks.knight_attacks_lo(square)),
		bit32.band(board.pieces_hi[by_color][KNIGHT], Attacks.knight_attacks_hi(square))
	) ~= 0 then return true end

	if bit32.bor(
		bit32.band(board.pieces_lo[by_color][KING],   Attacks.king_attacks_lo(square)),
		bit32.band(board.pieces_hi[by_color][KING],   Attacks.king_attacks_hi(square))
	) ~= 0 then return true end

	-- Check sliders using current occupancy.
	local occ_lo = board.occupied_lo[ALL]
	local occ_hi = board.occupied_hi[ALL]

	local ra_hi, ra_lo = Attacks.rook_attacks(square, 0, 0, occ_hi, occ_lo)
	local rq_lo = bit32.bor(board.pieces_lo[by_color][ROOK], board.pieces_lo[by_color][QUEEN])
	local rq_hi = bit32.bor(board.pieces_hi[by_color][ROOK], board.pieces_hi[by_color][QUEEN])
	if bit32.bor(bit32.band(ra_lo, rq_lo), bit32.band(ra_hi, rq_hi)) ~= 0 then return true end

	local ba_hi, ba_lo = Attacks.bishop_attacks(square, 0, 0, occ_hi, occ_lo)
	local bq_lo = bit32.bor(board.pieces_lo[by_color][BISHOP], board.pieces_lo[by_color][QUEEN])
	local bq_hi = bit32.bor(board.pieces_hi[by_color][BISHOP], board.pieces_hi[by_color][QUEEN])
	if bit32.bor(bit32.band(ba_lo, bq_lo), bit32.band(ba_hi, bq_hi)) ~= 0 then return true end

	return false
end

local CASTLE_MOVE_WK = Move.create(4,  6,  KING, false, nil, false, true, true)
local CASTLE_MOVE_WQ = Move.create(4,  2,  KING, false, nil, false, true, false)
local CASTLE_MOVE_BK = Move.create(60, 62, KING, false, nil, false, true, true)
local CASTLE_MOVE_BQ = Move.create(60, 58, KING, false, nil, false, true, false)

local CM_WK_np_lo, CM_WK_np_hi = 0x60, 0x0
local CM_WK_nc_lo, CM_WK_nc_hi = 0x70, 0x0
local CM_WQ_np_lo, CM_WQ_np_hi = 0x0E, 0x0
local CM_WQ_nc_lo, CM_WQ_nc_hi = 0x1C, 0x0
local CM_BK_np_lo, CM_BK_np_hi = 0x0, 0x60000000
local CM_BK_nc_lo, CM_BK_nc_hi = 0x0, 0x70000000
local CM_BQ_np_lo, CM_BQ_np_hi = 0x0, 0x0E000000
local CM_BQ_nc_lo, CM_BQ_nc_hi = 0x0, 0x1C000000

local function generate_castle_moves(board: Board, moves: {number}, n: number, color: number,
	atk_hi: number, atk_lo: number): number
	local occ_lo = board.occupied_lo[ALL]
	local occ_hi = board.occupied_hi[ALL]
	if color == WHITE then
		if get_bit32(board.castling_rights, WK)
			and bit32.bor(bit32.band(occ_lo, CM_WK_np_lo), bit32.band(occ_hi, CM_WK_np_hi)) == 0
			and bit32.bor(bit32.band(atk_lo, CM_WK_nc_lo), bit32.band(atk_hi, CM_WK_nc_hi)) == 0 then
			n += 1; moves[n] = CASTLE_MOVE_WK
		end
		if get_bit32(board.castling_rights, WQ)
			and bit32.bor(bit32.band(occ_lo, CM_WQ_np_lo), bit32.band(occ_hi, CM_WQ_np_hi)) == 0
			and bit32.bor(bit32.band(atk_lo, CM_WQ_nc_lo), bit32.band(atk_hi, CM_WQ_nc_hi)) == 0 then
			n += 1; moves[n] = CASTLE_MOVE_WQ
		end
	else
		if get_bit32(board.castling_rights, BK)
			and bit32.bor(bit32.band(occ_lo, CM_BK_np_lo), bit32.band(occ_hi, CM_BK_np_hi)) == 0
			and bit32.bor(bit32.band(atk_lo, CM_BK_nc_lo), bit32.band(atk_hi, CM_BK_nc_hi)) == 0 then
			n += 1; moves[n] = CASTLE_MOVE_BK
		end
		if get_bit32(board.castling_rights, BQ)
			and bit32.bor(bit32.band(occ_lo, CM_BQ_np_lo), bit32.band(occ_hi, CM_BQ_np_hi)) == 0
			and bit32.bor(bit32.band(atk_lo, CM_BQ_nc_lo), bit32.band(atk_hi, CM_BQ_nc_hi)) == 0 then
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
		local to_sq = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)
		n += 1
		moves[n] = bit32.bor(to_sq - from_offset, bit32.lshift(to_sq, 6), captured_bit, promo_sentinel)
	end

	bb_lo = bit32.band(tgt_lo, promo_lo)
	bb_hi = bit32.band(tgt_hi, promo_hi)
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local to_sq = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
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
	local pawns_lo = board.pieces_lo[color][PAWN]
	local pawns_hi = board.pieces_hi[color][PAWN]
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
		push_lo = bit32.band(bb_lshift_lo(pawns_lo, 8), empty_lo)
		push_hi = bit32.band(bb_lshift_hi(pawns_hi, pawns_lo, 8), empty_hi)
	else
		push_lo = bit32.band(bb_rshift_lo(pawns_hi, pawns_lo, 8), empty_lo)
		push_hi = bit32.band(bb_rshift_hi(pawns_hi, 8), empty_hi)
	end

	local dbl_lo: number
	local dbl_hi: number
	if color == WHITE then
		dbl_lo = bit32.band(bit32.band(bb_lshift_lo(push_lo, 8), empty_lo), bb_lshift_lo(start_lo, 16))
		dbl_hi = bit32.band(bit32.band(bb_lshift_hi(push_hi, push_lo, 8), empty_hi), bb_lshift_hi(start_hi, start_lo, 16))
	else
		dbl_lo = bit32.band(bit32.band(bb_rshift_lo(push_hi, push_lo, 8), empty_lo), bb_rshift_lo(start_hi, start_lo, 16))
		dbl_hi = bit32.band(bit32.band(bb_rshift_hi(push_hi, 8), empty_hi), bb_rshift_hi(start_hi, 16))
	end

	local lc_lo, lc_hi, rc_lo, rc_hi: number
	if color == WHITE then
		lc_lo = bit32.band(bit32.band(bb_lshift_lo(pawns_lo, 7), NOT_FILE_H_LO), enemy_lo)
		lc_hi = bit32.band(bit32.band(bb_lshift_hi(pawns_hi, pawns_lo, 7), NOT_FILE_H_HI), enemy_hi)
		rc_lo = bit32.band(bit32.band(bb_lshift_lo(pawns_lo, 9), NOT_FILE_A_LO), enemy_lo)
		rc_hi = bit32.band(bit32.band(bb_lshift_hi(pawns_hi, pawns_lo, 9), NOT_FILE_A_HI), enemy_hi)
	else
		lc_lo = bit32.band(bit32.band(bb_rshift_lo(pawns_hi, pawns_lo, 7), NOT_FILE_A_LO), enemy_lo)
		lc_hi = bit32.band(bit32.band(bb_rshift_hi(pawns_hi, 7), NOT_FILE_A_HI), enemy_hi)
		rc_lo = bit32.band(bit32.band(bb_rshift_lo(pawns_hi, pawns_lo, 9), NOT_FILE_H_LO), enemy_lo)
		rc_hi = bit32.band(bit32.band(bb_rshift_hi(pawns_hi, 9), NOT_FILE_H_HI), enemy_hi)
	end

	n = add_pawn_moves(moves, n, promo_lo, promo_hi, push_lo, push_hi, push_dir, false)
	n = add_pawn_moves(moves, n, promo_lo, promo_hi, dbl_lo,  dbl_hi,  push_dir * 2, false)
	n = add_pawn_moves(moves, n, promo_lo, promo_hi, lc_lo, lc_hi, if color == WHITE then 7 else -7, true)
	n = add_pawn_moves(moves, n, promo_lo, promo_hi, rc_lo, rc_hi, if color == WHITE then 9 else -9, true)

	if board.en_passant_square and board.en_passant_square > 0 then
		local ep = board.en_passant_square
		local ep_blo = BIT_LO[ep]
		local ep_bhi = BIT_HI[ep]

		local el_lo: number
		local el_hi: number
		local er_lo: number
		local er_hi: number
		if color == WHITE then
			el_lo = bb_rshift_lo(ep_bhi, ep_blo, 7)
			el_hi = bb_rshift_hi(ep_bhi, 7)
			er_lo = bb_rshift_lo(ep_bhi, ep_blo, 9)
			er_hi = bb_rshift_hi(ep_bhi, 9)
		else
			el_lo = bb_lshift_lo(ep_blo, 7)
			el_hi = bb_lshift_hi(ep_bhi, ep_blo, 7)
			er_lo = bb_lshift_lo(ep_blo, 9)
			er_hi = bb_lshift_hi(ep_bhi, ep_blo, 9)
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
	enemy_hi: number, enemy_lo: number
): boolean
	local pat_hi, pat_lo = pawn_attackers_to_square(square, by_color)
	if bit32.bor(
		bit32.band(board.pieces_lo[by_color][PAWN], pat_lo),
		bit32.band(board.pieces_hi[by_color][PAWN], pat_hi)
	) ~= 0 then return true end

	if bit32.bor(
		bit32.band(board.pieces_lo[by_color][KNIGHT], Attacks.knight_attacks_lo(square)),
		bit32.band(board.pieces_hi[by_color][KNIGHT], Attacks.knight_attacks_hi(square))
	) ~= 0 then return true end

	if bit32.bor(
		bit32.band(board.pieces_lo[by_color][KING], Attacks.king_attacks_lo(square)),
		bit32.band(board.pieces_hi[by_color][KING], Attacks.king_attacks_hi(square))
	) ~= 0 then return true end

	local occ_lo = bit32.bor(own_lo, enemy_lo)
	local occ_hi = bit32.bor(own_hi, enemy_hi)

	local ra_hi, ra_lo = Attacks.rook_attacks(square, 0, 0, occ_hi, occ_lo)
	local rq_lo = bit32.bor(board.pieces_lo[by_color][ROOK], board.pieces_lo[by_color][QUEEN])
	local rq_hi = bit32.bor(board.pieces_hi[by_color][ROOK], board.pieces_hi[by_color][QUEEN])
	if bit32.bor(bit32.band(ra_lo, rq_lo), bit32.band(ra_hi, rq_hi)) ~= 0 then return true end

	local ba_hi, ba_lo = Attacks.bishop_attacks(square, 0, 0, occ_hi, occ_lo)
	local bq_lo = bit32.bor(board.pieces_lo[by_color][BISHOP], board.pieces_lo[by_color][QUEEN])
	local bq_hi = bit32.bor(board.pieces_hi[by_color][BISHOP], board.pieces_hi[by_color][QUEEN])
	if bit32.bor(bit32.band(ba_lo, bq_lo), bit32.band(ba_hi, bq_hi)) ~= 0 then return true end

	return false
end

local function scan_sliders_for_pins_and_checks(
	board: Board, enemy: number, king_square: number,
	pieceType: number,
	occ_hi: number, occ_lo: number,
	own_hi: number, own_lo: number,
	pin_masks_lo: {[number]: number}, pin_masks_hi: {[number]: number},
	chk_lo: number, chk_hi: number
): (number, number)
	local LINE_LO = Attacks.LINE_LO
	local LINE_HI = Attacks.LINE_HI
	local sl_lo = board.pieces_lo[enemy][pieceType]
	local sl_hi = board.pieces_hi[enemy][pieceType]

	while sl_lo ~= 0 or sl_hi ~= 0 do
		local slider_sq = bb_countrz(sl_hi, sl_lo)
		local nlo = bb_sub_lo(sl_lo, 1)
		local nhi = bb_sub_hi(sl_hi, 0, sl_lo, 1)
		sl_lo = bit32.band(sl_lo, nlo)
		sl_hi = bit32.band(sl_hi, nhi)

		local line_lo = LINE_LO[slider_sq][king_square]
		local line_hi = LINE_HI[slider_sq][king_square]
		if line_lo ~= 0 or line_hi ~= 0 then
			local btwn_lo = bit32.band(line_lo or 0, bit32.band(NBIT_LO[slider_sq], NBIT_LO[king_square]))
			local btwn_hi = bit32.band(line_hi or 0, bit32.band(NBIT_HI[slider_sq], NBIT_HI[king_square]))
			local bo_lo = bit32.band(occ_lo, btwn_lo)
			local bo_hi = bit32.band(occ_hi, btwn_hi)
			if bo_lo == 0 and bo_hi == 0 then
				chk_lo = bit32.bor(chk_lo, BIT_LO[slider_sq])
				chk_hi = bit32.bor(chk_hi, BIT_HI[slider_sq])
			elseif popcount(bo_hi, bo_lo) == 1
				and bit32.bor(bit32.band(bo_lo, own_lo), bit32.band(bo_hi, own_hi)) ~= 0 then
				local pinned_sq = bb_countrz(bo_hi, bo_lo)
				pin_masks_lo[pinned_sq] = line_lo
				pin_masks_hi[pinned_sq] = line_hi
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
	local pin_lo: {[number]: number} = {}
	local pin_hi: {[number]: number} = {}

	local pat_hi, pat_lo = pawn_attackers_to_square(king_square, enemy)
	local chk_lo = bit32.bor(
		bit32.band(board.pieces_lo[enemy][PAWN],   pat_lo),
		bit32.band(board.pieces_lo[enemy][KNIGHT], Attacks.knight_attacks_lo(king_square))
	)
	local chk_hi = bit32.bor(
		bit32.band(board.pieces_hi[enemy][PAWN],   pat_hi),
		bit32.band(board.pieces_hi[enemy][KNIGHT], Attacks.knight_attacks_hi(king_square))
	)

	chk_hi, chk_lo = scan_sliders_for_pins_and_checks(board, enemy, king_square, ROOK,   occ_hi, occ_lo, own_hi, own_lo, pin_lo, pin_hi, chk_lo, chk_hi)
	chk_hi, chk_lo = scan_sliders_for_pins_and_checks(board, enemy, king_square, BISHOP, occ_hi, occ_lo, own_hi, own_lo, pin_lo, pin_hi, chk_lo, chk_hi)
	chk_hi, chk_lo = scan_sliders_for_pins_and_checks(board, enemy, king_square, QUEEN,  occ_hi, occ_lo, own_hi, own_lo, pin_lo, pin_hi, chk_lo, chk_hi)

	local num_checkers = popcount(chk_hi, chk_lo)

	if num_checkers >= 2 then
		return pin_lo, pin_hi, 0, 0, num_checkers, chk_lo, chk_hi
	elseif num_checkers == 0 then
		return pin_lo, pin_hi, 0xFFFFFFFF, 0xFFFFFFFF, num_checkers, chk_lo, chk_hi
	end

	local checker_sq  = bb_countrz(chk_hi, chk_lo)
	local checker_bit_lo = BIT_LO[checker_sq]
	local checker_bit_hi = BIT_HI[checker_sq]
	local checker_val    = board.pieceTable[checker_sq]
	local cm_lo: number
	local cm_hi: number

	if checker_val then
		local checker_type = bit32.rshift(checker_val, 6)
		if checker_type == BISHOP or checker_type == ROOK or checker_type == QUEEN then
			local line_lo = Attacks.LINE_LO[king_square][checker_sq]
			local line_hi = Attacks.LINE_HI[king_square][checker_sq]
			local btwn_lo = bit32.band(line_lo, bit32.band(NBIT_LO[king_square], NBIT_LO[checker_sq]))
			local btwn_hi = bit32.band(line_hi, bit32.band(NBIT_HI[king_square], NBIT_HI[checker_sq]))
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

	return pin_lo, pin_hi, cm_hi, cm_lo, num_checkers, chk_lo, chk_hi
end

local function is_en_passant_legal(board: Board, color: number, from: number, to: number, king_square: number): boolean
	local enemy = 1 - color
	local cap_sq = to - (if color == WHITE then 8 else -8)

	local own_lo = bit32.bor(bit32.band(board.occupied_lo[color], NBIT_LO[from]), BIT_LO[to])
	local own_hi = bit32.bor(bit32.band(board.occupied_hi[color], NBIT_HI[from]), BIT_HI[to])
	local enemy_lo = bit32.band(board.occupied_lo[enemy], NBIT_LO[cap_sq])
	local enemy_hi = bit32.band(board.occupied_hi[enemy], NBIT_HI[cap_sq])

	local cap_inv_lo = NBIT_LO[cap_sq]
	local cap_inv_hi = NBIT_HI[cap_sq]
	local pat_hi, pat_lo = pawn_attackers_to_square(king_square, enemy)
	if bit32.bor(
		bit32.band(board.pieces_lo[enemy][PAWN], bit32.band(cap_inv_lo, pat_lo)),
		bit32.band(board.pieces_hi[enemy][PAWN], bit32.band(cap_inv_hi, pat_hi))
	) ~= 0 then return false end

	if bit32.bor(
		bit32.band(board.pieces_lo[enemy][KNIGHT], Attacks.knight_attacks_lo(king_square)),
		bit32.band(board.pieces_hi[enemy][KNIGHT], Attacks.knight_attacks_hi(king_square))
	) ~= 0 then return false end

	if bit32.bor(
		bit32.band(board.pieces_lo[enemy][KING], Attacks.king_attacks_lo(king_square)),
		bit32.band(board.pieces_hi[enemy][KING], Attacks.king_attacks_hi(king_square))
	) ~= 0 then return false end

	local occ_lo = bit32.bor(own_lo, enemy_lo)
	local occ_hi = bit32.bor(own_hi, enemy_hi)

	local ra_hi, ra_lo = Attacks.rook_attacks(king_square, 0, 0, occ_hi, occ_lo)
	local rq_lo = bit32.bor(board.pieces_lo[enemy][ROOK], board.pieces_lo[enemy][QUEEN])
	local rq_hi = bit32.bor(board.pieces_hi[enemy][ROOK], board.pieces_hi[enemy][QUEEN])
	if bit32.bor(bit32.band(ra_lo, rq_lo), bit32.band(ra_hi, rq_hi)) ~= 0 then return false end

	local ba_hi, ba_lo = Attacks.bishop_attacks(king_square, 0, 0, occ_hi, occ_lo)
	local bq_lo = bit32.bor(board.pieces_lo[enemy][BISHOP], board.pieces_lo[enemy][QUEEN])
	local bq_hi = bit32.bor(board.pieces_hi[enemy][BISHOP], board.pieces_hi[enemy][QUEEN])
	if bit32.bor(bit32.band(ba_lo, bq_lo), bit32.band(ba_hi, bq_hi)) ~= 0 then return false end

	return true
end

local function add_pawn_moves_masked(
	moves: {number}, n: number,
	promo_lo: number, promo_hi: number,
	pin_lo: {[number]: number}, pin_hi: {[number]: number},
	tgt_lo: number, tgt_hi: number,
	from_offset: number, is_capture: boolean
): number
	local captured_bit   = if is_capture then 0x8000 else 0
	local promo_sentinel = bit32.lshift(5, 16)

	local bb_lo = bit32.band(tgt_lo, bit32.bnot(promo_lo))
	local bb_hi = bit32.band(tgt_hi, bit32.bnot(promo_hi))
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local to_sq = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)
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
		local to_sq = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)
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
	local bb_lo = board.pieces_lo[color][piece_type]
	local bb_hi = board.pieces_hi[color][piece_type]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from_sq = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
		bb_lo = bit32.band(bb_lo, nlo)
		bb_hi = bit32.band(bb_hi, nhi)

		local a_hi, a_lo = attack_func(from_sq, own_hi, own_lo, other_hi, other_lo)
		a_lo = bit32.band(a_lo, bit32.bnot(own_lo))
		a_hi = bit32.band(a_hi, bit32.bnot(own_hi))

		while a_lo ~= 0 or a_hi ~= 0 do
			local to_sq = bb_countrz(a_hi, a_lo)
			local alo2 = bb_sub_lo(a_lo, 1)
			local ahi2 = bb_sub_hi(a_hi, 0, a_lo, 1)
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
		local to = bb_countrz(q_hi, q_lo)
		local nlo = bb_sub_lo(q_lo, 1)
		local nhi = bb_sub_hi(q_hi, 0, q_lo, 1)
		q_lo = bit32.band(q_lo, nlo)
		q_hi = bit32.band(q_hi, nhi)
		n += 1
		moves[n] = bit32.bor(base_q, bit32.lshift(to, 6))
	end

	-- Captures (destinations occupied by enemy)
	local c_lo = bit32.band(a_lo, enemy_lo)
	local c_hi = bit32.band(a_hi, enemy_hi)
	while c_lo ~= 0 or c_hi ~= 0 do
		local to = bb_countrz(c_hi, c_lo)
		local nlo = bb_sub_lo(c_lo, 1)
		local nhi = bb_sub_hi(c_hi, 0, c_lo, 1)
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
	cm_hi: number, cm_lo: number,
	pin_lo: {[number]: number}, pin_hi: {[number]: number}
): number
	local bb_lo = board.pieces_lo[color][KNIGHT]
	local bb_hi = board.pieces_hi[color][KNIGHT]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
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
	cm_hi: number, cm_lo: number,
	pin_lo: {[number]: number}, pin_hi: {[number]: number}
): number
	local bb_lo = board.pieces_lo[color][BISHOP]
	local bb_hi = board.pieces_hi[color][BISHOP]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
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
	cm_hi: number, cm_lo: number,
	pin_lo: {[number]: number}, pin_hi: {[number]: number}
): number
	local bb_lo = board.pieces_lo[color][ROOK]
	local bb_hi = board.pieces_hi[color][ROOK]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
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
	cm_hi: number, cm_lo: number,
	pin_lo: {[number]: number}, pin_hi: {[number]: number}
): number
	local bb_lo = board.pieces_lo[color][QUEEN]
	local bb_hi = board.pieces_hi[color][QUEEN]
	while bb_lo ~= 0 or bb_hi ~= 0 do
		local from = bb_countrz(bb_hi, bb_lo)
		local nlo = bb_sub_lo(bb_lo, 1)
		local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
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
	pin_lo: {[number]: number}, pin_hi: {[number]: number},
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

	local king_lo = board.pieces_lo[color][KING]
	local king_hi = board.pieces_hi[color][KING]
	local king_square = 63 - bb_countlz(king_hi, king_lo)
	if king_square == -1 then return {} end

	-- Compute enemy non-slider attacks inline — no board mutation, no stale data.
	local enemy_atk_hi, enemy_atk_lo = compute_non_slider_attacks(board, enemy)

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
		n = generate_castle_moves(board, moves, n, color, enemy_atk_hi, enemy_atk_lo)
		return moves
	end

	local pin_lo, pin_hi, cm_hi, cm_lo, num_checkers, chk_lo, chk_hi =
		compute_check_and_pins(board, color, king_square)
	local king_only = num_checkers >= 2

	local own_lo   = board.occupied_lo[color]
	local own_hi   = board.occupied_hi[color]
	local enemy_lo = board.occupied_lo[enemy]
	local enemy_hi = board.occupied_hi[enemy]
	local empty_lo = bit32.bnot(board.occupied_lo[ALL])
	local empty_hi = bit32.bnot(board.occupied_hi[ALL])

	local checker_sq   = if num_checkers == 1 then bb_countrz(chk_hi, chk_lo) else -1
	local checker_val  = if checker_sq >= 0 then board.pieceTable[checker_sq] else nil
	local checker_type = if checker_val then bit32.rshift(checker_val, 6) else nil

	if not king_only then
		local pawns_lo = board.pieces_lo[color][PAWN]
		local pawns_hi = board.pieces_hi[color][PAWN]
		local push_dir   = if color == WHITE then 8 else -8
		local start_lo   = if color == WHITE then RANK_2_LO else RANK_7_LO
		local start_hi   = if color == WHITE then RANK_2_HI else RANK_7_HI
		local promo_lo   = if color == WHITE then RANK_8_LO else RANK_1_LO
		local promo_hi   = if color == WHITE then RANK_8_HI else RANK_1_HI

		local push_lo: number
		local push_hi: number
		if color == WHITE then
			push_lo = bit32.band(bit32.band(bb_lshift_lo(pawns_lo, 8), empty_lo), cm_lo)
			push_hi = bit32.band(bit32.band(bb_lshift_hi(pawns_hi, pawns_lo, 8), empty_hi), cm_hi)
		else
			push_lo = bit32.band(bit32.band(bb_rshift_lo(pawns_hi, pawns_lo, 8), empty_lo), cm_lo)
			push_hi = bit32.band(bit32.band(bb_rshift_hi(pawns_hi, 8), empty_hi), cm_hi)
		end

		local dbl_lo: number
		local dbl_hi: number
		if color == WHITE then
			dbl_lo = bit32.band(bit32.band(bit32.band(bb_lshift_lo(push_lo, 8), empty_lo), bb_lshift_lo(start_lo, 16)), cm_lo)
			dbl_hi = bit32.band(bit32.band(bit32.band(bb_lshift_hi(push_hi, push_lo, 8), empty_hi), bb_lshift_hi(start_hi, start_lo, 16)), cm_hi)
		else
			dbl_lo = bit32.band(bit32.band(bit32.band(bb_rshift_lo(push_hi, push_lo, 8), empty_lo), bb_rshift_lo(start_hi, start_lo, 16)), cm_lo)
			dbl_hi = bit32.band(bit32.band(bit32.band(bb_rshift_hi(push_hi, 8), empty_hi), bb_rshift_hi(start_hi, 16)), cm_hi)
		end

		local lc_lo, lc_hi, rc_lo, rc_hi: number
		if color == WHITE then
			lc_lo = bit32.band(bit32.band(bit32.band(bb_lshift_lo(pawns_lo, 7), NOT_FILE_H_LO), enemy_lo), cm_lo)
			lc_hi = bit32.band(bit32.band(bit32.band(bb_lshift_hi(pawns_hi, pawns_lo, 7), NOT_FILE_H_HI), enemy_hi), cm_hi)
			rc_lo = bit32.band(bit32.band(bit32.band(bb_lshift_lo(pawns_lo, 9), NOT_FILE_A_LO), enemy_lo), cm_lo)
			rc_hi = bit32.band(bit32.band(bit32.band(bb_lshift_hi(pawns_hi, pawns_lo, 9), NOT_FILE_A_HI), enemy_hi), cm_hi)
		else
			lc_lo = bit32.band(bit32.band(bit32.band(bb_rshift_lo(pawns_hi, pawns_lo, 7), NOT_FILE_A_LO), enemy_lo), cm_lo)
			lc_hi = bit32.band(bit32.band(bit32.band(bb_rshift_hi(pawns_hi, 7), NOT_FILE_A_HI), enemy_hi), cm_hi)
			rc_lo = bit32.band(bit32.band(bit32.band(bb_rshift_lo(pawns_hi, pawns_lo, 9), NOT_FILE_H_LO), enemy_lo), cm_lo)
			rc_hi = bit32.band(bit32.band(bit32.band(bb_rshift_hi(pawns_hi, 9), NOT_FILE_H_HI), enemy_hi), cm_hi)
		end

		n = add_pawn_moves_masked(moves, n, promo_lo, promo_hi, pin_lo, pin_hi, push_lo, push_hi, push_dir, false)
		n = add_pawn_moves_masked(moves, n, promo_lo, promo_hi, pin_lo, pin_hi, dbl_lo,  dbl_hi,  push_dir * 2, false)
		n = add_pawn_moves_masked(moves, n, promo_lo, promo_hi, pin_lo, pin_hi, lc_lo, lc_hi, if color == WHITE then 7 else -7, true)
		n = add_pawn_moves_masked(moves, n, promo_lo, promo_hi, pin_lo, pin_hi, rc_lo, rc_hi, if color == WHITE then 9 else -9, true)

		if board.en_passant_square and board.en_passant_square > 0 then
			local ep = board.en_passant_square
			local ep_blo = BIT_LO[ep]
			local ep_bhi = BIT_HI[ep]

			local el_lo: number
			local el_hi: number
			local er_lo: number
			local er_hi: number
			if color == WHITE then
				el_lo = bb_rshift_lo(ep_bhi, ep_blo, 7)
				el_hi = bb_rshift_hi(ep_bhi, 7)
				er_lo = bb_rshift_lo(ep_bhi, ep_blo, 9)
				er_hi = bb_rshift_hi(ep_bhi, 9)
			else
				el_lo = bb_lshift_lo(ep_blo, 7)
				el_hi = bb_lshift_hi(ep_bhi, ep_blo, 7)
				er_lo = bb_lshift_lo(ep_blo, 9)
				er_hi = bb_lshift_hi(ep_bhi, ep_blo, 9)
			end

			if bit32.bor(bit32.band(pawns_lo, el_lo), bit32.band(pawns_hi, el_hi)) ~= 0 then
				local from = ep - (if color == WHITE then 7 else -7)
				local from_rank = bit32.rshift(from, 3)
				local valid_rank = if color == WHITE then 4 else 3
				if from_rank == valid_rank then
					n = try_ep_helper(board, moves, n, from, pin_lo, pin_hi, num_checkers, checker_type, checker_sq, color, king_square)
				end
			end
			if bit32.bor(bit32.band(pawns_lo, er_lo), bit32.band(pawns_hi, er_hi)) ~= 0 then
				local from = ep - (if color == WHITE then 9 else -9)
				local from_rank = bit32.rshift(from, 3)
				local valid_rank = if color == WHITE then 4 else 3
				if from_rank == valid_rank then
					n = try_ep_helper(board, moves, n, from, pin_lo, pin_hi, num_checkers, checker_type, checker_sq, color, king_square)
				end
			end
		end

		n = add_knight_moves(board, moves, n, color, own_hi, own_lo, enemy_hi, enemy_lo, cm_hi, cm_lo, pin_lo, pin_hi)
		n = add_bishop_moves(board, moves, n, color, own_hi, own_lo, enemy_hi, enemy_lo, cm_hi, cm_lo, pin_lo, pin_hi)
		n = add_rook_moves  (board, moves, n, color, own_hi, own_lo, enemy_hi, enemy_lo, cm_hi, cm_lo, pin_lo, pin_hi)
		n = add_queen_moves (board, moves, n, color, own_hi, own_lo, enemy_hi, enemy_lo, cm_hi, cm_lo, pin_lo, pin_hi)
	end

	-- King moves
	do
		local ka_lo = bit32.band(Attacks.king_attacks_lo(king_square), bit32.bnot(own_lo))
		local ka_hi = bit32.band(Attacks.king_attacks_hi(king_square), bit32.bnot(own_hi))
		local bb_lo = ka_lo
		local bb_hi = ka_hi
		while bb_lo ~= 0 or bb_hi ~= 0 do
			local to = bb_countrz(bb_hi, bb_lo)
			local nlo = bb_sub_lo(bb_lo, 1)
			local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
			bb_lo = bit32.band(bb_lo, nlo)
			bb_hi = bit32.band(bb_hi, nhi)

			local to_blo = BIT_LO[to]
			local to_bhi = BIT_HI[to]
			local new_own_lo = bit32.bor(bit32.band(own_lo, NBIT_LO[king_square]), to_blo)
			local new_own_hi = bit32.bor(bit32.band(own_hi, NBIT_HI[king_square]), to_bhi)
			local captures = get_bit(enemy_hi, enemy_lo, to)
			local new_enemy_lo = if captures then bit32.band(enemy_lo, NBIT_LO[to]) else enemy_lo
			local new_enemy_hi = if captures then bit32.band(enemy_hi, NBIT_HI[to]) else enemy_hi

			if not is_square_attacked_with_occupancy(board, to, enemy,
				new_own_hi, new_own_lo, new_enemy_hi, new_enemy_lo) then
				n += 1
				moves[n] = Move.create(king_square, to, KING, captures)
			end
		end
	end

	if num_checkers == 0 then
		n = generate_castle_moves(board, moves, n, color, enemy_atk_hi, enemy_atk_lo)
	end

	return moves
end

function MoveGen.generate_legal_moves_from(board: Board, from: number, filePseudoLegal: boolean?, color: number?)
	local allMoves = MoveGen.generate_legal_moves(board, filePseudoLegal, color)
	local moves = {}
	local n = 0
	for _, move in allMoves do
		if Move.getFrom(move) == from then
			n += 1
			moves[n] = move
		end
	end
	return moves
end

return { MoveGen = MoveGen }

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

local RANK_1 = Utils.RANK_1
local RANK_2 = Utils.RANK_2
local RANK_7 = Utils.RANK_7
local RANK_8 = Utils.RANK_8
local NOT_FILE_A  = Utils.NOT_FILE_A
local NOT_FILE_H  = Utils.NOT_FILE_H
local NOT_FILE_AB = Utils.NOT_FILE_AB
local NOT_FILE_GH = Utils.NOT_FILE_GH

local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

local LINE = Attacks.LINE

local get_bit    = Utils.get_bit
local get_bit32  = Utils.get_bit32
local popcount   = Utils.popcount

local bishop_attacks         = Attacks.bishop_attacks
local rook_attacks           = Attacks.rook_attacks
local queen_attacks          = Attacks.queen_attacks
local knight_attacks         = Attacks.knight_attacks
local king_attacks           = Attacks.king_attacks
local between_squares_rook   = Attacks.between_squares_rook
local between_squares_bishop = Attacks.between_squares_bishop

local PROMO_SENTINEL = bit32.lshift(5, 16)  -- piece_type=5 means "no promotion"
local CAPTURED_BIT   = 0x8000

export type Board = Utils.Board

local MoveGen = {}

function MoveGen.attacked_occupancy(board: Board, by_color: number)
	local atk_base = by_color * ATK_STRIDE
	local atk = board.attacked
	atk[atk_base + ATTACKED_ALL] = integer.bor(
		atk[atk_base + ROOK],
		atk[atk_base + BISHOP],
		atk[atk_base + QUEEN],
		atk[atk_base + KNIGHT],
		atk[atk_base + KING],
		atk[atk_base + PAWN]
	)
end

local function pawn_attackers_to_square(square: number, enemy_color: number): integer
	local k = Utils.unit_board(square)
	if enemy_color == WHITE then
		return integer.bor(
			integer.band(integer.rshift(k, 7i), NOT_FILE_A),
			integer.band(integer.rshift(k, 9i), NOT_FILE_H)
		)
	else
		return integer.bor(
			integer.band(integer.lshift(k, 7i), NOT_FILE_H),
			integer.band(integer.lshift(k, 9i), NOT_FILE_A)
		)
	end
end

local function compute_non_slider_attacks(board: Board, by_color: number): integer
	local kn = board.pieces[by_color * PIECE_STRIDE + KNIGHT]
	local kg = board.pieces[by_color * PIECE_STRIDE + KING]
	local pw = board.pieces[by_color * PIECE_STRIDE + PAWN]

	local kn_atk = Attacks.bulk_knight_attacks(kn)
	local kg_atk = Attacks.bulk_king_attacks(kg)
	local pw_atk = Attacks.bulk_pawn_attacks(pw, by_color)

	return integer.bor(kn_atk, kg_atk, pw_atk)
end

function MoveGen.is_square_attacked(board: Board, square: number, by_color: number): boolean
	local base = by_color * PIECE_STRIDE
	local pat = pawn_attackers_to_square(square, by_color)
	if integer.band(board.pieces[base + PAWN], pat) ~= 0i then return true end

	if integer.band(board.pieces[base + KNIGHT], knight_attacks(square)) ~= 0i then return true end
	if integer.band(board.pieces[base + KING],   king_attacks(square))   ~= 0i then return true end

	local occ = board.occupied[ALL]

	local ra = rook_attacks(square, 0i, occ)
	local rq = integer.bor(board.pieces[base + ROOK], board.pieces[base + QUEEN])
	if integer.band(ra, rq) ~= 0i then return true end

	local ba = bishop_attacks(square, 0i, occ)
	local bq = integer.bor(board.pieces[base + BISHOP], board.pieces[base + QUEEN])
	if integer.band(ba, bq) ~= 0i then return true end

	return false
end

local CASTLE_MOVE_WK = Move.create(4,  6,  KING, false, nil, false, true, true)
local CASTLE_MOVE_WQ = Move.create(4,  2,  KING, false, nil, false, true, false)
local CASTLE_MOVE_BK = Move.create(60, 62, KING, false, nil, false, true, true)
local CASTLE_MOVE_BQ = Move.create(60, 58, KING, false, nil, false, true, false)

local CM_WK_np = 0x60i
local CM_WQ_np = 0x0Ei
local CM_BK_np = 0x6000_0000_0000_0000i
local CM_BQ_np = 0x0E00_0000_0000_0000i

local function generate_castle_moves(board: Board, moves: {number}, n: number, color: number): number
	local occ = board.occupied[ALL]
	local enemy = 1 - color

	if color == WHITE then
		if get_bit32(board.castling_rights, WK)
			and integer.band(occ, CM_WK_np) == 0i
			and not MoveGen.is_square_attacked(board, 4, enemy)
			and not MoveGen.is_square_attacked(board, 5, enemy)
			and not MoveGen.is_square_attacked(board, 6, enemy) then
			n += 1; moves[n] = CASTLE_MOVE_WK
		end
		if get_bit32(board.castling_rights, WQ)
			and integer.band(occ, CM_WQ_np) == 0i
			and not MoveGen.is_square_attacked(board, 4, enemy)
			and not MoveGen.is_square_attacked(board, 3, enemy)
			and not MoveGen.is_square_attacked(board, 2, enemy) then
			n += 1; moves[n] = CASTLE_MOVE_WQ
		end
	else
		if get_bit32(board.castling_rights, BK)
			and integer.band(occ, CM_BK_np) == 0i
			and not MoveGen.is_square_attacked(board, 60, enemy)
			and not MoveGen.is_square_attacked(board, 61, enemy)
			and not MoveGen.is_square_attacked(board, 62, enemy) then
			n += 1; moves[n] = CASTLE_MOVE_BK
		end
		if get_bit32(board.castling_rights, BQ)
			and integer.band(occ, CM_BQ_np) == 0i
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
	promo: integer,
	tgt: integer,
	from_offset: number, is_capture: boolean
): number
	local captured_bit   = if is_capture then 0x8000 else 0
	local promo_sentinel = bit32.lshift(5, 16)

	local bb = integer.band(tgt, integer.bnot(promo))
	while bb ~= 0i do
		local to_sq = integer.tonumber(integer.countrz(bb))
		bb = integer.band(bb, integer.sub(bb, 1i))
		n += 1
		moves[n] = bit32.bor(to_sq - from_offset, bit32.lshift(to_sq, 6), captured_bit, promo_sentinel)
	end

	bb = integer.band(tgt, promo)
	while bb ~= 0i do
		local to_sq = integer.tonumber(integer.countrz(bb))
		bb = integer.band(bb, integer.sub(bb, 1i))
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
	local pawns = board.pieces[color * PIECE_STRIDE + PAWN]
	local all   = board.occupied[ALL]
	local empty = integer.bnot(all)
	local enemy = board.occupied[1 - color]

	local push_dir = if color == WHITE then 8 else -8
	local start    = if color == WHITE then RANK_2 else RANK_7
	local promo    = if color == WHITE then RANK_8 else RANK_1

	local push: integer
	if color == WHITE then
		push = integer.band(integer.lshift(pawns, 8i), empty)
	else
		push = integer.band(integer.rshift(pawns, 8i), empty)
	end

	local dbl: integer
	if color == WHITE then
		dbl = integer.band(integer.lshift(push, 8i), empty, integer.lshift(start, 16i))
	else
		dbl = integer.band(integer.rshift(push, 8i), empty, integer.rshift(start, 16i))
	end

	local lc, rc: integer
	if color == WHITE then
		lc = integer.band(integer.lshift(pawns, 7i), NOT_FILE_H, enemy)
		rc = integer.band(integer.lshift(pawns, 9i), NOT_FILE_A, enemy)
	else
		lc = integer.band(integer.rshift(pawns, 7i), NOT_FILE_A, enemy)
		rc = integer.band(integer.rshift(pawns, 9i), NOT_FILE_H, enemy)
	end

	n = add_pawn_moves(moves, n, promo, push, push_dir, false)
	n = add_pawn_moves(moves, n, promo, dbl,  push_dir * 2, false)
	n = add_pawn_moves(moves, n, promo, lc, if color == WHITE then 7 else -7, true)
	n = add_pawn_moves(moves, n, promo, rc, if color == WHITE then 9 else -9, true)

	if board.en_passant_square and board.en_passant_square > 0 then
		local ep = board.en_passant_square
		local ep_b = Utils.unit_board(ep)

		local el: integer
		local er: integer
		if color == WHITE then
			el = integer.rshift(ep_b, 7i)
			er = integer.rshift(ep_b, 9i)
		else
			el = integer.lshift(ep_b, 7i)
			er = integer.lshift(ep_b, 9i)
		end

		if integer.band(pawns, el) ~= 0i then
			local from = ep - (if color == WHITE then 7 else -7)
			local from_rank = bit32.rshift(from, 3)
			local valid_rank = if color == WHITE then 4 else 3
			if from_rank == valid_rank then
				n += 1
				moves[n] = bit32.bor(from, bit32.lshift(ep, 6), bit32.lshift(PAWN, 12), 0x8000, 0x80000, PROMO_SENTINEL)
			end
		end
		if integer.band(pawns, er) ~= 0i then
			local from = ep - (if color == WHITE then 9 else -9)
			local from_rank = bit32.rshift(from, 3)
			local valid_rank = if color == WHITE then 4 else 3
			if from_rank == valid_rank then
				n += 1
				moves[n] = bit32.bor(from, bit32.lshift(ep, 6), bit32.lshift(PAWN, 12), 0x8000, 0x80000, PROMO_SENTINEL)
			end
		end
	end
	return n
end

local function is_square_attacked_with_occupancy(
	board: Board, square: number, by_color: number,
	own: integer,
	enemy: integer,
	captured_sq: number?
): boolean
	local cap_inv = if captured_sq then integer.bnot(Utils.unit_board(captured_sq)) else -1i

	local base = by_color * PIECE_STRIDE

	-- Pawn attacks
	local pat = pawn_attackers_to_square(square, by_color)
	if integer.band(board.pieces[base + PAWN], integer.band(pat, cap_inv)) ~= 0i then
		return true
	end

	-- Knight attacks
	if integer.band(board.pieces[base + KNIGHT], integer.band(knight_attacks(square), cap_inv)) ~= 0i then
		return true
	end

	-- King attacks (the enemy king can never be the captured piece, no masking needed)
	if integer.band(board.pieces[base + KING], king_attacks(square)) ~= 0i then
		return true
	end

	-- Combined occupancy (captured piece already removed from enemy by caller)
	local occ = integer.bor(own, enemy)

	-- Rook + Queen attacks
	local ra = rook_attacks(square, 0i, occ)
	local rq = integer.band(integer.bor(board.pieces[base + ROOK], board.pieces[base + QUEEN]), cap_inv)
	if integer.band(ra, rq) ~= 0i then
		return true
	end

	-- Bishop + Queen attacks
	local ba = bishop_attacks(square, 0i, occ)
	local bq = integer.band(integer.bor(board.pieces[base + BISHOP], board.pieces[base + QUEEN]), cap_inv)
	if integer.band(ba, bq) ~= 0i then
		return true
	end

	return false
end

local pin = table.create(64, 0i)
for i = 0, 63 do pin[i] = 0i end

local function scan_sliders_for_pins_and_checks(
	board: Board, enemy: number, king_square: number,
	pieceType: number,
	occ: integer,
	own: integer,
	chk: integer
): integer
	local sl = board.pieces[enemy * PIECE_STRIDE + pieceType]

	while sl ~= 0i do
		local slider_sq = integer.tonumber(integer.countrz(sl))
		sl = integer.band(sl, integer.sub(sl, 1i))

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
			local btwn: integer
			if pieceType == ROOK then
				btwn = between_squares_rook(king_square, slider_sq)
			elseif pieceType == BISHOP then
				btwn = between_squares_bishop(king_square, slider_sq)
			else
				btwn = between_squares_rook(king_square, slider_sq)
				if btwn == 0i then
					btwn = between_squares_bishop(king_square, slider_sq)
				end
			end
			local bo = integer.band(occ, btwn)

			-- popcount(bo) == 1 check
			local hasOne = bo ~= 0i and integer.band(bo, integer.sub(bo, 1i)) == 0i

			if bo == 0i then
				chk = integer.bor(chk, Utils.unit_board(slider_sq))
			elseif hasOne and integer.band(bo, own) ~= 0i then
				local pinned_sq = integer.tonumber(integer.countrz(bo))
				local king_b = Utils.unit_board(king_square)
				local slider_b = Utils.unit_board(slider_sq)
				pin[pinned_sq] = integer.bor(btwn, king_b, slider_b)
			end
		end
	end
	return chk
end

local function compute_check_and_pins(board: Board, color: number, king_square: number)
	local enemy = 1 - color
	local occ   = board.occupied[ALL]
	local own   = board.occupied[color]
	for i = 0, 63 do pin[i] = 0i end

	local pat = pawn_attackers_to_square(king_square, enemy)
	local chk = integer.bor(
		integer.band(board.pieces[enemy * PIECE_STRIDE + PAWN],   pat),
		integer.band(board.pieces[enemy * PIECE_STRIDE + KNIGHT], knight_attacks(king_square))
	)

	chk = scan_sliders_for_pins_and_checks(board, enemy, king_square, ROOK,   occ, own, chk)
	chk = scan_sliders_for_pins_and_checks(board, enemy, king_square, BISHOP, occ, own, chk)
	chk = scan_sliders_for_pins_and_checks(board, enemy, king_square, QUEEN,  occ, own, chk)

	local num_checkers = popcount(chk)

	if num_checkers >= 2 then
		return 0i, 0i, num_checkers, chk
	elseif num_checkers == 0 then
		return -1i, -1i, num_checkers, chk
	end

	local checker_sq = integer.tonumber(integer.countrz(chk))
	local checker_bit = Utils.unit_board(checker_sq)
	local checker_val = board.pieceTable[checker_sq]
	local cm: integer

	if checker_val then
		local checker_type = bit32.rshift(checker_val, 6)
		if checker_type == BISHOP or checker_type == ROOK or checker_type == QUEEN then
			local btwn: integer
			if checker_type == ROOK then
				btwn = between_squares_rook(king_square, checker_sq)
			elseif checker_type == BISHOP then
				btwn = between_squares_bishop(king_square, checker_sq)
			else
				btwn = between_squares_rook(king_square, checker_sq)
				if btwn == 0i then
					btwn = between_squares_bishop(king_square, checker_sq)
				end
			end
			cm = integer.bor(btwn, checker_bit)
		else
			cm = checker_bit
		end
	else
		cm = checker_bit
	end

	return cm, cm, num_checkers, chk
end

local function is_en_passant_legal(board: Board, color: number, from: number, to: number, king_square: number): boolean
	local enemy = 1 - color
	local cap_sq = to - (if color == WHITE then 8 else -8)

	local own = integer.bor(integer.band(board.occupied[color], integer.bnot(Utils.unit_board(from))), Utils.unit_board(to))
	local enemy_bb = integer.band(board.occupied[enemy], integer.bnot(Utils.unit_board(cap_sq)))

	local cap_inv = integer.bnot(Utils.unit_board(cap_sq))
	local pat = pawn_attackers_to_square(king_square, enemy)
	if integer.band(board.pieces[enemy * PIECE_STRIDE + PAWN], integer.band(cap_inv, pat)) ~= 0i then return false end
	if integer.band(board.pieces[enemy * PIECE_STRIDE + KNIGHT], knight_attacks(king_square)) ~= 0i then return false end
	if integer.band(board.pieces[enemy * PIECE_STRIDE + KING], king_attacks(king_square)) ~= 0i then return false end

	local occ = integer.bor(own, enemy_bb)

	local ra = rook_attacks(king_square, 0i, occ)
	local rq = integer.bor(board.pieces[enemy * PIECE_STRIDE + ROOK], board.pieces[enemy * PIECE_STRIDE + QUEEN])
	if integer.band(ra, rq) ~= 0i then return false end

	local ba = bishop_attacks(king_square, 0i, occ)
	local bq = integer.bor(board.pieces[enemy * PIECE_STRIDE + BISHOP], board.pieces[enemy * PIECE_STRIDE + QUEEN])
	if integer.band(ba, bq) ~= 0i then return false end

	return true
end

local function add_pawn_moves_masked(
	moves: {number}, n: number,
	promo: integer,
	tgt: integer,
	from_offset: number, is_capture: boolean
): number
	local captured_bit = if is_capture then CAPTURED_BIT else 0

	local bb = integer.band(tgt, integer.bnot(promo))
	while bb ~= 0i do
		local to_sq = integer.tonumber(integer.countrz(bb))
		bb = integer.band(bb, integer.sub(bb, 1i))
		local from_sq = to_sq - from_offset
		local pm = pin[from_sq]
		if pm == 0i or integer.band(pm, Utils.unit_board(to_sq)) ~= 0i then
			n += 1
			moves[n] = bit32.bor(from_sq, bit32.lshift(to_sq, 6), bit32.lshift(PAWN, 12), captured_bit, PROMO_SENTINEL)
		end
	end

	bb = integer.band(tgt, promo)
	while bb ~= 0i do
		local to_sq = integer.tonumber(integer.countrz(bb))
		bb = integer.band(bb, integer.sub(bb, 1i))
		local from_sq = to_sq - from_offset
		local pm = pin[from_sq]
		if pm == 0i or integer.band(pm, Utils.unit_board(to_sq)) ~= 0i then
			local base = bit32.bor(from_sq, bit32.lshift(to_sq, 6), bit32.lshift(PAWN, 12), captured_bit)
			moves[n+1] = bit32.bor(base, 0x10000)
			moves[n+2] = bit32.bor(base, 0x20000)
			moves[n+3] = bit32.bor(base, 0x30000)
			moves[n+4] = bit32.bor(base, 0x40000)
			n += 4
		end
	end
	return n
end

local function emit_sliding_moves(
	moves: {number}, n: number,
	from: number, piece_type: number,
	a: integer,
	enemy: integer
): number
	local base_q = bit32.bor(from, bit32.lshift(piece_type, 12), PROMO_SENTINEL)
	local base_c = bit32.bor(base_q, CAPTURED_BIT)

	-- Quiet moves (destinations not occupied by enemy)
	local q = integer.band(a, integer.bnot(enemy))
	while q ~= 0i do
		local to = integer.tonumber(integer.countrz(q))
		q = integer.band(q, integer.sub(q, 1i))
		n += 1
		moves[n] = bit32.bor(base_q, bit32.lshift(to, 6))
	end

	-- Captures (destinations occupied by enemy)
	local c = integer.band(a, enemy)
	while c ~= 0i do
		local to = integer.tonumber(integer.countrz(c))
		c = integer.band(c, integer.sub(c, 1i))
		n += 1
		moves[n] = bit32.bor(base_c, bit32.lshift(to, 6))
	end

	return n
end

local function add_knight_moves(
	board: Board, moves: {number}, n: number, color: number,
	own: integer,
	enemy: integer,
	cm: integer
): number
	local bb = board.pieces[color * PIECE_STRIDE + KNIGHT]
	while bb ~= 0i do
		local from = integer.tonumber(integer.countrz(bb))
		bb = integer.band(bb, integer.sub(bb, 1i))
		if pin[from] ~= 0i then continue end

		local a = integer.band(integer.band(knight_attacks(from), integer.bnot(own)), cm)
		n = emit_sliding_moves(moves, n, from, KNIGHT, a, enemy)
	end
	return n
end

local function add_bishop_moves(
	board: Board, moves: {number}, n: number, color: number,
	own: integer,
	enemy: integer,
	cm: integer
): number
	local bb = board.pieces[color * PIECE_STRIDE + BISHOP]
	while bb ~= 0i do
		local from = integer.tonumber(integer.countrz(bb))
		bb = integer.band(bb, integer.sub(bb, 1i))

		local a = bishop_attacks(from, 0i, integer.bor(own, enemy))
		a = integer.band(a, integer.band(integer.bnot(own), cm))
		local pm = pin[from]
		if pm ~= 0i then
			a = integer.band(a, pm)
		end

		n = emit_sliding_moves(moves, n, from, BISHOP, a, enemy)
	end
	return n
end

local function add_rook_moves(
	board: Board, moves: {number}, n: number, color: number,
	own: integer,
	enemy: integer,
	cm: integer
): number
	local bb = board.pieces[color * PIECE_STRIDE + ROOK]
	while bb ~= 0i do
		local from = integer.tonumber(integer.countrz(bb))
		bb = integer.band(bb, integer.sub(bb, 1i))

		local a = rook_attacks(from, 0i, integer.bor(own, enemy))
		a = integer.band(a, integer.band(integer.bnot(own), cm))
		local pm = pin[from]
		if pm ~= 0i then
			a = integer.band(a, pm)
		end

		n = emit_sliding_moves(moves, n, from, ROOK, a, enemy)
	end
	return n
end

local function add_queen_moves(
	board: Board, moves: {number}, n: number, color: number,
	own: integer,
	enemy: integer,
	cm: integer
): number
	local bb = board.pieces[color * PIECE_STRIDE + QUEEN]
	while bb ~= 0i do
		local from = integer.tonumber(integer.countrz(bb))
		bb = integer.band(bb, integer.sub(bb, 1i))

		local a = queen_attacks(from, 0i, integer.bor(own, enemy))
		a = integer.band(a, integer.band(integer.bnot(own), cm))
		local pm = pin[from]
		if pm ~= 0i then
			a = integer.band(a, pm)
		end

		n = emit_sliding_moves(moves, n, from, QUEEN, a, enemy)
	end
	return n
end

local function try_ep_helper(
	board: Board, moves: {number}, n: number,
	from: number,
	num_checkers: number, checker_type: number?, checker_sq: number,
	color: number, king_square: number
): number
	local pm = pin[from]
	local ep_sq = board.en_passant_square
	if not ep_sq then return n end
	if pm ~= 0i then
		local allowed = integer.band(pm, Utils.unit_board(ep_sq)) ~= 0i
		if not allowed then return n end
	end

	if num_checkers == 1 then
		if checker_type ~= PAWN then return n end
		if ep_sq - (if color == WHITE then 8 else -8) ~= checker_sq then return n end
	elseif num_checkers > 1 then
		return n
	end

	if is_en_passant_legal(board, color, from, ep_sq, king_square) then
		n += 1
		moves[n] = bit32.bor(from, bit32.lshift(ep_sq, 6), bit32.lshift(PAWN, 12), CAPTURED_BIT, 0x80000, PROMO_SENTINEL)
	end
	return n
end

function MoveGen.generate_legal_moves(board: Board, filePseudoLegal: boolean?, givenColor: number?): {number}
	local color = givenColor or board.side_to_move
	local enemy = 1 - color

	local moves = table.create(80)
	local n = 0

	local king_bb = board.pieces[color * PIECE_STRIDE + KING]
	if king_bb == 0i then return {} end
	local king_square = integer.tonumber(integer.countrz(king_bb))

	if filePseudoLegal then
		local own   = board.occupied[color]
		local other = board.occupied[enemy]

		n = generate_pawn_moves(board, moves, n, color)

		-- Knights
		local kn = board.pieces[color * PIECE_STRIDE + KNIGHT]
		while kn ~= 0i do
			local from = integer.tonumber(integer.countrz(kn))
			kn = integer.band(kn, integer.sub(kn, 1i))
			local a = integer.band(knight_attacks(from), integer.bnot(own))
			while a ~= 0i do
				local to = integer.tonumber(integer.countrz(a))
				a = integer.band(a, integer.sub(a, 1i))
				local cap = if integer.band(other, Utils.unit_board(to)) ~= 0i then CAPTURED_BIT else 0
				n += 1; moves[n] = bit32.bor(from, bit32.lshift(to, 6), bit32.lshift(KNIGHT, 12), cap, PROMO_SENTINEL)
			end
		end

		-- Bishops
		local bi = board.pieces[color * PIECE_STRIDE + BISHOP]
		while bi ~= 0i do
			local from = integer.tonumber(integer.countrz(bi))
			bi = integer.band(bi, integer.sub(bi, 1i))
			local a = integer.band(bishop_attacks(from, 0i, integer.bor(own, other)), integer.bnot(own))
			while a ~= 0i do
				local to = integer.tonumber(integer.countrz(a))
				a = integer.band(a, integer.sub(a, 1i))
				local cap = if integer.band(other, Utils.unit_board(to)) ~= 0i then CAPTURED_BIT else 0
				n += 1; moves[n] = bit32.bor(from, bit32.lshift(to, 6), bit32.lshift(BISHOP, 12), cap, PROMO_SENTINEL)
			end
		end

		-- Rooks
		local ro = board.pieces[color * PIECE_STRIDE + ROOK]
		while ro ~= 0i do
			local from = integer.tonumber(integer.countrz(ro))
			ro = integer.band(ro, integer.sub(ro, 1i))
			local a = integer.band(rook_attacks(from, 0i, integer.bor(own, other)), integer.bnot(own))
			while a ~= 0i do
				local to = integer.tonumber(integer.countrz(a))
				a = integer.band(a, integer.sub(a, 1i))
				local cap = if integer.band(other, Utils.unit_board(to)) ~= 0i then CAPTURED_BIT else 0
				n += 1; moves[n] = bit32.bor(from, bit32.lshift(to, 6), bit32.lshift(ROOK, 12), cap, PROMO_SENTINEL)
			end
		end

		-- Queens
		local qu = board.pieces[color * PIECE_STRIDE + QUEEN]
		while qu ~= 0i do
			local from = integer.tonumber(integer.countrz(qu))
			qu = integer.band(qu, integer.sub(qu, 1i))
			local a = integer.band(queen_attacks(from, 0i, integer.bor(own, other)), integer.bnot(own))
			while a ~= 0i do
				local to = integer.tonumber(integer.countrz(a))
				a = integer.band(a, integer.sub(a, 1i))
				local cap = if integer.band(other, Utils.unit_board(to)) ~= 0i then CAPTURED_BIT else 0
				n += 1; moves[n] = bit32.bor(from, bit32.lshift(to, 6), bit32.lshift(QUEEN, 12), cap, PROMO_SENTINEL)
			end
		end

		-- King
		local ki = board.pieces[color * PIECE_STRIDE + KING]
		while ki ~= 0i do
			local from = integer.tonumber(integer.countrz(ki))
			ki = integer.band(ki, integer.sub(ki, 1i))
			local a = integer.band(king_attacks(from), integer.bnot(own))
			while a ~= 0i do
				local to = integer.tonumber(integer.countrz(a))
				a = integer.band(a, integer.sub(a, 1i))
				local cap = if integer.band(other, Utils.unit_board(to)) ~= 0i then CAPTURED_BIT else 0
				n += 1; moves[n] = bit32.bor(from, bit32.lshift(to, 6), bit32.lshift(KING, 12), cap, PROMO_SENTINEL)
			end
		end

		n = generate_castle_moves(board, moves, n, color)
		return moves
	end

	local cm, _, num_checkers, chk = compute_check_and_pins(board, color, king_square)
	local king_only = num_checkers >= 2

	local own   = board.occupied[color]
	local enemy_bb = board.occupied[enemy]
	local empty = integer.bnot(board.occupied[ALL])

	local checker_sq   = if num_checkers == 1 then integer.tonumber(integer.countrz(chk)) else -1
	local checker_val  = if checker_sq >= 0 then board.pieceTable[checker_sq] else nil
	local checker_type = if checker_val then bit32.rshift(checker_val, 6) else nil

	if not king_only then
		local pawns = board.pieces[color * PIECE_STRIDE + PAWN]
		local push_dir   = if color == WHITE then 8 else -8
		local start   = if color == WHITE then RANK_2 else RANK_7
		local promo   = if color == WHITE then RANK_8 else RANK_1

		local raw_push: integer
		local push: integer
		if color == WHITE then
			raw_push = integer.band(integer.lshift(pawns, 8i), empty)
			push = integer.band(raw_push, cm)
		else
			raw_push = integer.band(integer.rshift(pawns, 8i), empty)
			push = integer.band(raw_push, cm)
		end

		local dbl: integer
		if color == WHITE then
			dbl = integer.band(integer.lshift(raw_push, 8i), empty, integer.lshift(start, 16i))
		else
			dbl = integer.band(integer.rshift(raw_push, 8i), empty, integer.rshift(start, 16i))
		end
		dbl = integer.band(dbl, cm)

		local lc, rc: integer
		if color == WHITE then
			lc = integer.band(integer.lshift(pawns, 7i), NOT_FILE_H, enemy_bb, cm)
			rc = integer.band(integer.lshift(pawns, 9i), NOT_FILE_A, enemy_bb, cm)
		else
			lc = integer.band(integer.rshift(pawns, 7i), NOT_FILE_A, enemy_bb, cm)
			rc = integer.band(integer.rshift(pawns, 9i), NOT_FILE_H, enemy_bb, cm)
		end

		n = add_pawn_moves_masked(moves, n, promo, push, push_dir, false)
		n = add_pawn_moves_masked(moves, n, promo, dbl,  push_dir * 2, false)
		n = add_pawn_moves_masked(moves, n, promo, lc, if color == WHITE then 7 else -7, true)
		n = add_pawn_moves_masked(moves, n, promo, rc, if color == WHITE then 9 else -9, true)

		if board.en_passant_square and board.en_passant_square > 0 then
			local ep = board.en_passant_square
			local ep_b = Utils.unit_board(ep)

			local el: integer
			local er: integer
			if color == WHITE then
				el = integer.rshift(ep_b, 7i)
				er = integer.rshift(ep_b, 9i)
			else
				el = integer.lshift(ep_b, 7i)
				er = integer.lshift(ep_b, 9i)
			end

			if integer.band(pawns, el) ~= 0i then
				local from = ep - (if color == WHITE then 7 else -7)
				local from_rank = bit32.rshift(from, 3)
				local valid_rank = if color == WHITE then 4 else 3
				if from_rank == valid_rank then
					n = try_ep_helper(board, moves, n, from, num_checkers, checker_type, checker_sq, color, king_square)
				end
			end
			if integer.band(pawns, er) ~= 0i then
				local from = ep - (if color == WHITE then 9 else -9)
				local from_rank = bit32.rshift(from, 3)
				local valid_rank = if color == WHITE then 4 else 3
				if from_rank == valid_rank then
					n = try_ep_helper(board, moves, n, from, num_checkers, checker_type, checker_sq, color, king_square)
				end
			end
		end

		n = add_knight_moves(board, moves, n, color, own, enemy_bb, cm)
		n = add_bishop_moves(board, moves, n, color, own, enemy_bb, cm)
		n = add_rook_moves  (board, moves, n, color, own, enemy_bb, cm)
		n = add_queen_moves (board, moves, n, color, own, enemy_bb, cm)
	end

	-- King moves
	local ks_inv = integer.bnot(Utils.unit_board(king_square))
	local king_base = bit32.bor(king_square, bit32.lshift(KING, 12), PROMO_SENTINEL)
	do
		local ka = integer.band(king_attacks(king_square), integer.bnot(own))
		while ka ~= 0i do
			local to = integer.tonumber(integer.countrz(ka))
			ka = integer.band(ka, integer.sub(ka, 1i))

			local to_b = Utils.unit_board(to)
			local new_own = integer.bor(integer.band(own, ks_inv), to_b)
			local captures = integer.band(enemy_bb, to_b) ~= 0i
			local new_enemy = if captures then integer.band(enemy_bb, integer.bnot(to_b)) else enemy_bb

			if not is_square_attacked_with_occupancy(board, to, enemy, new_own, new_enemy, if captures then to else nil) then
				n += 1
				moves[n] = bit32.bor(king_base, bit32.lshift(to, 6), if captures then CAPTURED_BIT else 0)
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

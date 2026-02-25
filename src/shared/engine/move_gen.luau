--!native
--!optimize 2
--!strict

local u64 = require("./int64")
local Utils = require("./utils")
local Attacks = require("./attacks")
local Move = require("./move").Move

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local RANK_1, RANK_2, RANK_7, RANK_8, NOT_FILE_A, NOT_FILE_H =
	Utils.RANK_1, Utils.RANK_2, Utils.RANK_7, Utils.RANK_8, Utils.NOT_FILE_A, Utils.NOT_FILE_H
local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

local ZERO = u64.ZERO
local ONE = u64.ONE
local countrz = u64.countrz
local countlz = u64.countlz
local bor = u64.bor
local band = u64.band
local bnot = u64.bnot
local lshift = u64.lshift
local rshift = u64.rshift
local hex_bor = u64.hex_bor
local from_pair = u64.from_pair
local btest = u64.btest
local sub = u64.sub

local get_bit = Utils.get_bit
local get_bit32 = Utils.get_bit32
local popcount = Utils.popcount

export type Board = Utils.Board

local MoveGen = {}

-- Attacked squares
function MoveGen.regenerate_piece_attacked(board: Board, by_color: number, piece: number)
	local attacks = ZERO
	local attack_func

	if piece == KNIGHT then
		attacks = Attacks.bulk_knight_attacks(board.pieces[by_color][piece])
	elseif piece == KING then
		attacks = Attacks.bulk_king_attacks(board.pieces[by_color][piece])
	elseif piece == PAWN then
		attacks = Attacks.bulk_pawn_attacks(board.pieces[by_color][piece], by_color)
	elseif piece == QUEEN then
		attack_func = Attacks.queen_attacks
	elseif piece == ROOK then
		attack_func = Attacks.rook_attacks
	elseif piece == BISHOP then
		attack_func = Attacks.bishop_attacks
	end

	if attack_func then
		local bb = board.pieces[by_color][piece]
		while bb ~= ZERO do
			local s = countrz(bb)
			attacks = bor(attacks, attack_func(s, board.occupied[by_color], board.occupied[1 - by_color]))
			bb = band(bb, sub(bb, ONE))
		end
	end

	board.attacked[by_color][piece] = attacks
end

function MoveGen.attacked_occupancy(board: Board, by_color: number)
	board.attacked[by_color].all = hex_bor(
		board.attacked[by_color][ROOK],
		board.attacked[by_color][BISHOP],
		board.attacked[by_color][QUEEN],
		board.attacked[by_color][KNIGHT],
		board.attacked[by_color][KING],
		board.attacked[by_color][PAWN]
	)
end

function MoveGen.regenerate_all_attacked(board: Board, by_color: number)
	MoveGen.regenerate_piece_attacked(board, by_color, KNIGHT)
	MoveGen.regenerate_piece_attacked(board, by_color, KING)
	MoveGen.regenerate_piece_attacked(board, by_color, PAWN)
	MoveGen.attacked_occupancy(board, by_color)
end

function MoveGen.is_square_attacked(board: Board, square: number, by_color: number): boolean
	return get_bit(board.attacked[by_color].all, square)
end

-- Precomputed castle move integers — Move.create is only called once at load time
local CASTLE_MOVE_WK = Move.create(4,  6,  KING, false, nil, false, true, true)
local CASTLE_MOVE_WQ = Move.create(4,  2,  KING, false, nil, false, true, false)
local CASTLE_MOVE_BK = Move.create(60, 62, KING, false, nil, false, true, true)
local CASTLE_MOVE_BQ = Move.create(60, 58, KING, false, nil, false, true, false)

local CASTLE_MASKS = {
	[WHITE] = {
		[true]  = { no_checks = from_pair(0x0, 0x70),        no_pieces = from_pair(0x0, 0x60) },
		[false] = { no_checks = from_pair(0x0, 0x1C),        no_pieces = from_pair(0x0, 0x0E) },
	},
	[BLACK] = {
		[true]  = { no_checks = from_pair(0x70000000, 0x0),  no_pieces = from_pair(0x60000000, 0x0) },
		[false] = { no_checks = from_pair(0x1C000000, 0x0),  no_pieces = from_pair(0x0E000000, 0x0) },
	},
}

local function generate_castle_moves(board: Board, moves: { number }, n: number, color: number, attacked: vector): number
	local occupied = board.occupied.all
	local masks = CASTLE_MASKS[color]
	if color == WHITE then
		if get_bit32(board.castling_rights, WK)
			and band(occupied, masks[true].no_pieces) == ZERO
			and band(attacked,  masks[true].no_checks) == ZERO then
			n += 1; moves[n] = CASTLE_MOVE_WK
		end
		if get_bit32(board.castling_rights, WQ)
			and band(occupied, masks[false].no_pieces) == ZERO
			and band(attacked,  masks[false].no_checks) == ZERO then
			n += 1; moves[n] = CASTLE_MOVE_WQ
		end
	else
		if get_bit32(board.castling_rights, BK)
			and band(occupied, masks[true].no_pieces) == ZERO
			and band(attacked,  masks[true].no_checks) == ZERO then
			n += 1; moves[n] = CASTLE_MOVE_BK
		end
		if get_bit32(board.castling_rights, BQ)
			and band(occupied, masks[false].no_pieces) == ZERO
			and band(attacked,  masks[false].no_checks) == ZERO then
			n += 1; moves[n] = CASTLE_MOVE_BQ
		end
	end
	return n
end

-- Pawn helpers
local function add_pawn_moves(
	moves: { number },
	n: number,
	promo_rank: vector,
	targets: vector,
	from_offset: number,
	is_capture: boolean
): number
	local captured_bit = if is_capture then 0x8000 else 0
	local promo_sentinel = bit32.lshift(5, 16)

	-- Normal moves (no promotion) — hot path, no branch on promo
	local bb = band(targets, bnot(promo_rank))
	while bb ~= ZERO do
		local to_square = countrz(bb)
		bb = band(bb, sub(bb, ONE))
		n += 1
		moves[n] = bit32.bor(to_square - from_offset, bit32.lshift(to_square, 6), captured_bit, promo_sentinel)
	end

	-- Promotion moves — rare, separate loop
	bb = band(targets, promo_rank)
	while bb ~= ZERO do
		local to_square = countrz(bb)
		bb = band(bb, sub(bb, ONE))
		local base = bit32.bor(to_square - from_offset, bit32.lshift(to_square, 6), captured_bit)
		moves[n+1] = bit32.bor(base, 0x10000)
		moves[n+2] = bit32.bor(base, 0x20000)
		moves[n+3] = bit32.bor(base, 0x30000)
		moves[n+4] = bit32.bor(base, 0x40000)
		n += 4
	end

	return n
end

local function generate_pawn_moves(board: Board, moves: { number }, n: number, color: number): number
	local pawns = board.pieces[color][PAWN]
	local empty = bnot(board.occupied.all)
	local enemies = board.occupied[1 - color]

	local push_dir   = if color == WHITE then 8 else -8
	local start_rank = if color == WHITE then RANK_2 else RANK_7
	local promo_rank = if color == WHITE then RANK_8 else RANK_1

	local push_targets = band(if color == WHITE then lshift(pawns, 8) else rshift(pawns, 8), empty)

	local double_push_targets = band(
		band(if color == WHITE then lshift(push_targets, 8) else rshift(push_targets, 8), empty),
		if color == WHITE then lshift(start_rank, 16) else rshift(start_rank, 16)
	)

	local left_captures, right_captures
	if color == WHITE then
		left_captures  = band(band(lshift(pawns, 7), NOT_FILE_H), enemies)
		right_captures = band(band(lshift(pawns, 9), NOT_FILE_A), enemies)
	else
		left_captures  = band(band(rshift(pawns, 7), NOT_FILE_A), enemies)
		right_captures = band(band(rshift(pawns, 9), NOT_FILE_H), enemies)
	end

	n = add_pawn_moves(moves, n, promo_rank, push_targets,        push_dir,     false)
	n = add_pawn_moves(moves, n, promo_rank, double_push_targets, push_dir * 2, false)
	n = add_pawn_moves(moves, n, promo_rank, left_captures,  if color == WHITE then 7 else -7, true)
	n = add_pawn_moves(moves, n, promo_rank, right_captures, if color == WHITE then 9 else -9, true)

	if board.en_passant_square and board.en_passant_square > 0 then
		local ep_bb    = lshift(ONE, board.en_passant_square)
		local ep_left  = if color == WHITE then rshift(ep_bb, 7) else lshift(ep_bb, 7)
		local ep_right = if color == WHITE then rshift(ep_bb, 9) else lshift(ep_bb, 9)
		if btest(pawns, ep_left) then
			n += 1
			moves[n] = Move.create(board.en_passant_square - (if color == WHITE then 7 else -7), board.en_passant_square, PAWN, true, nil, true)
		end
		if btest(pawns, ep_right) then
			n += 1
			moves[n] = Move.create(board.en_passant_square - (if color == WHITE then 9 else -9), board.en_passant_square, PAWN, true, nil, true)
		end
	end

	return n
end

-- Legal move helpers
local function pawn_attackers_to_square(square: number, enemy_color: number): vector
	local king_bb = lshift(ONE, square)
	if enemy_color == WHITE then
		return bor(band(rshift(king_bb, 7), NOT_FILE_H), band(rshift(king_bb, 9), NOT_FILE_A))
	else
		return bor(band(lshift(king_bb, 7), NOT_FILE_A), band(lshift(king_bb, 9), NOT_FILE_H))
	end
end

local function is_square_attacked_with_occupancy(
	board: Board,
	square: number,
	by_color: number,
	own_occ: vector,
	enemy_occ: vector
): boolean
	if band(board.pieces[by_color][PAWN],   pawn_attackers_to_square(square, by_color)) ~= ZERO then return true end
	if band(board.pieces[by_color][KNIGHT], Attacks.knight_attacks(square))              ~= ZERO then return true end
	if band(board.pieces[by_color][KING],   Attacks.king_attacks(square))                ~= ZERO then return true end

	local occupied = bor(own_occ, enemy_occ)
	if band(Attacks.rook_attacks(square, ZERO, occupied),
		bor(board.pieces[by_color][ROOK], board.pieces[by_color][QUEEN])) ~= ZERO then return true end
	if band(Attacks.bishop_attacks(square, ZERO, occupied),
		bor(board.pieces[by_color][BISHOP], board.pieces[by_color][QUEEN])) ~= ZERO then return true end

	return false
end

local function scan_sliders_for_pins_and_checks(
	board: Board,
	enemy: number,
	king_square: number,
	pieceType: number,
	occupied: vector,
	own_occ: vector,
	pin_masks: { [number]: vector },
	checkers: vector
): vector
	local LINE = Attacks.LINE
	local sliders = board.pieces[enemy][pieceType]
	while sliders ~= ZERO do
		local slider_sq = countrz(sliders)
		sliders = band(sliders, sub(sliders, ONE))

		local line = LINE[slider_sq][king_square]
		if line ~= ZERO then
			local between = band(line, band(bnot(lshift(ONE, slider_sq)), bnot(lshift(ONE, king_square))))
			local between_occ = band(occupied, between)
			if between_occ == ZERO then
				checkers = bor(checkers, lshift(ONE, slider_sq))
			elseif popcount(between_occ) == 1 and band(between_occ, own_occ) ~= ZERO then
				pin_masks[countrz(between_occ)] = line
			end
		end
	end
	return checkers
end

local function compute_check_and_pins(board: Board, color: number, king_square: number)
	local enemy     = 1 - color
	local occupied  = board.occupied.all
	local own_occ   = board.occupied[color]
	local pin_masks = {}

	local checkers = bor(
		band(board.pieces[enemy][PAWN],   pawn_attackers_to_square(king_square, enemy)),
		band(board.pieces[enemy][KNIGHT], Attacks.knight_attacks(king_square))
	)

	checkers = scan_sliders_for_pins_and_checks(board, enemy, king_square, ROOK,   occupied, own_occ, pin_masks, checkers)
	checkers = scan_sliders_for_pins_and_checks(board, enemy, king_square, BISHOP, occupied, own_occ, pin_masks, checkers)
	checkers = scan_sliders_for_pins_and_checks(board, enemy, king_square, QUEEN,  occupied, own_occ, pin_masks, checkers)

	local num_checkers = popcount(checkers)

	if num_checkers >= 2 then
		return pin_masks, ZERO, num_checkers, checkers
	elseif num_checkers == 0 then
		return pin_masks, bnot(ZERO), num_checkers, checkers
	end

	-- Exactly one checker — build check_mask using LINE table
	local checker_sq  = countrz(checkers)
	local checker_bit = lshift(ONE, checker_sq)
	local checker_val = board.pieceTable[checker_sq]
	local check_mask

	if checker_val then
		local checker_type = bit32.rshift(checker_val, 6)
		if checker_type == BISHOP or checker_type == ROOK or checker_type == QUEEN then
			local line    = Attacks.LINE[king_square][checker_sq]
			local between = band(line, band(bnot(lshift(ONE, king_square)), bnot(checker_bit)))
			check_mask = bor(between, checker_bit)
		else
			check_mask = checker_bit
		end
	else
		check_mask = checker_bit
	end

	return pin_masks, check_mask, num_checkers, checkers
end

local function is_en_passant_legal(board: Board, color: number, from: number, to: number, king_square: number): boolean
	local enemy = 1 - color
	local own_occ   = bor(band(board.occupied[color], bnot(lshift(ONE, from))), lshift(ONE, to))
	local cap_bb    = lshift(ONE, to - (if color == WHITE then 8 else -8))
	local enemy_occ = band(board.occupied[enemy], bnot(cap_bb))

	if band(band(board.pieces[enemy][PAWN], bnot(cap_bb)), pawn_attackers_to_square(king_square, enemy)) ~= ZERO then return false end
	if band(board.pieces[enemy][KNIGHT], Attacks.knight_attacks(king_square)) ~= ZERO then return false end
	if band(board.pieces[enemy][KING],   Attacks.king_attacks(king_square))   ~= ZERO then return false end

	local occupied = bor(own_occ, enemy_occ)
	if band(Attacks.rook_attacks(king_square, ZERO, occupied),
		bor(board.pieces[enemy][ROOK], board.pieces[enemy][QUEEN])) ~= ZERO then return false end
	if band(Attacks.bishop_attacks(king_square, ZERO, occupied),
		bor(board.pieces[enemy][BISHOP], board.pieces[enemy][QUEEN])) ~= ZERO then return false end

	return true
end

local function add_pawn_moves_masked(
	moves: { number },
	n: number,
	promo_rank: vector,
	pin_masks: { [number]: vector },
	targets: vector,
	from_offset: number,
	is_capture: boolean
): number
	local captured_bit   = if is_capture then 0x8000 else 0
	local promo_sentinel = bit32.lshift(5, 16)

	-- Normal moves — no promo branch in loop
	local bb = band(targets, bnot(promo_rank))
	while bb ~= ZERO do
		local to_square = countrz(bb)
		bb = band(bb, sub(bb, ONE))
		local from_square = to_square - from_offset
		local pin_mask = pin_masks[from_square]
		if not pin_mask or get_bit(pin_mask, to_square) then
			n += 1
			moves[n] = bit32.bor(from_square, bit32.lshift(to_square, 6), captured_bit, promo_sentinel)
		end
	end

	-- Promotion moves
	bb = band(targets, promo_rank)
	while bb ~= ZERO do
		local to_square = countrz(bb)
		bb = band(bb, sub(bb, ONE))
		local from_square = to_square - from_offset
		local pin_mask = pin_masks[from_square]
		if not pin_mask or get_bit(pin_mask, to_square) then
			local base = bit32.bor(from_square, bit32.lshift(to_square, 6), captured_bit)
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
	board: Board,
	moves: { number },
	n: number,
	color: number,
	own_pieces: vector,
	other_pieces: vector,
	piece_type: number,
	attack_func: (number, vector, vector) -> vector
): number
	local bb = board.pieces[color][piece_type]
	while bb ~= ZERO do
		local from_square = countrz(bb)
		bb = band(bb, sub(bb, ONE))
		local attacks = band(attack_func(from_square, own_pieces, other_pieces), bnot(own_pieces))
		while attacks ~= ZERO do
			local to_square = countrz(attacks)
			attacks = band(attacks, sub(attacks, ONE))
			n += 1
			moves[n] = Move.create(from_square, to_square, piece_type, get_bit(other_pieces, to_square))
		end
	end
	return n
end

local function add_knight_moves(
	board: Board,
	moves: { number },
	n: number,
	color: number,
	own_occ: vector,
	enemy_occ: vector,
	check_mask: vector,
	pin_masks: { [number]: vector }
): number
	local bb = board.pieces[color][KNIGHT]
	while bb ~= ZERO do
		local from = countrz(bb)
		bb = band(bb, sub(bb, ONE))
		-- A pinned knight can never legally move
		if pin_masks[from] then continue end

		local attacks = band(band(Attacks.knight_attacks(from), bnot(own_occ)), check_mask)
		while attacks ~= ZERO do
			local to = countrz(attacks)
			attacks = band(attacks, sub(attacks, ONE))
			n += 1
			moves[n] = Move.create(from, to, KNIGHT, get_bit(enemy_occ, to))
		end
	end
	return n
end

local function add_sliding_moves(
	board: Board,
	moves: { number },
	n: number,
	color: number,
	own_occ: vector,
	enemy_occ: vector,
	check_mask: vector,
	pin_masks: { [number]: vector },
	piece_type: number,
	attack_func: (number, vector, vector) -> vector
): number
	local bb = board.pieces[color][piece_type]
	while bb ~= ZERO do
		local from = countrz(bb)
		bb = band(bb, sub(bb, ONE))

		local attacks = band(attack_func(from, own_occ, enemy_occ), check_mask)
		local pin_mask = pin_masks[from]
		if pin_mask then
			attacks = band(attacks, pin_mask)
		end

		while attacks ~= ZERO do
			local to = countrz(attacks)
			attacks = band(attacks, sub(attacks, ONE))
			n += 1
			moves[n] = Move.create(from, to, piece_type, get_bit(enemy_occ, to))
		end
	end
	return n
end

local function try_ep_helper(
	board: Board,
	moves: { number },
	n: number,
	from: number,
	pin_masks: { [number]: vector },
	num_checkers: number,
	checker_type: number?,
	checker_sq: number,
	color: number,
	king_square: number
): number
	local pin_mask = pin_masks[from]
	if pin_mask and not get_bit(pin_mask, board.en_passant_square) then return n end

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

-- Generate legal moves
function MoveGen.generate_legal_moves(board: Board, filePseudoLegal: boolean?, givenColor: number?): { number }
	local color = givenColor or board.side_to_move
	local enemy = 1 - color

	local moves = table.create(30)
	local n = 0

	local king_bb     = board.pieces[color][KING]
	local king_square = 63 - countlz(king_bb)
	if king_square == -1 then return {} end

	MoveGen.regenerate_all_attacked(board, enemy)

	if filePseudoLegal then
		local own_pieces   = board.occupied[color]
		local other_pieces = board.occupied[enemy]
		n = generate_pawn_moves(board, moves, n, color)
		n = generate_piece_moves(board, moves, n, color, own_pieces, other_pieces, KNIGHT, Attacks.knight_attacks)
		n = generate_piece_moves(board, moves, n, color, own_pieces, other_pieces, BISHOP, Attacks.bishop_attacks)
		n = generate_piece_moves(board, moves, n, color, own_pieces, other_pieces, ROOK,   Attacks.rook_attacks)
		n = generate_piece_moves(board, moves, n, color, own_pieces, other_pieces, QUEEN,  Attacks.queen_attacks)
		n = generate_piece_moves(board, moves, n, color, own_pieces, other_pieces, KING,   Attacks.king_attacks)
		n = generate_castle_moves(board, moves, n, color, board.attacked[enemy].all)
		return moves
	end

	local pin_masks, check_mask, num_checkers, checkers = compute_check_and_pins(board, color, king_square)
	local king_only = num_checkers >= 2

	local own_occ   = board.occupied[color]
	local enemy_occ = board.occupied[enemy]
	local empty     = bnot(board.occupied.all)

	local checker_sq   = if num_checkers == 1 then countrz(checkers) else -1
	local checker_val  = if checker_sq >= 0 then board.pieceTable[checker_sq] else nil
	local checker_type = if checker_val then bit32.rshift(checker_val, 6) else nil

	if not king_only then
		local pawns      = board.pieces[color][PAWN]
		local push_dir   = if color == WHITE then 8 else -8
		local start_rank = if color == WHITE then RANK_2 else RANK_7
		local promo_rank = if color == WHITE then RANK_8 else RANK_1

		local push_targets = band(band(if color == WHITE then lshift(pawns, 8) else rshift(pawns, 8), empty), check_mask)

		local double_push_targets = band(
			band(
				band(if color == WHITE then lshift(push_targets, 8) else rshift(push_targets, 8), empty),
				if color == WHITE then lshift(start_rank, 16) else rshift(start_rank, 16)
			),
			check_mask
		)

		local left_captures, right_captures
		if color == WHITE then
			left_captures  = band(band(band(lshift(pawns, 7), NOT_FILE_H), enemy_occ), check_mask)
			right_captures = band(band(band(lshift(pawns, 9), NOT_FILE_A), enemy_occ), check_mask)
		else
			left_captures  = band(band(band(rshift(pawns, 7), NOT_FILE_A), enemy_occ), check_mask)
			right_captures = band(band(band(rshift(pawns, 9), NOT_FILE_H), enemy_occ), check_mask)
		end

		n = add_pawn_moves_masked(moves, n, promo_rank, pin_masks, push_targets,        push_dir,     false)
		n = add_pawn_moves_masked(moves, n, promo_rank, pin_masks, double_push_targets, push_dir * 2, false)
		n = add_pawn_moves_masked(moves, n, promo_rank, pin_masks, left_captures,  if color == WHITE then 7 else -7, true)
		n = add_pawn_moves_masked(moves, n, promo_rank, pin_masks, right_captures, if color == WHITE then 9 else -9, true)

		if board.en_passant_square and board.en_passant_square > 0 then
			local ep_bb    = lshift(ONE, board.en_passant_square)
			local ep_left  = if color == WHITE then rshift(ep_bb, 7) else lshift(ep_bb, 7)
			local ep_right = if color == WHITE then rshift(ep_bb, 9) else lshift(ep_bb, 9)
			if btest(pawns, ep_left) then
				local from = board.en_passant_square - (if color == WHITE then 7 else -7)
				n = try_ep_helper(board, moves, n, from, pin_masks, num_checkers, checker_type, checker_sq, color, king_square)
			end
			if btest(pawns, ep_right) then
				local from = board.en_passant_square - (if color == WHITE then 9 else -9)
				n = try_ep_helper(board, moves, n, from, pin_masks, num_checkers, checker_type, checker_sq, color, king_square)
			end
		end

		n = add_knight_moves(board, moves, n, color, own_occ, enemy_occ, check_mask, pin_masks)
		n = add_sliding_moves(board, moves, n, color, own_occ, enemy_occ, check_mask, pin_masks, BISHOP, Attacks.bishop_attacks)
		n = add_sliding_moves(board, moves, n, color, own_occ, enemy_occ, check_mask, pin_masks, ROOK,   Attacks.rook_attacks)
		n = add_sliding_moves(board, moves, n, color, own_occ, enemy_occ, check_mask, pin_masks, QUEEN,  Attacks.queen_attacks)
	end

	-- King moves
	do
		local king_only_bb  = lshift(ONE, king_square)
		local king_attacks  = band(Attacks.king_attacks(king_square), bnot(own_occ))
		local bb = king_attacks
		while bb ~= ZERO do
			local to = countrz(bb)
			bb = band(bb, sub(bb, ONE))
			local to_bb         = lshift(ONE, to)
			local own_occ_new   = bor(band(own_occ, bnot(king_only_bb)), to_bb)
			local enemy_occ_new = if get_bit(enemy_occ, to) then band(enemy_occ, bnot(to_bb)) else enemy_occ
			if not is_square_attacked_with_occupancy(board, to, enemy, enemy_occ_new, own_occ_new) then
				n += 1
				moves[n] = Move.create(king_square, to, KING, get_bit(enemy_occ, to))
			end
		end
	end

	if num_checkers == 0 then
		n = generate_castle_moves(board, moves, n, color, board.attacked[enemy].all)
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

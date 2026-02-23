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

export type Board = Utils.Board

local MoveGen = {}

-- Attacked squares
function MoveGen.regenerate_piece_attacked(board: Board, by_color: number, piece: number)
	local attacks = u64.ZERO
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

	-- Sliding pieces
	if attack_func then
		local bb = board.pieces[by_color][piece]
		while bb ~= u64.ZERO do
			local s = u64.countrz(bb)
			local attack = attack_func(s, board.occupied[by_color], board.occupied[1 - by_color])
			attacks = u64.bor(attacks, attack)

			bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, s)))
		end
	end

	board.attacked[by_color][piece] = attacks
end
function MoveGen.attacked_occupancy(board: Board, by_color: number)
	board.attacked[by_color].all = u64.hex_bor(
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
	return Utils.get_bit(board.attacked[by_color].all, square)
end

-- Move generation helpers
local function add_pawn_moves(moves: { number }, targets: vector, from_offset: number, is_capture: boolean, promo_rank: vector)
	local bb = targets
	while bb ~= u64.ZERO do
		local to_square = u64.countrz(bb)
		local from_square = to_square - from_offset

		if Utils.get_bit(promo_rank, to_square) then
			for promo = KNIGHT, QUEEN do
				table.insert(moves, Move.create(from_square, to_square, PAWN, is_capture, promo))
			end
		else
			table.insert(moves, Move.create(from_square, to_square, PAWN, is_capture, nil))
		end

		bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, to_square)))
	end
end
local function generate_pawn_moves(board: Board, moves: { number }, color: number)
	local pawns = board.pieces[color][PAWN]
	local empty = u64.bnot(board.occupied.all)
	local enemies = board.occupied[1 - color]

	local push_dir = if color == WHITE then 8 else -8
	local start_rank = if color == WHITE then RANK_2 else RANK_7
	local promo_rank = if color == WHITE then RANK_8 else RANK_1

	local push_targets = if color == WHITE then u64.lshift(pawns, 8) else u64.rshift(pawns, 8)
	push_targets = u64.band(push_targets, empty)

	local double_push_targets = if color == WHITE then u64.lshift(push_targets, 8) else u64.rshift(push_targets, 8)
	double_push_targets = u64.band(
		u64.band(double_push_targets, empty),
		if color == WHITE then u64.lshift(start_rank, 16) else u64.rshift(start_rank, 16)
	)

	local left_captures, right_captures
	if color == WHITE then
		left_captures = u64.band(u64.lshift(pawns, 7), NOT_FILE_H)
		right_captures = u64.band(u64.lshift(pawns, 9), NOT_FILE_A)
	else
		left_captures = u64.band(u64.rshift(pawns, 7), NOT_FILE_A)
		right_captures = u64.band(u64.rshift(pawns, 9), NOT_FILE_H)
	end
	left_captures = u64.band(left_captures, enemies)
	right_captures = u64.band(right_captures, enemies)

	add_pawn_moves(moves, push_targets, push_dir, false, promo_rank)
	add_pawn_moves(moves, double_push_targets, push_dir * 2, false, promo_rank)
	add_pawn_moves(moves, left_captures, if color == WHITE then 7 else -7, true, promo_rank)
	add_pawn_moves(moves, right_captures, if color == WHITE then 9 else -9, true, promo_rank)

	if board.en_passant_square and board.en_passant_square > 0 then
		local ep_bb = u64.lshift(u64.ONE, board.en_passant_square)
		local ep_left = if color == WHITE then u64.rshift(ep_bb, 7) else u64.lshift(ep_bb, 7)
		local ep_right = if color == WHITE then u64.rshift(ep_bb, 9) else u64.lshift(ep_bb, 9)

		if u64.btest(pawns, ep_left) then
			local from = board.en_passant_square - (if color == WHITE then 7 else -7)
			table.insert(moves, Move.create(from, board.en_passant_square, PAWN, true, nil, true))
		end
		if u64.btest(pawns, ep_right) then
			local from = board.en_passant_square - (if color == WHITE then 9 else -9)
			table.insert(moves, Move.create(from, board.en_passant_square, PAWN, true, nil, true))
		end
	end
end

local function generate_piece_moves(
	board: Board,
	moves: { number },
	piece_type: number,
	attack_func: (number, vector, vector) -> vector,
	color: number
)
	local own_pieces = board.occupied[color]
	local other_pieces = board.occupied[1 - color]

	local bb = board.pieces[color][piece_type]
	while bb ~= u64.ZERO do
		local from_square = u64.countrz(bb)
		local attacks = attack_func(from_square, own_pieces, other_pieces)
		attacks = u64.band(attacks, u64.bnot(own_pieces))

		local attacks_bb = attacks
		while attacks_bb ~= u64.ZERO do
			local to_square = u64.countrz(attacks_bb)
			local is_capture = Utils.get_bit(other_pieces, to_square)
			table.insert(moves, Move.create(from_square, to_square, piece_type, is_capture))
			attacks_bb = u64.band(attacks_bb, u64.bnot(u64.lshift(u64.ONE, to_square)))
		end

		bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, from_square)))
	end
end

-- Castling
local CASTLE_MASKS = {
	[WHITE] = {
		[true] = {
			no_checks = u64.from_pair(0x0, 0x70),
			no_pieces = u64.from_pair(0x0, 0x60),
		},
		[false] = {
			no_checks = u64.from_pair(0x0, 0x1C),
			no_pieces = u64.from_pair(0x0, 0x0E),
		},
	},
	[BLACK] = {
		[true] = {
			no_checks = u64.from_pair(0x70000000, 0x0),
			no_pieces = u64.from_pair(0x60000000, 0x0),
		},
		[false] = {
			no_checks = u64.from_pair(0x1C000000, 0x0),
			no_pieces = u64.from_pair(0x0E000000, 0x0),
		},
	},
}

local function generate_castle_moves(board: Board, moves: { number }, color: number, attacked: vector)
	local occupied = board.occupied.all
	local masks = CASTLE_MASKS[color]

	if color == WHITE then
		if Utils.get_bit32(board.castling_rights, WK) then
			if u64.band(occupied, masks[true].no_pieces) == u64.ZERO and u64.band(attacked, masks[true].no_checks) == u64.ZERO then
				table.insert(moves, Move.create(4, 6, KING, false, nil, false, true, true))
			end
		end
		if Utils.get_bit32(board.castling_rights, WQ) then
			if u64.band(occupied, masks[false].no_pieces) == u64.ZERO and u64.band(attacked, masks[false].no_checks) == u64.ZERO then
				table.insert(moves, Move.create(4, 2, KING, false, nil, false, true, false))
			end
		end
	else
		if Utils.get_bit32(board.castling_rights, BK) then
			if u64.band(occupied, masks[true].no_pieces) == u64.ZERO and u64.band(attacked, masks[true].no_checks) == u64.ZERO then
				table.insert(moves, Move.create(60, 62, KING, false, nil, false, true, true))
			end
		end
		if Utils.get_bit32(board.castling_rights, BQ) then
			if u64.band(occupied, masks[false].no_pieces) == u64.ZERO and u64.band(attacked, masks[false].no_checks) == u64.ZERO then
				table.insert(moves, Move.create(60, 58, KING, false, nil, false, true, false))
			end
		end
	end
end

-- Legal move helpers
local function pawn_attackers_to_square(square: number, enemy_color: number): vector
	local king_bb = u64.lshift(u64.ONE, square)
	if enemy_color == WHITE then
		local from_left = u64.band(u64.rshift(king_bb, 7), NOT_FILE_H)
		local from_right = u64.band(u64.rshift(king_bb, 9), NOT_FILE_A)
		return u64.bor(from_left, from_right)
	else
		local from_left = u64.band(u64.lshift(king_bb, 7), NOT_FILE_A)
		local from_right = u64.band(u64.lshift(king_bb, 9), NOT_FILE_H)
		return u64.bor(from_left, from_right)
	end
end

local function is_square_attacked_with_occupancy(
	board: Board,
	square: number,
	by_color: number,
	own_occ: vector,
	enemy_occ: vector
): boolean
	local pawn_attackers = pawn_attackers_to_square(square, by_color)
	if u64.band(board.pieces[by_color][PAWN], pawn_attackers) ~= u64.ZERO then
		return true
	end

	if u64.band(board.pieces[by_color][KNIGHT], Attacks.knight_attacks(square)) ~= u64.ZERO then
		return true
	end

	if u64.band(board.pieces[by_color][KING], Attacks.king_attacks(square)) ~= u64.ZERO then
		return true
	end

	local occupied = u64.bor(own_occ, enemy_occ)
	local rook_attacks = Attacks.rook_attacks(square, u64.ZERO, occupied)
	if u64.band(rook_attacks, u64.bor(board.pieces[by_color][ROOK], board.pieces[by_color][QUEEN])) ~= u64.ZERO then
		return true
	end

	local bishop_attacks = Attacks.bishop_attacks(square, u64.ZERO, occupied)
	if u64.band(bishop_attacks, u64.bor(board.pieces[by_color][BISHOP], board.pieces[by_color][QUEEN])) ~= u64.ZERO then
		return true
	end

	return false
end

local function scan_sliders_for_pins_and_checks(
	board: Board,
	enemy: number,
	king_square: number,
	pieceType: number,
	attack_func: (number, vector, vector, boolean?) -> (vector, { number }?),
	occupied: vector,
	own_occ: vector,
	enemy_occ: vector,
	pin_masks: { [number]: vector },
	checkers: vector
)
	local sliders = board.pieces[enemy][pieceType]
	while sliders ~= u64.ZERO do
		local slider_sq = u64.countrz(sliders)

		local between = Attacks.between_squares(slider_sq, king_square, pieceType)
		local aligned = between ~= u64.ZERO
		if not aligned then
			local attacks = attack_func(slider_sq, enemy_occ, own_occ, true)
			aligned = Utils.get_bit(attacks, king_square)
		end

		if aligned then
			local between_occ = if between == u64.ZERO then u64.ZERO else u64.band(occupied, between)
			if between_occ == u64.ZERO then
				checkers = u64.bor(checkers, u64.lshift(u64.ONE, slider_sq))
			else
				if Utils.popcount(between_occ) == 1 and u64.band(between_occ, own_occ) ~= u64.ZERO then
					local pinned_sq = u64.countrz(between_occ)
					local line_mask = u64.bor(
						between,
						u64.bor(u64.lshift(u64.ONE, slider_sq), u64.lshift(u64.ONE, king_square))
					)
					pin_masks[pinned_sq] = line_mask
				end
			end
		end

		sliders = u64.band(sliders, u64.bnot(u64.lshift(u64.ONE, slider_sq)))
	end

	return checkers
end

local function compute_check_and_pins(board: Board, color: number, king_square: number)
	local enemy = 1 - color
	local occupied = board.occupied.all
	local own_occ = board.occupied[color]
	local enemy_occ = board.occupied[enemy]

	local pin_masks = {}
	local checkers = u64.ZERO

	local pawn_checkers = u64.band(board.pieces[enemy][PAWN], pawn_attackers_to_square(king_square, enemy))
	if pawn_checkers ~= u64.ZERO then
		checkers = u64.bor(checkers, pawn_checkers)
	end

	local knight_checkers = u64.band(board.pieces[enemy][KNIGHT], Attacks.knight_attacks(king_square))
	if knight_checkers ~= u64.ZERO then
		checkers = u64.bor(checkers, knight_checkers)
	end

	checkers = scan_sliders_for_pins_and_checks(board, enemy, king_square, ROOK, Attacks.rook_attacks, occupied, own_occ, enemy_occ, pin_masks, checkers)
	checkers = scan_sliders_for_pins_and_checks(board, enemy, king_square, BISHOP, Attacks.bishop_attacks, occupied, own_occ, enemy_occ, pin_masks, checkers)
	checkers = scan_sliders_for_pins_and_checks(board, enemy, king_square, QUEEN, Attacks.queen_attacks, occupied, own_occ, enemy_occ, pin_masks, checkers)

	local num_checkers = Utils.popcount(checkers)
	local check_mask = u64.bnot(u64.ZERO)

	if num_checkers >= 2 then
		check_mask = u64.ZERO
	elseif num_checkers == 1 then
		local checker_sq = u64.countrz(checkers)
		local checker_val = board.pieceTable[checker_sq]
		if checker_val then
			local checker_type = bit32.rshift(checker_val, 6)
			if checker_type == KNIGHT or checker_type == PAWN or checker_type == KING then
				check_mask = u64.lshift(u64.ONE, checker_sq)
			else
				local between = Attacks.between_squares(king_square, checker_sq, checker_type)
				check_mask = u64.bor(between, u64.lshift(u64.ONE, checker_sq))
			end
		else
			check_mask = u64.lshift(u64.ONE, checker_sq)
		end
	end

	return pin_masks, check_mask, num_checkers, checkers
end

local function add_moves_from_attacks(moves: { number }, from: number, piece_type: number, attacks: vector, enemy_occ: vector)
	local bb = attacks
	while bb ~= u64.ZERO do
		local to = u64.countrz(bb)
		local is_capture = Utils.get_bit(enemy_occ, to)
		table.insert(moves, Move.create(from, to, piece_type, is_capture))
		bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, to)))
	end
end

local function add_pawn_moves_masked(
	moves: { number },
	targets: vector,
	from_offset: number,
	is_capture: boolean,
	promo_rank: vector,
	pin_masks: { [number]: vector },
	enemy_occ: vector
)
	local bb = targets
	while bb ~= u64.ZERO do
		local to_square = u64.countrz(bb)
		local from_square = to_square - from_offset

		local pin_mask = pin_masks[from_square]
		if not pin_mask or Utils.get_bit(pin_mask, to_square) then
			if Utils.get_bit(promo_rank, to_square) then
				for promo = KNIGHT, QUEEN do
					table.insert(moves, Move.create(from_square, to_square, PAWN, is_capture, promo))
				end
			else
				table.insert(moves, Move.create(from_square, to_square, PAWN, is_capture, nil))
			end
		end

		bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, to_square)))
	end
end

local function is_en_passant_legal(board: Board, color: number, from: number, to: number, king_square: number): boolean
	local enemy = 1 - color
	local own_occ = board.occupied[color]
	local enemy_occ = board.occupied[enemy]

	local from_bb = u64.lshift(u64.ONE, from)
	local to_bb = u64.lshift(u64.ONE, to)
	local cap_sq = to - (if color == WHITE then 8 else -8)
	local cap_bb = u64.lshift(u64.ONE, cap_sq)

	own_occ = u64.band(own_occ, u64.bnot(from_bb))
	own_occ = u64.bor(own_occ, to_bb)
	enemy_occ = u64.band(enemy_occ, u64.bnot(cap_bb))

	local enemy_pawns = u64.band(board.pieces[enemy][PAWN], u64.bnot(cap_bb))
	local pawn_attackers = pawn_attackers_to_square(king_square, enemy)
	if u64.band(enemy_pawns, pawn_attackers) ~= u64.ZERO then
		return false
	end

	if u64.band(board.pieces[enemy][KNIGHT], Attacks.knight_attacks(king_square)) ~= u64.ZERO then
		return false
	end

	if u64.band(board.pieces[enemy][KING], Attacks.king_attacks(king_square)) ~= u64.ZERO then
		return false
	end

	local occupied = u64.bor(own_occ, enemy_occ)
	local rook_attacks = Attacks.rook_attacks(king_square, u64.ZERO, occupied)
	if u64.band(rook_attacks, u64.bor(board.pieces[enemy][ROOK], board.pieces[enemy][QUEEN])) ~= u64.ZERO then
		return false
	end

	local bishop_attacks = Attacks.bishop_attacks(king_square, u64.ZERO, occupied)
	if u64.band(bishop_attacks, u64.bor(board.pieces[enemy][BISHOP], board.pieces[enemy][QUEEN])) ~= u64.ZERO then
		return false
	end

	return true
end

local function find_piece(board: Board, piece_type: number, color: number): number?
	local bb = board.pieces[color][piece_type]
	local square = 63 - u64.countlz(bb)
	if square == -1 then
		return nil
	end
	return square
end

-- Generate legal moves
function MoveGen.generate_legal_moves(board: Board, filePseudoLegal: boolean?, givenColor: number?): { number }
	local color = givenColor or board.side_to_move
	local enemy = 1 - color

	local moves = table.create(30)

	local king_square = find_piece(board, KING, color)
	if not king_square then
		return {}
	end

	MoveGen.regenerate_all_attacked(board, enemy)

	if filePseudoLegal then
		generate_pawn_moves(board, moves, color)
		generate_piece_moves(board, moves, KNIGHT, Attacks.knight_attacks, color)
		generate_piece_moves(board, moves, BISHOP, Attacks.bishop_attacks, color)
		generate_piece_moves(board, moves, ROOK, Attacks.rook_attacks, color)
		generate_piece_moves(board, moves, QUEEN, Attacks.queen_attacks, color)
		generate_piece_moves(board, moves, KING, Attacks.king_attacks, color)
		generate_castle_moves(board, moves, color, board.attacked[enemy].all)
		return moves
	end

	local pin_masks, check_mask, num_checkers, checkers = compute_check_and_pins(board, color, king_square)
	local king_only = num_checkers >= 2

	local own_occ = board.occupied[color]
	local enemy_occ = board.occupied[enemy]
	local empty = u64.bnot(board.occupied.all)

	local checker_sq = if num_checkers == 1 then u64.countrz(checkers) else -1
	local checker_val = if checker_sq >= 0 then board.pieceTable[checker_sq] else nil
	local checker_type = if checker_val then bit32.rshift(checker_val, 6) else nil

	-- Pawns
	if not king_only then
		local pawns = board.pieces[color][PAWN]
		local push_dir = if color == WHITE then 8 else -8
		local start_rank = if color == WHITE then RANK_2 else RANK_7
		local promo_rank = if color == WHITE then RANK_8 else RANK_1

		local push_targets = if color == WHITE then u64.lshift(pawns, 8) else u64.rshift(pawns, 8)
		push_targets = u64.band(push_targets, empty)
		push_targets = u64.band(push_targets, check_mask)

		local double_push_targets = if color == WHITE then u64.lshift(push_targets, 8) else u64.rshift(push_targets, 8)
		double_push_targets = u64.band(
			u64.band(double_push_targets, empty),
			if color == WHITE then u64.lshift(start_rank, 16) else u64.rshift(start_rank, 16)
		)
		double_push_targets = u64.band(double_push_targets, check_mask)

		local left_captures, right_captures
		if color == WHITE then
			left_captures = u64.band(u64.lshift(pawns, 7), NOT_FILE_H)
			right_captures = u64.band(u64.lshift(pawns, 9), NOT_FILE_A)
		else
			left_captures = u64.band(u64.rshift(pawns, 7), NOT_FILE_A)
			right_captures = u64.band(u64.rshift(pawns, 9), NOT_FILE_H)
		end
		left_captures = u64.band(left_captures, enemy_occ)
		right_captures = u64.band(right_captures, enemy_occ)

		left_captures = u64.band(left_captures, check_mask)
		right_captures = u64.band(right_captures, check_mask)

		add_pawn_moves_masked(moves, push_targets, push_dir, false, promo_rank, pin_masks, enemy_occ)
		add_pawn_moves_masked(moves, double_push_targets, push_dir * 2, false, promo_rank, pin_masks, enemy_occ)
		add_pawn_moves_masked(moves, left_captures, if color == WHITE then 7 else -7, true, promo_rank, pin_masks, enemy_occ)
		add_pawn_moves_masked(moves, right_captures, if color == WHITE then 9 else -9, true, promo_rank, pin_masks, enemy_occ)

		if board.en_passant_square and board.en_passant_square > 0 then
			local ep_bb = u64.lshift(u64.ONE, board.en_passant_square)
			local ep_left = if color == WHITE then u64.rshift(ep_bb, 7) else u64.lshift(ep_bb, 7)
			local ep_right = if color == WHITE then u64.rshift(ep_bb, 9) else u64.lshift(ep_bb, 9)

			local function try_ep(from: number)
				local pin_mask = pin_masks[from]
				if pin_mask and not Utils.get_bit(pin_mask, board.en_passant_square) then
					return
				end

				if num_checkers == 1 then
					if checker_type ~= PAWN then
						return
					end
					local captured_sq = board.en_passant_square - (if color == WHITE then 8 else -8)
					if captured_sq ~= checker_sq then
						return
					end
				elseif num_checkers > 1 then
					return
				end

				if is_en_passant_legal(board, color, from, board.en_passant_square, king_square) then
					table.insert(moves, Move.create(from, board.en_passant_square, PAWN, true, nil, true))
				end
			end

			if u64.btest(pawns, ep_left) then
				local from = board.en_passant_square - (if color == WHITE then 7 else -7)
				try_ep(from)
			end
			if u64.btest(pawns, ep_right) then
				local from = board.en_passant_square - (if color == WHITE then 9 else -9)
				try_ep(from)
			end
		end
	end

	-- Knights
	if not king_only then
		local bb = board.pieces[color][KNIGHT]
		while bb ~= u64.ZERO do
			local from = u64.countrz(bb)
			local attacks = Attacks.knight_attacks(from)
			attacks = u64.band(attacks, u64.bnot(own_occ))
			attacks = u64.band(attacks, check_mask)

			local pin_mask = pin_masks[from]
			if pin_mask then
				attacks = u64.band(attacks, pin_mask)
			end

			add_moves_from_attacks(moves, from, KNIGHT, attacks, enemy_occ)
			bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, from)))
		end
	end

	-- Bishops, Rooks, Queens
	if not king_only then
		local function add_sliding(piece_type: number, attack_func: (number, vector, vector) -> vector)
			local bb = board.pieces[color][piece_type]
			while bb ~= u64.ZERO do
				local from = u64.countrz(bb)
				local attacks = attack_func(from, own_occ, enemy_occ)
				attacks = u64.band(attacks, u64.bnot(own_occ))
				attacks = u64.band(attacks, check_mask)

				local pin_mask = pin_masks[from]
				if pin_mask then
					attacks = u64.band(attacks, pin_mask)
				end

				add_moves_from_attacks(moves, from, piece_type, attacks, enemy_occ)
				bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, from)))
			end
		end

		add_sliding(BISHOP, Attacks.bishop_attacks)
		add_sliding(ROOK, Attacks.rook_attacks)
		add_sliding(QUEEN, Attacks.queen_attacks)
	end

	-- King moves
	do
		local king_bb = u64.lshift(u64.ONE, king_square)
		local king_attacks = u64.band(Attacks.king_attacks(king_square), u64.bnot(own_occ))
		local bb = king_attacks
		while bb ~= u64.ZERO do
			local to = u64.countrz(bb)
			local to_bb = u64.lshift(u64.ONE, to)

			local own_occ_new = u64.bor(u64.band(own_occ, u64.bnot(king_bb)), to_bb)
			local enemy_occ_new = if Utils.get_bit(enemy_occ, to) then u64.band(enemy_occ, u64.bnot(to_bb)) else enemy_occ

			if not is_square_attacked_with_occupancy(board, to, enemy, enemy_occ_new, own_occ_new) then
				local is_capture = Utils.get_bit(enemy_occ, to)
				table.insert(moves, Move.create(king_square, to, KING, is_capture))
			end

			bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, to)))
		end
	end

	if num_checkers == 0 then
		generate_castle_moves(board, moves, color, board.attacked[enemy].all)
	end

	return moves
end

function MoveGen.generate_legal_moves_from(board: Board, from: number, filePseudoLegal: boolean?, color: number?)
	local allMoves = MoveGen.generate_legal_moves(board, filePseudoLegal, color)
	local moves = {}

	for _, move in allMoves do
		local moveFrom = Move.getFrom(move)
		if moveFrom == from then
			table.insert(moves, move)
		end
	end

	return moves
end

return { MoveGen = MoveGen }

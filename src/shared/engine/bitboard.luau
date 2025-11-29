--!native
--!optimize 2

local u64 = require("./int64")
local Utils = require("./utils")
local Attacks = require("./attacks")
local Move = require("./move")
local Zobrist = require("./zobrist")
local Encoding = require("./encoding")
local FEN = require("./fen")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local RANK_1, RANK_2, RANK_7, RANK_8, FILE_A, FILE_H, NOT_FILE_A, NOT_FILE_H, NOT_FILE_AB, NOT_FILE_GH = Utils.RANK_1, Utils.RANK_2, Utils.RANK_7, Utils.RANK_8, Utils.FILE_A, Utils.FILE_H, Utils.NOT_FILE_A, Utils.NOT_FILE_H, Utils.NOT_FILE_AB, Utils.NOT_FILE_GH

local Board = {
    hash = Zobrist,

    to_fen = FEN.to_fen,
    from_fen = FEN.from_fen,

    separate_square_index = Utils.separate_square_index,
    get_square_index = Utils.get_square_index,

    to_buffer = Encoding.to_buffer,
    from_buffer = Encoding.from_buffer
}

function Board.create(blank)
	local self = {}

	-- Bitboards for each piece type and color
	self.pieces = {
		[WHITE] = {
			[PAWN] = u64.ZERO,
			[KNIGHT] = u64.ZERO,
			[BISHOP] = u64.ZERO,
			[ROOK] = u64.ZERO,
			[QUEEN] = u64.ZERO,
			[KING] = u64.ZERO,
		},
		[BLACK] = {
			[PAWN] = u64.ZERO,
			[KNIGHT] = u64.ZERO,
			[BISHOP] = u64.ZERO,
			[ROOK] = u64.ZERO,
			[QUEEN] = u64.ZERO,
			[KING] = u64.ZERO,
		}
	}

	-- Combined bitboards
	self.occupied = {
		[WHITE] = u64.ZERO,
		[BLACK] = u64.ZERO,
		all = u64.ZERO
	}

	-- Game state
	self.side_to_move = WHITE
	self.castling_rights = {
		white_kingside = true,
		white_queenside = true,
		black_kingside = true,
		black_queenside = true,
	}
	self.en_passant_square = nil -- square index or nil
	self.halfmove_clock = 0
	self.fullmove_number = 1

	if not blank then Board.set_start_position(self) end

	return self
end
function Board.clone(board)
	return {
		pieces = {
			[WHITE] = table.clone(board.pieces[WHITE]),
			[BLACK] = table.clone(board.pieces[BLACK])
		},
		en_passant_square = board.en_passant_square,
		halfmove_clock = board.halfmove_clock,
		fullmove_number = board.fullmove_number,
		side_to_move = board.side_to_move,
		castling_rights = table.clone(board.castling_rights),
		occupied = table.clone(board.occupied),
	}
end

-- State
function Board.set_start_position(self)
    -- White pieces
    self.pieces[WHITE][PAWN]   = u64.from_pair(0x00000000, 0x0000FF00)
    self.pieces[WHITE][KNIGHT] = u64.from_pair(0x00000000, 0x00000042)
    self.pieces[WHITE][BISHOP] = u64.from_pair(0x00000000, 0x00000024)
    self.pieces[WHITE][ROOK]   = u64.from_pair(0x00000000, 0x00000081)
    self.pieces[WHITE][QUEEN]  = u64.from_pair(0x00000000, 0x00000008)
    self.pieces[WHITE][KING]   = u64.from_pair(0x00000000, 0x00000010)

    -- Black pieces
    self.pieces[BLACK][PAWN]   = u64.from_pair(0x00FF0000, 0x00000000)
    self.pieces[BLACK][KNIGHT] = u64.from_pair(0x42000000, 0x00000000)
    self.pieces[BLACK][BISHOP] = u64.from_pair(0x24000000, 0x00000000)
    self.pieces[BLACK][ROOK]   = u64.from_pair(0x81000000, 0x00000000)
    self.pieces[BLACK][QUEEN]  = u64.from_pair(0x08000000, 0x00000000)
    self.pieces[BLACK][KING]   = u64.from_pair(0x10000000, 0x00000000)

	Board.update_occupied(self)
end
function Board.update_occupied(self)
	self.occupied[WHITE] = u64.ZERO
	self.occupied[BLACK] = u64.ZERO

	for piece_type = PAWN, KING do
		self.occupied[WHITE] = u64.bor(self.occupied[WHITE], self.pieces[WHITE][piece_type])
		self.occupied[BLACK] = u64.bor(self.occupied[BLACK], self.pieces[BLACK][piece_type])
	end

	self.occupied.all = u64.bor(self.occupied[WHITE], self.occupied[BLACK])
end

-- Move operation
function Board.make_move(self, move)
	local color = self.side_to_move
	local opponent = 1 - color

	-- Clear the piece from its original square
	self.pieces[color][move.piece_type] = Utils.clear_bit(self.pieces[color][move.piece_type], move.from)

	-- Handle captures
	if move.captured then
		-- Check which piece type was captured
		for piece_type = PAWN, KING do
			if Utils.get_bit(self.pieces[opponent][piece_type], move.to) then
				self.pieces[opponent][piece_type] = Utils.clear_bit(self.pieces[opponent][piece_type], move.to)
				break
			end
		end

		-- Handle en passant capture (captured pawn is not on target square)
		if move.flags and move.flags.en_passant then
			local captured_pawn_square = move.to - (if color == WHITE then 8 else -8)
			self.pieces[opponent][PAWN] = Utils.clear_bit(self.pieces[opponent][PAWN], captured_pawn_square)
		end

		self.halfmove_clock = 0
	else
		self.halfmove_clock += 1
	end

	-- Place the piece on the new square (with promotion if applicable)
	local final_piece_type = move.promotion or move.piece_type
	self.pieces[color][final_piece_type] = Utils.set_bit(self.pieces[color][final_piece_type], move.to)

	-- Reset halfmove clock on pawn moves
	if move.piece_type == PAWN then
		self.halfmove_clock = 0
	end

	-- Update en passant square
	self.en_passant_square = nil
	if move.piece_type == PAWN then
		local move_distance = math.abs(move.to - move.from)
		if move_distance == 16 then
			-- Double pawn push, set en passant square
			self.en_passant_square = if color == WHITE then (move.from + 8) else (move.from - 8)
		end
	end

	-- Update castling rights
	if move.piece_type == KING then
		if color == WHITE then
			self.castling_rights.white_kingside = false
			self.castling_rights.white_queenside = false
		else
			self.castling_rights.black_kingside = false
			self.castling_rights.black_queenside = false
		end
	elseif move.piece_type == ROOK then
		-- Check if rook moved from starting square
		if color == WHITE then
			if move.from == 0 then
				self.castling_rights.white_queenside = false
			elseif move.from == 7 then
				self.castling_rights.white_kingside = false
			end
		else
			if move.from == 56 then
				self.castling_rights.black_queenside = false
			elseif move.from == 63 then
				self.castling_rights.black_kingside = false
			end
		end
	end

	-- Also lose castling rights if rook is captured
	if move.captured then
		if move.to == 0 then
			self.castling_rights.white_queenside = false
		elseif move.to == 7 then
			self.castling_rights.white_kingside = false
		elseif move.to == 56 then
			self.castling_rights.black_queenside = false
		elseif move.to == 63 then
			self.castling_rights.black_kingside = false
		end
	end

	-- Handle castling moves
	if move.flags and move.flags.castling then
		local rook_from, rook_to
		if move.flags.kingside then
			rook_from = if color == WHITE then 7 else 63
			rook_to = if color == WHITE then 5 else 61
		else -- queenside
			rook_from = if color == WHITE then 0 else 56
			rook_to = if color == WHITE then 3 else 59
		end

		-- Move the rook
		self.pieces[color][ROOK] = Utils.clear_bit(self.pieces[color][ROOK], rook_from)
		self.pieces[color][ROOK] = Utils.set_bit(self.pieces[color][ROOK], rook_to)
	end

	-- Update occupied bitboards
	Board.update_occupied(self)

	-- Switch side to move
	self.side_to_move = opponent

	-- Update fullmove number
	if color == BLACK then
		self.fullmove_number += 1
	end
end

-- Move generation
local function generate_pawn_moves(self, moves, color)
	local pawns = self.pieces[color][PAWN]
	local empty = u64.bnot(self.occupied.all)
	local enemies = self.occupied[1 - color]

	local push_dir = if color == WHITE then 8 else -8
	local start_rank = if color == WHITE then RANK_2 else RANK_7
	local promo_rank = if color == WHITE then RANK_8 else RANK_1

	-- Single pushes
	local push_targets = if color == WHITE then u64.lshift(pawns, 8) else u64.rshift(pawns, 8)
	push_targets = u64.band(push_targets, empty)

	-- Double pushes
	local double_push_targets = if color == WHITE then u64.lshift(push_targets, 8) else u64.rshift(push_targets, 8)
	double_push_targets = u64.band(u64.band(double_push_targets, empty),
		if color == WHITE then u64.lshift(start_rank, 16) else u64.rshift(start_rank, 16))

	-- Captures
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

	-- Generate moves
	local function add_pawn_moves(targets, from_offset, is_capture)
		while targets ~= u64.ZERO do
			local to_square
			targets, to_square = Utils.pop_lsb(targets)
			local from_square = to_square - from_offset

			-- Check for promotion
			if Utils.get_bit(promo_rank, to_square) then
				for promo = KNIGHT, QUEEN do
					table.insert(moves, Move.new(from_square, to_square, PAWN, is_capture, promo))
				end
			else
				table.insert(moves, Move.new(from_square, to_square, PAWN, is_capture, nil))
			end
		end
	end

	add_pawn_moves(push_targets, push_dir, false)
	add_pawn_moves(double_push_targets, push_dir * 2, false)
	add_pawn_moves(left_captures, if color == WHITE then 7 else -7, true)
	add_pawn_moves(right_captures, if color == WHITE then 9 else -9, true)

	-- En passant
	if self.en_passant_square then
		local ep_bb = u64.lshift(u64.ONE, self.en_passant_square)
		local ep_left = if color == WHITE then u64.rshift(ep_bb, 7) else u64.lshift(ep_bb, 7)
		local ep_right = if color == WHITE then u64.rshift(ep_bb, 9) else u64.lshift(ep_bb, 9)

		if u64.btest(pawns, ep_left) then
			local from = self.en_passant_square - (if color == WHITE then 7 else -7)
			table.insert(moves, Move.new(from, self.en_passant_square, PAWN, true, nil, {en_passant = true}))
		end
		if u64.btest(pawns, ep_right) then
			local from = self.en_passant_square - (if color == WHITE then 9 else -9)
			table.insert(moves, Move.new(from, self.en_passant_square, PAWN, true, nil, {en_passant = true}))
		end
	end
end
local function generate_piece_moves(self, moves, piece_type, attack_func, color)
	local pieces = self.pieces[color][piece_type]
	local own_pieces = self.occupied[color]
	local other_pieces = self.occupied[1 - color]

	while pieces ~= u64.ZERO do
		local from_square
		pieces, from_square = Utils.pop_lsb(pieces)

		local attacks
		if piece_type == KNIGHT or piece_type == KING then
			attacks = attack_func(from_square)
		else
			attacks = attack_func(from_square, own_pieces, other_pieces)
		end

		-- Remove moves to squares occupied by own pieces
		attacks = u64.band(attacks, u64.bnot(own_pieces))

		while attacks ~= u64.ZERO do
			local to_square
			attacks, to_square = Utils.pop_lsb(attacks)

			local is_capture = Utils.get_bit(other_pieces, to_square)
			table.insert(moves, Move.new(from_square, to_square, piece_type, is_capture))
		end
	end
end
function Board.generate_legal_moves(self, filePseudoLegal, color)
    color = color or self.side_to_move

	local moves = {}

	Board.update_occupied(self)
	generate_pawn_moves(self, moves, color)
	generate_piece_moves(self, moves, KNIGHT, Attacks.knight_attacks, color)
	generate_piece_moves(self, moves, BISHOP, Attacks.bishop_attacks, color)
	generate_piece_moves(self, moves, ROOK, Attacks.rook_attacks, color)
	generate_piece_moves(self, moves, QUEEN, Attacks.queen_attacks, color)
	generate_piece_moves(self, moves, KING, Attacks.king_attacks, color)

	-- TODO: Add castling moves

	if not filePseudoLegal then
	    local myKing = Board.find_piece(self, KING, color)
		if myKing < 0 then return {} end
	    local filtered_moves = {}

	    for _, move in moves do
			local branch = Board.clone(self)
			Board.make_move(branch, move)
	        if not Board.is_square_attacked(branch, myKing, 1-color) then
	            table.insert(filtered_moves, move)
	        end
	    end
	    return filtered_moves
	else
		return moves
	end
end
function Board.generate_legal_moves_from(self, from, filePseudoLegal, color)
    local allMoves = Board.generate_legal_moves(self, filePseudoLegal, color)
    local moves = {}

    for _, move in allMoves do
        if move.from == from then
            table.insert(moves, move)
        end
    end

    return moves
end
function Board:is_square_attacked(square, by_color)
	local occupiedMe = self.occupied[by_color]
	local myPieces = self.pieces[by_color]
	local occupiedEnemy = self.occupied[1 - by_color]

	local pawn_attack_bb = Attacks.pawn_attacks(square, 1 - by_color) -- Reverse color for "from where can pawns attack this square"
	if u64.btest(myPieces[PAWN], pawn_attack_bb) then
		return true
	end

	-- Check knight attacks
	local knight_attack_bb = Attacks.knight_attacks(square)
	if u64.btest(myPieces[KNIGHT], knight_attack_bb) then
		return true
	end

	-- Check king attacks
	local king_attack_bb = Attacks.king_attacks(square)
	if u64.btest(myPieces[KING], king_attack_bb) then
		return true
	end

	-- Check bishop/queen diagonal attacks
	local bishop_attack_bb = Attacks.bishop_attacks(square, occupiedMe, occupiedEnemy)
	local diagonal_attackers = u64.bor(myPieces[BISHOP], myPieces[QUEEN])
	if u64.btest(diagonal_attackers, bishop_attack_bb) then
		return true
	end

	-- Check rook/queen straight attacks
	local rook_attack_bb = Attacks.rook_attacks(square, occupiedMe, occupiedEnemy)
	local straight_attackers = u64.bor(myPieces[ROOK], myPieces[QUEEN])
	if u64.btest(straight_attackers, rook_attack_bb) then
		return true
	end

	return false
end


-- Pieces
function Board.get_piece(self, loc)
    local search = u64.lshift(u64.ONE, loc)
    for color, pieces in self.pieces do
        for typ, bb in pieces do
            if u64.band(bb, search) ~= u64.ZERO then
                return {color, typ}
            end
        end
    end
    return nil
end
function Board.get_all_pieces(self)
    local pieces_list = {}

    for color, piece_table in self.pieces do
        for typ, bb in piece_table do
            local b = bb

            while b ~= u64.ZERO do
                local lsb = 63 - u64.countlz(b)
                local loc = lsb
                table.insert(pieces_list, { typ, color, loc })
                b = u64.band(b, u64.bnot(u64.lshift(u64.ONE, lsb)))
            end
        end
    end

    return pieces_list
end
function Board.find_piece(self, piece_type, color)
    local bb = self.pieces[color][piece_type]
    local square = 63-u64.countlz(bb)
    return square
end

-- Endgame
function Board.get_game_state(self)
    -- TODO: Insufficent material
    local color = self.side_to_move

    -- Generate all legal moves
    local moves = Board.generate_legal_moves(self, true, color)

    -- Check if king is in check
    local king_bb = self.pieces[color][KING]
    local king_square = 63 - u64.countlz(king_bb)
    local in_check = Board.is_square_attacked(self, king_square, 1 - color)

    if #moves == 0 then
        if in_check then
            return "checkmate"
        else
            return "stalemate"
        end
    end

    return ""
end


return {BitBoard = Board} -- for roblox-ts

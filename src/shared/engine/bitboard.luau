--!native
--!optimize 2

local u64 = require("./int64")
local Utils = require("./utils")
local Attacks = require("./attacks")
local Move = require("./move")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local RANK_1, RANK_2, RANK_7, RANK_8, FILE_A, FILE_H, NOT_FILE_A, NOT_FILE_H, NOT_FILE_AB, NOT_FILE_GH = Utils.RANK_1, Utils.RANK_2, Utils.RANK_7, Utils.RANK_8, Utils.FILE_A, Utils.FILE_H, Utils.NOT_FILE_A, Utils.NOT_FILE_H, Utils.NOT_FILE_AB, Utils.NOT_FILE_GH

local Board = {}

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
    -- TODO: test out using table.clone, faster or slower?
	local bin = Board.to_buffer(board)
	local new = buffer.create(buffer.len(bin))
	buffer.copy(new, 0, bin, 0)
	return new
end

-- Encoding, unlike older versions this is designed to be **rapid**, not efficent.
function Board.to_buffer(self)
    local buf = buffer.create(1040) -- (64*15)+(8*6)+(16*2)
    local off = 0

    -- Helper for writing a u64
    local function writeU64(value)
        local tmp = u64.to_buffer(value)
        buffer.copy(buf, off, tmp, 0, 8)
        off += 8
    end

    -- Pieces
    for color = WHITE, BLACK do
        for piece = PAWN, KING do
            writeU64(self.pieces[color][piece])
        end
    end

    -- Occupancy
    writeU64(self.occupied[WHITE])
    writeU64(self.occupied[BLACK])
    writeU64(self.occupied.all)

    -- Side to move
    buffer.writeu8(buf, off, self.side_to_move)
    off += 1

    -- Castling
    buffer.writeu8(buf, off, self.castling_rights.white_kingside  and 1 or 0); off += 1
    buffer.writeu8(buf, off, self.castling_rights.white_queenside and 1 or 0); off += 1
    buffer.writeu8(buf, off, self.castling_rights.black_kingside  and 1 or 0); off += 1
    buffer.writeu8(buf, off, self.castling_rights.black_queenside and 1 or 0); off += 1

    -- En-passant
    local ep = self.en_passant_square or 0
    buffer.writeu8(buf, off, ep)
    off += 1

    -- Clocks
    buffer.writeu16(buf, off, self.halfmove_clock);  off += 2
    buffer.writeu16(buf, off, self.fullmove_number); off += 2

    return buf
end
function Board.from_buffer(buf)
    local self = Board.create()
    local off = 0

    -- Helper for reading a u64
    local function readU64()
        local val = u64.from_buffer(buf, off)
        off += 8
        return val
    end

    -- Pieces
    for color = WHITE, BLACK do
        for piece = PAWN, KING do
            self.pieces[color][piece] = readU64()
        end
    end

    -- Occupancy
    self.occupied[WHITE] = readU64()
    self.occupied[BLACK] = readU64()
    self.occupied.all   = readU64()

    -- Side to move
    self.side_to_move = buffer.readu8(buf, off)
    off += 1

    -- Castling rights
    self.castling_rights.white_kingside  = buffer.readu8(buf, off) == 1; off += 1
    self.castling_rights.white_queenside = buffer.readu8(buf, off) == 1; off += 1
    self.castling_rights.black_kingside  = buffer.readu8(buf, off) == 1; off += 1
    self.castling_rights.black_queenside = buffer.readu8(buf, off) == 1; off += 1

    -- En-passant
    local ep = buffer.readu8(buf, off)
    off += 1
    self.en_passant_square = (ep == EN_PASSANT_NONE) and nil or ep

    -- Clocks
    self.halfmove_clock  = buffer.readu16(buf, off); off += 2
    self.fullmove_number = buffer.readu16(buf, off); off += 2

    return self
end

-- Zobrist
local Zobrist = {}
Zobrist.piece_square = {}
Zobrist.castling = {}
Zobrist.en_passant = {}
Zobrist.side_to_move = 0
do
    math.randomseed(10)
    local random64 = function()
        return u64.from_pair(math.random(0, 0xFFFFFFFF), math.random(0, 0xFFFFFFFF))
    end

    for color = WHITE, BLACK do
        Zobrist.piece_square[color] = {}
        for piece = PAWN, KING do
            Zobrist.piece_square[color][piece] = {}
            for square = 0, 63 do
                Zobrist.piece_square[color][piece][square] = random64()
            end
        end
    end

    for i = 1, 4 do
        Zobrist.castling[i] = random64()
    end
    for file = 0, 7 do
        Zobrist.en_passant[file] = random64()
    end
    Zobrist.side_to_move = random64()
end
function Board.hash(board)
    local hash = u64.ZERO

    -- Pieces
    for color = WHITE, BLACK do
        for piece = PAWN, KING do
            local bb = board.pieces[color][piece]
            while bb ~= u64.ZERO do
                local square
                bb, square = Utils.pop_lsb(bb)
                hash = u64.bxor(hash, Zobrist.piece_square[color][piece][square])
            end
        end
    end

    -- Castling
    if board.castling_rights.white_kingside then hash = u64.bxor(hash, Zobrist.castling[1]) end
    if board.castling_rights.white_queenside then hash = u64.bxor(hash, Zobrist.castling[2]) end
    if board.castling_rights.black_kingside then hash = u64.bxor(hash, Zobrist.castling[3]) end
    if board.castling_rights.black_queenside then hash = u64.bxor(hash, Zobrist.castling[4]) end

    -- En passant
    if board.en_passant_square then
        local file = board.en_passant_square % 8
        hash = u64.bxor(hash, Zobrist.en_passant[file])
    end

    -- Side to move
    if board.side_to_move == WHITE then
        hash = u64.bxor(hash, Zobrist.side_to_move)
    end

    return u64.to_byte_string(hash)
end

-- FEN
local piece_map = {
	P = {color = WHITE, type = PAWN},
	N = {color = WHITE, type = KNIGHT},
	B = {color = WHITE, type = BISHOP},
	R = {color = WHITE, type = ROOK},
	Q = {color = WHITE, type = QUEEN},
	K = {color = WHITE, type = KING},
	p = {color = BLACK, type = PAWN},
	n = {color = BLACK, type = KNIGHT},
	b = {color = BLACK, type = BISHOP},
	r = {color = BLACK, type = ROOK},
	q = {color = BLACK, type = QUEEN},
	k = {color = BLACK, type = KING},
}
local piece_char = {
	[WHITE] = { [PAWN]="P", [KNIGHT]="N", [BISHOP]="B", [ROOK]="R", [QUEEN]="Q", [KING]="K"},
	[BLACK] = { [PAWN]="p", [KNIGHT]="n", [BISHOP]="b", [ROOK]="r", [QUEEN]="q", [KING]="k"},
}

function Board.from_fen(self)
	local board = self
	local parts = {}
	for part in string.gmatch(fen, "[^ ]+") do
		table.insert(parts, part)
	end

	local rows = {}
	for row in string.gmatch(parts[1], "[^/]+") do
		table.insert(rows, row)
	end

	-- clear all bitboards first
	for _, color in pairs({WHITE, BLACK}) do
		for _, typ in pairs({PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING}) do
			board.pieces[color][typ] = u64.ZERO
		end
		board.occupied[color] = u64.ZERO
	end
	board.occupied.all = u64.ZERO

	for rank = 1, 8 do
		local file = 0
		for c in rows[rank]:gmatch(".") do
			local n = tonumber(c)
			if n then
				file = file + n
			else
				local info = piece_map[c]
				if info then
					local square = (8 - rank) * 8 + file
					board.pieces[info.color][info.type] = u64.bor(board.pieces[info.color][info.type], u64.from_index(square))
                    board.occupied[info.color] = u64.bor(board.occupied[info.color], u64.from_index(square))
                    board.occupied.all = u64.bor(board.occupied.all, u64.from_index(square))
				end
				file = file + 1
			end
		end
	end

	board.side_to_move = (parts[2] == "w") and WHITE or BLACK

	board.castling_rights.white_kingside = parts[3]:find("K") ~= nil
	board.castling_rights.white_queenside = parts[3]:find("Q") ~= nil
	board.castling_rights.black_kingside = parts[3]:find("k") ~= nil
	board.castling_rights.black_queenside = parts[3]:find("q") ~= nil

	board.en_passant_square = (parts[4] ~= "-") and parts[4] or nil
	board.halfmove_clock = tonumber(parts[5])
	board.fullmove_number = tonumber(parts[6])
end
function Board.to_fen(self)
	local fen = {}
	for rank = 8, 1, -1 do
		local empty = 0
		for file = 0, 7 do
			local square = (rank - 1) * 8 + file
			local piece_found = false
			for color, color_table in self.pieces do
				for typ, bb in color_table do
					if Utils.get_bit(bb, square) then
						if empty > 0 then
							table.insert(fen, tostring(empty))
							empty = 0
						end
						table.insert(fen, piece_char[color][typ])
						piece_found = true
						break
					end
				end
				if piece_found then break end
			end
			if not piece_found then
				empty = empty + 1
			end
		end
		if empty > 0 then
			table.insert(fen, tostring(empty))
		end
		if rank > 1 then
			table.insert(fen, "/")
		end
	end

	local stm = (self.side_to_move == WHITE) and "w" or "b"

	local castling = ""
	if self.castling_rights.white_kingside then castling = castling.."K" end
	if self.castling_rights.white_queenside then castling = castling.."Q" end
	if self.castling_rights.black_kingside then castling = castling.."k" end
	if self.castling_rights.black_queenside then castling = castling.."q" end
	if castling == "" then castling = "-" end

	local ep = self.en_passant_square or "-"

	return table.concat(fen)..(" "..stm.." "..castling.." "..ep.." "..self.halfmove_clock.." "..self.fullmove_number)
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
function Board.save_state(self)
	-- Save state for unmake_move
	return {
		side_to_move = self.side_to_move,
		en_passant_square = self.en_passant_square,
		castling_rights = {
			white_kingside = self.castling_rights.white_kingside,
			white_queenside = self.castling_rights.white_queenside,
			black_kingside = self.castling_rights.black_kingside,
			black_queenside = self.castling_rights.black_queenside,
		},
		halfmove_clock = self.halfmove_clock,
		fullmove_number = self.fullmove_number,
	}
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
function Board.unmake_move(self, move, previous_state)
	-- Restore previous state
	self.side_to_move = previous_state.side_to_move
	self.en_passant_square = previous_state.en_passant_square
	self.castling_rights = previous_state.castling_rights
	self.halfmove_clock = previous_state.halfmove_clock
	self.fullmove_number = previous_state.fullmove_number

	local color = self.side_to_move
	local opponent = 1 - color

	-- Remove piece from destination square
	local final_piece_type = move.promotion or move.piece_type
	self.pieces[color][final_piece_type] = Utils.clear_bit(self.pieces[color][final_piece_type], move.to)

	-- Restore piece to original square
	self.pieces[color][move.piece_type] = Utils.set_bit(self.pieces[color][move.piece_type], move.from)

	-- Restore captured piece
	if move.captured then
		if move.flags and move.flags.en_passant then
			-- Restore en passant captured pawn
			local captured_pawn_square = move.to - (if color == WHITE then 8 else -8)
			self.pieces[opponent][PAWN] = Utils.set_bit(self.pieces[opponent][PAWN], captured_pawn_square)
		else
			-- Restore normally captured piece
			-- Note: you'd need to store which piece type was captured
			self.pieces[opponent][previous_state.captured_piece_type] = Utils.set_bit(
				self.pieces[opponent][previous_state.captured_piece_type],
				move.to
			)
		end
	end

	-- Restore castling rook
	if move.flags and move.flags.castling then
		local rook_from, rook_to
		if move.flags.kingside then
			rook_from = if color == WHITE then 7 else 63
			rook_to = if color == WHITE then 5 else 61
		else
			rook_from = if color == WHITE then 0 else 56
			rook_to = if color == WHITE then 3 else 59
		end

		self.pieces[color][ROOK] = Utils.clear_bit(self.pieces[color][ROOK], rook_to)
		self.pieces[color][ROOK] = Utils.set_bit(self.pieces[color][ROOK], rook_from)
	end

	Board.update_occupied(self)
end

-- Move generation
local function generate_pawn_moves(self, moves, color)
	color = color or self.side_to_move
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
	color = color or self.side_to_move
	local pieces = self.pieces[color][piece_type]
	local own_pieces = self.occupied[color]

	while pieces ~= u64.ZERO do
		local from_square
		pieces, from_square = Utils.pop_lsb(pieces)

		local attacks
		if piece_type == KNIGHT or piece_type == KING then
			attacks = attack_func(from_square)
		else
			attacks = attack_func(from_square, self.occupied.all)
		end

		-- Remove moves to squares occupied by own pieces
		attacks = u64.band(attacks, u64.bnot(own_pieces))

		while attacks ~= u64.ZERO do
			local to_square
			attacks, to_square = Utils.pop_lsb(attacks)

			local is_capture = Utils.get_bit(self.occupied[1 - color], to_square)
			table.insert(moves, Move.new(from_square, to_square, piece_type, is_capture))
		end
	end
end
function Board.generate_legal_moves(self, filePseudoLegal, color)
	local moves = {}

	generate_pawn_moves(self, moves, color)
	generate_piece_moves(self, moves, KNIGHT, Attacks.knight_attacks, color)
	generate_piece_moves(self, moves, BISHOP, Attacks.bishop_attacks, color)
	generate_piece_moves(self, moves, ROOK, Attacks.rook_attacks, color)
	generate_piece_moves(self, moves, QUEEN, Attacks.queen_attacks, color)
	generate_piece_moves(self, moves, KING, Attacks.king_attacks, color)

	-- TODO: Add castling moves
	-- TODO: Filter out moves that leave king in check

	return moves
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
function Board.is_square_attacked(self, square, by_color)
    local opponent = by_color

    -- Pawns
    local pawns = self.pieces[opponent][PAWN]
    local pawn_attacks
    if opponent == WHITE then
        pawn_attacks = u64.band(u64.rshift(pawns, 7), NOT_FILE_H)
        if u64.btest(pawn_attacks, u64.from_index(square)) then return true end
        pawn_attacks = u64.band(u64.rshift(pawns, 9), NOT_FILE_A)
        if u64.btest(pawn_attacks, u64.from_index(square)) then return true end
    else
        pawn_attacks = u64.band(u64.lshift(pawns, 7), NOT_FILE_A)
        if u64.btest(pawn_attacks, u64.from_index(square)) then return true end
        pawn_attacks = u64.band(u64.lshift(pawns, 9), NOT_FILE_H)
        if u64.btest(pawn_attacks, u64.from_index(square)) then return true end
    end

    -- Knights
    local knights = self.pieces[opponent][KNIGHT]
    while knights ~= u64.ZERO do
        local from_square
        knights, from_square = Utils.pop_lsb(knights)
        if u64.btest(Attacks.knight_attacks(from_square), u64.from_index(square)) then
            return true
        end
    end

    -- King
    local king = self.pieces[opponent][KING]
    local king_sq = u64.lsb(king)
    if u64.btest(Attacks.king_attacks(king_sq), u64.from_index(square)) then
        return true
    end

    -- Bishops / Queens (diagonals)
    local bishops = u64.bor(self.pieces[opponent][BISHOP], self.pieces[opponent][QUEEN])
    while bishops ~= u64.ZERO do
        local from_square
        bishops, from_square = Utils.pop_lsb(bishops)
        if u64.btest(Attacks.bishop_attacks(from_square, self.occupied.all), u64.from_index(square)) then
            return true
        end
    end

    -- Rooks / Queens (straight lines)
    local rooks = u64.bor(self.pieces[opponent][ROOK], self.pieces[opponent][QUEEN])
    while rooks ~= u64.ZERO do
        local from_square
        rooks, from_square = Utils.pop_lsb(rooks)
        if u64.btest(Attacks.rook_attacks(from_square, self.occupied.all), u64.from_index(square)) then
            return true
        end
    end

    return false
end


-- Pieces
function Board.get_piece(self, loc)
    for color, pieces in self.pieces do
        for typ, bb in pieces do
            if not u64.eq(u64.band(bb, u64.from_index(loc)), u64.ZERO) then
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
    local squares = {}

    while not u64.eq(bb, u64.ZERO) do
        local square
        bb, square = Utils.pop_lsb(bb)
        table.insert(squares, square)
    end

    return squares
end

-- Endgame
function Board.get_game_state(self)
    -- TODO: Insufficent material
    local color = self.side_to_move

    -- Generate all legal moves
    local moves = Board.generate_legal_moves(self, true, color)

    -- Check if king is in check
    local king_bb = self.pieces[color][KING]
    local king_square = u64.lsb(king_bb)
    local in_check = Board.is_square_attacked(self, king_square, 1 - color)

    if #moves == 0 then
        if in_check then
            return "checkmate"
        else
            return "stalemate"
        end
    end

    return "none"
end

-- Utils
function Board.separate_square_index(loc: number)
	return { bit32.band(loc, 7), bit32.arshift(loc, 3) }
end
function Board.get_square_index(file: number, rank: number)
	return bit32.bor(bit32.lshift(rank, 3), file)
end


return {BitBoard = Board} -- for roblox-ts

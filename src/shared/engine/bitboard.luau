--!native
--!optimize 2
--!strict
local u64 = require("./int64")
local Utils = require("./utils")
local Attacks = require("./attacks")
local Move = require("./move").Move
local Zobrist = require("./zobrist")
local Encoding = require("./encoding")
local FEN = require("./fen")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING
local RANK_1, RANK_2, RANK_7, RANK_8, NOT_FILE_A, NOT_FILE_H = Utils.RANK_1, Utils.RANK_2, Utils.RANK_7, Utils.RANK_8, Utils.NOT_FILE_A, Utils.NOT_FILE_H
local make_pair, split_pair = Utils.make_pair, Utils.split_pair

local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ;

export type Board = {
    pieceTable: {[number]: number},
    pieces: {[number]: {[number]: vector}},
    occupied: {[number]:vector, all: vector},
    attacked: {[number]: {[number]: vector, all: vector}},
    side_to_move: number,
    castling_rights: number,
    en_passant_square: number?,
    halfmove_clock: number,
    fullmove_number: number
}

local Board = {
    hash = Zobrist,

    to_fen = FEN.to_fen,
    from_fen = FEN.from_fen,

    separate_square_index = Utils.separate_square_index,
    get_square_index = Utils.get_square_index,

    to_buffer = Encoding.to_buffer,
    from_buffer = Encoding.from_buffer
}

function Board.create(blank: boolean?): Board
    local empty = {};
    for i = 0, 63 do empty[i] = {} end

    local board: Board = {
        -- Bitboards for each piece type and color
        pieceTable = {},
        pieces = {
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
        },

        -- Attacked bitboard
        attacked = {
            [WHITE] = {
                [PAWN] = u64.ZERO,
                [KNIGHT] = u64.ZERO,
                [BISHOP] = u64.ZERO,
                [ROOK] = u64.ZERO,
                [QUEEN] = u64.ZERO,
                [KING] = u64.ZERO,
                all = u64.ZERO,
            },
            [BLACK] = {
                [PAWN] = u64.ZERO,
                [KNIGHT] = u64.ZERO,
                [BISHOP] = u64.ZERO,
                [ROOK] = u64.ZERO,
                [QUEEN] = u64.ZERO,
                [KING] = u64.ZERO,
                all = u64.ZERO,
            }
        },

        -- Occupied bitboards (initialized empty)
        occupied = {
            [WHITE] = u64.ZERO,
            [BLACK] = u64.ZERO,
            all = u64.ZERO,
        },

        -- Game state
        side_to_move = WHITE,
        castling_rights = 0b1111,
        en_passant_square = nil, -- square index or nil
        halfmove_clock = 0,
        fullmove_number = 1,
    }

	if not blank then Board.set_start_position(board) end

	return board
end
function Board.clone(board: Board): Board
	return {
		pieceTable = table.clone(board.pieceTable),
		pieces = {
			[WHITE] = table.clone(board.pieces[WHITE]),
			[BLACK] = table.clone(board.pieces[BLACK])
		},
		attacked = {
			[WHITE] = table.clone(board.attacked[WHITE]),
			[BLACK] = table.clone(board.attacked[BLACK])
		},
		en_passant_square = board.en_passant_square,
		halfmove_clock = board.halfmove_clock,
		fullmove_number = board.fullmove_number,
		side_to_move = board.side_to_move,
		castling_rights = board.castling_rights,
		occupied = table.clone(board.occupied),
	}
end

-- State
function Board.set_start_position(board: Board)
    -- White pieces
    board.pieces[WHITE][PAWN]   = u64.from_pair(0x00000000, 0x0000FF00)
    board.pieces[WHITE][KNIGHT] = u64.from_pair(0x00000000, 0x00000042)
    board.pieces[WHITE][BISHOP] = u64.from_pair(0x00000000, 0x00000024)
    board.pieces[WHITE][ROOK]   = u64.from_pair(0x00000000, 0x00000081)
    board.pieces[WHITE][QUEEN]  = u64.from_pair(0x00000000, 0x00000008)
    board.pieces[WHITE][KING]   = u64.from_pair(0x00000000, 0x00000010)

    -- Black pieces
    board.pieces[BLACK][PAWN]   = u64.from_pair(0x00FF0000, 0x00000000)
    board.pieces[BLACK][KNIGHT] = u64.from_pair(0x42000000, 0x00000000)
    board.pieces[BLACK][BISHOP] = u64.from_pair(0x24000000, 0x00000000)
    board.pieces[BLACK][ROOK]   = u64.from_pair(0x81000000, 0x00000000)
    board.pieces[BLACK][QUEEN]  = u64.from_pair(0x08000000, 0x00000000)
    board.pieces[BLACK][KING]   = u64.from_pair(0x10000000, 0x00000000)

    -- Board.from_fen(board, "6K1/1r6/8/8/8/4k3/4N3/8 w - - 7 169");

	Board.update_occupied(board)
	for color = WHITE, BLACK do
		for pieceType = PAWN, KING do
			Utils.iterate_bits(board.pieces[color][pieceType], function(bitIndex)
				board.pieceTable[bitIndex] = make_pair(pieceType, color)
			end)
		end
	end
end
function Board.update_occupied(board: Board)
    local whitePieces = board.pieces[WHITE]
    local blackPieces = board.pieces[BLACK]

    -- White
    board.occupied[WHITE] = u64.hex_bor(
        whitePieces[PAWN],
        whitePieces[KNIGHT],
        whitePieces[BISHOP],
        whitePieces[ROOK],
        whitePieces[QUEEN],
        whitePieces[KING]
    )

    -- Black
    board.occupied[BLACK] = u64.hex_bor(
        blackPieces[PAWN],
        blackPieces[KNIGHT],
        blackPieces[BISHOP],
        blackPieces[ROOK],
        blackPieces[QUEEN],
        blackPieces[KING]
    )

    -- All
    board.occupied.all = u64.bor(board.occupied[WHITE], board.occupied[BLACK])
end

-- Move operation
export type UndoRecord = {
    move: number,
    from: number,
    to: number,
    piece: number,
    captured_piece: {type: number, color: number, square: number}?,
    promotion: number?,
    castling_rights: number,
    en_passant_square: number?,
    halfmove_clock: number,
    fullmove_number: number,
    additionallyMoved: {number}?,  -- rook moves for castling or ep captures
}

function Board.make_move(board: Board, move: number): {[number]: number}|nil -- Returns additional changes like: [{from, to} or {from, nil}]
	local color = board.side_to_move
	local opponent = 1 - color

	local from = Move.getFrom(move)
	local to = Move.getTo(move)
	local piece_type = Move.getPieceType(move)
	local captured = Move.getCaptured(move)
	local en_passant = Move.getEnPassant(move)
	local promotion = Move.getPromotion(move)
	local castling, kingside = Move.getCastling(move)

	local additionallyMoved = nil

	-- Clear the piece from its original square
	board.pieces[color][piece_type] = Utils.clear_bit(board.pieces[color][piece_type], from)
	board.pieceTable[from] = nil
	board.pieceTable[to] = make_pair(piece_type, color)

	-- Handle captures
	if captured then
		-- Check which piece type was captured
		for p = PAWN, KING do
			if Utils.get_bit(board.pieces[opponent][p], to) then
				board.pieces[opponent][p] = Utils.clear_bit(board.pieces[opponent][p], to)

				board.occupied.all = Utils.clear_bit(board.occupied.all, to)
				board.occupied[opponent] = Utils.clear_bit(board.occupied[opponent], to)

				break
			end
		end

		-- Handle en passant capture (captured pawn is not on target square)
		if en_passant then
			local captured_pawn_square = to - (if color == WHITE then 8 else -8)
			board.pieces[opponent][PAWN] = Utils.clear_bit(board.pieces[opponent][PAWN], captured_pawn_square)
			board.pieceTable[captured_pawn_square] = nil

			board.occupied.all = Utils.clear_bit(board.occupied.all, captured_pawn_square)
			board.occupied[opponent] = Utils.clear_bit(board.occupied[opponent], captured_pawn_square)

			additionallyMoved = {captured_pawn_square}
		end

		board.halfmove_clock = 0
	else
		board.halfmove_clock += 1
	end

	-- Place the piece on the new square (with promotion if applicable)
	local final_piece_type = promotion or piece_type
	board.pieces[color][final_piece_type] = Utils.set_bit(board.pieces[color][final_piece_type], to)
	board.pieceTable[to] = make_pair(final_piece_type, color)

	-- Reset halfmove clock on pawn moves
	if piece_type == PAWN then
		board.halfmove_clock = 0
	end

	-- Update en passant square
	board.en_passant_square = nil
	if piece_type == PAWN then
		local move_distance = math.abs(to - from)
		if move_distance == 16 then
			-- Double pawn push, set en passant square
			board.en_passant_square = if color == WHITE then (from + 8) else (from - 8)
		end
	end

	-- Update castling rights
	if piece_type == KING then
		if color == WHITE then
		    board.castling_rights = Utils.clear_bit32(board.castling_rights, WK)
		    board.castling_rights = Utils.clear_bit32(board.castling_rights, WQ)
		else
            board.castling_rights = Utils.clear_bit32(board.castling_rights, BK)
            board.castling_rights = Utils.clear_bit32(board.castling_rights, BQ)
		end
	elseif piece_type == ROOK then
		-- Check if rook moved from starting square
		if color == WHITE then
			if from == 0 then
				board.castling_rights = Utils.clear_bit32(board.castling_rights, WQ)
			elseif from == 7 then
				board.castling_rights = Utils.clear_bit32(board.castling_rights, WK)
			end
		else
			if from == 56 then
				board.castling_rights = Utils.clear_bit32(board.castling_rights, BQ)
			elseif from == 63 then
				board.castling_rights = Utils.clear_bit32(board.castling_rights, BK)
			end
		end
	end

	-- Also lose castling rights if rook is captured
	if captured then
		if to == 0 then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, WQ)
		elseif to == 7 then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, WK)
		elseif to == 56 then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, BQ)
		elseif to == 63 then
			board.castling_rights = Utils.clear_bit32(board.castling_rights, BK)
		end
	end

	-- Handle castling moves
	if castling then
		local rook_from, rook_to
		if kingside then
			rook_from = if color == WHITE then 7 else 63
			rook_to = if color == WHITE then 5 else 61
		else -- queenside
			rook_from = if color == WHITE then 0 else 56
			rook_to = if color == WHITE then 3 else 59
		end

		-- Move the rook
		board.pieces[color][ROOK] = Utils.clear_bit(board.pieces[color][ROOK], rook_from)
		board.pieces[color][ROOK] = Utils.set_bit(board.pieces[color][ROOK], rook_to)

		board.pieceTable[rook_from] = nil
		board.pieceTable[rook_to] = make_pair(ROOK, color)

		board.occupied.all = Utils.clear_bit(board.occupied.all, rook_from)
		board.occupied[color] = Utils.clear_bit(board.occupied[color], rook_from)

		board.occupied.all = Utils.set_bit(board.occupied.all, rook_to)
		board.occupied[color] = Utils.set_bit(board.occupied[color], rook_to)

		additionallyMoved = {rook_from, rook_to}
	end

	-- **Incrementally** update occupied bitboards
	-- Board.update_occupied(board)
	board.occupied.all = Utils.clear_bit(board.occupied.all, from)
	board.occupied.all = Utils.set_bit(board.occupied.all, to)

	board.occupied[color] = Utils.clear_bit(board.occupied[color], from)
	board.occupied[color] = Utils.set_bit(board.occupied[color], to)

	-- Switch side to move
	board.side_to_move = opponent

	-- Update fullmove number
	if color == BLACK then
		board.fullmove_number += 1
	end

	return additionallyMoved
end

-- Attacked squares
function Board.regenerate_piece_attacked(board: Board, by_color: number, piece: number): {number}
    local blockingPairs = {}

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

    -- SLIDING PIECES:
    -- Note: In the future, we can regenerate individuals or maybe even single rays (NE, NW) of a sliding piece based on pins.
    if attack_func then
        Utils.iterate_bits(board.pieces[by_color][piece], function(s)
            local attack, blockers = attack_func(s, board.occupied[by_color], board.occupied[1-by_color])
            attacks = u64.bor(attacks, attack)

            for _, blocker in blockers do
                table.insert(blockingPairs, make_pair(blocker, s))
            end
        end)
    end

    board.attacked[by_color][piece] = attacks

    return blockingPairs
end
function Board.attacked_occupancy(board: Board, by_color: number)
    board.attacked[by_color].all = u64.hex_bor(
        board.attacked[by_color][ROOK],
        board.attacked[by_color][BISHOP],
        board.attacked[by_color][QUEEN],
        board.attacked[by_color][KNIGHT],
        board.attacked[by_color][KING],
        board.attacked[by_color][PAWN]
    )
end
function Board.regenerate_all_attacked(board: Board, by_color: number)
    local blockingPairs = {}

    for _, i in Board.regenerate_piece_attacked(board, by_color, QUEEN) do table.insert(blockingPairs, i) end
    for _, i in Board.regenerate_piece_attacked(board, by_color, ROOK) do table.insert(blockingPairs, i) end
    for _, i in Board.regenerate_piece_attacked(board, by_color, BISHOP) do table.insert(blockingPairs, i) end

    Board.regenerate_piece_attacked(board, by_color, KNIGHT)
    Board.regenerate_piece_attacked(board, by_color, KING)
    Board.regenerate_piece_attacked(board, by_color, PAWN)

    Board.attacked_occupancy(board, by_color)

    return blockingPairs
end

function Board.is_square_attacked(board: Board, square: number, by_color: number): boolean
    return Utils.get_bit(board.attacked[by_color].all, square)
end

-- Move generation
local function generate_pawn_moves(board: Board, moves: {number}, color: number)
	local pawns = board.pieces[color][PAWN]
	local empty = u64.bnot(board.occupied.all)
	local enemies = board.occupied[1 - color]

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

	-- Captures. This does not use attacks because performing that in bulk will not let us know of the from square.
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
	    Utils.iterate_bits(targets, function(to_square: number)
			local from_square = to_square - from_offset

			-- Check for promotion
			if Utils.get_bit(promo_rank, to_square) then
				for promo = KNIGHT, QUEEN do
					table.insert(moves, Move.create(from_square, to_square, PAWN, is_capture, promo))
				end
			else
				table.insert(moves, Move.create(from_square, to_square, PAWN, is_capture, nil))
			end
		end)
	end

	add_pawn_moves(push_targets, push_dir, false)
	add_pawn_moves(double_push_targets, push_dir * 2, false)
	add_pawn_moves(left_captures, if color == WHITE then 7 else -7, true)
	add_pawn_moves(right_captures, if color == WHITE then 9 else -9, true)

	-- En passant
	if board.en_passant_square and board.en_passant_square>0 then
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
local function generate_piece_moves(board: Board, moves: {number}, piece_type: number, attack_func: (number, vector, vector) -> vector, color: number)
	local own_pieces = board.occupied[color]
	local other_pieces = board.occupied[1 - color]

	Utils.iterate_bits(board.pieces[color][piece_type], function(from_square)
        local attacks = attack_func(from_square, own_pieces, other_pieces)
        attacks = u64.band(attacks, u64.bnot(own_pieces))

        Utils.iterate_bits(attacks, function(to_square)
            local is_capture = Utils.get_bit(other_pieces, to_square)
            table.insert(moves, Move.create(from_square, to_square, piece_type, is_capture))
        end)
    end)
end

-- Castling
local CASTLE_MASKS = {
    [WHITE] = {
        [true] = {  -- kingside
            no_checks  = u64.from_pair(0x0, 0x70),  -- e1, f1, g1
            no_pieces  = u64.from_pair(0x0, 0x60)   -- f1, g1
        },
        [false] = { -- queenside
            no_checks  = u64.from_pair(0x0, 0x1C),  -- e1, d1, c1
            no_pieces  = u64.from_pair(0x0, 0x0E)   -- d1, c1, b1
        }
    },
    [BLACK] = {
        [true] = {  -- kingside
            no_checks  = u64.from_pair(0x70000000, 0x0),  -- e8, f8, g8
            no_pieces  = u64.from_pair(0x60000000, 0x0)   -- f8, g8
        },
        [false] = { -- queenside
            no_checks  = u64.from_pair(0x1C000000, 0x0),  -- e8, d8, c8
            no_pieces  = u64.from_pair(0x0E000000, 0x0)   -- d8, c8, b8
        }
    }
}
function generate_castle_moves(board: Board, moves: {number}, color: number, attacked: vector)
    local occupied = board.occupied.all
    local masks = CASTLE_MASKS[color]

    if color == WHITE then
        if Utils.get_bit32(board.castling_rights, WK) then
            if u64.band(occupied, masks[true].no_pieces) ~= u64.ZERO then return end
            if u64.band(attacked, masks[true].no_checks) ~= u64.ZERO then return end

    	    table.insert(moves, Move.create(4, 6, KING, false, nil, false, true, true))
    	end
        if Utils.get_bit32(board.castling_rights, WQ) then
            if u64.band(occupied, masks[false].no_pieces) ~= u64.ZERO then return end
            if u64.band(attacked, masks[false].no_checks) ~= u64.ZERO then return end

    	    table.insert(moves, Move.create(4, 2, KING, false, nil, false, true, false))
        end
    else
    	if Utils.get_bit32(board.castling_rights, BK) then
            if u64.band(occupied, masks[true].no_pieces) ~= u64.ZERO then return end
            if u64.band(attacked, masks[true].no_checks) ~= u64.ZERO then return end

    	    table.insert(moves, Move.create(60, 62, KING, false, nil, false, true, true))
    	end
        if Utils.get_bit32(board.castling_rights, BQ) then
            if u64.band(occupied, masks[false].no_pieces) ~= u64.ZERO then return end
            if u64.band(attacked, masks[false].no_checks) ~= u64.ZERO then return end

    	    table.insert(moves, Move.create(60, 58, KING, false, nil, false, true, false))
    	end
    end
end

-- Generate Legal Moves
function Board.generate_legal_moves(board: Board, filePseudoLegal: boolean?, givenColor: number?): {number}
    local color = givenColor or board.side_to_move
	local moves = table.create(30)

	generate_pawn_moves(board, moves, color)
	generate_piece_moves(board, moves, KNIGHT, Attacks.knight_attacks, color)
	generate_piece_moves(board, moves, BISHOP, Attacks.bishop_attacks, color)
	generate_piece_moves(board, moves, ROOK, Attacks.rook_attacks, color)
	generate_piece_moves(board, moves, QUEEN, Attacks.queen_attacks, color)
	generate_piece_moves(board, moves, KING, Attacks.king_attacks, color)
	generate_castle_moves(board, moves, color, board.attacked[1-color].all)

	local blocking = Board.regenerate_all_attacked(board, 1-color)

	local headKingPos = Board.find_piece(board, KING, color)
	if not headKingPos then
	    return {}
	end
	if filePseudoLegal then return moves end

    local filtered_moves = {}

    for _, move in moves do
		local branch = Board.clone(board)
		local isKing = Move.getPieceType(move) == KING

        local capturingPiece = if Move.getCaptured(move) then Board.get_piece(branch, Move.getTo(move)) else nil
		Board.make_move(branch, move)


        --- Regenerate attack bitboards
        -- Capturing piece (to escape check)
        if capturingPiece then
			Board.regenerate_piece_attacked(branch, 1-color, capturingPiece[1])
		end

		-- Blocking sliding pieces
		local valid = true;
		local alreadyGenerated = {};

		local to = Move.getTo(move)
		local from = Move.getFrom(move)

		for _, block in blocking do
		    local blocker, slider = split_pair(block)

			if isKing and blocker == to then -- king will take spot of blocker
			    valid = false
				break
			end
			if blocker ~= from then -- we are not moving the blocker
			    continue
			end

            local piece = Board.get_piece(branch, slider)
            if not piece then continue end

            -- if it is opponents piece and not already regenerated
            if piece[2] == 1-color and not alreadyGenerated[piece[1]] then
                alreadyGenerated[piece[2]] = true;
                Board.regenerate_piece_attacked(branch, 1-color, piece[1])
            end
        end

        if not valid then
            continue
        end

		Board.attacked_occupancy(branch, 1-color)

		-- Is this move moving the king?
		local kingPos = headKingPos
		if isKing then
			kingPos = Move.getTo(move)
		end

		local check = Board.is_square_attacked(branch, kingPos, 1-color)
        if not check then
            table.insert(filtered_moves, move)
        end
    end

    return filtered_moves
end
function Board.generate_legal_moves_from(board: Board, from: number, filePseudoLegal: boolean?, color: number?)
    -- This is not run much in the backend, so does not require the "ultraspeed" bitboard like the bot does.
    local allMoves = Board.generate_legal_moves(board, filePseudoLegal, color)
    local moves = {}

    for _, move in allMoves do
        local moveFrom = Move.getFrom(move)
        if moveFrom == from then
            table.insert(moves, move)
        end
    end

    return moves
end

-- Pieces
function Board.get_piece(board: Board, loc: number): {[number]: number}?
    local val = board.pieceTable[loc]
    if not val then return nil end
    return {split_pair(val)}
end

function Board.get_all_pieces(board: Board)
    local pieces_list = {}

    for pos = 0, 63 do
        local piece = Board.get_piece(board, pos)
        if piece then
            table.insert(pieces_list, { piece[1], piece[2], pos })
        end
    end

    return pieces_list
end
function Board.find_piece(board: Board, piece_type: number, color: number): number?
    local bb = board.pieces[color][piece_type]
    local square = 63-u64.countlz(bb)
    if square == -1 then return nil end
    return square
end

-- Endgame
function Board.get_game_state(board: Board, providedMoves: {number}?)
    -- TODO: Insufficent material
    local color = board.side_to_move

    -- Generate all legal moves
    local moves = providedMoves or Board.generate_legal_moves(board, false, color)

    -- Check if king is in check
    local king_square = Board.find_piece(board, KING, color)
    if not king_square then
        return "faulty"
    end

    local in_check = Board.is_square_attacked(board, king_square, 1 - color)

    if #moves == 0 then
        if in_check then
            return "checkmate"
        else
            return "stalemate"
        end
    end

    -- 50-move rule: draw if 50 full moves (100 halfmoves) without pawn move or capture
    if board.halfmove_clock >= 100 then
        return "draw_50_move_rule"
    end

    return ""
end


return {BitBoard = Board}

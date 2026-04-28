--!native
--!optimize 2
--!strict
local Utils   = require("./utils")
local MoveGen = require("./move_gen").MoveGen
local Zobrist = require("./zobrist")
local Encoding = require("./encoding")
local FEN     = require("./fen")
local MoveOps = require("./move_ops")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING

local ALL         = Utils.ALL
local ATTACKED_ALL = Utils.ATTACKED_ALL

local PIECE_STRIDE = Utils.PIECE_STRIDE  -- 6
local ATK_STRIDE   = Utils.ATK_STRIDE    -- 7

local make_pair_32, split_pair_32 = Utils.make_pair_32, Utils.split_pair_32

export type Board = Utils.Board

local Board = {
	hash = Zobrist.hash,

	to_fen   = FEN.to_fen,
	from_fen = FEN.from_fen,

	separate_square_index = Utils.separate_square_index,
	get_square_index      = Utils.get_square_index,

	to_buffer   = Encoding.to_buffer,
	from_buffer = Encoding.from_buffer,
}

function Board.create(blank: boolean?): Board
	local board: Board = {
		pieceTable = table.create(64),

		pieces  = table.create(PIECE_STRIDE * 2, 0i),  -- [color*6 + piece]
		attacked = table.create(ATK_STRIDE * 2, 0i),   -- [color*7 + piece], slot 6 = ATTACKED_ALL
		occupied = table.create(3, 0i),

		side_to_move    = WHITE,
		castling_rights = 0b1111,
		en_passant_square = nil,
		halfmove_clock  = 0,
		fullmove_number = 1,

		eval = 0,
		hash = 0,
	}

	if not blank then Board.set_start_position(board) end
	return board
end

function Board.clone(board: Board): Board
	return {
		pieceTable      = table.clone(board.pieceTable),
		pieces          = table.clone(board.pieces),
		attacked        = table.clone(board.attacked),
		occupied        = table.clone(board.occupied),
		en_passant_square = board.en_passant_square,
		halfmove_clock  = board.halfmove_clock,
		fullmove_number = board.fullmove_number,
		side_to_move    = board.side_to_move,
		castling_rights = board.castling_rights,
		eval            = board.eval,
		hash            = board.hash,
	}
end

function Board.set_start_position(board: Board)
	local W = WHITE * PIECE_STRIDE
	local B = BLACK * PIECE_STRIDE
	board.pieces[W+PAWN]   = 0x0000_0000_0000_FF00i
	board.pieces[W+KNIGHT] = 0x0000_0000_0000_0042i
	board.pieces[W+BISHOP] = 0x0000_0000_0000_0024i
	board.pieces[W+ROOK]   = 0x0000_0000_0000_0081i
	board.pieces[W+QUEEN]  = 0x0000_0000_0000_0008i
	board.pieces[W+KING]   = 0x0000_0000_0000_0010i

	board.pieces[B+PAWN]   = 0x00FF_0000_0000_0000i
	board.pieces[B+KNIGHT] = 0x4200_0000_0000_0000i
	board.pieces[B+BISHOP] = 0x2400_0000_0000_0000i
	board.pieces[B+ROOK]   = 0x8100_0000_0000_0000i
	board.pieces[B+QUEEN]  = 0x0800_0000_0000_0000i
	board.pieces[B+KING]   = 0x1000_0000_0000_0000i

	Board.update_occupied(board)

	for color = WHITE, BLACK do
		local base = color * PIECE_STRIDE
		for pieceType = PAWN, KING do
			local bb = board.pieces[base + pieceType]
			while bb ~= 0i do
				local bitIndex = integer.tonumber(integer.countrz(bb))
				board.pieceTable[bitIndex] = make_pair_32(pieceType, color)
				bb = integer.band(bb, integer.sub(bb, 1i))
			end
		end
	end
end

function Board.update_occupied(board: Board)
	local W = WHITE * PIECE_STRIDE
	local B = BLACK * PIECE_STRIDE
	local p = board.pieces

	local w = integer.bor(p[W+PAWN], p[W+KNIGHT], p[W+BISHOP], p[W+ROOK], p[W+QUEEN], p[W+KING])
	local b = integer.bor(p[B+PAWN], p[B+KNIGHT], p[B+BISHOP], p[B+ROOK], p[B+QUEEN], p[B+KING])

	board.occupied[WHITE] = w
	board.occupied[BLACK] = b
	board.occupied[ALL]   = integer.bor(w, b)
end

export type UndoRecord = MoveOps.UndoRecord

Board.make_move            = MoveOps.make_move
Board.undo_move            = MoveOps.undo_move
Board.get_undo_record_data = MoveOps.get_undo_record_data
Board.attacked_occupancy        = MoveGen.attacked_occupancy
Board.is_square_attacked        = MoveGen.is_square_attacked
Board.generate_legal_moves      = MoveGen.generate_legal_moves
Board.generate_legal_moves_from = MoveGen.generate_legal_moves_from

function Board.get_piece(board: Board, loc: number): (number?, number?)
	local val = board.pieceTable[loc]
	if not val then return nil, nil end
	return bit32.rshift(val, 6), bit32.band(val, 63)
end

function Board.get_all_pieces(board: Board)
	local pieces_list = {}
	for pos = 0, 63 do
		local piece = board.pieceTable[pos]
		if piece then
			local a, b = split_pair_32(piece)
			table.insert(pieces_list, { a, b, pos })
		end
	end
	return pieces_list
end

function Board.find_piece(board: Board, piece_type: number, color: number): number?
	local base = color * PIECE_STRIDE
	local bb = board.pieces[base + piece_type]
	if bb == 0i then return nil end
	local square = 63 - integer.tonumber(integer.countlz(bb))
	return square
end

function Board.get_game_state(board: Board, providedMoves: {number}?)
	local color = board.side_to_move
	local moves = providedMoves or Board.generate_legal_moves(board, false, color)

	local king_square = Board.find_piece(board, KING, color)
	if not king_square then return "faulty" end

	local in_check = Board.is_square_attacked(board, king_square, 1 - color)

	if #moves == 0 then
		if in_check then return "checkmate"
		else return "stalemate"
		end
	end

	if board.halfmove_clock >= 100 then return "draw_50_move_rule" end

	return ""
end

return { BitBoard = Board }

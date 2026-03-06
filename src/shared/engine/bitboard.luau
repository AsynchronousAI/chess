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

local make_pair, split_pair = Utils.make_pair, Utils.split_pair
local bb_countlz = Utils.bb_countlz
local bb_countrz = Utils.bb_countrz
local bb_sub_lo  = Utils.bb_sub_lo
local bb_sub_hi  = Utils.bb_sub_hi

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

		pieces_lo = {
			[WHITE] = table.create(6, 0),
			[BLACK] = table.create(6, 0),
		},
		pieces_hi = {
			[WHITE] = table.create(6, 0),
			[BLACK] = table.create(6, 0),
		},
		attacked_lo = {
			[WHITE] = table.create(7, 0),
			[BLACK] = table.create(7, 0),
		},
		attacked_hi = {
			[WHITE] = table.create(7, 0),
			[BLACK] = table.create(7, 0),
		},
		occupied_lo = table.create(3, 0),
		occupied_hi = table.create(3, 0),

		side_to_move    = WHITE,
		castling_rights = 0b1111,
		en_passant_square = nil,
		halfmove_clock  = 0,
		fullmove_number = 1,

		eval = 0,
		hash = 0,
	}

	for piece = PAWN, KING do
		board.pieces_lo[WHITE][piece] = 0
		board.pieces_hi[WHITE][piece] = 0
		board.pieces_lo[BLACK][piece] = 0
		board.pieces_hi[BLACK][piece] = 0
		board.attacked_lo[WHITE][piece] = 0
		board.attacked_hi[WHITE][piece] = 0
		board.attacked_lo[BLACK][piece] = 0
		board.attacked_hi[BLACK][piece] = 0
	end
	board.attacked_lo[WHITE][ATTACKED_ALL] = 0
	board.attacked_hi[WHITE][ATTACKED_ALL] = 0
	board.attacked_lo[BLACK][ATTACKED_ALL] = 0
	board.attacked_hi[BLACK][ATTACKED_ALL] = 0
	board.occupied_lo[WHITE] = 0
	board.occupied_hi[WHITE] = 0
	board.occupied_lo[BLACK] = 0
	board.occupied_hi[BLACK] = 0
	board.occupied_lo[ALL]   = 0
	board.occupied_hi[ALL]   = 0

	if not blank then Board.set_start_position(board) end
	return board
end

function Board.clone(board: Board): Board
	return {
		pieceTable      = table.clone(board.pieceTable),
		pieces_lo       = { [WHITE]=table.clone(board.pieces_lo[WHITE]), [BLACK]=table.clone(board.pieces_lo[BLACK]) },
		pieces_hi       = { [WHITE]=table.clone(board.pieces_hi[WHITE]), [BLACK]=table.clone(board.pieces_hi[BLACK]) },
		attacked_lo     = { [WHITE]=table.clone(board.attacked_lo[WHITE]), [BLACK]=table.clone(board.attacked_lo[BLACK]) },
		attacked_hi     = { [WHITE]=table.clone(board.attacked_hi[WHITE]), [BLACK]=table.clone(board.attacked_hi[BLACK]) },
		occupied_lo     = table.clone(board.occupied_lo),
		occupied_hi     = table.clone(board.occupied_hi),
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
	board.pieces_lo[WHITE][PAWN]   = 0x0000FF00; board.pieces_hi[WHITE][PAWN]   = 0x00000000
	board.pieces_lo[WHITE][KNIGHT] = 0x00000042; board.pieces_hi[WHITE][KNIGHT] = 0x00000000
	board.pieces_lo[WHITE][BISHOP] = 0x00000024; board.pieces_hi[WHITE][BISHOP] = 0x00000000
	board.pieces_lo[WHITE][ROOK]   = 0x00000081; board.pieces_hi[WHITE][ROOK]   = 0x00000000
	board.pieces_lo[WHITE][QUEEN]  = 0x00000008; board.pieces_hi[WHITE][QUEEN]  = 0x00000000
	board.pieces_lo[WHITE][KING]   = 0x00000010; board.pieces_hi[WHITE][KING]   = 0x00000000

	board.pieces_lo[BLACK][PAWN]   = 0x00000000; board.pieces_hi[BLACK][PAWN]   = 0x00FF0000
	board.pieces_lo[BLACK][KNIGHT] = 0x00000000; board.pieces_hi[BLACK][KNIGHT] = 0x42000000
	board.pieces_lo[BLACK][BISHOP] = 0x00000000; board.pieces_hi[BLACK][BISHOP] = 0x24000000
	board.pieces_lo[BLACK][ROOK]   = 0x00000000; board.pieces_hi[BLACK][ROOK]   = 0x81000000
	board.pieces_lo[BLACK][QUEEN]  = 0x00000000; board.pieces_hi[BLACK][QUEEN]  = 0x08000000
	board.pieces_lo[BLACK][KING]   = 0x00000000; board.pieces_hi[BLACK][KING]   = 0x10000000

	Board.update_occupied(board)

	for color = WHITE, BLACK do
		for pieceType = PAWN, KING do
			local bb_lo = board.pieces_lo[color][pieceType]
			local bb_hi = board.pieces_hi[color][pieceType]
			while bb_lo ~= 0 or bb_hi ~= 0 do
				local bitIndex = bb_countrz(bb_hi, bb_lo)
				board.pieceTable[bitIndex] = make_pair(pieceType, color)
				local nlo = bb_sub_lo(bb_lo, 1)
				local nhi = bb_sub_hi(bb_hi, 0, bb_lo, 1)
				bb_lo = bit32.band(bb_lo, nlo)
				bb_hi = bit32.band(bb_hi, nhi)
			end
		end
	end
end

function Board.update_occupied(board: Board)
	local wp = board.pieces_lo[WHITE]
	local bp = board.pieces_lo[BLACK]
	local wph = board.pieces_hi[WHITE]
	local bph = board.pieces_hi[BLACK]

	local w_lo = bit32.bor(wp[PAWN], wp[KNIGHT], wp[BISHOP], wp[ROOK], wp[QUEEN], wp[KING])
	local w_hi = bit32.bor(wph[PAWN], wph[KNIGHT], wph[BISHOP], wph[ROOK], wph[QUEEN], wph[KING])
	local b_lo = bit32.bor(bp[PAWN], bp[KNIGHT], bp[BISHOP], bp[ROOK], bp[QUEEN], bp[KING])
	local b_hi = bit32.bor(bph[PAWN], bph[KNIGHT], bph[BISHOP], bph[ROOK], bph[QUEEN], bph[KING])

	board.occupied_lo[WHITE] = w_lo; board.occupied_hi[WHITE] = w_hi
	board.occupied_lo[BLACK] = b_lo; board.occupied_hi[BLACK] = b_hi
	board.occupied_lo[ALL]   = bit32.bor(w_lo, b_lo)
	board.occupied_hi[ALL]   = bit32.bor(w_hi, b_hi)
end

export type UndoRecord = MoveOps.UndoRecord

Board.make_move            = MoveOps.make_move
Board.undo_move            = MoveOps.undo_move
Board.get_undo_record_data = MoveOps.get_undo_record_data
Board.regenerate_piece_attacked = MoveGen.regenerate_piece_attacked
Board.attacked_occupancy        = MoveGen.attacked_occupancy
Board.regenerate_all_attacked   = MoveGen.regenerate_all_attacked
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
			local a, b = split_pair(piece)
			table.insert(pieces_list, { a, b, pos })
		end
	end
	return pieces_list
end

function Board.find_piece(board: Board, piece_type: number, color: number): number?
	local hi = board.pieces_hi[color][piece_type]
	local lo = board.pieces_lo[color][piece_type]
	local square = 63 - bb_countlz(hi, lo)
	if square == -1 then return nil end
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

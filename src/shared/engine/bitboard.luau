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

local make_pair, split_pair = Utils.make_pair, Utils.split_pair

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

		pieces_lo  = table.create(PIECE_STRIDE * 2, 0),  -- [color*6 + piece]
		pieces_hi  = table.create(PIECE_STRIDE * 2, 0),
		attacked_lo = table.create(ATK_STRIDE * 2, 0),   -- [color*7 + piece], slot 6 = ATTACKED_ALL
		attacked_hi = table.create(ATK_STRIDE * 2, 0),
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

	if not blank then Board.set_start_position(board) end
	return board
end

function Board.clone(board: Board): Board
	return {
		pieceTable      = table.clone(board.pieceTable),
		pieces_lo       = table.clone(board.pieces_lo),
		pieces_hi       = table.clone(board.pieces_hi),
		attacked_lo     = table.clone(board.attacked_lo),
		attacked_hi     = table.clone(board.attacked_hi),
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
	local W = WHITE * PIECE_STRIDE
	local B = BLACK * PIECE_STRIDE
	board.pieces_lo[W+PAWN]   = 0x0000FF00; board.pieces_hi[W+PAWN]   = 0x00000000
	board.pieces_lo[W+KNIGHT] = 0x00000042; board.pieces_hi[W+KNIGHT] = 0x00000000
	board.pieces_lo[W+BISHOP] = 0x00000024; board.pieces_hi[W+BISHOP] = 0x00000000
	board.pieces_lo[W+ROOK]   = 0x00000081; board.pieces_hi[W+ROOK]   = 0x00000000
	board.pieces_lo[W+QUEEN]  = 0x00000008; board.pieces_hi[W+QUEEN]  = 0x00000000
	board.pieces_lo[W+KING]   = 0x00000010; board.pieces_hi[W+KING]   = 0x00000000

	board.pieces_lo[B+PAWN]   = 0x00000000; board.pieces_hi[B+PAWN]   = 0x00FF0000
	board.pieces_lo[B+KNIGHT] = 0x00000000; board.pieces_hi[B+KNIGHT] = 0x42000000
	board.pieces_lo[B+BISHOP] = 0x00000000; board.pieces_hi[B+BISHOP] = 0x24000000
	board.pieces_lo[B+ROOK]   = 0x00000000; board.pieces_hi[B+ROOK]   = 0x81000000
	board.pieces_lo[B+QUEEN]  = 0x00000000; board.pieces_hi[B+QUEEN]  = 0x08000000
	board.pieces_lo[B+KING]   = 0x00000000; board.pieces_hi[B+KING]   = 0x10000000

	-- Board.from_fen(board, "rnb3n1/1p2bk1r/3p2pp/p1p1pp2/1P3P2/2PP2PK/P3P2P/RNBQ1BNR w - - 0 13")
	Board.update_occupied(board)

	for color = WHITE, BLACK do
		local base = color * PIECE_STRIDE
		for pieceType = PAWN, KING do
			local bb_lo = board.pieces_lo[base + pieceType]
			local bb_hi = board.pieces_hi[base + pieceType]
			while bb_lo ~= 0 or bb_hi ~= 0 do
				local bitIndex = if bb_lo == 0 then bit32.countrz(bb_hi) + 32 else bit32.countrz(bb_lo)
				board.pieceTable[bitIndex] = make_pair(pieceType, color)
				local nlo = bit32.bor(bb_lo - 1, 0)
				local nhi = bit32.bor(bb_hi - (if bb_lo == 0 then 1 else 0), 0)
				bb_lo = bit32.band(bb_lo, nlo)
				bb_hi = bit32.band(bb_hi, nhi)
			end
		end
	end
end

function Board.update_occupied(board: Board)
	local W = WHITE * PIECE_STRIDE
	local B = BLACK * PIECE_STRIDE
	local pl = board.pieces_lo
	local ph = board.pieces_hi

	local w_lo = bit32.bor(pl[W+PAWN], pl[W+KNIGHT], pl[W+BISHOP], pl[W+ROOK], pl[W+QUEEN], pl[W+KING])
	local w_hi = bit32.bor(ph[W+PAWN], ph[W+KNIGHT], ph[W+BISHOP], ph[W+ROOK], ph[W+QUEEN], ph[W+KING])
	local b_lo = bit32.bor(pl[B+PAWN], pl[B+KNIGHT], pl[B+BISHOP], pl[B+ROOK], pl[B+QUEEN], pl[B+KING])
	local b_hi = bit32.bor(ph[B+PAWN], ph[B+KNIGHT], ph[B+BISHOP], ph[B+ROOK], ph[B+QUEEN], ph[B+KING])

	board.occupied_lo[WHITE] = w_lo; board.occupied_hi[WHITE] = w_hi
	board.occupied_lo[BLACK] = b_lo; board.occupied_hi[BLACK] = b_hi
	board.occupied_lo[ALL]   = bit32.bor(w_lo, b_lo)
	board.occupied_hi[ALL]   = bit32.bor(w_hi, b_hi)
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
			local a, b = split_pair(piece)
			table.insert(pieces_list, { a, b, pos })
		end
	end
	return pieces_list
end

function Board.find_piece(board: Board, piece_type: number, color: number): number?
	local base = color * PIECE_STRIDE
	local hi = board.pieces_hi[base + piece_type]
	local lo = board.pieces_lo[base + piece_type]
	local square = 63 - (if hi == 0 then bit32.countlz(lo) + 32 else bit32.countlz(hi))
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

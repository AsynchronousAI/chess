--!native
--!optimize 2
--!strict
local u64 = require("./int64")
local Utils = require("./utils")
local MoveGen = require("./move_gen").MoveGen
local Zobrist = require("./zobrist")
local Encoding = require("./encoding")
local FEN = require("./fen")
local MoveOps = require("./move_ops")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING

local make_pair, split_pair = Utils.make_pair, Utils.split_pair



export type Board = Utils.Board;

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
        pieceTable = table.create(64),
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
		eval = board.eval,
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

    -- Board.from_fen(board, "8/8/8/k7/8/q7/4K3/3Q1B2 w - - 0 1");

	Board.update_occupied(board)
	for color = WHITE, BLACK do
		for pieceType = PAWN, KING do
			local bb = board.pieces[color][pieceType]
			while bb ~= u64.ZERO do
				local bitIndex = u64.countrz(bb)
				board.pieceTable[bitIndex] = make_pair(pieceType, color)
				bb = u64.band(bb, u64.bnot(u64.lshift(u64.ONE, bitIndex)))
			end
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
export type UndoRecord = MoveOps.UndoRecord

Board.make_move = MoveOps.make_move
Board.undo_move = MoveOps.undo_move
Board.get_undo_record_data = MoveOps.get_undo_record_data

-- Move generation and attacks
Board.regenerate_piece_attacked = MoveGen.regenerate_piece_attacked
Board.attacked_occupancy = MoveGen.attacked_occupancy
Board.regenerate_all_attacked = MoveGen.regenerate_all_attacked
Board.is_square_attacked = MoveGen.is_square_attacked
Board.generate_legal_moves = MoveGen.generate_legal_moves
Board.generate_legal_moves_from = MoveGen.generate_legal_moves_from

-- Pieces
function Board.get_piece(board: Board, loc: number): (number?, number?)
    local val = board.pieceTable[loc]
    if not val then
        return nil, nil
    end
    return bit32.rshift(val, 6), bit32.band(val, 63) -- one less func call, inline split_pair
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

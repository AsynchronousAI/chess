--!native
--!optimize 2

local Utils = require("./utils")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING

local ATTACKED_ALL = Utils.ATTACKED_ALL
local PIECE_STRIDE = Utils.PIECE_STRIDE  -- 6
local ATK_STRIDE   = Utils.ATK_STRIDE    -- 7

local get_bit = Utils.get_bit

local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ

local FEN = {}

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
	[WHITE] = { [PAWN]="P", [KNIGHT]="N", [BISHOP]="B", [ROOK]="R", [QUEEN]="Q", [KING]="K" },
	[BLACK] = { [PAWN]="p", [KNIGHT]="n", [BISHOP]="b", [ROOK]="r", [QUEEN]="q", [KING]="k" },
}

function FEN.from_fen(board: Utils.Board, fen: string)
	local parts = {}
	for part in string.gmatch(fen, "[^ ]+") do
		table.insert(parts, part)
	end

	local rows = {}
	for row in string.gmatch(parts[1], "[^/]+") do
		table.insert(rows, row)
	end

	-- Clear
	board.pieceTable = {}
	for color = WHITE, BLACK do
		for typ = PAWN, KING do
			board.pieces[color * PIECE_STRIDE + typ] = 0i
		end
		board.occupied[color] = 0i
	end
	board.occupied[Utils.ALL] = 0i

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
					local b = Utils.unit_board(square)
					board.pieces[info.color * PIECE_STRIDE + info.type] = integer.bor(board.pieces[info.color * PIECE_STRIDE + info.type], b)
					board.occupied[info.color] = integer.bor(board.occupied[info.color], b)
					board.occupied[Utils.ALL] = integer.bor(board.occupied[Utils.ALL], b)
					board.pieceTable[square] = Utils.make_pair_32(info.type, info.color)
				end
				file = file + 1
			end
		end
	end

	board.side_to_move = (parts[2] == "w") and WHITE or BLACK

	board.castling_rights = 0
	if parts[3]:find("K") then board.castling_rights = Utils.set_bit32(board.castling_rights, WK) end
	if parts[3]:find("Q") then board.castling_rights = Utils.set_bit32(board.castling_rights, WQ) end
	if parts[3]:find("k") then board.castling_rights = Utils.set_bit32(board.castling_rights, BK) end
	if parts[3]:find("q") then board.castling_rights = Utils.set_bit32(board.castling_rights, BQ) end

	-- Parse en passant square (convert algebraic e.g. "e3" to square index)
	if parts[4] ~= "-" then
		local ep_str = parts[4]
		local ep_file = string.byte(ep_str, 1) - string.byte("a")
		local ep_rank = tonumber(ep_str:sub(2, 2)) - 1
		board.en_passant_square = ep_rank * 8 + ep_file
	else
		board.en_passant_square = nil
	end
	board.halfmove_clock    = tonumber(parts[5]) or 0
	board.fullmove_number   = tonumber(parts[6]) or 1

	-- Reset attacked tables
	for color = WHITE, BLACK do
		for piece = PAWN, KING do
			board.attacked[color * ATK_STRIDE + piece] = 0i
		end
		board.attacked[color * ATK_STRIDE + Utils.ATTACKED_ALL] = 0i
	end

	-- Reset eval and hash
	board.eval = 0
	board.hash = 0
end

function FEN.to_fen(self: Utils.Board)
	local fen = {}
	for rank = 8, 1, -1 do
		local empty = 0
		for file = 0, 7 do
			local square = (rank - 1) * 8 + file
			local piece_found = false
			for color = WHITE, BLACK do
				for typ = PAWN, KING do
					if get_bit(self.pieces[color * PIECE_STRIDE + typ], square) then
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
				empty += 1
			end
		end
		if empty > 0 then table.insert(fen, tostring(empty)) end
		if rank > 1 then table.insert(fen, "/") end
	end

	local stm      = (self.side_to_move == WHITE) and "w" or "b"
	local castling = ""
	if Utils.get_bit32(self.castling_rights, WK) then castling = castling.."K" end
	if Utils.get_bit32(self.castling_rights, WQ) then castling = castling.."Q" end
	if Utils.get_bit32(self.castling_rights, BK) then castling = castling.."k" end
	if Utils.get_bit32(self.castling_rights, BQ) then castling = castling.."q" end
	if castling == "" then castling = "-" end

	local ep = "-"
    if self.en_passant_square then
        local f = string.char(string.byte("a") + (self.en_passant_square % 8))
        local r = tostring(math.floor(self.en_passant_square / 8) + 1)
        ep = f .. r
    end

	return table.concat(fen)..(" "..stm.." "..castling.." "..ep.." "..self.halfmove_clock.." "..self.fullmove_number)
end

return FEN

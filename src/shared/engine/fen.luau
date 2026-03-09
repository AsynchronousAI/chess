--!native
--!optimize 2

local Utils = require("./utils")

local WHITE, BLACK, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING =
	Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KNIGHT, Utils.BISHOP, Utils.ROOK, Utils.QUEEN, Utils.KING

local ATTACKED_ALL = Utils.ATTACKED_ALL
local PIECE_STRIDE = Utils.PIECE_STRIDE  -- 6
local ATK_STRIDE   = Utils.ATK_STRIDE    -- 7

local BIT_LO  = Utils.BIT_LO
local BIT_HI  = Utils.BIT_HI
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

function FEN.from_fen(board, fen)
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
	for _, color in {WHITE, BLACK} do
		for _, typ in {PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING} do
			board.pieces_lo[color * PIECE_STRIDE + typ] = 0
			board.pieces_hi[color * PIECE_STRIDE + typ] = 0
		end
		board.occupied_lo[color] = 0
		board.occupied_hi[color] = 0
	end
	board.occupied_lo[Utils.ALL] = 0
	board.occupied_hi[Utils.ALL] = 0

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
					local blo = BIT_LO[square]
					local bhi = BIT_HI[square]
					board.pieces_lo[info.color * PIECE_STRIDE + info.type] = bit32.bor(board.pieces_lo[info.color * PIECE_STRIDE + info.type], blo)
					board.pieces_hi[info.color * PIECE_STRIDE + info.type] = bit32.bor(board.pieces_hi[info.color * PIECE_STRIDE + info.type], bhi)
					board.occupied_lo[info.color] = bit32.bor(board.occupied_lo[info.color], blo)
					board.occupied_hi[info.color] = bit32.bor(board.occupied_hi[info.color], bhi)
					board.occupied_lo[Utils.ALL] = bit32.bor(board.occupied_lo[Utils.ALL], blo)
					board.occupied_hi[Utils.ALL] = bit32.bor(board.occupied_hi[Utils.ALL], bhi)
					board.pieceTable[square] = Utils.make_pair(info.type, info.color)
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

	-- Reset attacked tables (will be regenerated on first generate_legal_moves call)
	for color = WHITE, BLACK do
		for piece = PAWN, KING do
			board.attacked_lo[color * ATK_STRIDE + piece] = 0
			board.attacked_hi[color * ATK_STRIDE + piece] = 0
		end
		board.attacked_lo[color * ATK_STRIDE + Utils.ATTACKED_ALL] = 0
		board.attacked_hi[color * ATK_STRIDE + Utils.ATTACKED_ALL] = 0
	end

	-- Reset eval and hash (will be recomputed lazily)
	board.eval = nil
	board.hash = nil
end

function FEN.to_fen(self)
	local fen = {}
	for rank = 8, 1, -1 do
		local empty = 0
		for file = 0, 7 do
			local square = (rank - 1) * 8 + file
			local piece_found = false
			for color = WHITE, BLACK do
				for typ = PAWN, KING do
					if get_bit(self.pieces_hi[color * PIECE_STRIDE + typ], self.pieces_lo[color * PIECE_STRIDE + typ], square) then
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

	local ep = self.en_passant_square or "-"

	return table.concat(fen)..(" "..stm.." "..castling.." "..ep.." "..self.halfmove_clock.." "..self.fullmove_number)
end

return FEN

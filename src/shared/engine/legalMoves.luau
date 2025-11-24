--!native
--!optimize 2

local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
local _board = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "board")
local Color = _board.Color
local IsSquareBlack = _board.IsSquareBlack
local Piece = _board.Piece
local BitBoard = require(script.Parent.bitboard).BitBoard
local SharedTableRegistry = TS.import(script, game:GetService("ReplicatedStorage"), "rbxts_include", "node_modules", "@rbxts", "services").SharedTableRegistry
local transposition = SharedTableRegistry:GetSharedTable("LegalMovesTransposition")

-- Move Type Enum
local MoveType = {
	Normal = 0,
	EnPassant = 1,
	CastleKingside = 2,
	CastleQueenside = 3,
	PawnDoubleMove = 4,
}

-- Utility functions
local function isOnBoard(index)
	return index >= 0 and index < 64
end

-- Shared Move Executors
local MoveExecutors = {
	[MoveType.Normal] = function(branch, from, to, skip)
		-- Normal moves don't need special handling
		return nil
	end,

	[MoveType.EnPassant] = function(branch, from, to, skip)
		if not skip then
			local piece = BitBoard.getPiece(branch, from)
			local dir = if piece[2] == 0 then 1 else -1
			local capturedPawnSquare = to - dir * 8
			BitBoard.setPiece(branch, capturedPawnSquare, Piece.none, 0)
		end
		local dir = if BitBoard.getPiece(branch, from)[2] == 0 then 1 else -1
		return { to - dir * 8, nil }
	end,

	[MoveType.CastleKingside] = function(branch, from, to, skip)
		if not skip then
			local rank = BitBoard.separateSquareIndex(from)[2]
			local rookFrom = 7 + rank * 8
			local rookTo = 5 + rank * 8
			BitBoard.movePiece(branch, rookFrom, rookTo)
		end
		local rank = BitBoard.separateSquareIndex(from)[2]
		return { 7 + rank * 8, 5 + rank * 8, "castle" }
	end,

	[MoveType.CastleQueenside] = function(branch, from, to, skip)
		if not skip then
			local rank = BitBoard.separateSquareIndex(from)[2]
			local rookFrom = 0 + rank * 8
			local rookTo = 3 + rank * 8
			BitBoard.movePiece(branch, rookFrom, rookTo)
		end
		local rank = BitBoard.separateSquareIndex(from)[2]
		return { 0 + rank * 8, 3 + rank * 8, "castle" }
	end,

	[MoveType.PawnDoubleMove] = function(branch, from, to, skip)
		if not skip then
			local oneStep = from + (if BitBoard.getPiece(branch, from)[2] == 0 then 8 else -8)
			BitBoard.setEnPassant(branch, oneStep)
		end
		return nil
	end,
}

-- Direction Rules
local SLIDE_DIRECTIONS = {
	[Piece.rook] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } },
	[Piece.bishop] = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } },
	[Piece.queen] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } },
}
local FIXED_DIRECTIONS = {
	[Piece.knight] = { { 2, 1 }, { 2, -1 }, { -2, 1 }, { -2, -1 }, { 1, 2 }, { 1, -2 }, { -1, 2 }, { -1, -2 } },
	[Piece.king] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } },
}

local IsSquareAttacked
local CUSTOM_DIRECTIONS = {
	[Piece.pawn] = function(piece, pos, board)
		local moves = {}
		local dir = if piece[2] == 0 then 1 else -1
		local startRank = if piece[2] == 0 then 1 else 6

		-- Forward move
		local oneStep = pos + dir * 8
		local onBoard = isOnBoard(oneStep)
		if onBoard and not BitBoard.hasPiece(board, oneStep) then
			table.insert(moves, { oneStep, MoveType.Normal })

			-- Two steps from start
			local twoStep = oneStep + dir * 8
			local isStarting = pos >= startRank * 8 and pos < startRank * 8 + 8
			if isStarting and not BitBoard.hasPiece(board, twoStep) then
				table.insert(moves, { twoStep, MoveType.PawnDoubleMove })
			end
		end

		-- Captures
		local file = pos % 8
		for _, dx in { -1, 1 } do
			local newFile = file + dx
			if newFile < 0 or newFile > 7 then
				continue
			end

			local newPos = pos + dir * 8 + dx
			if not isOnBoard(newPos) then
				continue
			end

			local target = BitBoard.getPiece(board, newPos)
			if target[1] ~= 0 and target[2] ~= piece[2] then
				table.insert(moves, { newPos, MoveType.Normal })
			else
				local enPassantSquare = BitBoard.getEnPassant(board)
				if enPassantSquare == newPos then
					table.insert(moves, { newPos, MoveType.EnPassant })
				end
			end
		end
		return moves
	end,
	[Piece.king] = function(piece, pos, board)
		-- this just handles castling, movement is in FIXED_DIRECTIONS
		local rank = BitBoard.separateSquareIndex(pos)[2]
		local moves = {}

		local isLegalCastle = function(mustBeEmpty, mustNotAttack)
			for _, sq in mustBeEmpty do
				if BitBoard.hasPiece(board, sq + rank * 8) then
					return false
				end
			end

			for _, sq in mustNotAttack do
				local attacker = IsSquareAttacked(board, sq + rank * 8, 1 - piece[2])
				if attacker ~= Piece.none then
					return false
				end
			end

			return true
		end
		if BitBoard.getCastlingRights(board, piece[2], true) and isLegalCastle({ 1, 2, 3 }, { 2, 3, 4 }) then
			-- castle queenside, king goes to c file
			table.insert(moves, { BitBoard.getSquareIndex(2, rank), MoveType.CastleQueenside })
		end
		if BitBoard.getCastlingRights(board, piece[2], false) and isLegalCastle({ 5, 6 }, { 4, 5, 6 }) then
			table.insert(moves, { BitBoard.getSquareIndex(6, rank), MoveType.CastleKingside })
		end
		return moves
	end,
}

-- Export
function IsSquareAttacked(board, target, attacker)
	for _, d in BitBoard.getAllPieces(board) do
	    -- Extract piece info
		local pos = d[1]
		local d2 = d[2]
		local piece = d2[1]
		local color = d2[2]

		if piece == Piece.none or color ~= attacker then
			continue
		end

		local posSquare = BitBoard.separateSquareIndex(pos)
		local x = posSquare[1]
		local y = posSquare[2]

		local targetSquare = BitBoard.separateSquareIndex(target)
		local tx = targetSquare[1]
		local ty = targetSquare[2]

		local dx = tx - x
		local dy = ty - y

		if piece == (Piece.pawn) then
			local attackDir = if color == Color.white then 1 else -1
			if ty - y == attackDir and math.abs(tx - x) == 1 then
				return piece
			end
		elseif piece == (Piece.knight) then
			if (math.abs(dx) == 2 and math.abs(dy) == 1) or (math.abs(dx) == 1 and math.abs(dy) == 2) then
				return piece
			end
		elseif piece == (Piece.king) then
			if math.max(math.abs(dx), math.abs(dy)) == 1 then
				return piece
			end
		elseif piece == (Piece.rook) or piece == (Piece.bishop) or piece == (Piece.queen) then
			local directions = SLIDE_DIRECTIONS[piece]
			for _, sxy in directions do
				local sx = sxy[1]
				local sy = sxy[2]

				local cx = x + sx
				local cy = y + sy

				while cx >= 0 and cx < 8 and cy >= 0 and cy < 8 do
					local cSquare = BitBoard.getSquareIndex(cx, cy)
					local cPiece = BitBoard.getPiece(board, cSquare)
					if cSquare == target then
						return piece
					end
					if cPiece[1] ~= Piece.none then
					    break
					end

					cx += sx
					cy += sy
				end
			end
		end
	end
	return Piece.none
end

local function GetLegalMoves(board, from, checks, turn)
	checks = checks or true
	turn = turn or BitBoard.getTurn(board)

	local piece = BitBoard.getPiece(board, from)
	if not piece then
		return {}
	end

	local moves = {}
	local kingPosition = BitBoard.findPiece(board, Piece.king, turn)[1]

	local pushMove = function(newPos)
		if checks then
			-- branch + move
			local newBoard = BitBoard.branch(board)
			local pos = newPos[1]
			local moveType = newPos[2]

			BitBoard.movePiece(newBoard, from, pos)

			-- Execute special move logic
			local executor = MoveExecutors[moveType]
			if executor then
				executor(newBoard, from, pos)
			end

			-- if the king moved then update it
			if piece[1] == Piece.king then
				kingPosition = pos
			end
			local attacker = IsSquareAttacked(newBoard, kingPosition, 1 - piece[2])
			if attacker ~= Piece.none then
				return nil
			end
		end
		table.insert(moves, newPos)

		return
	end

	if CUSTOM_DIRECTIONS[piece[1]] then
		local customMoves = CUSTOM_DIRECTIONS[piece[1]](piece, from, board)
		for _, newPos in customMoves do
			pushMove(newPos)
		end
	end

	if FIXED_DIRECTIONS[piece[1]] ~= nil then
		local _binding = BitBoard.separateSquareIndex(from)
		local xOrigin = _binding[1]
		local yOrigin = _binding[2]
		for _, _binding_1 in FIXED_DIRECTIONS[piece[1]] do
			local x = _binding_1[1]
			local y = _binding_1[2]
			local newPosition = from + x + y * 8
			local newX = xOrigin + x
			local newY = yOrigin + y
			if newX < 0 or newX > 7 or newY < 0 or newY > 7 then
				continue
			end
			local target = BitBoard.getPiece(board, newPosition)
			if target[1] == Piece.none or target[2] ~= piece[2] then
				pushMove({ newPosition, MoveType.Normal })
			end
		end
	end

	if SLIDE_DIRECTIONS[piece[1]] ~= nil then
		local _binding = BitBoard.separateSquareIndex(from)
		local fx = _binding[1]
		local fy = _binding[2]
		for _, _binding_1 in SLIDE_DIRECTIONS[piece[1]] do
			local dx = _binding_1[1]
			local dy = _binding_1[2]
			local x = fx + dx
			local y = fy + dy
			while x >= 0 and y >= 0 and x < 8 and y < 8 do
				local location = BitBoard.getSquareIndex(x, y)
				local target = BitBoard.getPiece(board, location)
				if target[1] == 0 then
					pushMove({ location, MoveType.Normal })
				else
					if target[2] ~= piece[2] then
						pushMove({ location, MoveType.Normal })
					end
					break
				end
				x += dx
				y += dy
			end
		end
	end
	return moves
end

local function GetAllLegalMoves(board, turn, checks, cache)
	if checks == nil then
		checks = true
	end
	if cache == nil then
		cache = true
	end
	local moves = {}
	-- Exists in cache, convert to local table
	local hash = BitBoard.hash(board)
	local transpositionTbl = transposition[hash]
	if transpositionTbl ~= nil then
		for i = 1, SharedTable.size(transpositionTbl) do
			local a = (transpositionTbl[i])[1]
			local b = (transpositionTbl[i])[2]
			local c = (transpositionTbl[i])[3]
			if c ~= turn then
				continue
			end
			local _arg0 = { a, b }
			table.insert(moves, _arg0)
		end
		return moves
	end
	-- Generate
	local sharedCache = SharedTable.new()
	for _, _binding in BitBoard.getAllPieces(board) do
		local location = _binding[1]
		local _binding_1 = _binding[2]
		local piece = _binding_1[1]
		local color = _binding_1[2]
		local pushToMoves = color == turn
		if not cache and not pushToMoves then
			continue
		end
		for _1, nextLocation in GetLegalMoves(board, location, checks) do
			if pushToMoves then
				local _arg0 = { location, nextLocation[1] }
				table.insert(moves, _arg0)
			end
			if cache then
				sharedCache[SharedTable.size(sharedCache) + 1] = SharedTable.new({ location, nextLocation[1], color })
			end
		end
	end
	if cache then
		transposition[hash] = sharedCache
	end
	return moves
end

local function isInsufficientMaterial(board)
	local pieces = {
		[Piece.king] = 0,
		[Piece.queen] = 0,
		[Piece.rook] = 0,
		[Piece.bishop] = 0,
		[Piece.knight] = 0,
		[Piece.pawn] = 0,
	}
	local bishopColors = {}
	for _, _binding in BitBoard.getAllPieces(board) do
		local location = _binding[1]
		local _binding_1 = _binding[2]
		local piece = _binding_1[1]
		local _condition = pieces[piece]
		if not (_condition ~= 0 and _condition == _condition and _condition) then
			_condition = 0
		end
		pieces[piece] = _condition + 1
		if piece == Piece.bishop then
			local _arg0 = IsSquareBlack(unpack(BitBoard.separateSquareIndex(location)))
			table.insert(bishopColors, _arg0)
		end
	end

	local bishops = pieces[Piece.bishop] or 0
	local knights = pieces[Piece.knight] or 0
	local rooks = pieces[Piece.rook] or 0
	local queens = pieces[Piece.queen] or 0
	local pawns = pieces[Piece.pawn] or 0

	-- Any pawns, rooks, or queens means sufficient material
	if pawns > 0 or rooks > 0 or queens > 0 then
		return false
	end
	-- King vs King
	if bishops == 0 and knights == 0 then
		return true
	end
	-- King + Bishop or Knight vs King
	if bishops == 1 and knights == 0 then
		return true
	end
	if bishops == 0 and knights == 1 then
		return true
	end
	-- King + Bishop vs King + Bishop (same color bishops)
	if bishops == 2 and knights == 0 and bishopColors[1] == bishopColors[2] then
		return true
	end
	-- King + Knight vs King + Knight
	if knights == 2 and bishops == 0 then
		return true
	end
	return false
end

local function AnalyzeMates(board)
	-- NOTE: timeouts, resigns, and draws are handled in gameplay.ts, this will not analyze them
	local turn = BitBoard.getTurn(board)
	local legalMoves = GetAllLegalMoves(board, turn, true)
	-- In-sufficent material
	if isInsufficientMaterial(board) then
		return "insufficent"
	end
	-- Based on legal moves
	if #legalMoves == 0 then
		local kingPosition = BitBoard.findPiece(board, Piece.king, turn)[1]
		local otherMoves = GetAllLegalMoves(board, 1 - turn, false)
		local inCheck = false
		for _, _binding in otherMoves do
			local _ = _binding[1]
			local to = _binding[2]
			if to == kingPosition then
				inCheck = true
				break
			end
		end
		if inCheck then
			return "checkmate"
		else
			return "stalemate"
		end
	end
	return ""
end

return {
	IsSquareAttacked = IsSquareAttacked,
	default = GetLegalMoves,
	GetAllLegalMoves = GetAllLegalMoves,
	AnalyzeMates = AnalyzeMates,
	MoveType = MoveType,
	MoveExecutors = MoveExecutors,
}

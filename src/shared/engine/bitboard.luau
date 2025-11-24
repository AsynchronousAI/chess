--!native
--!optimize 2

--[[
TODO: Store pieces as u4 (pairs in a u8) and castles + current turn as 5 bits, and en passant as 6 bits.
519bits -> 267bits. (almost half!)
([piece id][color])*64 [currentTurn] [WQ castle] [WK castle] [BQ castle] [BK castle] [EnPassant]
]]

-- Imports
local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
local Piece = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "board").Piece

-- Constants
local CURRENT_TURN = 8 * 64 + 1
local CASTLE_INDEX = {
    -- CASTLE_INDEX[color][queenSide ? 0 : 1]
	[0] = { 8 * 64 + 2, 8 * 64 + 3 },
	[1] = { 8 * 64 + 4, 8 * 64 + 5 },
}
local EN_PASSANT = 8 * 64 + 6
local SIZE = 8 * 64 + 7

local BitBoard = {}

-- internal
function BitBoard.getSquareIndex(file: number, rank: number)
	return bit32.bor(bit32.lshift(rank, 3), file)
end
function BitBoard.separateSquareIndex(loc: number)
	return { bit32.band(loc, 7), bit32.arshift(loc, 3) }
end
local function binaryToPiece(piece: number)
	return { bit32.arshift(piece, 1), bit32.band(piece, 1) }
end
local function getPieceBinary(pieceType: number, color: number)
	return bit32.bor(bit32.lshift(pieceType, 1), color)
end

-- base methods
function BitBoard.create()
	return buffer.create(SIZE)
end
 function BitBoard.setPiece(board, location, pieceType, color)
	local piece = getPieceBinary(pieceType, color)
	buffer.writeu8(board, location, piece)
end
 function BitBoard.getPiece(board, location)
	return binaryToPiece(buffer.readu8(board, location))
end
 function BitBoard.hasPiece(board, location)
	return buffer.readu8(board, location) ~= 0
end
function BitBoard.getAllPieces(board)
	local pieces = {}
	for rank = 0, 7 do
		local index = rank * 8
		for file = 0, 7 do
		    local piece = buffer.readu8(board, index);
			if (piece ~= 0) then
			    local pieceInfo = binaryToPiece(piece)
				table.insert(pieces, {BitBoard.getSquareIndex(file, rank), pieceInfo})
			end
		    index += 1
		end
	end
	return pieces
end
function BitBoard.movePiece(board, from, to)
	local originalPieceType = binaryToPiece(buffer.readu8(board, to))[1]

	local piece = buffer.readu8(board, from)
	buffer.writeu8(board, from, 0)
	buffer.writeu8(board, to, piece)

	-- castling rights
	local _binding_1 = binaryToPiece(piece)
	local pieceType = _binding_1[1]
	local color = _binding_1[2]
	--- moved king
	if pieceType == Piece.king then
		BitBoard.breakCastlingRights(board, color, false)
		BitBoard.breakCastlingRights(board, color, true)
	end
	--- moved rook
	if pieceType == Piece.rook then
		if from == 0 then
			BitBoard.breakCastlingRights(board, 0, true)
		elseif from == 7 then
			BitBoard.breakCastlingRights(board, 0, false)
		elseif from == 56 then
			BitBoard.breakCastlingRights(board, 1, true)
		elseif from == 63 then
			BitBoard.breakCastlingRights(board, 1, false)
		end
	end
	--- captured rook
	if originalPieceType == Piece.rook then
		if to == 0 then
			BitBoard.breakCastlingRights(board, 0, true)
		elseif to == 7 then
			BitBoard.breakCastlingRights(board, 0, false)
		elseif to == 56 then
			BitBoard.breakCastlingRights(board, 1, true)
		elseif to == 63 then
			BitBoard.breakCastlingRights(board, 1, false)
		end
	end

	-- en passant
	BitBoard.setEnPassant(board, nil)
end
function BitBoard.breakCastlingRights(board, color, queenSide)
    buffer.writeu8(board, CASTLE_INDEX[color][if queenSide then 1 else 2], 0)
end
function BitBoard.getCastlingRights(board, color, queenSide)
    return buffer.readu8(board, CASTLE_INDEX[color][if queenSide then 1 else 2]) == 1
end
function BitBoard.branch(board)
	local branch = BitBoard.create()
	buffer.copy(branch, 0, board)
	return branch
end
function BitBoard.findPiece(board, piece, color)
	local squares = {}
	for _, d in BitBoard.getAllPieces(board) do
		local location = d[1]
		local currentPiece = d[2][1]
		local currentColor = d[2][2]

		if piece == currentPiece and color == currentColor then
			table.insert(squares, location)
		end
	end
	return squares
end
function BitBoard.getTurn(board)
	return buffer.readu8(board, CURRENT_TURN)
end
function BitBoard.flipTurn(board)
	local currentTurn = BitBoard.getTurn(board)
	buffer.writeu8(board, CURRENT_TURN, 1 - currentTurn)
end
function BitBoard.getEnPassant(board)
	local index = buffer.readu8(board, EN_PASSANT)
	return if index == 0 then nil else index
end
function BitBoard.setEnPassant(board, square)
	buffer.writeu8(board, EN_PASSANT, square or 0)
end
function BitBoard.hash(board)
	return buffer.tostring(board)
end

return {
	BitBoard = BitBoard,
	CASTLE_INDEX = CASTLE_INDEX,
	EN_PASSANT = EN_PASSANT,
}

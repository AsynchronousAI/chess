local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))

local BitBoard = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "bitboard").BitBoard
local Board = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "board")
local LegalMoves = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "legalMoves")

return {
    BitBoard = BitBoard,
    Board = Board,
    LegalMoves = LegalMoves,
}

local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))

local BitBoard = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "bitboard").BitBoard
local Move = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "move").Move
local Board = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "board")
local Utils = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "utils")
local Eval = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "eval")
local Notation = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "notation").Notation

return {
    BitBoard = BitBoard,
    Move = Move,
    Board = Board,
    Notation = Notation,
    Utils = Utils,
    Eval = Eval,
}

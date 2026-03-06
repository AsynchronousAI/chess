-- This library works as a importer from bot to shared/engine,
-- from when the engine used to be more mixed with typescript.
--
-- This will eventually be eradicated.

local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))

local BitBoard = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "bitboard").BitBoard
local Move = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "move").Move
local Board = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "board")
local Utils = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "utils")
local Eval = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "eval")
local Notation = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "notation").Notation
local Minimax = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "minimax")
local MoveOrdering = TS.import(script, game:GetService("ReplicatedStorage"), "TS", "engine", "moveOrdering")

return {
    BitBoard = BitBoard,
    Move = Move,
    Board = Board,
    Notation = Notation,
    Utils = Utils,
    Minimax = Minimax,
    Eval = Eval.eval,
    MoveOrdering = MoveOrdering,
}

--!native
--!optimize 2

local libs, BitBoard, transposition
if game then
	libs = require(script.Parent.import)
	BitBoard = libs.BitBoard
	transposition = game:GetService("SharedTableRegistry"):GetSharedTable("EvaluationTransposition")
else
	libs = {
		Eval = require("../../shared/engine/eval"),
	}
	BitBoard = require("../../shared/engine/bitboard").BitBoard
end

local Eval = libs.Eval

return function(board)
	if board.eval ~= nil then
		return board.eval
	end

	local hash = if BitBoard then BitBoard.hash(board) else nil
	if transposition and hash then
		local cached = transposition[hash]
		if cached ~= nil then
			board.eval = cached
			return cached
		end
	end

	board.eval = Eval.evaluate(board)
	if transposition and hash then
		transposition[hash] = board.eval
	end
	return board.eval
end

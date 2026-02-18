--!native
--!optimize 2

local libs
if game then
	libs = require(script.Parent.import)
else
	libs = {
		Eval = require("../../shared/engine/eval"),
	}
end

local Eval = libs.Eval

return function(board)
	if board.eval == nil then
		board.eval = Eval.evaluate(board)
	end
	return board.eval
end

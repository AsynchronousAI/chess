--!native
--!optimize 2

local libs = require(script.import)

local DEPTH = 5
local TIME_LIMIT_MS = 1500

return {
	GetBestMove = function(board)
		local start = os.clock()
		local score, bestMove, nodes, _, depthReached, maxPly = libs.Minimax(
			board,
			board.side_to_move == 1,
			{ depth = DEPTH, timeLimitMs = TIME_LIMIT_MS },
			0,
			-math.huge,
			math.huge
		)

		print(`\n\
depth: {DEPTH}\
depthReached: {depthReached}\
maxPly: {maxPly}\
eval: {score}\
time: {math.ceil((os.clock()-start)*1000)}ms\
nodes: {nodes}`)

		return {
			["move"] = bestMove,
			["eval"] = score,
			["depth"] = depthReached,
			["mate"] = 0,
		}
	end,
}

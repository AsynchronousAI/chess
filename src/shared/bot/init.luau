--!native
--!optimize 2
local libs = require(script.import)
local eval = require(script.eval)

return {
    GetBestMoveLocal = function(board: buffer)
        local allMoves = libs.LegalMoves.GetAllLegalMoves(board, libs.BitBoard.getTurn(board))

        local bestEval = -math.huge
        local bestMove = 0;

        for index, move in allMoves do
            local branch = libs.BitBoard.branch(board)
            libs.Move.PerformMove(branch, move, false)
            local thisEvaluation = eval(branch)
            print(thisEvaluation, move[1], move[2])
            if thisEvaluation > bestEval then
                bestEval = thisEvaluation
                bestMove = index
            end
        end

        return {
            ["move"] = allMoves[bestMove],
            ["eval"] = bestEval,
            ["depth"] = 0,
            ["mate"] = 0,
        }
    end,
}

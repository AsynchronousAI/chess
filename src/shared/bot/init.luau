--!native
--!optimize 2
local libs = require(script.import)
local eval = require(script.eval)

function minimax(board, isMaximizing, maxDepth, depth)
    local score = eval(board)

    if depth >= maxDepth then
        return score, depth, nil
    end

    local maxDepthReached = depth
    local bestScore = isMaximizing and -math.huge or math.huge
    local bestMove = nil

    local moves = libs.LegalMoves.GetAllLegalMoves(board, libs.BitBoard.getTurn(board))
    for _, move in moves do
        local branch = libs.BitBoard.branch(board)
        libs.Move.PerformMove(branch, move, false)

        local currentScore, childDepth, _ = minimax(branch, not isMaximizing, maxDepth, depth + 1)

        if (isMaximizing and currentScore > bestScore) or (not isMaximizing and currentScore < bestScore) then
            bestScore = currentScore
            bestMove = move
        end

        maxDepthReached = math.max(maxDepthReached, childDepth)
    end

    return bestScore, maxDepthReached, bestMove
end


return {
    GetBestMoveLocal = function(board: buffer)
        local bestEval, depthReached, bestMove = minimax(board, true, 3, 0)

        print("depth: ", depthReached, "eval: ", bestEval)
        return {
            ["move"] = bestMove,
            ["eval"] = bestEval,
            ["depth"] = depthReached,
            ["mate"] = 0,
        }
    end,
}

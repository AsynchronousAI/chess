local actor = script:GetActor()
local name = actor.Name
if name == "ActorTemplate" then return end

local libs = require(script.Parent.Parent.Parent.import)
local eval = require(script.Parent.Parent.Parent.eval)
local moveOrdering = require(script.Parent.Parent.Parent.moveOrdering)

local function minimax(board, isMaximizing, maxDepth, depth, alpha, beta)
    local score = eval(board)

    if depth >= maxDepth then
        return score, depth, nil
    end

    local maxDepthReached = depth
    local bestScore = if isMaximizing then -math.huge else math.huge

    local allLegalMoves = libs.LegalMoves.GetAllLegalMoves(board, libs.BitBoard.getTurn(board))
    local moves = moveOrdering(board, allLegalMoves)

    for _, move in moves do
        local branch = libs.BitBoard.branch(board)
        libs.Move.PerformMove(branch, move, false)

        local currentScore, childDepth, _ = minimax(branch, not isMaximizing, maxDepth, depth + 1, alpha, beta)

        if isMaximizing then
            if currentScore > bestScore then
                bestScore = currentScore
            end
            alpha = math.max(alpha, bestScore)
        else
            if currentScore < bestScore then
                bestScore = currentScore
            end
            beta = math.min(beta, bestScore)
        end

        maxDepthReached = math.max(maxDepthReached, childDepth)

        -- Alpha-beta pruning cutoff
        if beta <= alpha then
            break
        end
    end

    return bestScore, maxDepthReached
end

actor:BindToMessageParallel("Minimax", function(tbl: SharedTable)
    local score, depthReached = minimax(buffer.fromstring(tbl.board), tbl.isMaximizing, tbl.maxDepth, tbl.depth, -math.huge, math.huge);
    tbl.score = score;
    tbl.depth = depthReached;
end)

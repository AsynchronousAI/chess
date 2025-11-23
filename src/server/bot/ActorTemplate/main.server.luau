local actor = script:GetActor()
local name = actor.Name
if name == "ActorTemplate" then return end

local libs = require(script.Parent.Parent.Parent.import)
local eval = require(script.Parent.Parent.Parent.eval)

local function minimax(board, isMaximizing, maxDepth, depth)
    local score = eval(board)

    if depth >= maxDepth then
        return score, depth, nil
    end

    local maxDepthReached = depth
    local bestScore = isMaximizing and -math.huge or math.huge

    local moves = libs.LegalMoves.GetAllLegalMoves(board, libs.BitBoard.getTurn(board))
    for _, move in moves do
        local branch = libs.BitBoard.branch(board)
        libs.Move.PerformMove(branch, move, false)

        local currentScore, childDepth, _ = minimax(branch, not isMaximizing, maxDepth, depth + 1)

        if (isMaximizing and currentScore > bestScore) or (not isMaximizing and currentScore < bestScore) then
            bestScore = currentScore
        end

        maxDepthReached = math.max(maxDepthReached, childDepth)
    end

    return bestScore, maxDepthReached
end

actor:BindToMessageParallel("Minimax", function(tbl: SharedTable)
    local score, depthReached = minimax(buffer.fromstring(tbl.board), tbl.isMaximizing, tbl.maxDepth, tbl.depth);
    tbl.score = score;
    tbl.depth = depthReached;
end)

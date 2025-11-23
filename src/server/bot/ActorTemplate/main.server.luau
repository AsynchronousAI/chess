--!native
--!optimize 2
local actor = script:GetActor()
local name = actor.Name
if name == "ActorTemplate" then return end

local libs = require(script.Parent.Parent.Parent.import)
local eval = require(script.Parent.Parent.Parent.eval)
local moveOrdering = require(script.Parent.Parent.Parent.moveOrdering)

local SEQUENCE  = true
local function minimax(board, isMaximizing, maxDepth, depth, alpha, beta)
    local score = eval(board)

    if depth >= maxDepth then
        return score, depth, if SEQUENCE then {} else nil
    end

    local maxDepthReached = depth
    local bestScore = if isMaximizing then -math.huge else math.huge
    local bestMove = 0
    local bestSequence = nil

    local allLegalMoves = libs.LegalMoves.GetAllLegalMoves(board, libs.BitBoard.getTurn(board))
    local moves = moveOrdering(board, allLegalMoves)

    for _, move in moves do
        local branch = libs.BitBoard.branch(board)
        libs.Move.PerformMove(branch, move)

        local currentScore, childDepth, subSequence = minimax(branch, not isMaximizing, maxDepth, depth + 1, alpha, beta)

        if isMaximizing then
            if currentScore > bestScore then
                bestScore = currentScore
                bestMove = move
                bestSequence = subSequence
            end
            alpha = math.max(alpha, bestScore)
        else
            if currentScore < bestScore then
                bestScore = currentScore
                bestMove = move
                bestSequence = subSequence
            end
            beta = math.min(beta, bestScore)
        end

        maxDepthReached = math.max(maxDepthReached, childDepth)

        -- Alpha-beta pruning cutoff
        if beta <= alpha then
            break
        end
    end

    local branchedSequence
    if bestSequence then
        branchedSequence = {bestMove}
        for _, move in bestSequence do
            table.insert(branchedSequence, move)
        end
    end

    return bestScore, maxDepthReached, branchedSequence
end

actor:BindToMessageParallel("Minimax", function(tbl: SharedTable)
    local score, depthReached, moveSequence = minimax(buffer.fromstring(tbl.board), tbl.isMaximizing, tbl.maxDepth, tbl.depth, -math.huge, math.huge);
    tbl.score = score;
    tbl.depth = depthReached;
    tbl.moveSequence = SharedTable.new(if moveSequence then moveSequence else {});
end)

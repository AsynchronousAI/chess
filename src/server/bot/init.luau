--!native
--!optimize 2
local libs = require(script.import)
local eval = require(script.eval)

--[[ Minimax host ]]
local function minimaxHost(board, isMaximizing, maxDepth, depth, callback)
    local score = eval(board)

    if depth >= maxDepth then
        return score, depth, nil
    end

    local maxDepthReached = depth
    local bestScore = isMaximizing and -math.huge or math.huge
    local bestMove = nil

    local moves = libs.LegalMoves.GetAllLegalMoves(board, libs.BitBoard.getTurn(board))
    local threads = {}

    -- Deploy threads
    for index, move in moves do
        local branch = libs.BitBoard.branch(board)
        libs.Move.PerformMove(branch, move, false)

        local thread = callback(branch, not isMaximizing, maxDepth, depth + 1)
        threads[index] = thread;
    end

    -- Yield for all threads being complete
    local complete = false;
    while not complete do
        task.wait()
        complete = true
        for _, thread in threads do
            if thread.score == nil then
                complete = false
                break
            end
        end
    end

    -- Merge threads back together
    for index, thread in threads do
        local currentScore = thread.score;
        local childDepth = thread.depth;
        local move = moves[index];

        if (isMaximizing and currentScore > bestScore) or (not isMaximizing and currentScore < bestScore) then
            bestScore = currentScore
            bestMove = move
        end

        maxDepthReached = math.max(maxDepthReached, childDepth)
    end

    return bestScore, maxDepthReached, bestMove
end

--[[ Actor Pool ]]
local actors = {}
function spawnThreads(threads)
    local pool = Instance.new("Folder");
    pool.Name = "ThreadPool";
    pool.Parent = script;

    for i = 1, threads do
        local clone = script.ActorTemplate:Clone()
        clone.Name = "Actor"..i
        clone.Parent = pool

        actors[i] = clone
    end
end
spawnThreads(40)

--[[ Return ]]
return {
    GetBestMoveLocal = function(board: buffer)
        local index = 0;
        local bestEval, depthReached, bestMove = minimaxHost(board, true, 3, 0, function(branch, isMaximizing, maxDepth, depth)
            index = (index%#actors)+1
            local tbl = SharedTable.new();
            tbl.board = buffer.tostring(branch);
            tbl.isMaximizing = isMaximizing;
            tbl.maxDepth = maxDepth;
            tbl.depth = depth;

            actors[index]:SendMessage("Minimax", tbl)
            return tbl
        end)

        print("depth: ", depthReached, "eval: ", bestEval)
        return {
            ["move"] = bestMove,
            ["eval"] = bestEval,
            ["depth"] = depthReached,
            ["mate"] = 0,
        }
    end,
}

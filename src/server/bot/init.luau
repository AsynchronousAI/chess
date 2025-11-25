--!native
--!optimize 2
local libs = require(script.import)
local eval = require(script.eval)
local moveOrdering = require(script.moveOrdering)

local DEPTH = if game:GetService("RunService"):IsStudio() then 3 else 3

--[[ Minimax host ]]
local function minimaxHost(board, isMaximizing, maxDepth, depth, callback)
    local score = eval(board)

    if depth >= maxDepth then
        return score, depth, nil
    end

    local maxDepthReached = depth
    local bestScore = isMaximizing and -math.huge or math.huge

    local allLegalMoves = libs.LegalMoves.GetAllLegalMoves(board, libs.BitBoard.getTurn(board))
    local moves = moveOrdering(board, allLegalMoves)
    local bestMove = moves[1] -- at times, bot doesnt want to move (zugzwang). in that case we do first legal move
    local threads = {}

    -- Deploy threads
    for index, move in moves do
        local branch = libs.BitBoard.branch(board)
        libs.Move.PerformMove(branch, move)

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
    local nodes = 0;
    local sequence = {}
    for index, thread in threads do
        local currentScore = thread.score;
        local childDepth = thread.depth;
        local move = moves[index];

        if if isMaximizing then currentScore > bestScore else currentScore < bestScore then
            bestScore = currentScore
            bestMove = move
            sequence = thread.moveSequence
        end

        nodes += thread.nodes
        maxDepthReached = math.max(maxDepthReached, childDepth)
    end

    -- Convert to sequence string
    local bestSequence = `{libs.Notation.encodeSquare(bestMove[1])}{libs.Notation.encodeSquare(bestMove[2])} `
    for _, v in sequence do
        bestSequence = `{bestSequence}{libs.Notation.encodeSquare(v[1])}{libs.Notation.encodeSquare(v[2])} `
    end

    return {score = bestScore, depth = maxDepthReached, bestMove = bestMove, sequence = bestSequence, legalMoves = #moves, nodes = nodes}
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
spawnThreads(50)

--[[ Return ]]
return {
    GetBestMoveLocal = function(board: buffer)
        local index = 0;
        local start = os.clock()
        local minimaxResults = minimaxHost(board, libs.BitBoard.getTurn(board) == 1, DEPTH, 0, function(branch, isMaximizing, maxDepth, depth)
            index = (index%#actors)+1
            local tbl = SharedTable.new();
            tbl.board = buffer.tostring(branch);
            tbl.isMaximizing = isMaximizing;
            tbl.maxDepth = maxDepth;
            tbl.depth = depth;

            actors[index]:SendMessage("Minimax", tbl)
            return tbl
        end)

        print(`depth: {minimaxResults.depth}, eval: {minimaxResults.score}, time: {math.ceil((os.clock()-start)*1000)}ms, moves: {minimaxResults.sequence}, heads: {minimaxResults.legalMoves}, nodes: {minimaxResults.nodes}`)
        return {
            ["move"] = minimaxResults.bestMove,
            ["eval"] = minimaxResults.score,
            ["depth"] = minimaxResults.depth,
            ["mate"] = 0,
        }
    end,
}

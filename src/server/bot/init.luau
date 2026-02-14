--!native
--!optimize 2
local libs = require(script.import)
local eval = require(script.eval)
local moveOrdering = require(script.moveOrdering)

local DEPTH = if game:GetService("RunService"):IsStudio() then 4 else 3

local MinimaxTranspositions = game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")
local EvaluationTransposition = game:GetService("SharedTableRegistry"):GetSharedTable("EvaluationTransposition")
local LegalMovesTransposition = game:GetService("SharedTableRegistry"):GetSharedTable("LegalMovesTransposition")


--[[ Minimax host ]]
local function minimaxHost(board, isMaximizing, maxDepth, depth, callback)
    if depth >= maxDepth then
        return eval(board), depth, nil
    end

    local maxDepthReached = depth
    local bestScore = isMaximizing and -math.huge or math.huge

    local allLegalMoves = libs.BitBoard.generate_legal_moves(board, false, board.side_to_move)
    local moves = moveOrdering(board, allLegalMoves)
    local bestMove = moves[1] -- at times, bot doesnt want to move (zugzwang). in that case we do first legal move
    local threads = {}

    -- Deploy threads
    for index, move in moves do
        local branch = libs.BitBoard.clone(board)
        libs.BitBoard.make_move(branch, move)

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
    local bestSequence = libs.Move.toString(bestMove) .. " "
    for _, v in sequence do
        bestSequence = `{bestSequence}{libs.Move.toString(v)} `
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
        clone.Name = i
        clone.Parent = pool

        actors[i] = clone
    end
end
spawnThreads(40)

--[[ Return ]]
return {
    GetBestMove = function(board)
        local index = 0;
        local start = os.clock()
        local minimaxResults = minimaxHost(board, board.side_to_move == 1, DEPTH, 0, function(branch, isMaximizing, maxDepth, depth)
            index = (index%#actors)+1
            local tbl = SharedTable.new();
            tbl.board = buffer.tostring(libs.BitBoard.to_buffer(branch));
            tbl.isMaximizing = isMaximizing;
            tbl.maxDepth = maxDepth;
            tbl.depth = depth;

            actors[index]:SendMessage("Minimax", tbl)
            return tbl
        end)

        print(`\n\
depth: {minimaxResults.depth}\
eval: {minimaxResults.score}\
time: {math.ceil((os.clock()-start)*1000)}ms\
moves: {minimaxResults.sequence}\
heads: {minimaxResults.legalMoves}\
nodes: {minimaxResults.nodes}\n\
minimaxTable: {SharedTable.size(MinimaxTranspositions)}\
evaluationTable: {SharedTable.size(EvaluationTransposition)}\
legalMoves: {SharedTable.size(LegalMovesTransposition)}`)

        return {
            ["move"] = minimaxResults.bestMove,
            ["eval"] = minimaxResults.score,
            ["depth"] = minimaxResults.depth,
            ["mate"] = 0,
        }
    end,
}

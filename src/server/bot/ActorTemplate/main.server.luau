--!native
--!optimize 2
local actor = script:GetActor()
local name = actor.Name
if name == "ActorTemplate" then return end

local TT = game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")

local libs = require(script.Parent.Parent.Parent.import)
local eval = require(script.Parent.Parent.Parent.eval)
local moveOrdering = require(script.Parent.Parent.Parent.moveOrdering)

local SEQUENCE  = true

local EXACT = 0
local LOWERBOUND = 1
local UPPERBOUND = 2

local nodes = 0;
local function minimax(board, isMaximizing, maxDepth, depth, alpha, beta)
    local score = eval(board)
    local hash = libs.BitBoard.hash(board)

    -- TT lookup
    local entry = TT[hash]
    if entry then
        -- entry: {depth, score, flag, alpha, beta, bestMove}
        if entry.depth >= maxDepth - depth then
            if entry.flag == EXACT then
                return entry.score, depth, entry.sequence
            elseif entry.flag == LOWERBOUND and entry.score > alpha then
                alpha = entry.score
            elseif entry.flag == UPPERBOUND and entry.score < beta then
                beta = entry.score
            end

            if alpha >= beta then
                return entry.score, depth, entry.sequence
            end
        end
    end


    if depth >= maxDepth then
        return score, depth, if SEQUENCE then {} else nil
    end

    local maxDepthReached = depth
    local bestScore = if isMaximizing then -math.huge else math.huge
    local bestMove = nil
    local bestSequence = nil

    local allLegalMoves = libs.BitBoard.generate_legal_moves(board, false, board.side_to_move)
    local moves = moveOrdering(board, allLegalMoves)

    for _, move in moves do
        -- TODO: try undo_move method
        local branch = libs.BitBoard.clone(board)
        libs.BitBoard.make_move(branch, move)

        nodes += 1;

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

    -- Move sequence
    local branchedSequence
    if bestSequence then
        branchedSequence = {bestMove}
        for _, move in bestSequence do
            table.insert(branchedSequence, move)
        end
    end

    -- Transpositions
    local flag
    if bestScore <= alpha then
        flag = UPPERBOUND
    elseif bestScore >= beta then
        flag = LOWERBOUND
    else
        flag = EXACT
    end

    TT[hash] = SharedTable.new({
        depth = maxDepth - depth,
        score = bestScore,
        flag = flag,
        sequence = branchedSequence,
        bestMove = bestMove,
    })


    return bestScore, maxDepthReached, branchedSequence
end

actor:BindToMessageParallel("Minimax", function(tbl: SharedTable)
    nodes = 1;

    local score, depthReached, moveSequence = minimax(libs.BitBoard.from_buffer(buffer.fromstring(tbl.board)), tbl.isMaximizing, tbl.maxDepth, tbl.depth, -math.huge, math.huge);
    tbl.score = score;
    tbl.depth = depthReached;
    tbl.moveSequence = SharedTable.new(if moveSequence then moveSequence else {});
    tbl.nodes = nodes;
end)

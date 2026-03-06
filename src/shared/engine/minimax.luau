--!native
--!optimize 2

local Move = require("./move").Move
local bitboard = require("./bitboard").BitBoard
local eval = require("./eval").eval
local moveOrdering = require("./moveOrdering")

local IS_ROBLOX = game ~= nil

local EXACT = 0
local LOWERBOUND = 1
local UPPERBOUND = 2

local nodes = 0

local TT: any
if IS_ROBLOX then
    TT = game:GetService("SharedTableRegistry"):GetSharedTable("MinimaxTranspositions")
else
    TT = {}
end

local function newTTEntry(depth, score, flag, bestMove)
    if IS_ROBLOX then
        return SharedTable.new({
            depth = depth,
            score = score,
            flag = flag,
            bestMove = bestMove,
        })
    else
        return {
            depth = depth,
            score = score,
            flag = flag,
            bestMove = bestMove,
        }
    end
end

local function minimax(board, isMaximizing, maxDepth, depth, alpha, beta)
    if depth == 0 then nodes = 0 end

    local alphaOrig = alpha
    local betaOrig = beta

    local hash = bitboard.hash(board)
    local entry = TT[hash]

    if entry then
        if entry.depth >= maxDepth - depth then
            if entry.flag == EXACT then
                return entry.score, entry.bestMove, nodes
            elseif entry.flag == LOWERBOUND and entry.score > alpha then
                alpha = entry.score
            elseif entry.flag == UPPERBOUND and entry.score < beta then
                beta = entry.score
            end
            if alpha >= beta then
                return entry.score, entry.bestMove, nodes
            end
        end
    end

    if depth >= maxDepth then
        return eval(board), nil, nodes
    end

    local bestScore = isMaximizing and -math.huge or math.huge
    local allLegalMoves = bitboard.generate_legal_moves(board, false, board.side_to_move)
    moveOrdering(board, allLegalMoves)

    local n = #allLegalMoves
    local getValue = Move.getValue
    local bestMove = allLegalMoves[1]

    for i = 1, n do
        -- Selection sort for move ordering
        local bestIndex = i
        local bestMoveLocal = allLegalMoves[i]
        local bestValue = getValue(bestMoveLocal)

        for j = i + 1, n do
            local m = allLegalMoves[j]
            local v = getValue(m)
            if v > bestValue then
                bestValue = v
                bestIndex = j
                bestMoveLocal = m
            end
        end

        allLegalMoves[i], allLegalMoves[bestIndex] = allLegalMoves[bestIndex], allLegalMoves[i]

        local move = allLegalMoves[i]
        local record = bitboard.make_move(board, move)
        nodes += 1

        local score = minimax(board, not isMaximizing, maxDepth, depth + 1, alpha, beta)

        bitboard.undo_move(board, move, record)

        if isMaximizing then
            if score > bestScore then
                bestScore = score
                bestMove = move
            end
            alpha = math.max(alpha, bestScore)
        else
            if score < bestScore then
                bestScore = score
                bestMove = move
            end
            beta = math.min(beta, bestScore)
        end

        if beta <= alpha then
            break
        end
    end

    -- Store in TT
    local flag
    if bestScore <= alphaOrig then
        flag = UPPERBOUND
    elseif bestScore >= betaOrig then
        flag = LOWERBOUND
    else
        flag = EXACT
    end

    TT[hash] = newTTEntry(maxDepth - depth, bestScore, flag, bestMove)

    return bestScore, bestMove, nodes
end

return minimax

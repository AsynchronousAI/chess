local bitboard = require("./bitboard").BitBoard
local Move = require("./move").Move
local eval = require("../../server/bot/eval")
local moveOrdering = require("../../server/bot/moveOrdering")

local nodes = 0
local TT = {}
local EXACT = 0
local LOWERBOUND = 1
local UPPERBOUND = 2

local function minimax(board, isMaximizing, maxDepth, depth, alpha, beta)
    if depth == 0 then nodes = 0 end

    local alphaOrig = alpha
    local betaOrig = beta
    local hash = bitboard.hash(board)

    local entry = TT[hash]
    if entry then
        if entry.depth >= maxDepth - depth then
            if entry.flag == EXACT then
                return entry.score, entry.bestMove, nodes, entry.bestLine
            elseif entry.flag == LOWERBOUND and entry.score > alpha then
                alpha = entry.score
            elseif entry.flag == UPPERBOUND and entry.score < beta then
                beta = entry.score
            end

            if alpha >= beta then
                return entry.score, entry.bestMove, nodes, entry.bestLine
            end
        end
    end

    if depth >= maxDepth then
        return eval(board), nil, nodes, {}
    end

    local bestScore = isMaximizing and -math.huge or math.huge
    local allLegalMoves = bitboard.generate_legal_moves(board, false, board.side_to_move)
    moveOrdering(board, allLegalMoves)
    local n = #allLegalMoves
    local getValue = Move.getValue

    local bestMove = allLegalMoves[1]
    local bestLine = {}

    for i = 1, n do
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

        -- Recursive call returns PV of the subtree
        local score, _, _, line = minimax(board, not isMaximizing, maxDepth, depth + 1, alpha, beta)

        bitboard.undo_move(board, move, record)

        if isMaximizing then
            if score > bestScore then
                bestScore = score
                bestMove = move
                bestLine = {move}
                for _, m in ipairs(line) do table.insert(bestLine, m) end
            end
            alpha = math.max(alpha, bestScore)
        else
            if score < bestScore then
                bestScore = score
                bestMove = move
                bestLine = {move}
                for _, m in ipairs(line) do table.insert(bestLine, m) end
            end
            beta = math.min(beta, bestScore)
        end

        if beta <= alpha then
            break
        end
    end

    local flag
    if bestScore <= alphaOrig then
        flag = UPPERBOUND
    elseif bestScore >= betaOrig then
        flag = LOWERBOUND
    else
        flag = EXACT
    end

    TT[hash] = {
        depth = maxDepth - depth,
        score = bestScore,
        flag = flag,
        bestMove = bestMove,
        bestLine = bestLine,
    }

    return bestScore, bestMove, nodes, bestLine
end

return minimax
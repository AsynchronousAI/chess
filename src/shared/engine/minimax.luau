--!native
--!optimize 2

local Move = require("./move").Move
local bitboard = require("./bitboard").BitBoard
local eval = require("./eval").eval
local moveOrdering = require("./moveOrdering")
local Utils = require("./utils")
local Zobrist = require("./zobrist")

local IS_ROBLOX = game ~= nil

local EXACT = 0
local LOWERBOUND = 1
local UPPERBOUND = 2

local NULL_MOVE_REDUCTION = 2
local QUIESCENCE_MAX_DEPTH = 6
local FUTILITY_DEPTH = 2
local FUTILITY_MARGIN = 150
local ASPIRATION_WINDOW = 100
local LMR_DEPTH = 3
local LMR_MOVE_THRESHOLD = 3
local LMR_REDUCTION = 1

local nodes = 0
local startTime = 0
local timeLimitSec = nil
local stopSearch = false
local lastCompletedDepth = 0
local maxPlyReached = 0
local currentRootDepth = 0

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

local function timeUp()
    if not timeLimitSec then
        return false
    end
    if (os.clock() - startTime) >= timeLimitSec then
        stopSearch = true
        return true
    end
    return false
end

local function isInCheck(board, color)
    local kingSquare = bitboard.find_piece(board, Utils.KING, color)
    if not kingSquare then
        return true
    end
    return bitboard.is_square_attacked(board, kingSquare, 1 - color)
end

local function doNullMove(board)
    if board.hash == nil then
        board.hash = bitboard.hash(board)
    end
    local old = {
        side = board.side_to_move,
        ep = board.en_passant_square,
        hash = board.hash,
    }

    local hash = board.hash
    if board.en_passant_square then
        hash = Zobrist.toggle_en_passant(hash, board.en_passant_square % 8)
    end
    hash = Zobrist.toggle_side(hash)
    board.hash = hash
    board.en_passant_square = nil
    board.side_to_move = 1 - board.side_to_move

    return old
end

local function undoNullMove(board, old)
    board.side_to_move = old.side
    board.en_passant_square = old.ep
    board.hash = old.hash
end

local function quiescence(board, isMaximizing, alpha, beta, depth)
    if timeUp() then
        return eval(board)
    end

    local standPat = eval(board)

    local qUsed = QUIESCENCE_MAX_DEPTH - depth
    local plyReached = currentRootDepth + qUsed
    if plyReached > maxPlyReached then
        maxPlyReached = plyReached
    end

    if isMaximizing then
        if standPat > alpha then alpha = standPat end
        if alpha >= beta then return standPat end
    else
        if standPat < beta then beta = standPat end
        if beta <= alpha then return standPat end
    end

    if depth <= 0 then
        return standPat
    end

    local allLegalMoves = bitboard.generate_legal_moves(board, false, board.side_to_move)
    moveOrdering(board, allLegalMoves)

    local n = #allLegalMoves

    for i = 1, n do
        -- Selection sort for move ordering
        local bestIndex = i
        local bestMoveLocal = allLegalMoves[i]
        local bestValue = bit32.band(bit32.rshift(bestMoveLocal, 22), 0x7F)  -- inline: getValue(bestMoveLocal)

        for j = i + 1, n do
            local m = allLegalMoves[j]
            local v = bit32.band(bit32.rshift(m, 22), 0x7F)  -- inline: getValue(m)
            if v > bestValue then
                bestValue = v
                bestIndex = j
                bestMoveLocal = m
            end
        end

        allLegalMoves[i], allLegalMoves[bestIndex] = allLegalMoves[bestIndex], allLegalMoves[i]

        local move = allLegalMoves[i]
        local isCapture = (bit32.band(bit32.rshift(move, 20), 0x3) ~= 0) or (bit32.band(bit32.rshift(move, 19), 0x1) == 1) -- inline: Move.getCaptured(move) or Move.getEnPassant(move)
        local isPromotion = bit32.band(bit32.rshift(move, 16), 0x7) ~= 5 -- inline: Move.getPromotion(move) ~= nil
        if not isCapture and not isPromotion then
            continue
        end

        local record = bitboard.make_move(board, move)
        nodes += 1

        local score = quiescence(board, not isMaximizing, alpha, beta, depth - 1)

        bitboard.undo_move(board, move, record)

        if isMaximizing then
            standPat = math.max(standPat, score)
            alpha = math.max(alpha, standPat)
        else
            standPat = math.min(standPat, score)
            beta = math.min(beta, standPat)
        end

        if beta <= alpha then
            break
        end
    end

    return standPat
end

local function alphaBeta(board, isMaximizing, depthRemaining, alpha, beta, allowNull)
    if stopSearch or timeUp() then
        return eval(board), nil
    end

    local plyReached = currentRootDepth - depthRemaining
    if plyReached > maxPlyReached then
        maxPlyReached = plyReached
    end

    local alphaOrig = alpha
    local betaOrig = beta

    local hash = bitboard.hash(board)
    local entry = TT[hash]

    if entry then
        if entry.depth >= depthRemaining then
            if entry.flag == EXACT then
                return entry.score, entry.bestMove
            elseif entry.flag == LOWERBOUND and entry.score > alpha then
                alpha = entry.score
            elseif entry.flag == UPPERBOUND and entry.score < beta then
                beta = entry.score
            end
            if alpha >= beta then
                return entry.score, entry.bestMove
            end
        end
    end

    if depthRemaining <= 0 then
        return quiescence(board, isMaximizing, alpha, beta, QUIESCENCE_MAX_DEPTH), nil
    end

    local inCheck = isInCheck(board, board.side_to_move)
    if depthRemaining <= FUTILITY_DEPTH and not inCheck then
        local standPat = eval(board)
        if isMaximizing then
            if standPat + FUTILITY_MARGIN <= alpha then
                return standPat, nil
            end
        else
            if standPat - FUTILITY_MARGIN >= beta then
                return standPat, nil
            end
        end
    end

    if allowNull and depthRemaining >= 3 and not inCheck then
        local old = doNullMove(board)
        local score = alphaBeta(board, not isMaximizing, depthRemaining - 1 - NULL_MOVE_REDUCTION, alpha, beta, false)
        undoNullMove(board, old)

        if isMaximizing then
            if score >= beta then
                return score, nil
            end
        else
            if score <= alpha then
                return score, nil
            end
        end
    end

    local bestScore = isMaximizing and -math.huge or math.huge
    local allLegalMoves = bitboard.generate_legal_moves(board, false, board.side_to_move)
    moveOrdering(board, allLegalMoves)

    if #allLegalMoves == 0 then
        return eval(board), nil
    end

    local n = #allLegalMoves
    local bestMove = allLegalMoves[1]

    for i = 1, n do
        -- Selection sort for move ordering
        local bestIndex = i
        local bestMoveLocal = allLegalMoves[i]
        local bestValue = bit32.band(bit32.rshift(bestMoveLocal, 22), 0x7F) -- inline: getValue(bestMoveLocal)

        for j = i + 1, n do
            local m = allLegalMoves[j]
            local v = bit32.band(bit32.rshift(m, 22), 0x7F) -- inline: getValue(m)
            if v > bestValue then
                bestValue = v
                bestIndex = j
                bestMoveLocal = m
            end
        end

        allLegalMoves[i], allLegalMoves[bestIndex] = allLegalMoves[bestIndex], allLegalMoves[i]

        local move = allLegalMoves[i]
        local isCapture = (bit32.band(bit32.rshift(move, 15), 0x1) == 1) or (bit32.band(bit32.rshift(move, 19), 0x1) == 1) -- inline: Move.getCaptured(move) or Move.getEnPassant(move)
        local isPromotion = bit32.band(bit32.rshift(move, 16), 0x7) ~= 5 -- inline: Move.getPromotion(move) ~= nil
        local reduction = 0
        if depthRemaining >= LMR_DEPTH and i > LMR_MOVE_THRESHOLD and not inCheck and not isCapture and not isPromotion then
            reduction = LMR_REDUCTION
        end

        local record = bitboard.make_move(board, move)
        nodes += 1

        local score
        if reduction > 0 then
            score = alphaBeta(board, not isMaximizing, depthRemaining - 1 - reduction, alpha, beta, true)
            if not stopSearch then
                if isMaximizing then
                    if score > alpha then
                        score = alphaBeta(board, not isMaximizing, depthRemaining - 1, alpha, beta, true)
                    end
                else
                    if score < beta then
                        score = alphaBeta(board, not isMaximizing, depthRemaining - 1, alpha, beta, true)
                    end
                end
            end
        else
            score = alphaBeta(board, not isMaximizing, depthRemaining - 1, alpha, beta, true)
        end

        bitboard.undo_move(board, move, record)

        if stopSearch then
            return score, bestMove
        end

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

    if not stopSearch then
        local flag
        if bestScore <= alphaOrig then
            flag = UPPERBOUND
        elseif bestScore >= betaOrig then
            flag = LOWERBOUND
        else
            flag = EXACT
        end

        TT[hash] = newTTEntry(depthRemaining, bestScore, flag, bestMove)
    end

    return bestScore, bestMove
end

local function parseLimits(maxDepth, timeLimitMs)
    local depthLimit = maxDepth
    local timeMs = timeLimitMs

    if type(maxDepth) == "table" then
        depthLimit = maxDepth.depth or maxDepth.maxDepth or maxDepth[1] or 1
        timeMs = maxDepth.timeLimitMs or maxDepth.timeMs or maxDepth.ms or maxDepth.time
    end

    return depthLimit, timeMs
end

local function minimax(board, isMaximizing, maxDepth, depth, alpha, beta, timeLimitMs)
    nodes = 0
    lastCompletedDepth = 0
    maxPlyReached = 0
    currentRootDepth = 0

    local depthLimit, timeMs = parseLimits(maxDepth, timeLimitMs)

    local targetDepth = depthLimit - depth
    if targetDepth <= 0 then
        return eval(board), nil, nodes, nil, lastCompletedDepth, maxPlyReached
    end

    if timeMs then
        startTime = os.clock()
        timeLimitSec = timeMs / 1000
        stopSearch = false
    else
        timeLimitSec = nil
        stopSearch = false
    end

    local bestScore
    local bestMove
    local alphaRoot = alpha
    local betaRoot = beta

    for d = 1, targetDepth do
        currentRootDepth = d
        local searchAlpha = alphaRoot
        local searchBeta = betaRoot

        if bestScore ~= nil then
            searchAlpha = bestScore - ASPIRATION_WINDOW
            searchBeta = bestScore + ASPIRATION_WINDOW
        end

        local score, move = alphaBeta(board, isMaximizing, d, searchAlpha, searchBeta, true)
        if not stopSearch and bestScore ~= nil and (score <= searchAlpha or score >= searchBeta) then
            score, move = alphaBeta(board, isMaximizing, d, alphaRoot, betaRoot, true)
        end
        if stopSearch then
            break
        end
        bestScore = score
        bestMove = move
        lastCompletedDepth = d
    end

    if bestScore == nil then
        bestScore = eval(board)
    end
    bestMove = bestMove or bitboard.generate_legal_moves(board)[1]

    return bestScore, bestMove, nodes, nil, lastCompletedDepth, maxPlyReached
end

return minimax

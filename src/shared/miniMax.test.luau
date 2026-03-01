local bitboard = require("./engine/bitboard").BitBoard
local Move = require("./engine/move").Move
local eval = require("../server/bot/eval")
local moveOrdering = require("../server/bot/moveOrdering")


local UNICODE = {
    { -- White
        "♙", "♘", "♗", "♖", "♕", "♔",
    },
    { -- Black
        "♟", "♞", "♝", "♜", "♛", "♚",
    }
}
local CHAR = {
    { -- White
        "p", "n", "b", "r", "q", "k",
    },
    { -- Black
        "P", "N", "B", "R", "Q", "K",
    }
}

local DEPTH = 5
local MAX_MOVES = math.huge

local nodes = 0
local TT = {}
local EXACT = 0
local LOWERBOUND = 1
local UPPERBOUND = 2

local function printBoard(board)
    for rank = 7, 0, -1 do
        local row = tostring(rank + 1) .. " "
        for file = 0, 7 do
            local square = rank * 8 + file
            local val = board.pieceTable[square]
            if val then
                local pieceType = bit32.rshift(val, 6)
                local pieceColor = bit32.band(val, 63)
                row = row .. (CHAR[pieceColor+1][pieceType+1]) .. " "
            else
                row = row .. ". "
            end
        end
        print(row)
    end
    print("  a b c d e f g h")
end
local function minimax(board, isMaximizing, maxDepth, depth, alpha, beta)
    local alphaOrig = alpha
    local betaOrig = beta
    local hash = bitboard.hash(board)

    local entry = TT[hash]
    if entry then
        if entry.depth >= maxDepth - depth then
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

    if depth >= maxDepth then
        return eval(board), nil
    end

    local bestScore = isMaximizing and -math.huge or math.huge

    local allLegalMoves = bitboard.generate_legal_moves(board, false, board.side_to_move)
    moveOrdering(board, allLegalMoves)
    local n = #allLegalMoves
    local getValue = Move.getValue

    local bestMove = allLegalMoves[1]

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
    }

    return bestScore, bestMove
end

local board = bitboard.create()
bitboard.set_start_position(board)

local moveCount = 0
local moveComputeCount = 0
local maxNPS = 0
local sumNPS = 0
while moveCount < MAX_MOVES do
    nodes = 0
    local start = os.clock()

    local state = bitboard.get_game_state(board)
    if state ~= "" then
        print("Game over to ", state)
        break
    end

    local isWhite = board.side_to_move == 1
    local score, move = minimax(board, isWhite, DEPTH, 0, -math.huge, math.huge)
    if not move then
        print("Could not find move")
        break
    end

    bitboard.make_move(board, move)
    local time = (os.clock() - start)

    moveCount += 1

    local nps = math.floor(nodes / time)
    maxNPS = math.max(maxNPS, nps)
    sumNPS += nps
    if nps ~= 0 then moveComputeCount += 1 end

    printBoard(board)
    print(string.format(
        "Move %d: %s\n %s | eval: %.2f | time: %dms | nodes: %d | %d nodes/sec",
        moveCount,
        bitboard.to_fen(board),
        Move.toString(move),
        score,
        math.ceil(time * 1000),
        nodes,
        nps
    ))
end

print(string.format("Complete\nMaximum NPS: %d\nAverage NPS: %d", maxNPS, sumNPS/moveComputeCount))

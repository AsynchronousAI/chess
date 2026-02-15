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

local DEPTH = 3
local MAX_MOVES = math.huge

local nodes = 0

local function printBoard(board)
    for rank = 7, 0, -1 do
        local row = tostring(rank + 1) .. " "
        for file = 0, 7 do
            local square = rank * 8 + file
            local piece = bitboard.get_piece(board, square) -- returns {type, color} or nil
            if piece then
                local pieceType = piece[1]
                local color = piece[2]
                row = row .. (CHAR[color+1][pieceType+1]) .. " "
            else
                row = row .. ". "
            end
        end
        print(row)
    end
    print("  a b c d e f g h")
end
local function minimax(board, isMaximizing, maxDepth, depth, alpha, beta)
    if depth >= maxDepth then
        return eval(board), nil
    end

    local bestScore = isMaximizing and -math.huge or math.huge

    local allLegalMoves = bitboard.generate_legal_moves(board, false, board.side_to_move)
    local moves = moveOrdering(board, allLegalMoves)

    local bestMove = moves[1]

    for _, move in moves do
        local branch = bitboard.clone(board)
        bitboard.make_move(branch, move)

        nodes = nodes + 1

        local score = minimax(branch, not isMaximizing, maxDepth, depth + 1, alpha, beta)

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

    return bestScore, bestMove
end

local board = bitboard.create()
bitboard.set_start_position(board)

local moveCount = 0
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
    moveCount = moveCount + 1

    printBoard(board)
    print(string.format(
        "Move %d: %s\n %s | eval: %.2f | time: %dms | nodes: %d",
        moveCount,
        bitboard.to_fen(board),
        Move.toString(move),
        score,
        math.ceil((os.clock() - start) * 1000),
        nodes
    ))
end

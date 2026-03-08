local bitboard = require("../src/shared/engine/bitboard").BitBoard
local Move = require("../src/shared/engine/move").Move
local minimax = require("../src/shared/engine/minimax")

local DEPTH = 10
local TIME_LIMIT_MS = 50
local MAX_MOVES = math.huge

local nodes = 0

local CHAR = {
    { -- White
        "p", "n", "b", "r", "q", "k",
    },
    { -- Black
        "P", "N", "B", "R", "Q", "K",
    }
}
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
    local score, move, n, _, depthReached, maxPlyReached = minimax(board, isWhite, DEPTH, 0, -math.huge, math.huge, TIME_LIMIT_MS)
    nodes += n
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
        "Move %d: %s\n %s | eval: %.2f | maxDepth: %d | depth: %d | maxPly: %d | time: %dms | nodes: %d | %d nodes/sec",
        moveCount,
        bitboard.to_fen(board),
        Move.toString(move),
        score,
        DEPTH,
        depthReached,
        maxPlyReached,
        math.ceil(time * 1000),
        nodes,
        nps
    ))
end

print(string.format("Complete\nMaximum NPS: %d\nAverage NPS: %d", maxNPS, sumNPS/moveComputeCount))

-- Run with Lute
local io = require("@std/io")

local bitboard = require("../src/shared/engine/bitboard").BitBoard
local Move = require("../src/shared/engine/move").Move
local minimax = require("../src/shared/engine/minimax")

local DEPTH = 5
local running = true
local board = bitboard.create()

local FILES = {"a", "b", "c", "d", "e", "f", "g", "h"}

function parseSquare(square)
    square = square:match("^%s*(.-)%s*$")
    local fileChar = square:sub(1,1)
    local rankChar = square:sub(2,2)

    local fileIndex
    for i, f in ipairs(FILES) do
        if f == fileChar then
            fileIndex = i - 1
            break
        end
    end

    local rankIndex = tonumber(rankChar)
    if not fileIndex or not rankIndex then
        error("Invalid square: " .. square)
    end
    return bitboard.get_square_index(fileIndex, rankIndex - 1)
end
function encodeSquare(square)
    local fileIndex, rankIndex = unpack(bitboard.separate_square_index(square))
    return FILES[fileIndex + 1] .. tostring(rankIndex + 1)
end
local function handlePosition(line)
    board = bitboard.create()

    if line:match("startpos") then
        bitboard.set_start_position(board)
    elseif line:match("fen") then
        local fenPart = line:match("fen%s+(.*)")
        bitboard.from_fen(board, fenPart)
    end

    local movesPart = line:match("moves%s+(.*)")
    if movesPart then
        for moveStr in movesPart:gmatch("%S+") do
            local startSq = parseSquare(moveStr:sub(1,2))
            local endSq = parseSquare(moveStr:sub(3,4))

            local allMoves = bitboard.generate_legal_moves_from(board, startSq)
            local moveMade = false

            for _, possibleMove in allMoves do
                if Move.getTo(possibleMove) == endSq then
                    if #moveStr == 5 then
                        local promoChar = moveStr:sub(5,5)
                        Move.setPromotion(possibleMove, promoChar:lower())
                    end
                    bitboard.make_move(board, possibleMove)
                    moveMade = true
                    break
                end
            end

            if not moveMade then
                warn("Illegal move: " .. moveStr)
            end
        end
    end
end
local function handleGo(line)
    local depth = tonumber(line:match("depth (%d+)") or DEPTH)

    local start = os.clock()
    local score, best, nodes, moveSeq = minimax(board, board.side_to_move == 1, depth, 0, -math.huge, math.huge)
    local timeTaken = math.floor((os.clock()-start)*1000)/1000;

    for i = 1, #moveSeq do
        moveSeq[i] = Move.toSimpleString(moveSeq[i])
    end

    print(`info nodes {nodes} nps {math.ceil(nodes/timeTaken)} time {timeTaken}s depth {depth} eval {score}: {table.concat(moveSeq, " ")}`)
    print(`bestmove {Move.toSimpleString(best)}`)
end

while running do
    local line = io.input():gsub("\n", "")
    if line and line ~= "" then
        if line == "uci" then
            print("id name roblox-chess-engine")
            print("id author AsynchronousAI")
            print("uciok")
        elseif line == "isready" then
            print("readyok")
        elseif line:match("^position") then
            handlePosition(line)
        elseif line:match("^go") then
            handleGo(line)
        elseif line == "quit" then
            running = false
        end
    end
end

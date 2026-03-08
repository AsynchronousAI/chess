local bitboard = require("../src/shared/engine/bitboard").BitBoard
local perft = require("../src/shared/engine/perft")

local DEPTH = 6
local function run_perft(depth)
    local board = bitboard.create()

    local startTime = os.clock()
    local nodes = perft(board, depth)
    local elapsed = os.clock() - startTime

    print(string.format("Perft depth: %d, nodes: %d, time: %.4fs. %.2f nodes/sec", depth, nodes, elapsed, nodes / elapsed))
end

for depth = 1, DEPTH do
    run_perft(depth)
end

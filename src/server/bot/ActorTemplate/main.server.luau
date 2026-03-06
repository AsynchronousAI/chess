--!native
--!optimize 2

local actor = script:GetActor()
local name = actor.Name
if name == "ActorTemplate" then return end

local libs = require(script.Parent.Parent.Parent.import)
local minimax = libs.Minimax

-- In actor script
actor:BindToMessageParallel("Minimax", function(tbl: SharedTable)
    local board = libs.BitBoard.create()
    libs.BitBoard.from_buffer(board, buffer.fromstring(tbl.board))
    local score, bestMove, nodeCount, sequence = minimax(
        board,
        tbl.isMaximizing,
        tbl.maxDepth,
        tbl.depth,
        -math.huge,
        math.huge
    )

    tbl.score = score
    tbl.bestMove = bestMove or 0
    tbl.nodes = nodeCount
    tbl.moveSequence = sequence or SharedTable.new()
end)

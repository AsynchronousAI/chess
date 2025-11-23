local libs = require(script.Parent.import)
local hasPiece = libs.BitBoard.hasPiece

return function(board, moves)
    for index, move in (moves) do
        local isCapture = hasPiece(board, move[2]) -- check if the destination square has a piece

        move[4] = if isCapture then 2 else 1 -- use [from, to, promotion?, value]
    end

    table.sort(moves, function(a, b)
        return a[4] > b[4]
    end)

    return moves
end

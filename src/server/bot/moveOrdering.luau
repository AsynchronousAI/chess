local libs = require(script.Parent.import)
local hasPiece = libs.BitBoard.hasPiece

return function(board, moves)
    local color = libs.BitBoard.getTurn(board)
    for index, move in (moves) do
        local isCapture = hasPiece(board, move[2]) -- check if the destination square has a piece

        move[4] = if isCapture then 2 else 1 -- use [from, to, promotion?, value]

        --  promotions
        local piece = libs.BitBoard.getPiece(board, move[1])[1]
        if move[3] == nil and libs.Board.IsPromotion(move[2], piece, color) then
            table.insert(moves, {move[1], move[2], libs.Board.Piece.knight, 3})
            table.insert(moves, {move[1], move[2], libs.Board.Piece.bishop, 3})
            table.insert(moves, {move[1], move[2], libs.Board.Piece.rook, 4})
            table.insert(moves, {move[1], move[2], libs.Board.Piece.queen, 5})
        end
    end

    table.sort(moves, function(a, b)
        return a[4] > b[4]
    end)

    return moves
end

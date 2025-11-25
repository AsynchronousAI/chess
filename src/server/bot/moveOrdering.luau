local libs = require(script.Parent.import)
local hasPiece = libs.BitBoard.hasPiece

return function(board, moves)
    local color = libs.BitBoard.getTurn(board)
    for index, move in (moves) do -- move: {from: Square, to: Square, promotion: Piece, moveType: MoveType, sort: number (adding)}
        local isCapture = hasPiece(board, move[2]) -- check if the destination square has a piece

        move[5] = if isCapture then 2 else 1

        -- promotions
        local piece = libs.BitBoard.getPiece(board, move[1])[1]
        if move[3] == nil and libs.Board.IsPromotion(move[2], piece, color) then
            -- TODO: bot has the option to not promote still
            table.insert(moves, {move[1], move[2], libs.Board.Piece.knight, move[4], 3})
            table.insert(moves, {move[1], move[2], libs.Board.Piece.bishop, move[4], 3})
            table.insert(moves, {move[1], move[2], libs.Board.Piece.rook, move[4], 4})
            table.insert(moves, {move[1], move[2], libs.Board.Piece.queen, move[4], 5})
        end
    end

    table.sort(moves, function(a, b)
        return a[5] > b[5]
    end)

    return moves
end

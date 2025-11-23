--!native
--!optimize 2
local libs = require(script.import)
local eval = require(script.eval)

return {
    GetBestMoveLocal = function(board: buffer)
        local allMoves = libs.LegalMoves.GetAllLegalMoves(board, libs.BitBoard.getTurn(board))
        return {
            ["move"] = allMoves[math.random(1,#allMoves)],
            ["eval"] = eval(board),
            ["depth"] = 0,
            ["mate"] = 0,
        }
    end,
}

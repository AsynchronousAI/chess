--!native
--!optimize 2
local Utils = require("./utils")
local WK, WQ, BK, BQ = Utils.WK, Utils.WQ, Utils.BK, Utils.BQ;
local split_pair = Utils.split_pair

local Zobrist = {}
Zobrist.piece_square = {}
Zobrist.castling = {}
Zobrist.en_passant = {}
Zobrist.side_to_move = 0

do
    local seed = math.floor(os.clock()/60)
    math.randomseed(seed)
    local random = function()
        return math.random(0, 0xFFFFFFF)
    end

    for color = Utils.WHITE, Utils.BLACK do
        Zobrist.piece_square[color] = {}
        for piece = Utils.PAWN, Utils.KING do
            Zobrist.piece_square[color][piece] = {}
            for square = 0, 64 do
                Zobrist.piece_square[color][piece][square] = random()
            end
        end
    end

    for i = 1, 4 do
        Zobrist.castling[i] = random()
    end
    for file = 0, 7 do
        Zobrist.en_passant[file] = random()
    end
    Zobrist.side_to_move = random()
end

return function(board)
    local hash = 0

    -- Pieces
    for pos = 0, 63 do
        local pieceAtPos = board.pieceTable[pos]
        if not pieceAtPos then continue end

        local piece, color = split_pair(pieceAtPos)
        hash = bit32.bxor(hash, Zobrist.piece_square[color][piece][pos])
    end

    -- Castling
    if Utils.get_bit32(board.castling_rights, WK) then hash = bit32.bxor(hash, Zobrist.castling[1]) end
    if Utils.get_bit32(board.castling_rights, WQ) then hash = bit32.bxor(hash, Zobrist.castling[2]) end
    if Utils.get_bit32(board.castling_rights, BK) then hash = bit32.bxor(hash, Zobrist.castling[3]) end
    if Utils.get_bit32(board.castling_rights, BQ) then hash = bit32.bxor(hash, Zobrist.castling[4]) end

    -- En passant
    if board.en_passant_square then
        local file = board.en_passant_square % 8
        hash = bit32.bxor(hash, Zobrist.en_passant[file])
    end

    -- Side to move
    if board.side_to_move == Utils.WHITE then
        hash = bit32.bxor(hash, Zobrist.side_to_move)
    end

    return hash
end

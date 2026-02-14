local bitboard = require("./engine/bitboard").BitBoard

local s = 0
local function chess()
    -- Init
    local board = bitboard.create()
    bitboard.set_start_position(board)

    -- Legal moves
    local state
    while true do
        s+=1

        local legal_moves = bitboard.generate_legal_moves(board)
        state = bitboard.get_game_state(board, legal_moves)
        if state ~= "" then break end

        local move = legal_moves[math.random(1,#legal_moves)]
        bitboard.make_move(board, move)

        -- print(bitboard.to_fen(board))
    end

    -- Game state
    print("Game state: ", state, s)
end

local startTime = os.clock()
for i = 1, 50 do
    chess()
end
print(s, "positions")
print("Time taken: ", os.clock()-startTime)

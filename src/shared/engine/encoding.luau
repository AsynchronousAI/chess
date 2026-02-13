--!optimize 2
--!native
local u64 = require("./int64")
local Utils = require("./utils")

local WHITE, BLACK, PAWN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KING

-- unlike older versions this is designed to be **rapid**, not efficent.
local Encoding = {}
local EN_PASSANT_NONE = 67 -- for the love of the game

function Encoding.to_buffer(self)
    local buf = buffer.create(242)
    local off = 0

    -- Helper for writing a u64
    local function writeU64(value)
        u64.write_to_buffer(buf, value, off)
        off += 8
    end

    -- Pieces
    for color = WHITE, BLACK do
        for piece = PAWN, KING do
            writeU64(self.pieces[color][piece])
        end
    end

    -- Attacks
    for color = WHITE, BLACK do
        for piece = PAWN, KING do
            writeU64(self.attacked[color][piece])
        end
        writeU64(self.attacked[color].all)
    end

    -- Occupancy
    writeU64(self.occupied[WHITE])
    writeU64(self.occupied[BLACK])
    writeU64(self.occupied.all)

    -- Side to move
    buffer.writeu8(buf, off, self.side_to_move)
    off += 1

    -- Castling
    buffer.writeu8(buf, off, self.castling_rights.white_kingside  and 1 or 0); off += 1
    buffer.writeu8(buf, off, self.castling_rights.white_queenside and 1 or 0); off += 1
    buffer.writeu8(buf, off, self.castling_rights.black_kingside  and 1 or 0); off += 1
    buffer.writeu8(buf, off, self.castling_rights.black_queenside and 1 or 0); off += 1

    -- En-passant
    local ep = self.en_passant_square or EN_PASSANT_NONE
    buffer.writeu8(buf, off, ep)
    off += 1

    -- Clocks
    buffer.writeu16(buf, off, self.halfmove_clock);  off += 2
    buffer.writeu16(buf, off, self.fullmove_number); off += 2

    return buf
end
function Encoding.from_buffer(self, buf)
    local off = 0

    -- Helper for reading a u64
    local function readU64()
        local val = u64.from_buffer(buf, off)
        off += 8
        return val
    end

    -- Pieces
    for color = WHITE, BLACK do
        for piece = PAWN, KING do
            self.pieces[color][piece] = readU64()
        end
    end

    -- Attacks
    for color = WHITE, BLACK do
        for piece = PAWN, KING do
            self.attacked[color][piece] = readU64()
        end
        self.attacked[color].all = readU64()
    end

    -- Occupancy
    self.occupied[WHITE] = readU64()
    self.occupied[BLACK] = readU64()
    self.occupied.all   = readU64()

    -- Side to move
    self.side_to_move = buffer.readu8(buf, off)
    off += 1

    -- Castling rights
    self.castling_rights.white_kingside  = buffer.readu8(buf, off) == 1; off += 1
    self.castling_rights.white_queenside = buffer.readu8(buf, off) == 1; off += 1
    self.castling_rights.black_kingside  = buffer.readu8(buf, off) == 1; off += 1
    self.castling_rights.black_queenside = buffer.readu8(buf, off) == 1; off += 1

    -- En-passant
    local ep = buffer.readu8(buf, off)
    off += 1
    self.en_passant_square = if (ep == EN_PASSANT_NONE) then nil else ep

    -- Clocks
    self.halfmove_clock  = buffer.readu16(buf, off); off += 2
    self.fullmove_number = buffer.readu16(buf, off); off += 2

    return self
end

return Encoding

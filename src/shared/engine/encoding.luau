--!optimize 2
--!native
local Utils = require("./utils")
local WHITE, BLACK, PAWN, KING = Utils.WHITE, Utils.BLACK, Utils.PAWN, Utils.KING
local ALL, ATTACKED_ALL = Utils.ALL, Utils.ATTACKED_ALL
local PIECE_STRIDE = Utils.PIECE_STRIDE  -- 6
local ATK_STRIDE   = Utils.ATK_STRIDE    -- 7
local split_pair, make_pair = Utils.split_pair, Utils.make_pair
local Encoding = {}
local EN_PASSANT_NONE = 67
local U8_MAX = 255

local function writeBB(buf, off, lo, hi)
	buffer.writeu32(buf, off,     lo)
	buffer.writeu32(buf, off + 4, hi)
	return off + 8
end
local function readBB(buf, off)
	local lo = buffer.readu32(buf, off)
	local hi = buffer.readu32(buf, off + 4)
	return lo, hi, off + 8
end

function Encoding.to_buffer(self)
	local buf = buffer.create(402)
	local off = 0
	for color = WHITE, BLACK do
		for piece = PAWN, KING do
			off = writeBB(buf, off, self.pieces_lo[color * PIECE_STRIDE + piece], self.pieces_hi[color * PIECE_STRIDE + piece])
		end
	end
	for square = 0, 63 do
		local val = self.pieceTable[square]
		if val then
			local a, b = split_pair(val)
			buffer.writeu8(buf, off, bit32.bor(bit32.lshift(a, 4), b))
		else
			buffer.writeu8(buf, off, U8_MAX)
		end
		off += 1
	end
	for color = WHITE, BLACK do
		for piece = PAWN, KING do
			off = writeBB(buf, off, self.attacked_lo[color * ATK_STRIDE + piece], self.attacked_hi[color * ATK_STRIDE + piece])
		end
		off = writeBB(buf, off, self.attacked_lo[color * ATK_STRIDE + ATTACKED_ALL], self.attacked_hi[color * ATK_STRIDE + ATTACKED_ALL])
	end
	off = writeBB(buf, off, self.occupied_lo[WHITE], self.occupied_hi[WHITE])
	off = writeBB(buf, off, self.occupied_lo[BLACK], self.occupied_hi[BLACK])
	off = writeBB(buf, off, self.occupied_lo[ALL],   self.occupied_hi[ALL])
	buffer.writeu8(buf, off, self.side_to_move);     off += 1
	buffer.writeu8(buf, off, self.castling_rights);  off += 1
	buffer.writeu8(buf, off, self.en_passant_square or EN_PASSANT_NONE); off += 1
	buffer.writeu16(buf, off, self.halfmove_clock);  off += 2
	buffer.writeu16(buf, off, self.fullmove_number); off += 2
	buffer.writef64(buf, off, self.eval);            off += 8
	buffer.writei32(buf, off, self.hash);            off += 4
	return buf
end

function Encoding.from_buffer(self, buf)
	local off = 0
	local lo, hi
	for color = WHITE, BLACK do
		for piece = PAWN, KING do
			lo, hi, off = readBB(buf, off)
			self.pieces_lo[color * PIECE_STRIDE + piece] = lo
			self.pieces_hi[color * PIECE_STRIDE + piece] = hi
		end
	end
	for square = 0, 63 do
		local val = buffer.readu8(buf, off); off += 1
		if val == U8_MAX then
			self.pieceTable[square] = nil
		else
			local b = bit32.band(val, 0xF)
			local a = bit32.rshift(val, 4)
			self.pieceTable[square] = make_pair(a, b)
		end
	end
	for color = WHITE, BLACK do
		for piece = PAWN, KING do
			lo, hi, off = readBB(buf, off)
			self.attacked_lo[color * ATK_STRIDE + piece] = lo
			self.attacked_hi[color * ATK_STRIDE + piece] = hi
		end
		lo, hi, off = readBB(buf, off)
		self.attacked_lo[color * ATK_STRIDE + ATTACKED_ALL] = lo
		self.attacked_hi[color * ATK_STRIDE + ATTACKED_ALL] = hi
	end
	lo, hi, off = readBB(buf, off); self.occupied_lo[WHITE] = lo; self.occupied_hi[WHITE] = hi
	lo, hi, off = readBB(buf, off); self.occupied_lo[BLACK] = lo; self.occupied_hi[BLACK] = hi
	lo, hi, off = readBB(buf, off); self.occupied_lo[ALL]   = lo; self.occupied_hi[ALL]   = hi
	self.side_to_move    = buffer.readu8(buf, off);  off += 1
	self.castling_rights = buffer.readu8(buf, off);  off += 1
	local ep = buffer.readu8(buf, off); off += 1
	self.en_passant_square = if ep == EN_PASSANT_NONE then nil else ep
	self.halfmove_clock  = buffer.readu16(buf, off); off += 2
	self.fullmove_number = buffer.readu16(buf, off); off += 2
	self.eval            = buffer.readf64(buf, off); off += 8
	self.hash            = buffer.readi32(buf, off); off += 4
	return self
end

return Encoding

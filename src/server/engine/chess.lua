-- ROBLOX upstream: chess.ts
--[[*
 * @license
 * Copyright (c) 2025, Jeff Hlywa (jhlywa@gmail.com)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 ]]
 local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
 local LuauPolyfill = TS.import(script, game:GetService("ReplicatedStorage"), "rbxts_include", "node_modules", "@rbxts", "luau-polyfill", "out")
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
local Map = LuauPolyfill.Map
local Object = LuauPolyfill.Object
local Set = LuauPolyfill.Set
local BigInt = function(x) return x end
type Array<T> = LuauPolyfill.Array<T>
type Object = LuauPolyfill.Object
type Partial<T> = T --[[ ROBLOX TODO: TS 'Partial' built-in type is not available in Luau ]]
type Record<K, T> = { [K]: T } --[[ ROBLOX TODO: TS 'Record' built-in type is not available in Luau ]]
local RegExp = require(script.Parent.regex)
local exports = {}
local parse = require(script.Parent.pgn).parse
local MASK64 = 0xffffffffffffffff
function split_by_whitespace(fen)
  local result = {}
  for part in string.gmatch(fen, "%S+") do
    table.insert(result, part)
  end
  return result
end
local function rotl(
	x: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]],
	k: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]]
): any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]]
	return bit32.band(
		bit32.bor(
			bit32.lshift(x, k), --[[ ROBLOX CHECK: `bit32.lshift` clamps arguments and result to [0,2^32 - 1] ]]
			bit32.arshift(x, 64 - k) --[[ ROBLOX CHECK: `bit32.arshift` clamps arguments and result to [0,2^32 - 1] ]]
		), --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
		0xffffffffffffffff
	) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
end
local function wrappingMul(
	x: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]],
	y: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]]
)
	return bit32.band(x * y, MASK64) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
end -- xoroshiro128**
local function xoroshiro128(
	state: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]]
)
	return function()
		local s0 = BigInt(
			bit32.band(state, MASK64) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
		local s1 = BigInt(
			bit32.band(
				bit32.arshift(state, 64), --[[ ROBLOX CHECK: `bit32.arshift` clamps arguments and result to [0,2^32 - 1] ]]
				MASK64
			) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
		local result = wrappingMul(rotl(wrappingMul(s0, 5), 7), 9)
		s1 = bit32.bxor(s1, s0) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
		s0 = bit32.band(
			bit32.bxor(
				bit32.bxor(rotl(s0, 24), s1), --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
				bit32.lshift(s1, 16) --[[ ROBLOX CHECK: `bit32.lshift` clamps arguments and result to [0,2^32 - 1] ]]
			), --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
			MASK64
		) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		s1 = rotl(s1, 37)
		state = bit32.bor(
			bit32.lshift(s1, 64), --[[ ROBLOX CHECK: `bit32.lshift` clamps arguments and result to [0,2^32 - 1] ]]
			s0
		) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
		return result
	end
end
exports.xoroshiro128 = xoroshiro128
local rand = xoroshiro128(0xa187eb39cdcaed8f31c4b365b102e01e)
local PIECE_KEYS = Array.from({ length = 2 }, function()
	return Array.from({ length = 6 }, function()
		return Array.from({ length = 128 }, function()
			return rand()
		end)
	end)
end)
local EP_KEYS = Array.from({ length = 8 }, function()
	return rand()
end)
local CASTLING_KEYS = Array.from({ length = 16 }, function()
	return rand()
end)
local SIDE_KEY = rand()
local WHITE = "w"
exports.WHITE = WHITE
local BLACK = "b"
exports.BLACK = BLACK
local PAWN = "p"
exports.PAWN = PAWN
local KNIGHT = "n"
exports.KNIGHT = KNIGHT
local BISHOP = "b"
exports.BISHOP = BISHOP
local ROOK = "r"
exports.ROOK = ROOK
local QUEEN = "q"
exports.QUEEN = QUEEN
local KING = "k"
exports.KING = KING
export type Color = "w" | "b"
export type PieceSymbol = "p" | "n" | "b" | "r" | "q" | "k" -- prettier-ignore
export type Square =
	"a8"
	| "b8"
	| "c8"
	| "d8"
	| "e8"
	| "f8"
	| "g8"
	| "h8"
	| "a7"
	| "b7"
	| "c7"
	| "d7"
	| "e7"
	| "f7"
	| "g7"
	| "h7"
	| "a6"
	| "b6"
	| "c6"
	| "d6"
	| "e6"
	| "f6"
	| "g6"
	| "h6"
	| "a5"
	| "b5"
	| "c5"
	| "d5"
	| "e5"
	| "f5"
	| "g5"
	| "h5"
	| "a4"
	| "b4"
	| "c4"
	| "d4"
	| "e4"
	| "f4"
	| "g4"
	| "h4"
	| "a3"
	| "b3"
	| "c3"
	| "d3"
	| "e3"
	| "f3"
	| "g3"
	| "h3"
	| "a2"
	| "b2"
	| "c2"
	| "d2"
	| "e2"
	| "f2"
	| "g2"
	| "h2"
	| "a1"
	| "b1"
	| "c1"
	| "d1"
	| "e1"
	| "f1"
	| "g1"
	| "h1"
local SUFFIX_LIST = { "!", "?", "!!", "!?", "?!", "??" } :: const
exports.SUFFIX_LIST = SUFFIX_LIST
export type Suffix = typeof((({} :: any) :: typeof(SUFFIX_LIST))[1]) --[[ ROBLOX CHECK: Resulting type may differ ]] --[[ Upstream: (typeof SUFFIX_LIST)[number] ]]
local DEFAULT_POSITION = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
exports.DEFAULT_POSITION = DEFAULT_POSITION
export type Piece = { color: Color, type: PieceSymbol }
type InternalMove = {
	color: Color,
	from: number,
	to: number,
	piece: PieceSymbol,
	captured: PieceSymbol?,
	promotion: PieceSymbol?,
	flags: number,
}
type History = {
	move: InternalMove,
	kings: Record<Color, number>,
	turn: Color,
	castling: Record<Color, number>,
	epSquare: number,
	fenEpSquare: number,
	halfMoves: number,
	moveNumber: number,
}
export type Move = {
	color: Color,
	from: Square,
	to: Square,
	piece: PieceSymbol,
	captured: PieceSymbol,
	promotion: PieceSymbol,
	--[[*
   * @deprecated This field is deprecated and will be removed in version 2.0.0.
   * Please use move descriptor functions instead: `isCapture`, `isPromotion`,
   * `isEnPassant`, `isKingsideCastle`, `isQueensideCastle`, `isCastle`, and
   * `isBigPawn`
   ]]
	flags: string,
	san: string,
	lan: string,
	before: string,
	after: string,
	isCapture: (self: Move) -> any,
	isPromotion: (self: Move) -> any,
	isEnPassant: (self: Move) -> any,
	isKingsideCastle: (self: Move) -> any,
	isQueensideCastle: (self: Move) -> any,
	isBigPawn: (self: Move) -> any,
	isNullMove: (self: Move) -> any,
}
type Move_statics = {
	new: (internal: InternalMove, san: string, before: string, after: string) -> Move,
}
local Move = {} :: Move & Move_statics;
(Move :: any).__index = Move
function Move.new(internal: InternalMove, san: string, before: string, after: string): Move
	local self = setmetatable({}, Move)
	local color, piece, from, to, flags, captured, promotion =
		internal.color,
		internal.piece,
		internal.from,
		internal.to,
		internal.flags,
		internal.captured,
		internal.promotion
	local fromAlgebraic = algebraic(from)
	local toAlgebraic = algebraic(to)
	self.color = color
	self.piece = piece
	self.from = fromAlgebraic
	self.to = toAlgebraic
	self.san = san
	self.lan = fromAlgebraic + toAlgebraic
	self.before = before
	self.after = after -- Build the text representation of the move flags
	self.flags = ""
	for flag in BITS do
		if
			Boolean.toJSBoolean(
				bit32.band(BITS[tostring(flag)], flags) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			)
		then
			self.flags += FLAGS[tostring(flag)]
		end
	end
	if Boolean.toJSBoolean(captured) then
		self.captured = captured
	end
	if Boolean.toJSBoolean(promotion) then
		self.promotion = promotion
		self.lan += promotion
	end
	return (self :: any) :: Move
end
function Move:isCapture()
	return Array.indexOf(self.flags, FLAGS["CAPTURE"]) --[[ ROBLOX CHECK: check if 'this.flags' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
end
function Move:isPromotion()
	return Array.indexOf(self.flags, FLAGS["PROMOTION"]) --[[ ROBLOX CHECK: check if 'this.flags' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
end
function Move:isEnPassant()
	return Array.indexOf(self.flags, FLAGS["EP_CAPTURE"]) --[[ ROBLOX CHECK: check if 'this.flags' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
end
function Move:isKingsideCastle()
	return Array.indexOf(self.flags, FLAGS["KSIDE_CASTLE"]) --[[ ROBLOX CHECK: check if 'this.flags' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
end
function Move:isQueensideCastle()
	return Array.indexOf(self.flags, FLAGS["QSIDE_CASTLE"]) --[[ ROBLOX CHECK: check if 'this.flags' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
end
function Move:isBigPawn()
	return Array.indexOf(self.flags, FLAGS["BIG_PAWN"]) --[[ ROBLOX CHECK: check if 'this.flags' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
end
function Move:isNullMove()
	return Array.indexOf(self.flags, FLAGS["NULL_MOVE"]) --[[ ROBLOX CHECK: check if 'this.flags' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
end
exports.Move = Move
local EMPTY = -1
local FLAGS: Record<string, string> = {
	NORMAL = "n",
	CAPTURE = "c",
	BIG_PAWN = "b",
	EP_CAPTURE = "e",
	PROMOTION = "p",
	KSIDE_CASTLE = "k",
	QSIDE_CASTLE = "q",
	NULL_MOVE = "-",
} -- prettier-ignore
local SQUARES: Array<Square> = {
	"a8",
	"b8",
	"c8",
	"d8",
	"e8",
	"f8",
	"g8",
	"h8",
	"a7",
	"b7",
	"c7",
	"d7",
	"e7",
	"f7",
	"g7",
	"h7",
	"a6",
	"b6",
	"c6",
	"d6",
	"e6",
	"f6",
	"g6",
	"h6",
	"a5",
	"b5",
	"c5",
	"d5",
	"e5",
	"f5",
	"g5",
	"h5",
	"a4",
	"b4",
	"c4",
	"d4",
	"e4",
	"f4",
	"g4",
	"h4",
	"a3",
	"b3",
	"c3",
	"d3",
	"e3",
	"f3",
	"g3",
	"h3",
	"a2",
	"b2",
	"c2",
	"d2",
	"e2",
	"f2",
	"g2",
	"h2",
	"a1",
	"b1",
	"c1",
	"d1",
	"e1",
	"f1",
	"g1",
	"h1",
}
exports.SQUARES = SQUARES
local BITS: Record<string, number> = {
	NORMAL = 1,
	CAPTURE = 2,
	BIG_PAWN = 4,
	EP_CAPTURE = 8,
	PROMOTION = 16,
	KSIDE_CASTLE = 32,
	QSIDE_CASTLE = 64,
	NULL_MOVE = 128,
}
--[[ eslint-disable @typescript-eslint/naming-convention ]]
-- these are required, according to spec
local SEVEN_TAG_ROSTER: Record<string, string> = {
	Event = "?",
	Site = "?",
	Date = "????.??.??",
	Round = "?",
	White = "?",
	Black = "?",
	Result = "*",
}
exports.SEVEN_TAG_ROSTER = SEVEN_TAG_ROSTER
--[[*
 * These nulls are placeholders to fix the order of tags (as they appear in PGN spec); null values will be
 * eliminated in getHeaders()
 ]]
local SUPLEMENTAL_TAGS: Record<string, string | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]> =
	{
		WhiteTitle = nil,
		BlackTitle = nil,
		WhiteElo = nil,
		BlackElo = nil,
		WhiteUSCF = nil,
		BlackUSCF = nil,
		WhiteNA = nil,
		BlackNA = nil,
		WhiteType = nil,
		BlackType = nil,
		EventDate = nil,
		EventSponsor = nil,
		Section = nil,
		Stage = nil,
		Board = nil,
		Opening = nil,
		Variation = nil,
		SubVariation = nil,
		ECO = nil,
		NIC = nil,
		Time = nil,
		UTCTime = nil,
		UTCDate = nil,
		TimeControl = nil,
		SetUp = nil,
		FEN = nil,
		Termination = nil,
		Annotator = nil,
		Mode = nil,
		PlyCount = nil,
	}
local HEADER_TEMPLATE = Object.assign({}, SEVEN_TAG_ROSTER, SUPLEMENTAL_TAGS)
--[[ eslint-enable @typescript-eslint/naming-convention ]]
--[[
 * NOTES ABOUT 0x88 MOVE GENERATION ALGORITHM
 * ----------------------------------------------------------------------------
 * From https://github.com/jhlywa/chess.js/issues/230
 *
 * A lot of people are confused when they first see the internal representation
 * of chess.js. It uses the 0x88 Move Generation Algorithm which internally
 * stores the board as an 8x16 array. This is purely for efficiency but has a
 * couple of interesting benefits:
 *
 * 1. 0x88 offers a very inexpensive "off the board" check. Bitwise AND (&) any
 *    square with 0x88, if the result is non-zero then the square is off the
 *    board. For example, assuming a knight square A8 (0 in 0x88 notation),
 *    there are 8 possible directions in which the knight can move. These
 *    directions are relative to the 8x16 board and are stored in the
 *    PIECE_OFFSETS map. One possible move is A8 - 18 (up one square, and two
 *    squares to the left - which is off the board). 0 - 18 = -18 & 0x88 = 0x88
 *    (because of two-complement representation of -18). The non-zero result
 *    means the square is off the board and the move is illegal. Take the
 *    opposite move (from A8 to C7), 0 + 18 = 18 & 0x88 = 0. A result of zero
 *    means the square is on the board.
 *
 * 2. The relative distance (or difference) between two squares on a 8x16 board
 *    is unique and can be used to inexpensively determine if a piece on a
 *    square can attack any other arbitrary square. For example, let's see if a
 *    pawn on E7 can attack E2. The difference between E7 (20) - E2 (100) is
 *    -80. We add 119 to make the ATTACKS array index non-negative (because the
 *    worst case difference is A8 - H1 = -119). The ATTACKS array contains a
 *    bitmask of pieces that can attack from that distance and direction.
 *    ATTACKS[-80 + 119=39] gives us 24 or 0b11000 in binary. Look at the
 *    PIECE_MASKS map to determine the mask for a given piece type. In our pawn
 *    example, we would check to see if 24 & 0x1 is non-zero, which it is
 *    not. So, naturally, a pawn on E7 can't attack a piece on E2. However, a
 *    rook can since 24 & 0x8 is non-zero. The only thing left to check is that
 *    there are no blocking pieces between E7 and E2. That's where the RAYS
 *    array comes in. It provides an offset (in this case 16) to add to E7 (20)
 *    to check for blocking pieces. E7 (20) + 16 = E6 (36) + 16 = E5 (52) etc.
 ]]
-- prettier-ignore
-- eslint-disable-next-line
local Ox88: Record<Square, number> = {
	a8 = 0,
	b8 = 1,
	c8 = 2,
	d8 = 3,
	e8 = 4,
	f8 = 5,
	g8 = 6,
	h8 = 7,
	a7 = 16,
	b7 = 17,
	c7 = 18,
	d7 = 19,
	e7 = 20,
	f7 = 21,
	g7 = 22,
	h7 = 23,
	a6 = 32,
	b6 = 33,
	c6 = 34,
	d6 = 35,
	e6 = 36,
	f6 = 37,
	g6 = 38,
	h6 = 39,
	a5 = 48,
	b5 = 49,
	c5 = 50,
	d5 = 51,
	e5 = 52,
	f5 = 53,
	g5 = 54,
	h5 = 55,
	a4 = 64,
	b4 = 65,
	c4 = 66,
	d4 = 67,
	e4 = 68,
	f4 = 69,
	g4 = 70,
	h4 = 71,
	a3 = 80,
	b3 = 81,
	c3 = 82,
	d3 = 83,
	e3 = 84,
	f3 = 85,
	g3 = 86,
	h3 = 87,
	a2 = 96,
	b2 = 97,
	c2 = 98,
	d2 = 99,
	e2 = 100,
	f2 = 101,
	g2 = 102,
	h2 = 103,
	a1 = 112,
	b1 = 113,
	c1 = 114,
	d1 = 115,
	e1 = 116,
	f1 = 117,
	g1 = 118,
	h1 = 119,
}
local PAWN_OFFSETS = { b = { 16, 32, 17, 15 }, w = { -16, -32, -17, -15 } }
local PIECE_OFFSETS = {
	n = { -18, -33, -31, -14, 18, 33, 31, 14 },
	b = { -17, -15, 17, 15 },
	r = { -16, 1, 16, -1 },
	q = { -17, -16, -15, 1, 17, 16, 15, -1 },
	k = { -17, -16, -15, 1, 17, 16, 15, -1 },
} -- prettier-ignore
local ATTACKS = {
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	24,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	0,
	24,
	0,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	24,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	24,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	24,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
	2,
	24,
	2,
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	2,
	53,
	56,
	53,
	2,
	0,
	0,
	0,
	0,
	0,
	0,
	24,
	24,
	24,
	24,
	24,
	24,
	56,
	0,
	56,
	24,
	24,
	24,
	24,
	24,
	24,
	0,
	0,
	0,
	0,
	0,
	0,
	2,
	53,
	56,
	53,
	2,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
	2,
	24,
	2,
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	24,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	24,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	24,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	0,
	24,
	0,
	0,
	0,
	0,
	0,
	20,
	0,
	0,
	20,
	0,
	0,
	0,
	0,
	0,
	0,
	24,
	0,
	0,
	0,
	0,
	0,
	0,
	20,
} -- prettier-ignore
local RAYS = {
	17,
	0,
	0,
	0,
	0,
	0,
	0,
	16,
	0,
	0,
	0,
	0,
	0,
	0,
	15,
	0,
	0,
	17,
	0,
	0,
	0,
	0,
	0,
	16,
	0,
	0,
	0,
	0,
	0,
	15,
	0,
	0,
	0,
	0,
	17,
	0,
	0,
	0,
	0,
	16,
	0,
	0,
	0,
	0,
	15,
	0,
	0,
	0,
	0,
	0,
	0,
	17,
	0,
	0,
	0,
	16,
	0,
	0,
	0,
	15,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	17,
	0,
	0,
	16,
	0,
	0,
	15,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	17,
	0,
	16,
	0,
	15,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	17,
	16,
	15,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	0,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	-15,
	-16,
	-17,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	-15,
	0,
	-16,
	0,
	-17,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	-15,
	0,
	0,
	-16,
	0,
	0,
	-17,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	-15,
	0,
	0,
	0,
	-16,
	0,
	0,
	0,
	-17,
	0,
	0,
	0,
	0,
	0,
	0,
	-15,
	0,
	0,
	0,
	0,
	-16,
	0,
	0,
	0,
	0,
	-17,
	0,
	0,
	0,
	0,
	-15,
	0,
	0,
	0,
	0,
	0,
	-16,
	0,
	0,
	0,
	0,
	0,
	-17,
	0,
	0,
	-15,
	0,
	0,
	0,
	0,
	0,
	0,
	-16,
	0,
	0,
	0,
	0,
	0,
	0,
	-17,
}
local PIECE_MASKS = { p = 0x1, n = 0x2, b = 0x4, r = 0x8, q = 0x10, k = 0x20 }
local SYMBOLS = "pnbrqkPNBRQK"
local PROMOTIONS: Array<PieceSymbol> = { KNIGHT, BISHOP, ROOK, QUEEN }
local RANK_1 = 7
local RANK_2 = 6
--[[
 * const RANK_3 = 5
 * const RANK_4 = 4
 * const RANK_5 = 3
 * const RANK_6 = 2
 ]]
local RANK_7 = 1
local RANK_8 = 0
local SIDES = { [tostring(KING)] = BITS.KSIDE_CASTLE, [tostring(QUEEN)] = BITS.QSIDE_CASTLE }
local ROOKS = {
	w = {
		{ square = Ox88.a1, flag = BITS.QSIDE_CASTLE },
		{ square = Ox88.h1, flag = BITS.KSIDE_CASTLE },
	},
	b = {
		{ square = Ox88.a8, flag = BITS.QSIDE_CASTLE },
		{ square = Ox88.h8, flag = BITS.KSIDE_CASTLE },
	},
}
local SECOND_RANK = { b = RANK_7, w = RANK_2 }
local SAN_NULLMOVE = "--" -- Extracts the zero-based rank of an 0x88 square.
local function rank(square: number): number
	return bit32.arshift(square, 4) --[[ ROBLOX CHECK: `bit32.arshift` clamps arguments and result to [0,2^32 - 1] ]]
end -- Extracts the zero-based file of an 0x88 square.
local function file(square: number): number
	return bit32.band(square, 0xf) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
end
local function isDigit(c: string): boolean
	return Array.indexOf("0123456789", c) --[[ ROBLOX CHECK: check if '"0123456789"' is an Array ]]
		~= -1
end -- Converts a 0x88 square to algebraic notation.
local function algebraic(square: number): Square
	local f = file(square)
	local r = rank(square)
	return ("abcdefgh"):substring(f, f + 1) + ("87654321"):substring(r, r + 1) :: Square
end
local function swapColor(color: Color): Color
	return if color == WHITE then BLACK else WHITE
end
local function validateFen(fen: string): { ok: boolean, error: string? }
	-- 1st criterion: 6 space-seperated fields?
	local tokens = split_by_whitespace(fen)
	if #tokens ~= 6 then
		return { ok = false, error = "Invalid FEN: must contain six space-delimited fields" }
	end -- 2nd criterion: move number field is a integer value > 0?
	local moveNumber = tonumber(
		tokens[
			6 --[[ ROBLOX adaptation: added 1 to array index ]]
		],
		10
	)
	if
		Boolean.toJSBoolean((function()
			local ref = tonumber(moveNumber) == nil
			return Boolean.toJSBoolean(ref) and ref or moveNumber <= 0 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		end)())
	then
		return { ok = false, error = "Invalid FEN: move number must be a positive integer" }
	end -- 3rd criterion: half move counter is an integer >= 0?
	local halfMoves = tonumber(
		tokens[
			5 --[[ ROBLOX adaptation: added 1 to array index ]]
		],
		10
	)
	if
		Boolean.toJSBoolean((function()
			local ref = tonumber(halfMoves) == nil
			return Boolean.toJSBoolean(ref) and ref or halfMoves < 0 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		end)())
	then
		return {
			ok = false,
			error = "Invalid FEN: half move counter number must be a non-negative integer",
		}
	end -- 4th criterion: 4th field is a valid e.p.-string?
	if
		not Boolean.toJSBoolean(RegExp("^(-|[abcdefgh][36])$"):test(tokens[
			4 --[[ ROBLOX adaptation: added 1 to array index ]]
		]))
	then
		return { ok = false, error = "Invalid FEN: en-passant square is invalid" }
	end -- 5th criterion: 3th field is a valid castle-string?
	if
		Boolean.toJSBoolean(RegExp("[^kKqQ-]"):test(tokens[
			3 --[[ ROBLOX adaptation: added 1 to array index ]]
		]))
	then
		return { ok = false, error = "Invalid FEN: castling availability is invalid" }
	end -- 6th criterion: 2nd field is "w" (white) or "b" (black)?
	if
		not Boolean.toJSBoolean(RegExp("^(w|b)$"):test(tokens[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]))
	then
		return { ok = false, error = "Invalid FEN: side-to-move is invalid" }
	end -- 7th criterion: 1st field contains 8 rows?
	local rows = tokens[
		1 --[[ ROBLOX adaptation: added 1 to array index ]]
	]:split("/")
	if #rows ~= 8 then
		return {
			ok = false,
			error = "Invalid FEN: piece data does not contain 8 '/'-delimited rows",
		}
	end -- 8th criterion: every row is valid?
	do
		local i = 0
		while
			i
			< #rows --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			-- check for right sum of fields AND not two numbers in succession
			local sumFields = 0
			local previousWasNumber = false
			do
				local k = 0
				while
					k
					< #rows[i+1] --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
				do
					if Boolean.toJSBoolean(isDigit(rows[i+1][tostring(k)])) then
						if Boolean.toJSBoolean(previousWasNumber) then
							return {
								ok = false,
								error = "Invalid FEN: piece data is invalid (consecutive number)",
							}
						end
						print(rows[i+1][k])
						sumFields += tonumber(rows[i+1][(k)])
						previousWasNumber = true
					else
						if
							not Boolean.toJSBoolean(
								RegExp("^[prnbqkPRNBQK]$"):test(rows[i+1][tostring(k)])
							)
						then
							return {
								ok = false,
								error = "Invalid FEN: piece data is invalid (invalid piece)",
							}
						end
						sumFields += 1
						previousWasNumber = false
					end
					k += 1
				end
			end
			if sumFields ~= 8 then
				return {
					ok = false,
					error = "Invalid FEN: piece data is invalid (too many squares in rank)",
				}
			end
			i += 1
		end
	end -- 9th criterion: is en-passant square legal?
	if
		tokens[
					4 --[[ ROBLOX adaptation: added 1 to array index ]]
				][
					2 --[[ ROBLOX adaptation: added 1 to array index ]]
				]
				== "3" --[[ ROBLOX CHECK: loose equality used upstream ]]
			and tokens[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			] == "w" --[[ ROBLOX CHECK: loose equality used upstream ]]
		or tokens[
					4 --[[ ROBLOX adaptation: added 1 to array index ]]
				][
					2 --[[ ROBLOX adaptation: added 1 to array index ]]
				]
				== "6" --[[ ROBLOX CHECK: loose equality used upstream ]]
			and tokens[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			] == "b" --[[ ROBLOX CHECK: loose equality used upstream ]]
	then
		return { ok = false, error = "Invalid FEN: illegal en-passant square" }
	end -- 10th criterion: does chess position contain exact two kings?
	local kings = {
		{
			color = "white",
			regex = RegExp("K", "g"),--[[ ROBLOX NOTE: global flag is not implemented yet ]]
		},
		{
			color = "black",
			regex = RegExp("k", "g"),--[[ ROBLOX NOTE: global flag is not implemented yet ]]
		},
	}
	for _, ref in kings do
		local color, regex = ref.color, ref.regex
		if
			not Boolean.toJSBoolean(regex:test(tokens[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]))
		then
			return { ok = false, error = ("Invalid FEN: missing %s king"):format(tostring(color)) }
		end
		if
			(function()
				local ref = tokens[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				]:match(regex)
				return Boolean.toJSBoolean(ref) and ref or {}
			end)().length
			> 1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			return { ok = false, error = ("Invalid FEN: too many %s kings"):format(tostring(color)) }
		end
	end -- 11th criterion: are any pawns on the first or eighth rows?
	if
		Boolean.toJSBoolean(Array.some(
			Array.from(rows[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			] + rows[
				8 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			function(char)
				return char:toUpperCase() == "P"
			end
		) --[[ ROBLOX CHECK: check if 'Array.from(rows[0] + rows[7])' is an Array ]])
	then
		return { ok = false, error = "Invalid FEN: some pawns are on the edge rows" }
	end
	return { ok = true }
end
exports.validateFen = validateFen -- this function is used to uniquely identify ambiguous moves
local function getDisambiguator(move: InternalMove, moves: Array<InternalMove>): string
	local from = move.from
	local to = move.to
	local piece = move.piece
	local ambiguities = 0
	local sameRank = 0
	local sameFile = 0
	do
		local i, len = 0, moves.length
		while
			i
			< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local ambigFrom = moves[tostring(i)].from
			local ambigTo = moves[tostring(i)].to
			local ambigPiece = moves[tostring(i)].piece
			--[[
     * if a move of the same piece type ends on the same to square, we'll need
     * to add a disambiguator to the algebraic notation
     ]]
			if piece == ambigPiece and from ~= ambigFrom and to == ambigTo then
				ambiguities += 1
				if rank(from) == rank(ambigFrom) then
					sameRank += 1
				end
				if file(from) == file(ambigFrom) then
					sameFile += 1
				end
			end
			i += 1
		end
	end
	if
		ambiguities
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		if
			sameRank > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			and sameFile > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			--[[
       * if there exists a similar moving piece on the same rank and file as
       * the move in question, use the square as the disambiguator
       ]]
			return algebraic(from)
		elseif
			sameFile
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			--[[
       * if the moving piece rests on the same file, use the rank symbol as the
       * disambiguator
       ]]
			return algebraic(from):charAt(1)
		else
			-- else use the file symbol
			return algebraic(from):charAt(0)
		end
	end
	return ""
end
local function addMove(
	moves: Array<InternalMove>,
	color: Color,
	from: number,
	to: number,
	piece: PieceSymbol,
	captured_: (PieceSymbol | nil)?,
	flags_: number?
)
	local captured: PieceSymbol | nil = if captured_ ~= nil then captured_ else nil
	local flags: number = if flags_ ~= nil then flags_ else BITS.NORMAL
	local r = rank(to)
	if piece == PAWN and (r == RANK_1 or r == RANK_8) then
		do
			local i = 0
			while
				i
				< PROMOTIONS.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				local promotion = PROMOTIONS[tostring(i)]
				table.insert(moves, {
					color = color,
					from = from,
					to = to,
					piece = piece,
					captured = captured,
					promotion = promotion,
					flags = bit32.bor(flags, BITS.PROMOTION),--[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
				}) --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
				i += 1
			end
		end
	else
		table.insert(moves, {
			color = color,
			from = from,
			to = to,
			piece = piece,
			captured = captured,
			flags = flags,
		}) --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
	end
end
local function inferPieceType(san: string): PieceSymbol | nil
	local pieceType = san:charAt(0)
	if
		pieceType >= "a" --[[ ROBLOX CHECK: operator '>=' works only if either both arguments are strings or both are a number ]]
		and pieceType <= "h" --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
	then
		local matches = san:match(RegExp("[a-h]\\d.*[a-h]\\d"))
		if Boolean.toJSBoolean(matches) then
			return nil
		end
		return PAWN
	end
	pieceType = pieceType:toLowerCase()
	if pieceType == "o" then
		return KING
	end
	return pieceType :: PieceSymbol
end -- parses all of the decorators out of a SAN string
local function strippedSan(move: string): string
	return move:replace(RegExp("="), ""):replace(RegExp("[+#]?[?!]*$"), "")
end
export type Chess = {
	clear: (self: Chess, ref0_: Object?) -> any,
	load: (self: Chess, fen: string, ref0_: Object?) -> any,
	fen: (self: Chess, ref0_: { forceEnpassantSquare: boolean? }?) -> any,
	reset: (self: Chess) -> any,
	get: (self: Chess, square: Square) -> Piece | nil,
	findPiece: (self: Chess, piece: Piece) -> Array<Square>,
	put: (self: Chess, ref0: { type: PieceSymbol, color: Color }, square: Square) -> boolean,
	remove: (self: Chess, square: Square) -> Piece | nil,
	attackers: (self: Chess, square: Square, attackedBy: Color?) -> Array<Square>,
	hash: (self: Chess) -> string,
	isAttacked: (self: Chess, square: Square, attackedBy: Color) -> boolean,
	isCheck: (self: Chess) -> boolean,
	inCheck: (self: Chess) -> boolean,
	isCheckmate: (self: Chess) -> boolean,
	isStalemate: (self: Chess) -> boolean,
	isInsufficientMaterial: (self: Chess) -> boolean,
	isThreefoldRepetition: (self: Chess) -> boolean,
	isDrawByFiftyMoves: (self: Chess) -> boolean,
	isDraw: (self: Chess) -> boolean,
	isGameOver: (self: Chess) -> boolean,
	isPromotion: (self: Chess, ref0: { from: Square, to: Square }) -> boolean,
	moves: (self: Chess) -> Array<string>,
	moves: (self: Chess, ref0: { square: Square }) -> Array<string>,
	moves: (self: Chess, ref0: { piece: PieceSymbol }) -> Array<string>,
	moves: (self: Chess, ref0: { square: Square, piece: PieceSymbol }) -> Array<string>,
	moves: (self: Chess, ref0: { verbose: true, square: Square? }) -> Array<Move>,
	moves: (self: Chess, ref0: { verbose: false, square: Square? }) -> Array<string>,
	moves: (
		self: Chess,
		ref0: { verbose: boolean?, square: Square? }
	) -> Array<string> | Array<Move>,
	moves: (self: Chess, ref0: { verbose: true, piece: PieceSymbol? }) -> Array<Move>,
	moves: (self: Chess, ref0: { verbose: false, piece: PieceSymbol? }) -> Array<string>,
	moves: (
		self: Chess,
		ref0: { verbose: boolean?, piece: PieceSymbol? }
	) -> Array<string> | Array<Move>,
	moves: (
		self: Chess,
		ref0: { verbose: true, square: Square?, piece: PieceSymbol? }
	) -> Array<Move>,
	moves: (
		self: Chess,
		ref0: { verbose: false, square: Square?, piece: PieceSymbol? }
	) -> Array<string>,
	moves: (
		self: Chess,
		ref0: { verbose: boolean?, square: Square?, piece: PieceSymbol? }
	) -> Array<string> | Array<Move>,
	moves: (self: Chess, ref0: { square: Square?, piece: PieceSymbol? }) -> Array<Move>,
	moves: (
		self: Chess,
		ref0_: { verbose: boolean?, square: Square?, piece: PieceSymbol? }?
	) -> any,
	move: (
		self: Chess,
		move: string | { from: string, to: string, promotion: string? } | nil, --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
		ref0_: { strict: boolean? }?
	) -> Move,
	undo: (self: Chess) -> Move | nil,--[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	pgn: (self: Chess, ref0_: { newline: string?, maxWidth: number? }?) -> string,
	--[[*
   * @deprecated Use `setHeader` and `getHeaders` instead. This method will return null header tags (which is not what you want)
   ]]
	header: (
		self: Chess,
		...string
	) -> Record<string, string | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]>, -- TODO: value validation per spec
	setHeader: (self: Chess, key: string, value: string) -> Record<string, string>,
	removeHeader: (self: Chess, key: string) -> boolean, -- return only non-null headers (omit placemarker nulls)
	getHeaders: (self: Chess) -> Record<string, string>,
	loadPgn: (self: Chess, pgn: string, ref0_: { strict: boolean?, newlineChar: string? }?) -> any,
	--[[
   * Convert a move from 0x88 coordinates to Standard Algebraic Notation
   * (SAN)
   *
   * @param {boolean} strict Use the strict SAN parser. It will throw errors
   * on overly disambiguated moves (see below):
   *
   * r1bqkbnr/ppp2ppp/2n5/1B1pP3/4P3/8/PPPP2PP/RNBQK1NR b KQkq - 2 4
   * 4. ... Nge7 is overly disambiguated because the knight on c6 is pinned
   * 4. ... Ne7 is technically the valid SAN
   ]]
	ascii: (self: Chess) -> string,
	perft: (self: Chess, depth: number) -> number,
	setTurn: (self: Chess, color: Color) -> boolean,
	turn: (self: Chess) -> Color,
	board: (
		self: Chess
	) -> Array<Array<{ square: Square, type: PieceSymbol, color: Color } | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]>>,
	squareColor: (self: Chess, square: Square) -> "light" | "dark" | nil,--[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	history: (self: Chess) -> Array<string>,
	history: (self: Chess, ref0: { verbose: true }) -> Array<Move>,
	history: (self: Chess, ref0: { verbose: false }) -> Array<string>,
	history: (self: Chess, ref0: { verbose: boolean }) -> Array<string> | Array<Move>,
	history: (self: Chess, ref0_: { verbose: boolean? }?) -> any,
	--[[
   * Keeps track of position occurrence counts for the purpose of repetition
   * checking. Old positions are removed from the map if their counts are reduced to 0.
   ]]
	getComment: (self: Chess) -> string,
	setComment: (self: Chess, comment: string) -> any,
	--[[*
   * @deprecated Renamed to `removeComment` for consistency
   ]]
	deleteComment: (self: Chess) -> string,
	removeComment: (self: Chess) -> string,
	getComments: (
		self: Chess
	) -> Array<{ fen: string, comment: string?, suffixAnnotation: string? }>,
	--[[*
   * Get the suffix annotation for the given position (or current one).
   ]]
	getSuffixAnnotation: (self: Chess, fen: string?) -> Suffix | nil,
	--[[*
   * Set or overwrite the suffix annotation for the given position (or current).
   * Throws if the suffix isn't one of the allowed SUFFIX_LIST values.
   ]]
	setSuffixAnnotation: (self: Chess, suffix: Suffix, fen: string?) -> (),
	--[[*
   * Remove the suffix annotation for the given position (or current).
   ]]
	removeSuffixAnnotation: (self: Chess, fen: string?) -> Suffix | nil,
	--[[*
   * @deprecated Renamed to `removeComments` for consistency
   ]]
	deleteComments: (self: Chess) -> Array<{ fen: string, comment: string }>,
	removeComments: (self: Chess) -> Array<{ fen: string, comment: string }>,
	setCastlingRights: (
		self: Chess,
		color: Color,
		rights: Partial<Record<typeof(KING) | typeof(QUEEN), boolean>>
	) -> boolean,
	getCastlingRights: (self: Chess, color: Color) -> { KING: boolean, QUEEN: boolean },
	moveNumber: (self: Chess) -> number,
}
type Chess_private = { --
	-- *** PUBLIC ***
	--
	clear: (self: Chess_private, ref0_: Object?) -> any,
	load: (self: Chess_private, fen: string, ref0_: Object?) -> any,
	fen: (self: Chess_private, ref0_: { forceEnpassantSquare: boolean? }?) -> any,
	reset: (self: Chess_private) -> any,
	get: (self: Chess_private, square: Square) -> Piece | nil,
	findPiece: (self: Chess_private, piece: Piece) -> Array<Square>,
	put: (
		self: Chess_private,
		ref0: { type: PieceSymbol, color: Color },
		square: Square
	) -> boolean,
	remove: (self: Chess_private, square: Square) -> Piece | nil,
	attackers: (self: Chess_private, square: Square, attackedBy: Color?) -> Array<Square>,
	hash: (self: Chess_private) -> string,
	isAttacked: (self: Chess_private, square: Square, attackedBy: Color) -> boolean,
	isCheck: (self: Chess_private) -> boolean,
	inCheck: (self: Chess_private) -> boolean,
	isCheckmate: (self: Chess_private) -> boolean,
	isStalemate: (self: Chess_private) -> boolean,
	isInsufficientMaterial: (self: Chess_private) -> boolean,
	isThreefoldRepetition: (self: Chess_private) -> boolean,
	isDrawByFiftyMoves: (self: Chess_private) -> boolean,
	isDraw: (self: Chess_private) -> boolean,
	isGameOver: (self: Chess_private) -> boolean,
	isPromotion: (self: Chess_private, ref0: { from: Square, to: Square }) -> boolean,
	moves: (self: Chess_private) -> Array<string>,
	moves: (self: Chess_private, ref0: { square: Square }) -> Array<string>,
	moves: (self: Chess_private, ref0: { piece: PieceSymbol }) -> Array<string>,
	moves: (self: Chess_private, ref0: { square: Square, piece: PieceSymbol }) -> Array<string>,
	moves: (self: Chess_private, ref0: { verbose: true, square: Square? }) -> Array<Move>,
	moves: (self: Chess_private, ref0: { verbose: false, square: Square? }) -> Array<string>,
	moves: (
		self: Chess_private,
		ref0: { verbose: boolean?, square: Square? }
	) -> Array<string> | Array<Move>,
	moves: (self: Chess_private, ref0: { verbose: true, piece: PieceSymbol? }) -> Array<Move>,
	moves: (self: Chess_private, ref0: { verbose: false, piece: PieceSymbol? }) -> Array<string>,
	moves: (
		self: Chess_private,
		ref0: { verbose: boolean?, piece: PieceSymbol? }
	) -> Array<string> | Array<Move>,
	moves: (
		self: Chess_private,
		ref0: { verbose: true, square: Square?, piece: PieceSymbol? }
	) -> Array<Move>,
	moves: (
		self: Chess_private,
		ref0: { verbose: false, square: Square?, piece: PieceSymbol? }
	) -> Array<string>,
	moves: (
		self: Chess_private,
		ref0: { verbose: boolean?, square: Square?, piece: PieceSymbol? }
	) -> Array<string> | Array<Move>,
	moves: (self: Chess_private, ref0: { square: Square?, piece: PieceSymbol? }) -> Array<Move>,
	moves: (
		self: Chess_private,
		ref0_: { verbose: boolean?, square: Square?, piece: PieceSymbol? }?
	) -> any,
	move: (
		self: Chess_private,
		move: string | { from: string, to: string, promotion: string? } | nil, --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
		ref0_: { strict: boolean? }?
	) -> Move,
	undo: (self: Chess_private) -> Move | nil,--[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	pgn: (self: Chess_private, ref0_: { newline: string?, maxWidth: number? }?) -> string,
	header: (
		self: Chess_private,
		...string
	) -> Record<string, string | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]>,
	setHeader: (self: Chess_private, key: string, value: string) -> Record<string, string>,
	removeHeader: (self: Chess_private, key: string) -> boolean,
	getHeaders: (self: Chess_private) -> Record<string, string>,
	loadPgn: (
		self: Chess_private,
		pgn: string,
		ref0_: { strict: boolean?, newlineChar: string? }?
	) -> any,
	ascii: (self: Chess_private) -> string,
	perft: (self: Chess_private, depth: number) -> number,
	setTurn: (self: Chess_private, color: Color) -> boolean,
	turn: (self: Chess_private) -> Color,
	board: (
		self: Chess_private
	) -> Array<Array<{ square: Square, type: PieceSymbol, color: Color } | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]>>,
	squareColor: (self: Chess_private, square: Square) -> "light" | "dark" | nil,--[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	history: (self: Chess_private) -> Array<string>,
	history: (self: Chess_private, ref0: { verbose: true }) -> Array<Move>,
	history: (self: Chess_private, ref0: { verbose: false }) -> Array<string>,
	history: (self: Chess_private, ref0: { verbose: boolean }) -> Array<string> | Array<Move>,
	history: (self: Chess_private, ref0_: { verbose: boolean? }?) -> any,
	getComment: (self: Chess_private) -> string,
	setComment: (self: Chess_private, comment: string) -> any,
	deleteComment: (self: Chess_private) -> string,
	removeComment: (self: Chess_private) -> string,
	getComments: (
		self: Chess_private
	) -> Array<{ fen: string, comment: string?, suffixAnnotation: string? }>,
	getSuffixAnnotation: (self: Chess_private, fen: string?) -> Suffix | nil,
	setSuffixAnnotation: (self: Chess_private, suffix: Suffix, fen: string?) -> (),
	removeSuffixAnnotation: (self: Chess_private, fen: string?) -> Suffix | nil,
	deleteComments: (self: Chess_private) -> Array<{ fen: string, comment: string }>,
	removeComments: (self: Chess_private) -> Array<{ fen: string, comment: string }>,
	setCastlingRights: (
		self: Chess_private,
		color: Color,
		rights: Partial<Record<typeof(KING) | typeof(QUEEN), boolean>>
	) -> boolean,
	getCastlingRights: (self: Chess_private, color: Color) -> { KING: boolean, QUEEN: boolean },
	moveNumber: (self: Chess_private) -> number,
	--
	-- *** PRIVATE ***
	--
	_board: any,
	_turn: Color,
	_header: Record<string, string | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]>,
	_kings: Record<Color, number>,
	_epSquare: any,
	_fenEpSquare: any,
	_halfMoves: number,
	_moveNumber: number,
	_history: Array<History>,
	_comments: Record<string, string>,
	_suffixes: Record<string, Suffix>,
	_castling: Record<Color, number>,
	_hash: any, -- tracks number of times a position has been seen for repetition checking
	_positionCount: any,
	_pieceKey: (self: Chess_private, i: number) -> any,
	_epKey: (self: Chess_private) -> any,
	_castlingKey: (self: Chess_private) -> any,
	_computeHash: (self: Chess_private) -> any,
	--[[
   * Called when the initial board setup is changed with put() or remove().
   * modifies the SetUp and FEN properties of the header object. If the FEN
   * is equal to the default position, the SetUp and FEN are deleted the setup
   * is only updated if history.length is zero, ie moves haven't been made.
   ]]
	_updateSetup: (self: Chess_private, fen: string) -> any,
	_set: (self: Chess_private, sq: number, piece: Piece) -> any,
	_put: (
		self: Chess_private,
		ref0: { type: PieceSymbol, color: Color },
		square: Square
	) -> boolean,
	_clear: (self: Chess_private, sq: number) -> any,
	_updateCastlingRights: (self: Chess_private) -> any,
	_updateEnPassantSquare: (self: Chess_private) -> any,
	_attacked: (self: Chess_private, color: Color, square: number) -> boolean,
	_attacked: (self: Chess_private, color: Color, square: number, verbose: false) -> boolean,
	_attacked: (self: Chess_private, color: Color, square: number, verbose: true) -> Array<Square>,
	_attacked: (self: Chess_private, color: Color, square: number, verbose: boolean?) -> any,
	_isKingAttacked: (self: Chess_private, color: Color) -> boolean,
	_createMove: (self: Chess_private, internal: InternalMove) -> any,
	_moves: (
		self: Chess_private,
		ref0_: { legal: boolean?, piece: PieceSymbol?, square: Square? }?
	) -> Array<InternalMove>,
	_push: (self: Chess_private, move: InternalMove) -> any,
	_movePiece: (self: Chess_private, from: number, to: number) -> any,
	_makeMove: (self: Chess_private, move: InternalMove) -> any,
	_undoMove: (self: Chess_private) -> InternalMove | nil,--[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	_moveToSan: (self: Chess_private, move: InternalMove, moves: Array<InternalMove>) -> string, -- convert a move from Standard Algebraic Notation (SAN) to 0x88 coordinates
	_moveFromSan: (self: Chess_private, move: string, strict_: boolean?) -> InternalMove | nil,--[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	_getPositionCount: (
		self: Chess_private,
		hash: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]]
	) -> number,
	_incPositionCount: (self: Chess_private) -> any,
	_decPositionCount: (
		self: Chess_private,
		hash: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]]
	) -> any,
	_pruneComments: (self: Chess_private) -> any,
}
type Chess_statics = { new: (fen_: any?, ref0_: Object?) -> Chess }
local Chess = {} :: Chess & Chess_statics
local Chess_private = Chess :: Chess_private & Chess_statics;
(Chess :: any).__index = Chess
function Chess_private.new(fen_: any?, ref0_: Object?): Chess
	local self = setmetatable({}, Chess)
	local fen: any = if fen_ ~= nil then fen_ else DEFAULT_POSITION
	local ref0: Object = if ref0_ ~= nil then ref0_ else {}
	local skipValidation = if ref0.skipValidation == nil then false else ref0.skipValidation
	self._board = table.create(128)
	self._turn = WHITE
	self._header = {}
	self._kings = { w = EMPTY, b = EMPTY }
	self._epSquare = -1
	self._fenEpSquare = -1
	self._halfMoves = 0
	self._moveNumber = 0
	self._history = {}
	self._comments = {}
	self._suffixes = {}
	self._castling = { w = 0, b = 0 }
	self._hash = 0
	self._positionCount = Map.new()
	self._comments = {}
	self._suffixes = {}
	self:load(fen, { skipValidation = skipValidation })
	return (self :: any) :: Chess
end
function Chess_private:clear(ref0_: Object?)
	local ref0: Object = if ref0_ ~= nil then ref0_ else {}
	local preserveHeaders = if ref0.preserveHeaders == nil then false else ref0.preserveHeaders
	self._board = table.create(128)
	self._kings = { w = EMPTY, b = EMPTY }
	self._turn = WHITE
	self._castling = { w = 0, b = 0 }
	self._epSquare = EMPTY
	self._fenEpSquare = EMPTY
	self._halfMoves = 0
	self._moveNumber = 1
	self._history = {}
	self._comments = {}
	self._header = if Boolean.toJSBoolean(preserveHeaders)
		then self._header
		else Object.assign({}, HEADER_TEMPLATE)
	self._hash = self:_computeHash()
	self._positionCount = Map.new()
	--[[
     * Delete the SetUp and FEN headers (if preserved), the board is empty and
     * these headers don't make sense in this state. They'll get added later
     * via .load() or .put()
     ]]
	self._header["SetUp"] = nil
	self._header["FEN"] = nil
end
function Chess_private:load(fen: string, ref0_: Object?)
	local ref0: Object = if ref0_ ~= nil then ref0_ else {}
	local skipValidation, preserveHeaders =
		if ref0.skipValidation == nil then false else ref0.skipValidation,
		if ref0.preserveHeaders == nil then false else ref0.preserveHeaders
	print(fen, RegExp("\\s+"))
	local tokens = split_by_whitespace(fen) -- append commonly omitted fen tokens
	if
		#tokens >= 2 --[[ ROBLOX CHECK: operator '>=' works only if either both arguments are strings or both are a number ]]
		and #tokens < 6 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
	then
		local adjustments = { "-", "-", "0", "1" }
		fen = Array.join(
			Array.concat(
				tokens,
				Array.slice(adjustments, -(6 - #tokens)) --[[ ROBLOX CHECK: check if 'adjustments' is an Array ]]
			), --[[ ROBLOX CHECK: check if 'tokens' is an Array ]]
			" "
		)
	end
	tokens = split_by_whitespace(fen)
	if not Boolean.toJSBoolean(skipValidation) then
		local ok, error_
		do
			local ref = validateFen(fen)
			ok, error_ = ref.ok, ref.error
		end
		if not Boolean.toJSBoolean(ok) then
			error(Error.new(error_))
		end
	end
	local position = tokens[
		1 --[[ ROBLOX adaptation: added 1 to array index ]]
	]
	local square = 0
	self:clear({ preserveHeaders = preserveHeaders })
	do
		local i = 0
		while
			i
			< position.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local piece = position:charAt(i)
			if piece == "/" then
				square += 8
			elseif Boolean.toJSBoolean(isDigit(piece)) then
				square += tonumber(piece, 10)
			else
				local color = if piece
						< "a" --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
					then WHITE
					else BLACK
				self:_put(
					{ type = piece:toLowerCase() :: PieceSymbol, color = color },
					algebraic(square)
				)
				square += 1
			end
			i += 1
		end
	end
	self._turn = tokens[
		2 --[[ ROBLOX adaptation: added 1 to array index ]]
	] :: Color
	if
		Array.indexOf(
			tokens[
				3 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"K"
		) --[[ ROBLOX CHECK: check if 'tokens[2]' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		self._castling.w = bit32.bor(self._castling.w, BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
	end
	if
		Array.indexOf(
			tokens[
				3 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"Q"
		) --[[ ROBLOX CHECK: check if 'tokens[2]' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		self._castling.w = bit32.bor(self._castling.w, BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
	end
	if
		Array.indexOf(
			tokens[
				3 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"k"
		) --[[ ROBLOX CHECK: check if 'tokens[2]' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		self._castling.b = bit32.bor(self._castling.b, BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
	end
	if
		Array.indexOf(
			tokens[
				3 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"q"
		) --[[ ROBLOX CHECK: check if 'tokens[2]' is an Array ]]
		> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		self._castling.b = bit32.bor(self._castling.b, BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
	end
	self._epSquare = if tokens[
			4 --[[ ROBLOX adaptation: added 1 to array index ]]
		] == "-"
		then EMPTY
		else Ox88[
			tostring(tokens[
				4 --[[ ROBLOX adaptation: added 1 to array index ]]
			] :: Square)
		]
	self._fenEpSquare = self._epSquare
	self._halfMoves = tonumber(
		tokens[
			5 --[[ ROBLOX adaptation: added 1 to array index ]]
		],
		10
	)
	self._moveNumber = tonumber(
		tokens[
			6 --[[ ROBLOX adaptation: added 1 to array index ]]
		],
		10
	)
	self._hash = self:_computeHash()
	self:_updateSetup(fen)
	self:_incPositionCount()
end
function Chess_private:fen(ref0_: { forceEnpassantSquare: boolean? }?)
	local ref0: { forceEnpassantSquare: boolean? } = if ref0_ ~= nil then ref0_ else {}
	local forceEnpassantSquare = if ref0.forceEnpassantSquare == nil
		then false
		else ref0.forceEnpassantSquare
	local empty = 0
	local fen = ""
	do
		local i = Ox88.a8
		while
			i
			<= Ox88.h1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		do
			if Boolean.toJSBoolean(self._board[tostring(i)]) then
				if
					empty
					> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				then
					fen += empty
					empty = 0
				end
				local color, piece
				do
					local ref = self._board[tostring(i)]
					color, piece = ref.color, ref.type
				end
				fen += if color == WHITE then piece:toUpperCase() else piece:toLowerCase()
			else
				empty += 1
			end
			if
				Boolean.toJSBoolean(
					bit32.band(i + 1, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				if
					empty
					> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				then
					fen += empty
				end
				if i ~= Ox88.h1 then
					fen ..= "/"
				end
				empty = 0
				i += 8
			end
			i += 1
		end
	end
	local castling = ""
	if
		Boolean.toJSBoolean(
			bit32.band(self._castling[tostring(WHITE)], BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		castling ..= "K"
	end
	if
		Boolean.toJSBoolean(
			bit32.band(self._castling[tostring(WHITE)], BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		castling ..= "Q"
	end
	if
		Boolean.toJSBoolean(
			bit32.band(self._castling[tostring(BLACK)], BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		castling ..= "k"
	end
	if
		Boolean.toJSBoolean(
			bit32.band(self._castling[tostring(BLACK)], BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		castling ..= "q"
	end -- do we have an empty castling flag?
	castling = Boolean.toJSBoolean(castling) and castling or "-"
	local epSquare = "-"
	--[[
     * only print the ep square if en passant is a valid move (pawn is present
     * and ep capture is not pinned)
     ]]
	if self._fenEpSquare ~= EMPTY then
		if Boolean.toJSBoolean(forceEnpassantSquare) then
			epSquare = algebraic(self._fenEpSquare)
		elseif self._epSquare ~= EMPTY then
			local bigPawnSquare = self._epSquare + (if self._turn == WHITE then 16 else -16)
			local squares = { bigPawnSquare + 1, bigPawnSquare - 1 }
			for _, square in squares do
				-- is the square off the board?
				if
					Boolean.toJSBoolean(
						bit32.band(square, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
					)
				then
					continue
				end
				local color = self._turn -- is there a pawn that can capture the epSquare?
				if
					(
							if typeof(self._board[tostring(square)]) == "table"
								then self._board[tostring(square)].color
								else nil
						)
						== color
					and (
							if typeof(self._board[tostring(square)]) == "table"
								then self._board[tostring(square)].type
								else nil
						)
						== PAWN
				then
					-- if the pawn makes an ep capture, does it leave its king in check?
					self:_makeMove({
						color = color,
						from = square,
						to = self._epSquare,
						piece = PAWN,
						captured = PAWN,
						flags = BITS.EP_CAPTURE,
					})
					local isLegal = not Boolean.toJSBoolean(self:_isKingAttacked(color))
					self:_undoMove() -- if ep is legal, break and set the ep square in the FEN output
					if Boolean.toJSBoolean(isLegal) then
						epSquare = algebraic(self._epSquare)
						break
					end
				end
			end
		end
	end
	return Array.join(
		{ fen, self._turn, castling, epSquare, self._halfMoves, self._moveNumber },
		" "
	)
end
function Chess_private:_pieceKey(i: number)
	if not Boolean.toJSBoolean(self._board[tostring(i)]) then
		return 0
	end
	local color, type_
	do
		local ref = self._board[tostring(i)]
		color, type_ = ref.color, ref.type
	end
	local colorIndex = ({ w = 0, b = 1 })[tostring(color)]
	local typeIndex = ({ p = 0, n = 1, b = 2, r = 3, q = 4, k = 5 })[tostring(type_)]
	return PIECE_KEYS[tostring(colorIndex)][tostring(typeIndex)][tostring(i)]
end
function Chess_private:_epKey()
	return if self._epSquare == EMPTY
		then 0
		else EP_KEYS[
			tostring(
				bit32.band(self._epSquare, 7) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			)
		]
end
function Chess_private:_castlingKey()
	local index = bit32.bor(
		bit32.arshift(self._castling.w, 5), --[[ ROBLOX CHECK: `bit32.arshift` clamps arguments and result to [0,2^32 - 1] ]]
		bit32.arshift(self._castling.b, 3) --[[ ROBLOX CHECK: `bit32.arshift` clamps arguments and result to [0,2^32 - 1] ]]
	) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
	return CASTLING_KEYS[tostring(index)]
end
function Chess_private:_computeHash()
	local hash = 0
	do
		local i = Ox88.a8
		while
			i
			<= Ox88.h1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		do
			-- did we run off the end of the board
			if
				Boolean.toJSBoolean(
					bit32.band(i, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				i += 7
				i += 1
				continue
			end
			if Boolean.toJSBoolean(self._board[tostring(i)]) then
				hash = bit32.bxor(hash, self:_pieceKey(i)) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
			end
			i += 1
		end
	end
	hash = bit32.bxor(hash, self:_epKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	hash = bit32.bxor(hash, self:_castlingKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	if self._turn == "b" then
		hash = bit32.bxor(hash, SIDE_KEY) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	end
	return hash
end
function Chess_private:_updateSetup(fen: string)
	if
		self._history.length
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		return
	end
	if fen ~= DEFAULT_POSITION then
		self._header["SetUp"] = "1"
		self._header["FEN"] = fen
	else
		self._header["SetUp"] = nil
		self._header["FEN"] = nil
	end
end
function Chess_private:reset()
	self:load(DEFAULT_POSITION)
	self._comments = {}
	self._suffixes = {}
end
function Chess_private:get(square: Square): Piece | nil
	return self._board[tostring(Ox88[tostring(square)])]
end
function Chess_private:findPiece(piece: Piece): Array<Square>
	local squares: Array<Square> = {}
	do
		local i = Ox88.a8
		while
			i
			<= Ox88.h1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		do
			-- did we run off the end of the board
			if
				Boolean.toJSBoolean(
					bit32.band(i, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				i += 7
				i += 1
				continue
			end -- if empty square or wrong color
			if
				not Boolean.toJSBoolean(self._board[tostring(i)])
				or (
						if typeof(self._board[tostring(i)]) == "table"
							then self._board[tostring(i)].color
							else nil
					)
					~= piece.color
			then
				i += 1
				continue
			end -- check if square contains the requested piece
			if
				self._board[tostring(i)].color == piece.color
				and self._board[tostring(i)].type == piece.type
			then
				table.insert(squares, algebraic(i)) --[[ ROBLOX CHECK: check if 'squares' is an Array ]]
			end
			i += 1
		end
	end
	return squares
end
function Chess_private:put(ref0: { type: PieceSymbol, color: Color }, square: Square): boolean
	local type_, color = ref0.type, ref0.color
	if Boolean.toJSBoolean(self:_put({ type = type_, color = color }, square)) then
		self:_updateCastlingRights()
		self:_updateEnPassantSquare()
		self:_updateSetup(self:fen())
		return true
	end
	return false
end
function Chess_private:_set(sq: number, piece: Piece)
	self._hash = bit32.bxor(self._hash, self:_pieceKey(sq)) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	self._board[tostring(sq)] = piece
	self._hash = bit32.bxor(self._hash, self:_pieceKey(sq)) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
end
function Chess_private:_put(ref0: { type: PieceSymbol, color: Color }, square: Square): boolean
	local type_, color = ref0.type, ref0.color
	-- check for piece
	if
		Array.indexOf(SYMBOLS, type_:toLowerCase()) --[[ ROBLOX CHECK: check if 'SYMBOLS' is an Array ]]
		== -1
	then
		return false
	end -- check for valid square
	if not (Array.indexOf(Object.keys(Ox88), tostring(square)) ~= -1) then
		return false
	end
	local sq = Ox88[tostring(square)] -- don't let the user place more than one king
	if
		type_ == KING --[[ ROBLOX CHECK: loose equality used upstream ]]
		and not (
			self._kings[tostring(color)] == EMPTY --[[ ROBLOX CHECK: loose equality used upstream ]]
			or self._kings[tostring(color)] == sq --[[ ROBLOX CHECK: loose equality used upstream ]]
		)
	then
		return false
	end
	local currentPieceOnSquare = self._board[tostring(sq)] -- if one of the kings will be replaced by the piece from args, set the `_kings` respective entry to `EMPTY`
	if
		Boolean.toJSBoolean(
			if Boolean.toJSBoolean(currentPieceOnSquare)
				then currentPieceOnSquare.type == KING
				else currentPieceOnSquare
		)
	then
		self._kings[tostring(currentPieceOnSquare.color)] = EMPTY
	end
	self:_set(sq, { type = type_ :: PieceSymbol, color = color :: Color })
	if type_ == KING then
		self._kings[tostring(color)] = sq
	end
	return true
end
function Chess_private:_clear(sq: number)
	self._hash = bit32.bxor(self._hash, self:_pieceKey(sq)) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	self._board[tostring(sq)] = nil
end
function Chess_private:remove(square: Square): Piece | nil
	local piece = self:get(square)
	self:_clear(Ox88[tostring(square)])
	if Boolean.toJSBoolean(if Boolean.toJSBoolean(piece) then piece.type == KING else piece) then
		self._kings[tostring(piece.color)] = EMPTY
	end
	self:_updateCastlingRights()
	self:_updateEnPassantSquare()
	self:_updateSetup(self:fen())
	return piece
end
function Chess_private:_updateCastlingRights()
	self._hash = bit32.bxor(self._hash, self:_castlingKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	local whiteKingInPlace = (
		if typeof(self._board[tostring(Ox88.e1)]) == "table"
			then self._board[tostring(Ox88.e1)].type
			else nil
	)
			== KING
		and (
				if typeof(self._board[tostring(Ox88.e1)]) == "table"
					then self._board[tostring(Ox88.e1)].color
					else nil
			)
			== WHITE
	local blackKingInPlace = (
		if typeof(self._board[tostring(Ox88.e8)]) == "table"
			then self._board[tostring(Ox88.e8)].type
			else nil
	)
			== KING
		and (
				if typeof(self._board[tostring(Ox88.e8)]) == "table"
					then self._board[tostring(Ox88.e8)].color
					else nil
			)
			== BLACK
	if
		not Boolean.toJSBoolean(whiteKingInPlace)
		or (if typeof(self._board[tostring(Ox88.a1)]) == "table"
			then self._board[tostring(Ox88.a1)].type
			else nil) ~= ROOK
		or (
				if typeof(self._board[tostring(Ox88.a1)]) == "table"
					then self._board[tostring(Ox88.a1)].color
					else nil
			)
			~= WHITE
	then
		self._castling.w = bit32.band(
			self._castling.w,
			bit32.bnot(BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bnot` clamps arguments and result to [0,2^32 - 1] ]]
		) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
	end
	if
		not Boolean.toJSBoolean(whiteKingInPlace)
		or (if typeof(self._board[tostring(Ox88.h1)]) == "table"
			then self._board[tostring(Ox88.h1)].type
			else nil) ~= ROOK
		or (
				if typeof(self._board[tostring(Ox88.h1)]) == "table"
					then self._board[tostring(Ox88.h1)].color
					else nil
			)
			~= WHITE
	then
		self._castling.w = bit32.band(
			self._castling.w,
			bit32.bnot(BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bnot` clamps arguments and result to [0,2^32 - 1] ]]
		) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
	end
	if
		not Boolean.toJSBoolean(blackKingInPlace)
		or (if typeof(self._board[tostring(Ox88.a8)]) == "table"
			then self._board[tostring(Ox88.a8)].type
			else nil) ~= ROOK
		or (
				if typeof(self._board[tostring(Ox88.a8)]) == "table"
					then self._board[tostring(Ox88.a8)].color
					else nil
			)
			~= BLACK
	then
		self._castling.b = bit32.band(
			self._castling.b,
			bit32.bnot(BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bnot` clamps arguments and result to [0,2^32 - 1] ]]
		) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
	end
	if
		not Boolean.toJSBoolean(blackKingInPlace)
		or (if typeof(self._board[tostring(Ox88.h8)]) == "table"
			then self._board[tostring(Ox88.h8)].type
			else nil) ~= ROOK
		or (
				if typeof(self._board[tostring(Ox88.h8)]) == "table"
					then self._board[tostring(Ox88.h8)].color
					else nil
			)
			~= BLACK
	then
		self._castling.b = bit32.band(
			self._castling.b,
			bit32.bnot(BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bnot` clamps arguments and result to [0,2^32 - 1] ]]
		) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
	end
	self._hash = bit32.bxor(self._hash, self:_castlingKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
end
function Chess_private:_updateEnPassantSquare()
	if self._epSquare == EMPTY then
		return
	end
	local startSquare = self._epSquare + (if self._turn == WHITE then -16 else 16)
	local currentSquare = self._epSquare + (if self._turn == WHITE then 16 else -16)
	local attackers = { currentSquare + 1, currentSquare - 1 }
	if
		self._board[tostring(startSquare)] ~= nil
		or self._board[tostring(self._epSquare)] ~= nil
		or (if typeof(self._board[tostring(currentSquare)]) == "table"
			then self._board[tostring(currentSquare)].color
			else nil) ~= swapColor(self._turn)
		or (
				if typeof(self._board[tostring(currentSquare)]) == "table"
					then self._board[tostring(currentSquare)].type
					else nil
			)
			~= PAWN
	then
		self._hash = bit32.bxor(self._hash, self:_epKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
		self._epSquare = EMPTY
		return
	end
	local function canCapture(square: number)
		return not Boolean.toJSBoolean(
			bit32.band(square, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		) and (if typeof(self._board[tostring(square)]) == "table"
			then self._board[tostring(square)].color
			else nil) == self._turn and (if typeof(self._board[tostring(square)]) == "table"
			then self._board[tostring(square)].type
			else nil) == PAWN
	end
	if
		not Boolean.toJSBoolean(
			Array.some(attackers, canCapture) --[[ ROBLOX CHECK: check if 'attackers' is an Array ]]
		)
	then
		self._hash = bit32.bxor(self._hash, self:_epKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
		self._epSquare = EMPTY
	end
end
function Chess_private:_attacked(color: Color, square: number): boolean
	error("not implemented method")
end
function Chess_private:_attacked(color: Color, square: number, verbose: false): boolean
	error("not implemented method")
end
function Chess_private:_attacked(color: Color, square: number, verbose: true): Array<Square>
	error("not implemented method")
end
function Chess_private:_attacked(color: Color, square: number, verbose: boolean?)
	local attackers: Array<Square> = {}
	do
		local i = Ox88.a8
		while
			i
			<= Ox88.h1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		do
			-- did we run off the end of the board
			if
				Boolean.toJSBoolean(
					bit32.band(i, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				i += 7
				i += 1
				continue
			end -- if empty square or wrong color
			if self._board[tostring(i)] == nil or self._board[tostring(i)].color ~= color then
				i += 1
				continue
			end
			local piece = self._board[tostring(i)]
			local difference = i - square -- skip - to/from square are the same
			if difference == 0 then
				i += 1
				continue
			end
			local index = difference + 119
			if
				Boolean.toJSBoolean(
					bit32.band(ATTACKS[tostring(index)], PIECE_MASKS[tostring(piece.type)]) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				if piece.type == PAWN then
					if
						difference > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
							and piece.color == WHITE
						or difference <= 0 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
							and piece.color == BLACK
					then
						if not Boolean.toJSBoolean(verbose) then
							return true
						else
							table.insert(attackers, algebraic(i)) --[[ ROBLOX CHECK: check if 'attackers' is an Array ]]
						end
					end
					i += 1
					continue
				end -- if the piece is a knight or a king
				if piece.type == "n" or piece.type == "k" then
					if not Boolean.toJSBoolean(verbose) then
						return true
					else
						table.insert(attackers, algebraic(i)) --[[ ROBLOX CHECK: check if 'attackers' is an Array ]]
						i += 1
						continue
					end
				end
				local offset = RAYS[tostring(index)]
				local j = i + offset
				local blocked = false
				while j ~= square do
					if
						self._board[tostring(j)]
						~= nil --[[ ROBLOX CHECK: loose inequality used upstream ]]
					then
						blocked = true
						break
					end
					j += offset
				end
				if not Boolean.toJSBoolean(blocked) then
					if not Boolean.toJSBoolean(verbose) then
						return true
					else
						table.insert(attackers, algebraic(i)) --[[ ROBLOX CHECK: check if 'attackers' is an Array ]]
						i += 1
						continue
					end
				end
			end
			i += 1
		end
	end
	if Boolean.toJSBoolean(verbose) then
		return attackers
	else
		return false
	end
end
function Chess_private:attackers(square: Square, attackedBy: Color?): Array<Square>
	if not Boolean.toJSBoolean(attackedBy) then
		return self:_attacked(self._turn, Ox88[tostring(square)], true)
	else
		return self:_attacked(attackedBy, Ox88[tostring(square)], true)
	end
end
function Chess_private:_isKingAttacked(color: Color): boolean
	local square = self._kings[tostring(color)]
	return if square == -1 then false else self:_attacked(swapColor(color), square)
end
function Chess_private:hash(): string
	return self._hash:toString(16)
end
function Chess_private:isAttacked(square: Square, attackedBy: Color): boolean
	return self:_attacked(attackedBy, Ox88[tostring(square)])
end
function Chess_private:isCheck(): boolean
	return self:_isKingAttacked(self._turn)
end
function Chess_private:inCheck(): boolean
	return self:isCheck()
end
function Chess_private:isCheckmate(): boolean
	local ref = self:isCheck()
	return if Boolean.toJSBoolean(ref) then self:_moves().length == 0 else ref
end
function Chess_private:isStalemate(): boolean
	return not Boolean.toJSBoolean(self:isCheck()) and self:_moves().length == 0
end
function Chess_private:isInsufficientMaterial(): boolean
	--[[
     * k.b. vs k.b. (of opposite colors) with mate in 1:
     * 8/8/8/8/1b6/8/B1k5/K7 b - - 0 1
     *
     * k.b. vs k.n. with mate in 1:
     * 8/8/8/8/1n6/8/B7/K1k5 b - - 2 1
     ]]
	local pieces: Record<PieceSymbol, number> = { b = 0, n = 0, r = 0, q = 0, k = 0, p = 0 }
	local bishops = {}
	local numPieces = 0
	local squareColor = 0
	do
		local i = Ox88.a8
		while
			i
			<= Ox88.h1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		do
			squareColor = (squareColor + 1) % 2
			if
				Boolean.toJSBoolean(
					bit32.band(i, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				i += 7
				i += 1
				continue
			end
			local piece = self._board[tostring(i)]
			if Boolean.toJSBoolean(piece) then
				pieces[tostring(piece.type)] = if Array.indexOf(
						Object.keys(pieces),
						tostring(piece.type)
					) ~= -1
					then pieces[tostring(piece.type)] + 1
					else 1
				if piece.type == BISHOP then
					table.insert(bishops, squareColor) --[[ ROBLOX CHECK: check if 'bishops' is an Array ]]
				end
				numPieces += 1
			end
			i += 1
		end
	end -- k vs. k
	if numPieces == 2 then
		return true
	elseif -- k vs. kn .... or .... k vs. kb
		-- k vs. kn .... or .... k vs. kb
		numPieces == 3 and (pieces[tostring(BISHOP)] == 1 or pieces[tostring(KNIGHT)] == 1)
	then
		return true
	elseif numPieces == pieces[tostring(BISHOP)] + 2 then
		-- kb vs. kb where any number of bishops are all on the same color
		local sum = 0
		local len = bishops.length
		do
			local i = 0
			while
				i
				< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				sum += bishops[tostring(i)]
				i += 1
			end
		end
		if sum == 0 or sum == len then
			return true
		end
	end
	return false
end
function Chess_private:isThreefoldRepetition(): boolean
	return self:_getPositionCount(self._hash) >= 3 --[[ ROBLOX CHECK: operator '>=' works only if either both arguments are strings or both are a number ]]
end
function Chess_private:isDrawByFiftyMoves(): boolean
	return self._halfMoves >= 100 --[[ ROBLOX CHECK: operator '>=' works only if either both arguments are strings or both are a number ]] -- 50 moves per side = 100 half moves
end
function Chess_private:isDraw(): boolean
	local ref = self:isDrawByFiftyMoves()
	local ref = Boolean.toJSBoolean(ref) and ref or self:isStalemate()
	local ref = Boolean.toJSBoolean(ref) and ref or self:isInsufficientMaterial()
	return Boolean.toJSBoolean(ref) and ref or self:isThreefoldRepetition()
end
function Chess_private:isGameOver(): boolean
	local ref = self:isCheckmate()
	return Boolean.toJSBoolean(ref) and ref or self:isDraw()
end
function Chess_private:isPromotion(ref0: { from: Square, to: Square }): boolean
	local from, to = ref0.from, ref0.to
	return Array.some(self:_moves({ square = from, piece = "p" }), function(move)
		return move.to == Ox88[tostring(to)] and move.promotion
	end) --[[ ROBLOX CHECK: check if 'this._moves({
      square: from,
      piece: "p"
    })' is an Array ]]
end
function Chess_private:_createMove(internal: InternalMove)
	local san = self:_moveToSan(internal, self:_moves({ legal = true }))
	local before = self:fen()
	self:_makeMove(internal)
	local after = self:fen()
	self:_undoMove()
	return Move.new(internal, san, before, after)
end
function Chess_private:moves(): Array<string>
	error("not implemented method")
end
function Chess_private:moves(ref0: { square: Square }): Array<string>
	local square = ref0.square
	error("not implemented method")
end
function Chess_private:moves(ref0: { piece: PieceSymbol }): Array<string>
	local piece = ref0.piece
	error("not implemented method")
end
function Chess_private:moves(ref0: { square: Square, piece: PieceSymbol }): Array<string>
	local square, piece = ref0.square, ref0.piece
	error("not implemented method")
end
function Chess_private:moves(ref0: { verbose: true, square: Square? }): Array<Move>
	local verbose, square = ref0.verbose, ref0.square
	error("not implemented method")
end
function Chess_private:moves(ref0: { verbose: false, square: Square? }): Array<string>
	local verbose, square = ref0.verbose, ref0.square
	error("not implemented method")
end
function Chess_private:moves(
	ref0: { verbose: boolean?, square: Square? }
): Array<string> | Array<Move>
	local verbose, square = ref0.verbose, ref0.square
	error("not implemented method")
end
function Chess_private:moves(ref0: { verbose: true, piece: PieceSymbol? }): Array<Move>
	local verbose, piece = ref0.verbose, ref0.piece
	error("not implemented method")
end
function Chess_private:moves(ref0: { verbose: false, piece: PieceSymbol? }): Array<string>
	local verbose, piece = ref0.verbose, ref0.piece
	error("not implemented method")
end
function Chess_private:moves(
	ref0: { verbose: boolean?, piece: PieceSymbol? }
): Array<string> | Array<Move>
	local verbose, piece = ref0.verbose, ref0.piece
	error("not implemented method")
end
function Chess_private:moves(
	ref0: { verbose: true, square: Square?, piece: PieceSymbol? }
): Array<Move>
	local verbose, square, piece = ref0.verbose, ref0.square, ref0.piece
	error("not implemented method")
end
function Chess_private:moves(
	ref0: { verbose: false, square: Square?, piece: PieceSymbol? }
): Array<string>
	local verbose, square, piece = ref0.verbose, ref0.square, ref0.piece
	error("not implemented method")
end
function Chess_private:moves(
	ref0: { verbose: boolean?, square: Square?, piece: PieceSymbol? }
): Array<string> | Array<Move>
	local verbose, square, piece = ref0.verbose, ref0.square, ref0.piece
	error("not implemented method")
end
function Chess_private:moves(ref0: { square: Square?, piece: PieceSymbol? }): Array<Move>
	local square, piece = ref0.square, ref0.piece
	error("not implemented method")
end
function Chess_private:moves(ref0_: { verbose: boolean?, square: Square?, piece: PieceSymbol? }?)
	local ref0: { verbose: boolean?, square: Square?, piece: PieceSymbol? } = if ref0_ ~= nil
		then ref0_
		else {}
	local verbose, square, piece =
		if ref0.verbose == nil then false else ref0.verbose,
		if ref0.square == nil then nil else ref0.square,
		if ref0.piece == nil then nil else ref0.piece
	local moves = self:_moves({ square = square, piece = piece })
	if Boolean.toJSBoolean(verbose) then
		return Array.map(moves, function(move)
			return self:_createMove(move)
		end) --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
	else
		return Array.map(moves, function(move)
			return self:_moveToSan(move, moves)
		end) --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
	end
end
function Chess_private:_moves(
	ref0_: { legal: boolean?, piece: PieceSymbol?, square: Square? }?
): Array<InternalMove>
	local ref0: { legal: boolean?, piece: PieceSymbol?, square: Square? } = if ref0_ ~= nil
		then ref0_
		else {}
	local legal, piece, square =
		if ref0.legal == nil then true else ref0.legal,
		if ref0.piece == nil then nil else ref0.piece,
		if ref0.square == nil then nil else ref0.square
	local forSquare = if Boolean.toJSBoolean(square) then square:toLowerCase() :: Square else nil
	local ref = if typeof(piece) == "table" then piece.toLowerCase else nil
	local forPiece = if ref ~= nil then ref() else nil
	local moves: Array<InternalMove> = {}
	local us = self._turn
	local them = swapColor(us)
	local firstSquare = Ox88.a8
	local lastSquare = Ox88.h1
	local singleSquare = false -- are we generating moves for a single square?
	if Boolean.toJSBoolean(forSquare) then
		-- illegal square, return empty moves
		if not (Array.indexOf(Object.keys(Ox88), tostring(forSquare)) ~= -1) then
			return {}
		else
			lastSquare = Ox88[tostring(forSquare)]
			firstSquare = lastSquare
			singleSquare = true
		end
	end
	do
		local from = firstSquare
		while
			from
			<= lastSquare --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		do
			-- did we run off the end of the board
			if
				Boolean.toJSBoolean(
					bit32.band(from, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				from += 7
				from += 1
				continue
			end -- empty square or opponent, skip
			if
				not Boolean.toJSBoolean(self._board[tostring(from)])
				or self._board[tostring(from)].color == them
			then
				from += 1
				continue
			end
			local type_ = self._board[tostring(from)].type
			local to: number
			if type_ == PAWN then
				if
					Boolean.toJSBoolean(
						if Boolean.toJSBoolean(forPiece) then forPiece ~= type_ else forPiece
					)
				then
					from += 1
					continue
				end -- single square, non-capturing
				to = from
					+ PAWN_OFFSETS[tostring(us)][
						1 --[[ ROBLOX adaptation: added 1 to array index ]]
					]
				if not Boolean.toJSBoolean(self._board[tostring(to)]) then
					addMove(moves, us, from, to, PAWN) -- double square
					to = from
						+ PAWN_OFFSETS[tostring(us)][
							2 --[[ ROBLOX adaptation: added 1 to array index ]]
						]
					if
						SECOND_RANK[tostring(us)] == rank(from)
						and not Boolean.toJSBoolean(self._board[tostring(to)])
					then
						addMove(moves, us, from, to, PAWN, nil, BITS.BIG_PAWN)
					end
				end -- pawn captures
				do
					local j = 2
					while
						j
						< 4 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
					do
						to = from + PAWN_OFFSETS[tostring(us)][tostring(j)]
						if
							Boolean.toJSBoolean(
								bit32.band(to, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
							)
						then
							j += 1
							continue
						end
						if
							(
								if typeof(self._board[tostring(to)]) == "table"
									then self._board[tostring(to)].color
									else nil
							) == them
						then
							addMove(
								moves,
								us,
								from,
								to,
								PAWN,
								self._board[tostring(to)].type,
								BITS.CAPTURE
							)
						elseif to == self._epSquare then
							addMove(moves, us, from, to, PAWN, PAWN, BITS.EP_CAPTURE)
						end
						j += 1
					end
				end
			else
				if
					Boolean.toJSBoolean(
						if Boolean.toJSBoolean(forPiece) then forPiece ~= type_ else forPiece
					)
				then
					from += 1
					continue
				end
				do
					local j, len = 0, PIECE_OFFSETS[tostring(type_)].length
					while
						j
						< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
					do
						local offset = PIECE_OFFSETS[tostring(type_)][tostring(j)]
						to = from
						while true do
							to += offset
							if
								Boolean.toJSBoolean(
									bit32.band(to, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
								)
							then
								break
							end
							if not Boolean.toJSBoolean(self._board[tostring(to)]) then
								addMove(moves, us, from, to, type_)
							else
								-- own color, stop loop
								if self._board[tostring(to)].color == us then
									break
								end
								addMove(
									moves,
									us,
									from,
									to,
									type_,
									self._board[tostring(to)].type,
									BITS.CAPTURE
								)
								break
							end
							--[[ break, if knight or king ]]
							if type_ == KNIGHT or type_ == KING then
								break
							end
						end
						j += 1
					end
				end
			end
			from += 1
		end
	end
	--[[
     * check for castling if we're:
     *   a) generating all moves, or
     *   b) doing single square move generation on the king's square
     ]]
	if forPiece == nil or forPiece == KING then
		if not Boolean.toJSBoolean(singleSquare) or lastSquare == self._kings[tostring(us)] then
			-- king-side castling
			if
				Boolean.toJSBoolean(
					bit32.band(self._castling[tostring(us)], BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				local castlingFrom = self._kings[tostring(us)]
				local castlingTo = castlingFrom + 2
				if
					not Boolean.toJSBoolean(self._board[tostring(castlingFrom + 1)])
					and not Boolean.toJSBoolean(self._board[tostring(castlingTo)])
					and not Boolean.toJSBoolean(self:_attacked(them, self._kings[tostring(us)]))
					and not Boolean.toJSBoolean(self:_attacked(them, castlingFrom + 1))
					and not Boolean.toJSBoolean(self:_attacked(them, castlingTo))
				then
					addMove(
						moves,
						us,
						self._kings[tostring(us)],
						castlingTo,
						KING,
						nil,
						BITS.KSIDE_CASTLE
					)
				end
			end -- queen-side castling
			if
				Boolean.toJSBoolean(
					bit32.band(self._castling[tostring(us)], BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				local castlingFrom = self._kings[tostring(us)]
				local castlingTo = castlingFrom - 2
				if
					not Boolean.toJSBoolean(self._board[tostring(castlingFrom - 1)])
					and not Boolean.toJSBoolean(self._board[tostring(castlingFrom - 2)])
					and not Boolean.toJSBoolean(self._board[tostring(castlingFrom - 3)])
					and not Boolean.toJSBoolean(self:_attacked(them, self._kings[tostring(us)]))
					and not Boolean.toJSBoolean(self:_attacked(them, castlingFrom - 1))
					and not Boolean.toJSBoolean(self:_attacked(them, castlingTo))
				then
					addMove(
						moves,
						us,
						self._kings[tostring(us)],
						castlingTo,
						KING,
						nil,
						BITS.QSIDE_CASTLE
					)
				end
			end
		end
	end
	--[[
     * return all pseudo-legal moves (this includes moves that allow the king
     * to be captured)
     ]]
	if not Boolean.toJSBoolean(legal) or self._kings[tostring(us)] == -1 then
		return moves
	end -- filter out illegal moves
	local legalMoves = {}
	do
		local i, len = 0, moves.length
		while
			i
			< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			self:_makeMove(moves[tostring(i)])
			if not Boolean.toJSBoolean(self:_isKingAttacked(us)) then
				table.insert(legalMoves, moves[tostring(i)]) --[[ ROBLOX CHECK: check if 'legalMoves' is an Array ]]
			end
			self:_undoMove()
			i += 1
		end
	end
	return legalMoves
end
function Chess_private:move(
	move: string | { from: string, to: string, promotion: string? } | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]],
	ref0_: { strict: boolean? }?
): Move
	local ref0: { strict: boolean? } = if ref0_ ~= nil then ref0_ else {}
	local strict = if ref0.strict == nil then false else ref0.strict
	--[[
     * The move function can be called with in the following parameters:
     *
     * .move('Nxb7')       <- argument is a case-sensitive SAN string
     *
     * .move({ from: 'h7', <- argument is a move object
     *         to :'h8',
     *         promotion: 'q' })
     *
     *
     * An optional strict argument may be supplied to tell chess.js to
     * strictly follow the SAN specification.
     ]]
	local moveObj = nil
	if typeof(move) == "string" then
		moveObj = self:_moveFromSan(move, strict)
	elseif move == nil then
		moveObj = self:_moveFromSan(SAN_NULLMOVE, strict)
	elseif typeof(move) == "table" then
		local moves = self:_moves() -- convert the pretty move object to an ugly move object
		do
			local i, len = 0, moves.length
			while
				i
				< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				if
					move.from == algebraic(moves[tostring(i)].from)
					and move.to == algebraic(moves[tostring(i)].to)
					and (
						not (Array.indexOf(Object.keys(moves[tostring(i)]), "promotion") ~= -1)
						or move.promotion == moves[tostring(i)].promotion
					)
				then
					moveObj = moves[tostring(i)]
					break
				end
				i += 1
			end
		end
	end -- failed to find move
	if not Boolean.toJSBoolean(moveObj) then
		if typeof(move) == "string" then
			error(Error.new(("Invalid move: %s"):format(tostring(move))))
		else
			error(Error.new(("Invalid move: %s"):format(tostring(JSON.stringify(move)))))
		end
	end --disallow null moves when in check
	if
		Boolean.toJSBoolean((function()
			local ref = self:isCheck()
			return if Boolean.toJSBoolean(ref)
				then bit32.band(moveObj.flags, BITS.NULL_MOVE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				else ref
		end)())
	then
		error(Error.new("Null move not allowed when in check"))
	end
	--[[
     * need to make a copy of move because we can't generate SAN after the move
     * is made
     ]]
	local prettyMove = self:_createMove(moveObj)
	self:_makeMove(moveObj)
	self:_incPositionCount()
	return prettyMove
end
function Chess_private:_push(move: InternalMove)
	table.insert(self._history, {
		move = move,
		kings = { b = self._kings.b, w = self._kings.w },
		turn = self._turn,
		castling = { b = self._castling.b, w = self._castling.w },
		epSquare = self._epSquare,
		fenEpSquare = self._fenEpSquare,
		halfMoves = self._halfMoves,
		moveNumber = self._moveNumber,
	}) --[[ ROBLOX CHECK: check if 'this._history' is an Array ]]
end
function Chess_private:_movePiece(from: number, to: number)
	self._hash = bit32.bxor(self._hash, self:_pieceKey(from)) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	self._board[tostring(to)] = self._board[tostring(from)]
	self._board[tostring(from)] = nil
	self._hash = bit32.bxor(self._hash, self:_pieceKey(to)) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
end
function Chess_private:_makeMove(move: InternalMove)
	local us = self._turn
	local them = swapColor(us)
	self:_push(move)
	if
		Boolean.toJSBoolean(
			bit32.band(move.flags, BITS.NULL_MOVE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		if us == BLACK then
			self._moveNumber += 1
		end
		self._halfMoves += 1
		self._turn = them
		self._epSquare = EMPTY
		return
	end
	self._hash = bit32.bxor(self._hash, self:_epKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	self._hash = bit32.bxor(self._hash, self:_castlingKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	if Boolean.toJSBoolean(move.captured) then
		self._hash = bit32.bxor(self._hash, self:_pieceKey(move.to)) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	end
	self:_movePiece(move.from, move.to) -- if ep capture, remove the captured pawn
	if
		Boolean.toJSBoolean(
			bit32.band(move.flags, BITS.EP_CAPTURE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		if self._turn == BLACK then
			self:_clear(move.to - 16)
		else
			self:_clear(move.to + 16)
		end
	end -- if pawn promotion, replace with new piece
	if Boolean.toJSBoolean(move.promotion) then
		self:_clear(move.to)
		self:_set(move.to, { type = move.promotion, color = us })
	end -- if we moved the king
	if self._board[tostring(move.to)].type == KING then
		self._kings[tostring(us)] = move.to -- if we castled, move the rook next to the king
		if
			Boolean.toJSBoolean(
				bit32.band(move.flags, BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			)
		then
			local castlingTo = move.to - 1
			local castlingFrom = move.to + 1
			self:_movePiece(castlingFrom, castlingTo)
		elseif
			Boolean.toJSBoolean(
				bit32.band(move.flags, BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			)
		then
			local castlingTo = move.to + 1
			local castlingFrom = move.to - 2
			self:_movePiece(castlingFrom, castlingTo)
		end -- turn off castling
		self._castling[tostring(us)] = 0
	end -- turn off castling if we move a rook
	if Boolean.toJSBoolean(self._castling[tostring(us)]) then
		do
			local i, len = 0, ROOKS[tostring(us)].length
			while
				i
				< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				if
					Boolean.toJSBoolean(
						move.from == ROOKS[tostring(us)][tostring(i)].square
							and bit32.band(
								self._castling[tostring(us)],
								ROOKS[tostring(us)][tostring(i)].flag
							) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
					)
				then
					self._castling[tostring(us)] = bit32.bxor(
						self._castling[tostring(us)],
						ROOKS[tostring(us)][tostring(i)].flag
					) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
					break
				end
				i += 1
			end
		end
	end -- turn off castling if we capture a rook
	if Boolean.toJSBoolean(self._castling[tostring(them)]) then
		do
			local i, len = 0, ROOKS[tostring(them)].length
			while
				i
				< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				if
					Boolean.toJSBoolean(
						move.to == ROOKS[tostring(them)][tostring(i)].square
							and bit32.band(
								self._castling[tostring(them)],
								ROOKS[tostring(them)][tostring(i)].flag
							) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
					)
				then
					self._castling[tostring(them)] = bit32.bxor(
						self._castling[tostring(them)],
						ROOKS[tostring(them)][tostring(i)].flag
					) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
					break
				end
				i += 1
			end
		end
	end
	self._hash = bit32.bxor(self._hash, self:_castlingKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]] -- if big pawn move, update the en passant square
	if
		Boolean.toJSBoolean(
			bit32.band(move.flags, BITS.BIG_PAWN) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		local epSquare
		if us == BLACK then
			epSquare = move.to - 16
		else
			epSquare = move.to + 16
		end
		self._fenEpSquare = epSquare
		if
			not Boolean.toJSBoolean(
					bit32.band(move.to - 1, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
				and (if typeof(self._board[tostring(move.to - 1)]) == "table"
					then self._board[tostring(move.to - 1)].type
					else nil) == PAWN
				and (if typeof(self._board[tostring(move.to - 1)]) == "table"
					then self._board[tostring(move.to - 1)].color
					else nil) == them
			or not Boolean.toJSBoolean(
					bit32.band(move.to + 1, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
				and (if typeof(self._board[tostring(move.to + 1)]) == "table"
					then self._board[tostring(move.to + 1)].type
					else nil) == PAWN
				and (if typeof(self._board[tostring(move.to + 1)]) == "table"
					then self._board[tostring(move.to + 1)].color
					else nil) == them
		then
			self._epSquare = epSquare
			self._hash = bit32.bxor(self._hash, self:_epKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
		else
			self._epSquare = EMPTY
		end
	else
		self._epSquare = EMPTY
		self._fenEpSquare = EMPTY
	end -- reset the 50 move counter if a pawn is moved or a piece is captured
	if move.piece == PAWN then
		self._halfMoves = 0
	elseif
		Boolean.toJSBoolean(
			bit32.band(
				move.flags,
				bit32.bor(BITS.CAPTURE, BITS.EP_CAPTURE) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
			) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		self._halfMoves = 0
	else
		self._halfMoves += 1
	end
	if us == BLACK then
		self._moveNumber += 1
	end
	self._turn = them
	self._hash = bit32.bxor(self._hash, SIDE_KEY) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
end
function Chess_private:undo(
): Move | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	local hash = self._hash
	local move = self:_undoMove()
	if Boolean.toJSBoolean(move) then
		local prettyMove = self:_createMove(move)
		self:_decPositionCount(hash)
		return prettyMove
	end
	return nil
end
function Chess_private:_undoMove(
): InternalMove | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	local old = table.remove(self._history) --[[ ROBLOX CHECK: check if 'this._history' is an Array ]]
	if old == nil then
		return nil
	end
	self._hash = bit32.bxor(self._hash, self:_epKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	self._hash = bit32.bxor(self._hash, self:_castlingKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	local move = old.move
	self._kings = old.kings
	self._turn = old.turn
	self._castling = old.castling
	self._epSquare = old.epSquare
	self._fenEpSquare = old.fenEpSquare
	self._halfMoves = old.halfMoves
	self._moveNumber = old.moveNumber
	self._hash = bit32.bxor(self._hash, self:_epKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	self._hash = bit32.bxor(self._hash, self:_castlingKey()) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	self._hash = bit32.bxor(self._hash, SIDE_KEY) --[[ ROBLOX CHECK: `bit32.bxor` clamps arguments and result to [0,2^32 - 1] ]]
	local us = self._turn
	local them = swapColor(us)
	if
		Boolean.toJSBoolean(
			bit32.band(move.flags, BITS.NULL_MOVE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		return move
	end
	self:_movePiece(move.to, move.from) -- to undo any promotions
	if Boolean.toJSBoolean(move.piece) then
		self:_clear(move.from)
		self:_set(move.from, { type = move.piece, color = us })
	end
	if Boolean.toJSBoolean(move.captured) then
		if
			Boolean.toJSBoolean(
				bit32.band(move.flags, BITS.EP_CAPTURE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			)
		then
			-- en passant capture
			local index: number
			if us == BLACK then
				index = move.to - 16
			else
				index = move.to + 16
			end
			self:_set(index, { type = PAWN, color = them })
		else
			-- regular capture
			self:_set(move.to, { type = move.captured, color = them })
		end
	end
	if
		Boolean.toJSBoolean(
			bit32.band(
				move.flags,
				bit32.bor(BITS.KSIDE_CASTLE, BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
			) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		local castlingTo: number, castlingFrom: number
		if
			Boolean.toJSBoolean(
				bit32.band(move.flags, BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			)
		then
			castlingTo = move.to + 1
			castlingFrom = move.to - 1
		else
			castlingTo = move.to - 2
			castlingFrom = move.to + 1
		end
		self:_movePiece(castlingFrom, castlingTo)
	end
	return move
end
function Chess_private:pgn(ref0_: { newline: string?, maxWidth: number? }?): string
	local ref0: { newline: string?, maxWidth: number? } = if ref0_ ~= nil then ref0_ else {}
	local newline, maxWidth =
		if ref0.newline == nil then "\n" else ref0.newline,
		if ref0.maxWidth == nil then 0 else ref0.maxWidth
	--[[
     * using the specification from http://www.chessclub.com/help/PGN-spec
     * example for html usage: .pgn({ max_width: 72, newline_char: "<br />" })
     ]]
	local result: Array<string> = {}
	local headerExists = false
	--[[ add the PGN header information ]]
	for i in self._header do
		--[[
       * TODO: order of enumerated properties in header object is not
       * guaranteed, see ECMA-262 spec (section 12.6.4)
       *
       * By using HEADER_TEMPLATE, the order of tags should be preserved; we
       * do have to check for null placeholders, though, and omit them
       ]]
		local headerTag = self._header[tostring(i)]
		if Boolean.toJSBoolean(headerTag) then
			table.insert(
				result,
				('[%s "%s"]'):format(tostring(i), tostring(self._header[tostring(i)]))
					.. tostring(newline)
			) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
		end
		headerExists = true
	end
	if
		Boolean.toJSBoolean(
			if Boolean.toJSBoolean(headerExists) then self._history.length else headerExists
		)
	then
		table.insert(result, newline) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
	end
	local function appendComment(moveString: string)
		local comment = self._comments[tostring(self:fen())]
		if typeof(comment) ~= "undefined" then
			local delimiter = if moveString.length
					> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				then " "
				else ""
			moveString = ("%s%s{%s}"):format(
				tostring(moveString),
				tostring(delimiter),
				tostring(comment)
			)
		end
		return moveString
	end -- pop all of history onto reversed_history
	local reversedHistory = {}
	while
		self._history.length
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	do
		table.insert(reversedHistory, self:_undoMove()) --[[ ROBLOX CHECK: check if 'reversedHistory' is an Array ]]
	end
	local moves = {}
	local moveString = "" -- special case of a commented starting position with no moves
	if reversedHistory.length == 0 then
		table.insert(moves, appendComment("")) --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
	end -- build the list of moves.  a move_string looks like: "3. e3 e6"
	while
		reversedHistory.length
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	do
		moveString = appendComment(moveString)
		local move = table.remove(reversedHistory) --[[ ROBLOX CHECK: check if 'reversedHistory' is an Array ]] -- make TypeScript stop complaining about move being undefined
		if not Boolean.toJSBoolean(move) then
			break
		end -- if the position started with black to move, start PGN with #. ...
		if not Boolean.toJSBoolean(self._history.length) and move.color == "b" then
			local prefix = ("%s. ..."):format(tostring(self._moveNumber)) -- is there a comment preceding the first move?
			moveString = if Boolean.toJSBoolean(moveString)
				then ("%s %s"):format(tostring(moveString), tostring(prefix))
				else prefix
		elseif move.color == "w" then
			-- store the previous generated move_string if we have one
			if Boolean.toJSBoolean(moveString.length) then
				table.insert(moves, moveString) --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
			end
			moveString = tostring(self._moveNumber) .. "."
		end
		moveString = tostring(moveString)
			.. " "
			.. tostring(self:_moveToSan(move, self:_moves({ legal = true })))
		self:_makeMove(move)
	end -- are there any other leftover moves?
	if Boolean.toJSBoolean(moveString.length) then
		table.insert(moves, appendComment(moveString)) --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
	end -- is there a result? (there ALWAYS has to be a result according to spec; see Seven Tag Roster)
	table.insert(moves, Boolean.toJSBoolean(self._header.Result) and self._header.Result or "*") --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
	--[[
     * history should be back to what it was before we started generating PGN,
     * so join together moves
     ]]
	if maxWidth == 0 then
		return Array.join(result, "") --[[ ROBLOX CHECK: check if 'result' is an Array ]]
			+ Array.join(moves, " ") --[[ ROBLOX CHECK: check if 'moves' is an Array ]]
	end -- TODO (jah): huh?
	local function strip()
		if
			result.length > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			and result[tostring(result.length - 1)] == " "
		then
			table.remove(result) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
			return true
		end
		return false
	end -- NB: this does not preserve comment whitespace.
	local function wrapComment(width: number, move: string)
		for _, token in move:split(" ") do
			if not Boolean.toJSBoolean(token) then
				continue
			end
			if
				width + token.length
				> maxWidth --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			then
				while Boolean.toJSBoolean(strip()) do
					width -= 1
				end
				table.insert(result, newline) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
				width = 0
			end
			table.insert(result, token) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
			width += token.length
			table.insert(result, " ") --[[ ROBLOX CHECK: check if 'result' is an Array ]]
			width += 1
		end
		if Boolean.toJSBoolean(strip()) then
			width -= 1
		end
		return width
	end -- wrap the PGN output at max_width
	local currentWidth = 0
	do
		local i = 0
		while
			i
			< moves.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			if
				currentWidth + moves[tostring(i)].length
				> maxWidth --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			then
				if
					Boolean.toJSBoolean(
						Array.includes(moves[tostring(i)], "{") --[[ ROBLOX CHECK: check if 'moves[i]' is an Array ]]
					)
				then
					currentWidth = wrapComment(currentWidth, moves[tostring(i)])
					i += 1
					continue
				end
			end -- if the current move will push past max_width
			if
				currentWidth + moves[tostring(i)].length > maxWidth --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				and i ~= 0
			then
				-- don't end the line with whitespace
				if result[tostring(result.length - 1)] == " " then
					table.remove(result) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
				end
				table.insert(result, newline) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
				currentWidth = 0
			elseif i ~= 0 then
				table.insert(result, " ") --[[ ROBLOX CHECK: check if 'result' is an Array ]]
				currentWidth += 1
			end
			table.insert(result, moves[tostring(i)]) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
			currentWidth += moves[tostring(i)].length
			i += 1
		end
	end
	return Array.join(result, "") --[[ ROBLOX CHECK: check if 'result' is an Array ]]
end
function Chess_private:header(
	...: string
): Record<string, string | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]>
	local args = { ... }
	do
		local i = 0
		while
			i
			< args.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			if
				typeof(args[tostring(i)]) == "string"
				and typeof(args[tostring(i + 1)]) == "string"
			then
				self._header[tostring(args[tostring(i)])] = args[tostring(i + 1)]
			end
			i += 2
		end
	end
	return self._header
end
function Chess_private:setHeader(key: string, value: string): Record<string, string>
	local ref = if value ~= nil then value else SEVEN_TAG_ROSTER[tostring(key)]
	self._header[tostring(key)] = if ref ~= nil then ref else nil
	return self:getHeaders()
end
function Chess_private:removeHeader(key: string): boolean
	if Array.indexOf(Object.keys(self._header), tostring(key)) ~= -1 then
		self._header[tostring(key)] = Boolean.toJSBoolean(SEVEN_TAG_ROSTER[tostring(key)])
				and SEVEN_TAG_ROSTER[tostring(key)]
			or nil
		return true
	end
	return false
end
function Chess_private:getHeaders(): Record<string, string>
	local nonNullHeaders: Record<string, string> = {}
	for _, ref in Object.entries(self._header) do
		local key, value = table.unpack(ref, 1, 2)
		if value ~= nil then
			nonNullHeaders[tostring(key)] = value
		end
	end
	return nonNullHeaders
end
function Chess_private:loadPgn(pgn: string, ref0_: { strict: boolean?, newlineChar: string? }?)
	local ref0: { strict: boolean?, newlineChar: string? } = if ref0_ ~= nil then ref0_ else {}
	local strict, newlineChar =
		if ref0.strict == nil then false else ref0.strict,
		if ref0.newlineChar == nil then "\r?\n" else ref0.newlineChar
	-- If newlineChar is not the default, replace all instances with \n
	if newlineChar ~= "\r?\n" then
		pgn = pgn:replace(RegExp.new(newlineChar, "g"), "\n")
	end
	local parsedPgn = parse(pgn) -- Put the board in the starting position
	self:reset() -- parse PGN header
	local headers = parsedPgn.headers
	local fen = ""
	for key in headers do
		-- check to see user is including fen (possibly with wrong tag case)
		if key:toLowerCase() == "fen" then
			fen = headers[tostring(key)]
		end
		self:header(key, headers[tostring(key)])
	end
	--[[
     * the permissive parser should attempt to load a fen tag, even if it's the
     * wrong case and doesn't include a corresponding [SetUp "1"] tag
     ]]
	if not Boolean.toJSBoolean(strict) then
		if Boolean.toJSBoolean(fen) then
			self:load(fen, { preserveHeaders = true })
		end
	else
		--[[
       * strict parser - load the starting position indicated by [Setup '1']
       * and [FEN position]
       ]]
		if headers["SetUp"] == "1" then
			if not (Array.indexOf(Object.keys(headers), "FEN") ~= -1) then
				error(Error.new("Invalid PGN: FEN tag must be supplied with SetUp tag"))
			end -- don't clear the headers when loading
			self:load(headers["FEN"], { preserveHeaders = true })
		end
	end
	local node = parsedPgn.root
	while Boolean.toJSBoolean(node) do
		if Boolean.toJSBoolean(node.move) then
			local suffixAnnotation = node.suffixAnnotation
			local move = self:_moveFromSan(node.move, strict)
			if not Boolean.toJSBoolean(move) then
				error(Error.new(("Invalid move in PGN: %s"):format(tostring(node.move))))
			else
				self:_makeMove(move)
				self:_incPositionCount()
				if Boolean.toJSBoolean(suffixAnnotation) then
					self._suffixes[tostring(self:fen())] = suffixAnnotation :: Suffix
				end
			end
		end
		if node.comment ~= nil then
			self._comments[tostring(self:fen())] = node.comment
		end
		node = node.variations[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
	end
	--[[
     * Per section 8.2.6 of the PGN spec, the Result tag pair must match match
     * the termination marker. Only do this when headers are present, but the
     * result tag is missing
     ]]
	local result = parsedPgn.result
	if
		Boolean.toJSBoolean((function()
			local ref = if Boolean.toJSBoolean(result)
				then Object.keys(self._header).length
				else result
			return if Boolean.toJSBoolean(ref) then self._header["Result"] ~= result else ref
		end)())
	then
		self:setHeader("Result", result)
	end
end
function Chess_private:_moveToSan(move: InternalMove, moves: Array<InternalMove>): string
	local output = ""
	if
		Boolean.toJSBoolean(
			bit32.band(move.flags, BITS.KSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		output = "O-O"
	elseif
		Boolean.toJSBoolean(
			bit32.band(move.flags, BITS.QSIDE_CASTLE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		output = "O-O-O"
	elseif
		Boolean.toJSBoolean(
			bit32.band(move.flags, BITS.NULL_MOVE) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
		)
	then
		return SAN_NULLMOVE
	else
		if move.piece ~= PAWN then
			local disambiguator = getDisambiguator(move, moves)
			output += move.piece:toUpperCase() + disambiguator
		end
		if
			Boolean.toJSBoolean(
				bit32.band(
					move.flags,
					bit32.bor(BITS.CAPTURE, BITS.EP_CAPTURE) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
				) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			)
		then
			if move.piece == PAWN then
				output += algebraic(move.from)[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				]
			end
			output ..= "x"
		end
		output += algebraic(move.to)
		if Boolean.toJSBoolean(move.promotion) then
			output ..= "=" .. tostring(move.promotion:toUpperCase())
		end
	end
	self:_makeMove(move)
	if Boolean.toJSBoolean(self:isCheck()) then
		if Boolean.toJSBoolean(self:isCheckmate()) then
			output ..= "#"
		else
			output ..= "+"
		end
	end
	self:_undoMove()
	return output
end
function Chess_private:_moveFromSan(
	move: string,
	strict_: boolean?
): InternalMove | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	local strict: boolean = if strict_ ~= nil then strict_ else false
	-- strip off any move decorations: e.g Nf3+?! becomes Nf3
	local cleanMove = strippedSan(move)
	if not Boolean.toJSBoolean(strict) then
		if cleanMove == "0-0" then
			cleanMove = "O-O"
		elseif cleanMove == "0-0-0" then
			cleanMove = "O-O-O"
		end
	end --first implementation of null with a dummy move (black king moves from a8 to a8), maybe this can be implemented better
	if
		cleanMove == SAN_NULLMOVE --[[ ROBLOX CHECK: loose equality used upstream ]]
	then
		local res: InternalMove =
			{ color = self._turn, from = 0, to = 0, piece = "k", flags = BITS.NULL_MOVE }
		return res
	end
	local pieceType = inferPieceType(cleanMove)
	local moves = self:_moves({ legal = true, piece = pieceType }) -- strict parser
	do
		local i, len = 0, moves.length
		while
			i
			< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			if cleanMove == strippedSan(self:_moveToSan(moves[tostring(i)], moves)) then
				return moves[tostring(i)]
			end
			i += 1
		end
	end -- the strict parser failed
	if Boolean.toJSBoolean(strict) then
		return nil
	end
	local piece = nil
	local matches = nil
	local from = nil
	local to = nil
	local promotion = nil
	--[[
     * The default permissive (non-strict) parser allows the user to parse
     * non-standard chess notations. This parser is only run after the strict
     * Standard Algebraic Notation (SAN) parser has failed.
     *
     * When running the permissive parser, we'll run a regex to grab the piece, the
     * to/from square, and an optional promotion piece. This regex will
     * parse common non-standard notation like: Pe2-e4, Rc1c4, Qf3xf7,
     * f7f8q, b1c3
     *
     * NOTE: Some positions and moves may be ambiguous when using the permissive
     * parser. For example, in this position: 6k1/8/8/B7/8/8/8/BN4K1 w - - 0 1,
     * the move b1c3 may be interpreted as Nc3 or B1c3 (a disambiguated bishop
     * move). In these cases, the permissive parser will default to the most
     * basic interpretation (which is b1c3 parsing to Nc3).
     ]]
	local overlyDisambiguated = false
	matches = cleanMove:match(
		RegExp("([pnbrqkPNBRQK])?([a-h][1-8])x?-?([a-h][1-8])([qrbnQRBN])?") --     piece         from              to       promotion
	)
	if Boolean.toJSBoolean(matches) then
		piece = matches[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		from = matches[
			3 --[[ ROBLOX adaptation: added 1 to array index ]]
		] :: Square
		to = matches[
			4 --[[ ROBLOX adaptation: added 1 to array index ]]
		] :: Square
		promotion = matches[
			5 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		if
			from.length == 1 --[[ ROBLOX CHECK: loose equality used upstream ]]
		then
			overlyDisambiguated = true
		end
	else
		--[[
       * The [a-h]?[1-8]? portion of the regex below handles moves that may be
       * overly disambiguated (e.g. Nge7 is unnecessary and non-standard when
       * there is one legal knight move to e7). In this case, the value of
       * 'from' variable will be a rank or file, not a square.
       ]]
		matches =
			cleanMove:match(RegExp("([pnbrqkPNBRQK])?([a-h]?[1-8]?)x?-?([a-h][1-8])([qrbnQRBN])?"))
		if Boolean.toJSBoolean(matches) then
			piece = matches[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			]
			from = matches[
				3 --[[ ROBLOX adaptation: added 1 to array index ]]
			] :: Square
			to = matches[
				4 --[[ ROBLOX adaptation: added 1 to array index ]]
			] :: Square
			promotion = matches[
				5 --[[ ROBLOX adaptation: added 1 to array index ]]
			]
			if
				from.length == 1 --[[ ROBLOX CHECK: loose equality used upstream ]]
			then
				overlyDisambiguated = true
			end
		end
	end
	pieceType = inferPieceType(cleanMove)
	moves = self:_moves({
		legal = true,
		piece = if Boolean.toJSBoolean(piece) then piece :: PieceSymbol else pieceType,
	})
	if not Boolean.toJSBoolean(to) then
		return nil
	end
	do
		local i, len = 0, moves.length
		while
			i
			< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			if not Boolean.toJSBoolean(from) then
				-- if there is no from square, it could be just 'x' missing from a capture
				if
					cleanMove
					== strippedSan(self:_moveToSan(moves[tostring(i)], moves)):replace("x", "")
				then
					return moves[tostring(i)]
				end -- hand-compare move properties with the results from our permissive regex
			elseif
				(
					not Boolean.toJSBoolean(piece)
					or piece:toLowerCase() == moves[tostring(i)].piece --[[ ROBLOX CHECK: loose equality used upstream ]]
				)
				and Ox88[tostring(from)] == moves[tostring(i)].from --[[ ROBLOX CHECK: loose equality used upstream ]]
				and Ox88[tostring(to)] == moves[tostring(i)].to --[[ ROBLOX CHECK: loose equality used upstream ]]
				and (
					not Boolean.toJSBoolean(promotion)
					or promotion:toLowerCase() == moves[tostring(i)].promotion --[[ ROBLOX CHECK: loose equality used upstream ]]
				)
			then
				return moves[tostring(i)]
			elseif Boolean.toJSBoolean(overlyDisambiguated) then
				--[[
         * SPECIAL CASE: we parsed a move string that may have an unneeded
         * rank/file disambiguator (e.g. Nge7).  The 'from' variable will
         ]]
				local square = algebraic(moves[tostring(i)].from)
				if
					(
						not Boolean.toJSBoolean(piece)
						or piece:toLowerCase() == moves[tostring(i)].piece --[[ ROBLOX CHECK: loose equality used upstream ]]
					)
					and Ox88[tostring(to)] == moves[tostring(i)].to --[[ ROBLOX CHECK: loose equality used upstream ]]
					and (
						from
							== square[
								1 --[[ ROBLOX adaptation: added 1 to array index ]]
							] --[[ ROBLOX CHECK: loose equality used upstream ]]
						or from
							== square[
								2 --[[ ROBLOX adaptation: added 1 to array index ]]
							] --[[ ROBLOX CHECK: loose equality used upstream ]]
					)
					and (
						not Boolean.toJSBoolean(promotion)
						or promotion:toLowerCase() == moves[tostring(i)].promotion --[[ ROBLOX CHECK: loose equality used upstream ]]
					)
				then
					return moves[tostring(i)]
				end
			end
			i += 1
		end
	end
	return nil
end
function Chess_private:ascii(): string
	local s = "   +------------------------+\n"
	do
		local i = Ox88.a8
		while
			i
			<= Ox88.h1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		do
			-- display the rank
			if file(i) == 0 then
				s ..= " " .. tostring(("87654321")[tostring(rank(i))]) .. " |"
			end
			if Boolean.toJSBoolean(self._board[tostring(i)]) then
				local piece = self._board[tostring(i)].type
				local color = self._board[tostring(i)].color
				local symbol = if color == WHITE then piece:toUpperCase() else piece:toLowerCase()
				s ..= " " .. tostring(symbol) .. " "
			else
				s ..= " . "
			end
			if
				Boolean.toJSBoolean(
					bit32.band(i + 1, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				s ..= "|\n"
				i += 8
			end
			i += 1
		end
	end
	s ..= "   +------------------------+\n"
	s ..= "     a  b  c  d  e  f  g  h"
	return s
end
function Chess_private:perft(depth: number): number
	local moves = self:_moves({ legal = false })
	local nodes = 0
	local color = self._turn
	do
		local i, len = 0, moves.length
		while
			i
			< len --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			self:_makeMove(moves[tostring(i)])
			if not Boolean.toJSBoolean(self:_isKingAttacked(color)) then
				if
					depth - 1
					> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				then
					nodes += self:perft(depth - 1)
				else
					nodes += 1
				end
			end
			self:_undoMove()
			i += 1
		end
	end
	return nodes
end
function Chess_private:setTurn(color: Color): boolean
	if
		self._turn == color --[[ ROBLOX CHECK: loose equality used upstream ]]
	then
		return false
	end
	self:move("--")
	return true
end
function Chess_private:turn(): Color
	return self._turn
end
function Chess_private:board(): Array<
	Array<{ square: Square, type: PieceSymbol, color: Color } | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]>
>
	local output = {}
	local row = {}
	do
		local i = Ox88.a8
		while
			i
			<= Ox88.h1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]]
		do
			if
				self._board[tostring(i)] == nil --[[ ROBLOX CHECK: loose equality used upstream ]]
			then
				table.insert(row, nil) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
			else
				table.insert(row, {
					square = algebraic(i),
					type = self._board[tostring(i)].type,
					color = self._board[tostring(i)].color,
				}) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
			end
			if
				Boolean.toJSBoolean(
					bit32.band(i + 1, 0x88) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
				)
			then
				table.insert(output, row) --[[ ROBLOX CHECK: check if 'output' is an Array ]]
				row = {}
				i += 8
			end
			i += 1
		end
	end
	return output
end
function Chess_private:squareColor(
	square: Square
): "light" | "dark" | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	if Array.indexOf(Object.keys(Ox88), tostring(square)) ~= -1 then
		local sq = Ox88[tostring(square)]
		return if (rank(sq) + file(sq)) % 2 == 0 then "light" else "dark"
	end
	return nil
end
function Chess_private:history(): Array<string>
	error("not implemented method")
end
function Chess_private:history(ref0: { verbose: true }): Array<Move>
	local verbose = ref0.verbose
	error("not implemented method")
end
function Chess_private:history(ref0: { verbose: false }): Array<string>
	local verbose = ref0.verbose
	error("not implemented method")
end
function Chess_private:history(ref0: { verbose: boolean }): Array<string> | Array<Move>
	local verbose = ref0.verbose
	error("not implemented method")
end
function Chess_private:history(ref0_: { verbose: boolean? }?)
	local ref0: { verbose: boolean? } = if ref0_ ~= nil then ref0_ else {}
	local verbose = if ref0.verbose == nil then false else ref0.verbose
	local reversedHistory = {}
	local moveHistory = {}
	while
		self._history.length
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	do
		table.insert(reversedHistory, self:_undoMove()) --[[ ROBLOX CHECK: check if 'reversedHistory' is an Array ]]
	end
	while true do
		local move = table.remove(reversedHistory) --[[ ROBLOX CHECK: check if 'reversedHistory' is an Array ]]
		if not Boolean.toJSBoolean(move) then
			break
		end
		if Boolean.toJSBoolean(verbose) then
			table.insert(moveHistory, self:_createMove(move)) --[[ ROBLOX CHECK: check if 'moveHistory' is an Array ]]
		else
			table.insert(moveHistory, self:_moveToSan(move, self:_moves())) --[[ ROBLOX CHECK: check if 'moveHistory' is an Array ]]
		end
		self:_makeMove(move)
	end
	return moveHistory
end
function Chess_private:_getPositionCount(
	hash: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]]
): number
	local ref = self._positionCount:get(hash)
	return if ref ~= nil then ref else 0
end
function Chess_private:_incPositionCount()
	self._positionCount:set(self._hash, (function()
		local ref = self._positionCount:get(self._hash)
		return if ref ~= nil then ref else 0
	end)() + 1)
end
function Chess_private:_decPositionCount(
	hash: any --[[ ROBLOX TODO: Unhandled node for type: TSBigIntKeyword ]] --[[ bigint ]]
)
	local ref = self._positionCount:get(hash)
	local currentCount = if ref ~= nil then ref else 0
	if currentCount == 1 then
		self._positionCount:delete(hash)
	else
		self._positionCount:set(hash, currentCount - 1)
	end
end
function Chess_private:_pruneComments()
	local reversedHistory = {}
	local currentComments: Record<string, string> = {}
	local function copyComment(fen: string)
		if Array.indexOf(Object.keys(self._comments), tostring(fen)) ~= -1 then
			currentComments[tostring(fen)] = self._comments[tostring(fen)]
		end
	end
	while
		self._history.length
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	do
		table.insert(reversedHistory, self:_undoMove()) --[[ ROBLOX CHECK: check if 'reversedHistory' is an Array ]]
	end
	copyComment(self:fen())
	while true do
		local move = table.remove(reversedHistory) --[[ ROBLOX CHECK: check if 'reversedHistory' is an Array ]]
		if not Boolean.toJSBoolean(move) then
			break
		end
		self:_makeMove(move)
		copyComment(self:fen())
	end
	self._comments = currentComments
end
function Chess_private:getComment(): string
	return self._comments[tostring(self:fen())]
end
function Chess_private:setComment(comment: string)
	self._comments[tostring(self:fen())] = comment:replace("{", "["):replace("}", "]")
end
function Chess_private:deleteComment(): string
	return self:removeComment()
end
function Chess_private:removeComment(): string
	local comment = self._comments[tostring(self:fen())]
	self._comments[tostring(self:fen())] = nil
	return comment
end
function Chess_private:getComments(
): Array<{ fen: string, comment: string?, suffixAnnotation: string? }>
	self:_pruneComments()
	local allFenKeys = Set.new()
	Array.forEach(Object.keys(self._comments), function(fen)
		return allFenKeys:add(fen)
	end) --[[ ROBLOX CHECK: check if 'Object.keys(this._comments)' is an Array ]]
	Array.forEach(Object.keys(self._suffixes), function(fen)
		return allFenKeys:add(fen)
	end) --[[ ROBLOX CHECK: check if 'Object.keys(this._suffixes)' is an Array ]]
	local result: Array<{ fen: string, comment: string?, suffixAnnotation: string? }> = {}
	for _, fen in allFenKeys do
		local commentContent = self._comments[tostring(fen)]
		local suffixAnnotation = self._suffixes[tostring(fen)]
		local entry: { fen: string, comment: string?, suffixAnnotation: string? } = { fen = fen }
		if commentContent ~= nil then
			entry.comment = commentContent
		end
		if suffixAnnotation ~= nil then
			entry.suffixAnnotation = suffixAnnotation
		end
		table.insert(result, entry) --[[ ROBLOX CHECK: check if 'result' is an Array ]]
	end
	return result
end
function Chess_private:getSuffixAnnotation(fen: string?): Suffix | nil
	local key = if fen ~= nil then fen else self:fen()
	return self._suffixes[tostring(key)]
end
function Chess_private:setSuffixAnnotation(suffix: Suffix, fen: string?): ()
	if
		not Boolean.toJSBoolean(
			Array.includes(SUFFIX_LIST, suffix) --[[ ROBLOX CHECK: check if 'SUFFIX_LIST' is an Array ]]
		)
	then
		error(Error.new(("Invalid suffix: %s"):format(tostring(suffix))))
	end
	self._suffixes[tostring(Boolean.toJSBoolean(fen) and fen or self:fen())] = suffix
end
function Chess_private:removeSuffixAnnotation(fen: string?): Suffix | nil
	local key = Boolean.toJSBoolean(fen) and fen or self:fen()
	local old = self._suffixes[tostring(key)]
	self._suffixes[tostring(key)] = nil
	return old
end
function Chess_private:deleteComments(): Array<{ fen: string, comment: string }>
	return self:removeComments()
end
function Chess_private:removeComments(): Array<{ fen: string, comment: string }>
	self:_pruneComments()
	return Array.map(Object.keys(self._comments), function(fen)
		local comment = self._comments[tostring(fen)]
		self._comments[tostring(fen)] = nil
		return { fen = fen, comment = comment }
	end) --[[ ROBLOX CHECK: check if 'Object.keys(this._comments)' is an Array ]]
end
function Chess_private:setCastlingRights(
	color: Color,
	rights: Partial<Record<typeof(KING) | typeof(QUEEN), boolean>>
): boolean
	for _, side in { KING, QUEEN } :: const do
		if rights[tostring(side)] ~= nil then
			if Boolean.toJSBoolean(rights[tostring(side)]) then
				self._castling[tostring(color)] =
					bit32.bor(self._castling[tostring(color)], SIDES[tostring(side)]) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
			else
				self._castling[tostring(color)] = bit32.band(
					self._castling[tostring(color)],
					bit32.bnot(SIDES[tostring(side)]) --[[ ROBLOX CHECK: `bit32.bnot` clamps arguments and result to [0,2^32 - 1] ]]
				) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			end
		end
	end
	self:_updateCastlingRights()
	local result = self:getCastlingRights(color)
	return (rights[tostring(KING)] == nil or rights[tostring(KING)] == result[tostring(KING)])
		and (rights[tostring(QUEEN)] == nil or rights[tostring(QUEEN)] == result[tostring(QUEEN)])
end
function Chess_private:getCastlingRights(color: Color): { KING: boolean, QUEEN: boolean }
	return {
		[tostring(KING)] = bit32.band(self._castling[tostring(color)], SIDES[tostring(KING)]) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			~= 0,
		[tostring(QUEEN)] = bit32.band(self._castling[tostring(color)], SIDES[tostring(QUEEN)]) --[[ ROBLOX CHECK: `bit32.band` clamps arguments and result to [0,2^32 - 1] ]]
			~= 0,
	}
end
function Chess_private:moveNumber(): number
	return self._moveNumber
end
exports.Chess = Chess
return exports

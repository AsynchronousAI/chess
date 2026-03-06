--!native
--!optimize 2
--!strict

local Utils = require("./utils")
local zobrist = require("./zobrist")
local transposition = if game then game:GetService("SharedTableRegistry"):GetSharedTable("EvaluationTransposition") else {}



local COLOR_STRIDE  = 6 * 64  -- 384
local PIECE_STRIDE  = 64

local pst_raw = {
	[Utils.PAWN] = {
		198,198,198,198,198,198,198,198,
		178,198,198,198,198,198,198,178,
		178,198,198,198,198,198,198,178,
		178,198,208,218,218,208,198,178,
		178,198,218,238,238,218,198,178,
		178,198,208,218,218,208,198,178,
		178,198,198,198,198,198,198,178,
		198,198,198,198,198,198,198,198,
	},
	[Utils.BISHOP] = {
		797,824,817,808,808,817,824,797,
		814,841,834,825,825,834,841,814,
		818,845,838,829,829,838,845,818,
		824,851,844,835,835,844,851,824,
		827,854,847,838,838,847,854,827,
		826,853,846,837,837,846,853,826,
		817,844,837,828,828,837,844,817,
		792,819,812,803,803,812,819,792,
	},
	[Utils.KNIGHT] = {
		627,762,786,798,798,786,762,627,
		763,798,822,834,834,822,798,763,
		817,852,876,888,888,876,852,817,
		797,832,856,868,868,856,832,797,
		799,834,858,870,870,858,834,799,
		758,793,817,829,829,817,793,758,
		739,774,798,810,810,798,774,739,
		683,718,742,754,754,742,718,683,
	},
	[Utils.ROOK] = {
		1258,1263,1268,1272,1272,1268,1263,1258,
		1258,1263,1268,1272,1272,1268,1263,1258,
		1258,1263,1268,1272,1272,1268,1263,1258,
		1258,1263,1268,1272,1272,1268,1263,1258,
		1258,1263,1268,1272,1272,1268,1263,1258,
		1258,1263,1268,1272,1272,1268,1263,1258,
		1258,1263,1268,1272,1272,1268,1263,1258,
		1258,1263,1268,1272,1272,1268,1263,1258,
	},
	[Utils.QUEEN] = {
		2529,2529,2529,2529,2529,2529,2529,2529,
		2529,2529,2529,2529,2529,2529,2529,2529,
		2529,2529,2529,2529,2529,2529,2529,2529,
		2529,2529,2529,2529,2529,2529,2529,2529,
		2529,2529,2529,2529,2529,2529,2529,2529,
		2529,2529,2529,2529,2529,2529,2529,2529,
		2529,2529,2529,2529,2529,2529,2529,2529,
		2529,2529,2529,2529,2529,2529,2529,2529,
	},
	[Utils.KING] = {
		60098,60132,60073,60025,60025,60073,60132,60098,
		60119,60153,60094,60046,60046,60094,60153,60119,
		60146,60180,60121,60073,60073,60121,60180,60146,
		60173,60207,60148,60100,60100,60148,60207,60173,
		60196,60230,60171,60123,60123,60171,60230,60196,
		60224,60258,60199,60151,60151,60199,60258,60224,
		60287,60321,60262,60214,60214,60262,60321,60287,
		60298,60332,60273,60225,60225,60273,60332,60298,
	},
}

local PST = table.create(2 * COLOR_STRIDE, 0)

for piece, table64 in pst_raw do
	local white_base = Utils.WHITE * COLOR_STRIDE + piece * PIECE_STRIDE
	local black_base = Utils.BLACK * COLOR_STRIDE + piece * PIECE_STRIDE
	for square = 0, 63 do
		PST[white_base + square] = -(table64[square + 1] or 0)
		PST[black_base + square] =   table64[(63 - square) + 1] or 0
	end
end

local function evaluate(board: Utils.Board): number
	local value = 0
	for pos = 0, 63 do
		local pieceInfo = board.pieceTable[pos]
		if pieceInfo then
			local piece = bit32.rshift(pieceInfo, 6)
			local color = bit32.band(pieceInfo, 63)
			value += PST[color * COLOR_STRIDE + piece * PIECE_STRIDE + pos]
		end
	end
	return value
end

return {
	pst_raw     = pst_raw,
	PST         = PST,
	COLOR_STRIDE = COLOR_STRIDE,
	PIECE_STRIDE = PIECE_STRIDE,
	evaluate    = evaluate, -- while this fully evaluates.
	eval = function(board) -- this incorporates hashing
		if board.eval ~= nil then
			return board.eval
		end

		local hash = --[[board.hash or]] zobrist.hash(board)
		if transposition and hash then
			local cached = transposition[hash]
			if cached ~= nil then
				board.eval = cached
				return cached
			end
		end

		board.eval = evaluate(board)
		if transposition and hash then
			transposition[hash] = board.eval
		end
		return board.eval
	end
}

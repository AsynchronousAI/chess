--!native
--!optimize 2
local u64 = require("./int64")
local ZERO    = u64.ZERO
local bor     = u64.bor
local band    = u64.band
local sub     = u64.sub
local bnot    = u64.bnot
local countrz = u64.countrz
local countlz = u64.countlz
local ONE     = u64.ONE
local Utils      = require("./utils")
local unit_board = Utils.unit_board

local SHIFT32 = 2 ^ 32

local function rook_magic_index(occ: vector, magic_hi: number, magic_lo: number, bits: number): number
	local occ_hi, occ_lo = u64.to_pair(occ)
	local hi32 = (occ_hi * magic_hi) // SHIFT32 + (occ_lo * magic_lo) // SHIFT32
	return bit32.rshift(bit32.band(hi32, 0xFFFFFFFF), 32 - bits)
end

local function bishop_magic_index(occ: vector, magic_lo: number, bits: number): number
	local occ_hi, occ_lo = u64.to_pair(occ)
	local folded = bit32.bxor(occ_lo, occ_hi)
	local hi32   = (folded * magic_lo) // SHIFT32
	return bit32.rshift(bit32.band(hi32, 0xFFFFFFFF), 32 - bits)
end

local function enumerate_subsets(mask: vector): {vector}
	local subsets = {}
	local subset = ZERO
	repeat
		table.insert(subsets, subset)
		subset = band(sub(subset, mask), mask)
	until subset == ZERO
	return subsets
end

local function classical_rook_attacks(square: number, occ: vector, rays): vector
	local function ray(ray_bb, positive: boolean)
		local blockers = band(ray_bb, occ)
		if blockers == ZERO then return ray_bb end
		local blocker_sq = if positive then countrz(blockers) else 63 - countlz(blockers)
		local blocker_bb = unit_board(blocker_sq)
		return band(ray_bb, if positive
			then bor(blocker_bb, sub(blocker_bb, ONE))
			else bnot(sub(blocker_bb, ONE)))
	end
	return bor(
		ray(rays.NORTH[square], true),
		ray(rays.EAST[square],  true),
		ray(rays.SOUTH[square], false),
		ray(rays.WEST[square],  false)
	)
end

local function classical_bishop_attacks(square: number, occ: vector, rays): vector
	local function ray(ray_bb, positive: boolean)
		local blockers = band(ray_bb, occ)
		if blockers == ZERO then return ray_bb end
		local blocker_sq = if positive then countrz(blockers) else 63 - countlz(blockers)
		local blocker_bb = unit_board(blocker_sq)
		return band(ray_bb, if positive
			then bor(blocker_bb, sub(blocker_bb, ONE))
			else bnot(sub(blocker_bb, ONE)))
	end
	return bor(
		ray(rays.NE[square], true),
		ray(rays.NW[square], true),
		ray(rays.SE[square], false),
		ray(rays.SW[square], false)
	)
end

local function make_rook_mask(square: number): vector
	local rank = math.floor(square / 8)
	local file  = square % 8
	local mask  = ZERO
	for r = rank + 1, 6 do mask = bor(mask, unit_board(r * 8 + file)) end
	for r = rank - 1, 1, -1 do mask = bor(mask, unit_board(r * 8 + file)) end
	for f = file + 1, 6 do mask = bor(mask, unit_board(rank * 8 + f)) end
	for f = file - 1, 1, -1 do mask = bor(mask, unit_board(rank * 8 + f)) end
	return mask
end

local function make_bishop_mask(square: number): vector
	local rank = math.floor(square / 8)
	local file  = square % 8
	local mask  = ZERO
	local r, f
	r, f = rank + 1, file + 1; while r <= 6 and f <= 6 do mask = bor(mask, unit_board(r*8+f)); r+=1; f+=1 end
	r, f = rank + 1, file - 1; while r <= 6 and f >= 1 do mask = bor(mask, unit_board(r*8+f)); r+=1; f-=1 end
	r, f = rank - 1, file + 1; while r >= 1 and f <= 6 do mask = bor(mask, unit_board(r*8+f)); r-=1; f+=1 end
	r, f = rank - 1, file - 1; while r >= 1 and f >= 1 do mask = bor(mask, unit_board(r*8+f)); r-=1; f-=1 end
	return mask
end

return function(
	ROOK_BITS, BISHOP_BITS,
	ROOK_MAGICS_HI, ROOK_MAGICS_LO, BISHOP_MAGICS_LO,
	rays
)
	local ROOK_MASK   = table.create(64)
	local BISHOP_MASK = table.create(64)
	local ROOK_TABLE:   {{vector}} = table.create(64)
	local BISHOP_TABLE: {{vector}} = table.create(64)

	for square = 0, 63 do
		local rmask = make_rook_mask(square)
		ROOK_MASK[square] = rmask
		local rbits  = ROOK_BITS[square + 1]
		local rtable = table.create(bit32.lshift(1, rbits))
		ROOK_TABLE[square] = rtable
		for _, occ in enumerate_subsets(rmask) do
			local idx = rook_magic_index(occ, ROOK_MAGICS_HI[square + 1], ROOK_MAGICS_LO[square + 1], rbits)
			rtable[idx] = classical_rook_attacks(square, occ, rays)
		end

		local bmask = make_bishop_mask(square)
		BISHOP_MASK[square] = bmask
		local bbits  = BISHOP_BITS[square + 1]
		local btable = table.create(bit32.lshift(1, bbits))
		BISHOP_TABLE[square] = btable
		for _, occ in enumerate_subsets(bmask) do
			local idx = bishop_magic_index(occ, BISHOP_MAGICS_LO[square + 1], bbits)
			btable[idx] = classical_bishop_attacks(square, occ, rays)
		end
	end

	return ROOK_MASK, BISHOP_MASK, ROOK_TABLE, BISHOP_TABLE
end

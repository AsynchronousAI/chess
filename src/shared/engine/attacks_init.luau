--!native
--!optimize 2
local Utils = require("./utils")

local bb_countrz    = Utils.bb_countrz
local bb_countlz    = Utils.bb_countlz
local bb_sub_lo     = Utils.bb_sub_lo
local bb_sub_hi     = Utils.bb_sub_hi
local BIT_LO        = Utils.BIT_LO
local BIT_HI        = Utils.BIT_HI

local SHIFT32 = 2 ^ 32

local function rook_magic_index(occ_hi: number, occ_lo: number, magic_hi: number, magic_lo: number, bits: number): number
	local hi32 = (occ_hi * magic_hi) // SHIFT32 + (occ_lo * magic_lo) // SHIFT32
	return bit32.rshift(bit32.band(hi32, 0xFFFFFFFF), 32 - bits)
end

local function bishop_magic_index(occ_hi: number, occ_lo: number, magic_lo: number, bits: number): number
	local folded = bit32.bxor(occ_lo, occ_hi)
	local hi32   = (folded * magic_lo) // SHIFT32
	return bit32.rshift(bit32.band(hi32, 0xFFFFFFFF), 32 - bits)
end

local function enumerate_subsets(mask_hi: number, mask_lo: number): ({number}, {number})
	local los = {}
	local his = {}
	local sub_lo = 0
	local sub_hi = 0
	repeat
		table.insert(los, sub_lo)
		table.insert(his, sub_hi)
		-- subset = (subset - mask) & mask
		local new_lo = bb_sub_lo(sub_lo, mask_lo)
		local new_hi = bb_sub_hi(sub_hi, mask_hi, sub_lo, mask_lo)
		sub_lo = bit32.band(new_lo, mask_lo)
		sub_hi = bit32.band(new_hi, mask_hi)
	until sub_lo == 0 and sub_hi == 0
	return los, his
end

local function classical_rook_attacks(square: number, occ_hi: number, occ_lo: number, rays): (number, number)
	local result_lo = 0
	local result_hi = 0

	local function ray(ray_lo: number, ray_hi: number, positive: boolean)
		local blk_lo = bit32.band(ray_lo, occ_lo)
		local blk_hi = bit32.band(ray_hi, occ_hi)
		if blk_lo == 0 and blk_hi == 0 then
			result_lo = bit32.bor(result_lo, ray_lo)
			result_hi = bit32.bor(result_hi, ray_hi)
			return
		end
		local blocker_sq
		if positive then
			blocker_sq = bb_countrz(blk_hi, blk_lo)
		else
			blocker_sq = 63 - bb_countlz(blk_hi, blk_lo)
		end
		local blo = BIT_LO[blocker_sq]
		local bhi = BIT_HI[blocker_sq]

		local m_hi: number
		if positive then
			local s_lo = bb_sub_lo(blo, 1)
			local s_hi = bb_sub_hi(bhi, 0, blo, 1)
			m_lo = bit32.bor(blo, s_lo)
			m_hi = bit32.bor(bhi, s_hi)
		else
			local s_lo = bb_sub_lo(blo, 1)
			local s_hi = bb_sub_hi(bhi, 0, blo, 1)
			m_lo = bit32.bnot(s_lo)
			m_hi = bit32.bnot(s_hi)
		end
		result_lo = bit32.bor(result_lo, bit32.band(ray_lo, m_lo))
		result_hi = bit32.bor(result_hi, bit32.band(ray_hi, m_hi))
	end

	ray(rays.NORTH_LO[square], rays.NORTH_HI[square], true)
	ray(rays.EAST_LO[square],  rays.EAST_HI[square],  true)
	ray(rays.SOUTH_LO[square], rays.SOUTH_HI[square], false)
	ray(rays.WEST_LO[square],  rays.WEST_HI[square],  false)
	return result_hi, result_lo
end

local function classical_bishop_attacks(square: number, occ_hi: number, occ_lo: number, rays): (number, number)
	local result_lo = 0
	local result_hi = 0

	local function ray(ray_lo: number, ray_hi: number, positive: boolean)
		local blk_lo = bit32.band(ray_lo, occ_lo)
		local blk_hi = bit32.band(ray_hi, occ_hi)
		if blk_lo == 0 and blk_hi == 0 then
			result_lo = bit32.bor(result_lo, ray_lo)
			result_hi = bit32.bor(result_hi, ray_hi)
			return
		end
		local blocker_sq
		if positive then
			blocker_sq = bb_countrz(blk_hi, blk_lo)
		else
			blocker_sq = 63 - bb_countlz(blk_hi, blk_lo)
		end
		local blo = BIT_LO[blocker_sq]
		local bhi = BIT_HI[blocker_sq]
		local m_lo: number
		local m_hi: number
		if positive then
			local s_lo = bb_sub_lo(blo, 1)
			local s_hi = bb_sub_hi(bhi, 0, blo, 1)
			m_lo = bit32.bor(blo, s_lo)
			m_hi = bit32.bor(bhi, s_hi)
		else
			local s_lo = bb_sub_lo(blo, 1)
			local s_hi = bb_sub_hi(bhi, 0, blo, 1)
			m_lo = bit32.bnot(s_lo)
			m_hi = bit32.bnot(s_hi)
		end
		result_lo = bit32.bor(result_lo, bit32.band(ray_lo, m_lo))
		result_hi = bit32.bor(result_hi, bit32.band(ray_hi, m_hi))
	end

	ray(rays.NE_LO[square], rays.NE_HI[square], true)
	ray(rays.NW_LO[square], rays.NW_HI[square], true)
	ray(rays.SE_LO[square], rays.SE_HI[square], false)
	ray(rays.SW_LO[square], rays.SW_HI[square], false)
	return result_hi, result_lo
end

local function make_rook_mask(square: number): (number, number)
	local rank = math.floor(square / 8)
	local file  = square % 8
	local lo = 0
	local hi = 0
	for r = rank + 1, 6 do
		local s = r * 8 + file
		lo = bit32.bor(lo, BIT_LO[s])
		hi = bit32.bor(hi, BIT_HI[s])
	end
	for r = rank - 1, 1, -1 do
		local s = r * 8 + file
		lo = bit32.bor(lo, BIT_LO[s])
		hi = bit32.bor(hi, BIT_HI[s])
	end
	for f = file + 1, 6 do
		local s = rank * 8 + f
		lo = bit32.bor(lo, BIT_LO[s])
		hi = bit32.bor(hi, BIT_HI[s])
	end
	for f = file - 1, 1, -1 do
		local s = rank * 8 + f
		lo = bit32.bor(lo, BIT_LO[s])
		hi = bit32.bor(hi, BIT_HI[s])
	end
	return hi, lo
end

local function make_bishop_mask(square: number): (number, number)
	local rank = math.floor(square / 8)
	local file  = square % 8
	local lo = 0
	local hi = 0
	local r, f
	r, f = rank + 1, file + 1; while r <= 6 and f <= 6 do local s = r*8+f; lo = bit32.bor(lo, BIT_LO[s]); hi = bit32.bor(hi, BIT_HI[s]); r+=1; f+=1 end
	r, f = rank + 1, file - 1; while r <= 6 and f >= 1 do local s = r*8+f; lo = bit32.bor(lo, BIT_LO[s]); hi = bit32.bor(hi, BIT_HI[s]); r+=1; f-=1 end
	r, f = rank - 1, file + 1; while r >= 1 and f <= 6 do local s = r*8+f; lo = bit32.bor(lo, BIT_LO[s]); hi = bit32.bor(hi, BIT_HI[s]); r-=1; f+=1 end
	r, f = rank - 1, file - 1; while r >= 1 and f >= 1 do local s = r*8+f; lo = bit32.bor(lo, BIT_LO[s]); hi = bit32.bor(hi, BIT_HI[s]); r-=1; f-=1 end
	return hi, lo
end

return function(
	ROOK_BITS, BISHOP_BITS,
	ROOK_MAGICS_HI, ROOK_MAGICS_LO, BISHOP_MAGICS_LO,
	rays
)
	local ROOK_MASK_LO   = table.create(64)
	local ROOK_MASK_HI   = table.create(64)
	local BISHOP_MASK_LO = table.create(64)
	local BISHOP_MASK_HI = table.create(64)

	local ROOK_TABLE_LO:   {{number}} = table.create(64)
	local ROOK_TABLE_HI:   {{number}} = table.create(64)
	local BISHOP_TABLE_LO: {{number}} = table.create(64)
	local BISHOP_TABLE_HI: {{number}} = table.create(64)

	for square = 0, 63 do
		local rmask_hi, rmask_lo = make_rook_mask(square)
		ROOK_MASK_LO[square] = rmask_lo
		ROOK_MASK_HI[square] = rmask_hi

		local rbits  = ROOK_BITS[square + 1]
		local rtable_lo = table.create(bit32.lshift(1, rbits))
		local rtable_hi = table.create(bit32.lshift(1, rbits))
		ROOK_TABLE_LO[square] = rtable_lo
		ROOK_TABLE_HI[square] = rtable_hi

		local occ_los, occ_his = enumerate_subsets(rmask_hi, rmask_lo)
		for i = 1, #occ_los do
			local occ_lo = occ_los[i]
			local occ_hi = occ_his[i]
			local idx = rook_magic_index(occ_hi, occ_lo, ROOK_MAGICS_HI[square + 1], ROOK_MAGICS_LO[square + 1], rbits)
			local att_hi, att_lo = classical_rook_attacks(square, occ_hi, occ_lo, rays)
			rtable_lo[idx] = att_lo
			rtable_hi[idx] = att_hi
		end

		local bmask_hi, bmask_lo = make_bishop_mask(square)
		BISHOP_MASK_LO[square] = bmask_lo
		BISHOP_MASK_HI[square] = bmask_hi

		local bbits  = BISHOP_BITS[square + 1]
		local btable_lo = table.create(bit32.lshift(1, bbits))
		local btable_hi = table.create(bit32.lshift(1, bbits))
		BISHOP_TABLE_LO[square] = btable_lo
		BISHOP_TABLE_HI[square] = btable_hi

		local bocc_los, bocc_his = enumerate_subsets(bmask_hi, bmask_lo)
		for i = 1, #bocc_los do
			local occ_lo = bocc_los[i]
			local occ_hi = bocc_his[i]
			local idx = bishop_magic_index(occ_hi, occ_lo, BISHOP_MAGICS_LO[square + 1], bbits)
			local att_hi, att_lo = classical_bishop_attacks(square, occ_hi, occ_lo, rays)
			btable_lo[idx] = att_lo
			btable_hi[idx] = att_hi
		end
	end

	return ROOK_MASK_LO, ROOK_MASK_HI, BISHOP_MASK_LO, BISHOP_MASK_HI,
	       ROOK_TABLE_LO, ROOK_TABLE_HI, BISHOP_TABLE_LO, BISHOP_TABLE_HI
end

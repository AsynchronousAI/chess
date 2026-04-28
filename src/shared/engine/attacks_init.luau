--!native
--!optimize 2
local Utils = require("./utils")

-- Magic index (Uses Grant Osborne optimization: https://www.chessprogramming.org/Magic_Bitboards#32-bit_Magics)
local function rook_magic_index(occ_hi: number, occ_lo: number, magic_hi: number, magic_lo: number, shift: number): number
    local lo = bit32.bor(occ_lo * magic_lo, 0)
    local hi = bit32.bor(occ_hi * magic_hi, 0)
    return bit32.rshift(bit32.bxor(lo, hi), shift)
end
local function bishop_magic_index(occ_hi: number, occ_lo: number, magic_hi: number, magic_lo: number, bits: number): number
    if bits >= 5 then -- this condition is not in the original algorithm, but we fallback to rook-style magic indexs to avoid collisions
        local lo = bit32.bor(occ_lo * magic_lo, 0)
        local hi = bit32.bor(occ_hi * magic_hi, 0)
        return bit32.rshift(bit32.bxor(lo, hi), 32 - bits)
    end
    local folded = bit32.bor(bit32.bxor(occ_lo, occ_hi) * magic_lo, 0)
    return bit32.rshift(folded, 32 - bits)
end

-- Slow, classical attacks
local function apply_ray(ray: integer, occ: integer, positive: boolean, result: integer): integer
	local blk = integer.band(ray, occ)

	if blk == 0i then
		return integer.bor(result, ray)
	end

	local blocker_sq
	if positive then
		blocker_sq = integer.tonumber(integer.countrz(blk))
	else
		blocker_sq = 63 - integer.tonumber(integer.countlz(blk))
	end

	local b = Utils.unit_board(blocker_sq)
	local s = integer.sub(b, 1i)

	local m
	if positive then
		m = integer.bor(b, s)
	else
		m = integer.bnot(s)
	end

	return integer.bor(result, integer.band(ray, m))
end
local function classical_rook_attacks(square, occ, rays)
	local result = 0i

	result = apply_ray(rays.NORTH[square], occ, true,  result)
	result = apply_ray(rays.EAST[square],  occ, true,  result)
	result = apply_ray(rays.SOUTH[square], occ, false, result)
	result = apply_ray(rays.WEST[square],  occ, false, result)

	return result
end
local function classical_bishop_attacks(square, occ, rays)
	local result = 0i

	result = apply_ray(rays.NE[square], occ, true,  result)
	result = apply_ray(rays.NW[square], occ, true,  result)
	result = apply_ray(rays.SE[square], occ, false, result)
	result = apply_ray(rays.SW[square], occ, false, result)

	return result
end

-- Subset enumerator
local function enumerate_subsets(mask: integer)
	local sub = 0i
	local first = true

	return function()
		if not first and sub == 0i then
			return nil
		end

		first = false

		local ret = sub
		sub = integer.band(integer.sub(sub, mask), mask)

		return ret
	end
end

-- Rook & Bishop masks
local function make_rook_mask(square: number): integer
	local rank = math.floor(square / 8)
	local file  = square % 8
	local bb = 0i
	for r = rank + 1, 6 do
		bb = Utils.set_bit(bb, r * 8 + file)
	end
	for r = rank - 1, 1, -1 do
		bb = Utils.set_bit(bb, r * 8 + file)
	end
	for f = file + 1, 6 do
		bb = Utils.set_bit(bb, rank * 8 + f)
	end
	for f = file - 1, 1, -1 do
		bb = Utils.set_bit(bb, rank * 8 + f)
	end
	return bb
end
local function make_bishop_mask(square: number): integer
	local rank = math.floor(square / 8)
	local file  = square % 8
	local bb = 0i
	local r, f
	r, f = rank + 1, file + 1; while r <= 6 and f <= 6 do bb = Utils.set_bit(bb, r*8+f); r+=1; f+=1 end
	r, f = rank + 1, file - 1; while r <= 6 and f >= 1 do bb = Utils.set_bit(bb, r*8+f); r+=1; f-=1 end
	r, f = rank - 1, file + 1; while r >= 1 and f <= 6 do bb = Utils.set_bit(bb, r*8+f); r-=1; f+=1 end
	r, f = rank - 1, file - 1; while r >= 1 and f >= 1 do bb = Utils.set_bit(bb, r*8+f); r-=1; f-=1 end
	return bb
end

-- Initializer
return {
    rook_magic_index = rook_magic_index,
    bishop_magic_index = bishop_magic_index,
    apply_ray = apply_ray,
    classical_rook_attacks = classical_rook_attacks,
    classical_bishop_attacks = classical_bishop_attacks,
    enumerate_subsets = enumerate_subsets,
    make_rook_mask = make_rook_mask,
    make_bishop_mask = make_bishop_mask,

    iniitialize = function(
    	ROOK_BITS, BISHOP_BITS,
    	ROOK_MAGICS_HI, ROOK_MAGICS_LO, BISHOP_MAGICS_HI, BISHOP_MAGICS_LO,
    	rays_lo_hi
    )
        -- Convert rays to 64-bit
        local rays = {
            NORTH = rays_lo_hi.NORTH_LO,
            SOUTH = rays_lo_hi.SOUTH_LO,
            EAST  = rays_lo_hi.EAST_LO,
            WEST  = rays_lo_hi.WEST_LO,
            NE    = rays_lo_hi.NE_LO,
            NW    = rays_lo_hi.NW_LO,
            SE    = rays_lo_hi.SE_LO,
            SW    = rays_lo_hi.SW_LO,
        }

    	local ROOK_MASK_LO   = table.create(64)
    	local ROOK_MASK_HI   = table.create(64)
    	local BISHOP_MASK_LO = table.create(64)
    	local BISHOP_MASK_HI = table.create(64)

    	local ROOK_TABLE_LO:   {{number}} = table.create(64)
    	local ROOK_TABLE_HI:   {{number}} = table.create(64)
    	local BISHOP_TABLE_LO: {{number}} = table.create(64)
    	local BISHOP_TABLE_HI: {{number}} = table.create(64)

    	for square = 0, 63 do
    	    -- Rook masks
    		local rmask = make_rook_mask(square)
            local rm_lo, rm_hi = Utils.split_pair(rmask)
    		ROOK_MASK_LO[square] = rm_lo
    		ROOK_MASK_HI[square] = rm_hi

    		-- Rook attacks
    		local rbits  = ROOK_BITS[square + 1]
    		local rtable_lo = table.create(bit32.lshift(1, rbits))
    		local rtable_hi = table.create(bit32.lshift(1, rbits))
    		for occ in enumerate_subsets(rmask) do
                local occ_lo, occ_hi = Utils.split_pair(occ)
    			local idx = rook_magic_index(
    				occ_hi, occ_lo,
    				ROOK_MAGICS_HI[square + 1],
    				ROOK_MAGICS_LO[square + 1],
    				rbits
    			)

    			local att = classical_rook_attacks(square, occ, rays)
                local att_lo, att_hi = Utils.split_pair(att)

    			rtable_lo[idx] = att_lo
    			rtable_hi[idx] = att_hi
    		end
    		ROOK_TABLE_LO[square] = rtable_lo
    		ROOK_TABLE_HI[square] = rtable_hi

    		-- Bishop masks
    		local bmask = make_bishop_mask(square)
            local bm_lo, bm_hi = Utils.split_pair(bmask)
    		BISHOP_MASK_LO[square] = bm_lo
    		BISHOP_MASK_HI[square] = bm_hi

    		-- Bishop attacks
    		local bbits  = BISHOP_BITS[square + 1]
    		local btable_lo = table.create(bit32.lshift(1, bbits))
    		local btable_hi = table.create(bit32.lshift(1, bbits))
    		for occ in enumerate_subsets(bmask) do
                local occ_lo, occ_hi = Utils.split_pair(occ)
    			local idx = bishop_magic_index(
    				occ_hi,
    				occ_lo,
    				BISHOP_MAGICS_HI[square + 1],
    				BISHOP_MAGICS_LO[square + 1],
    				bbits
    			)

    			local att = classical_bishop_attacks(square, occ, rays)
                local att_lo, att_hi = Utils.split_pair(att)

    			btable_lo[idx] = att_lo
    			btable_hi[idx] = att_hi
    		end
    		BISHOP_TABLE_LO[square] = btable_lo
    		BISHOP_TABLE_HI[square] = btable_hi
    	end

    	return ROOK_MASK_LO, ROOK_MASK_HI, BISHOP_MASK_LO, BISHOP_MASK_HI,
    	       ROOK_TABLE_LO, ROOK_TABLE_HI, BISHOP_TABLE_LO, BISHOP_TABLE_HI
    end
}

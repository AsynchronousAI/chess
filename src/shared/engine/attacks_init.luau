--!native
--!optimize 2
local Utils = require("./utils")

-- Standard 64-bit Magic Indexing
local function magic_index(occ: integer, magic: integer, bits: number): number
    -- (occ * magic) >> (64 - bits)
    local mul = integer.mul(occ, magic)
    local shift = integer.create(64 - bits) :: integer
    return integer.tonumber(integer.rshift(mul, shift))
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

local function classical_rook_attacks(square: number, occ: integer, rays)
	local result = 0i
	result = apply_ray(rays.NORTH[square], occ, true,  result)
	result = apply_ray(rays.EAST[square],  occ, true,  result)
	result = apply_ray(rays.SOUTH[square], occ, false, result)
	result = apply_ray(rays.WEST[square],  occ, false, result)
	return result
end

local function classical_bishop_attacks(square: number, occ: integer, rays)
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
		if not first and sub == 0i then return nil end
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
	for r = rank + 1, 6 do bb = Utils.set_bit(bb, r * 8 + file) end
	for r = rank - 1, 1, -1 do bb = Utils.set_bit(bb, r * 8 + file) end
	for f = file + 1, 6 do bb = Utils.set_bit(bb, rank * 8 + f) end
	for f = file - 1, 1, -1 do bb = Utils.set_bit(bb, rank * 8 + f) end
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
    magic_index = magic_index,
    apply_ray = apply_ray,
    classical_rook_attacks = classical_rook_attacks,
    classical_bishop_attacks = classical_bishop_attacks,
    enumerate_subsets = enumerate_subsets,
    make_rook_mask = make_rook_mask,
    make_bishop_mask = make_bishop_mask,

    initialize = function(ROOK_BITS, BISHOP_BITS, ROOK_MAGICS, BISHOP_MAGICS, rays)
    	local ROOK_MASKS   = table.create(64)
    	local BISHOP_MASKS = table.create(64)
    	local ROOK_TABLES:   {{integer}} = table.create(64)
    	local BISHOP_TABLES: {{integer}} = table.create(64)

    	for square = 0, 63 do
    		-- Rook
    		local rmask = make_rook_mask(square)
    		ROOK_MASKS[square] = rmask
    		local rbits  = ROOK_BITS[square + 1]
    		local rtable = table.create(2^rbits)
    		for occ in enumerate_subsets(rmask) do
    			local idx = magic_index(occ, ROOK_MAGICS[square + 1], rbits)
    			rtable[idx] = classical_rook_attacks(square, occ, rays)
    		end
    		ROOK_TABLES[square] = rtable

    		-- Bishop
    		local bmask = make_bishop_mask(square)
    		BISHOP_MASKS[square] = bmask
    		local bbits  = BISHOP_BITS[square + 1]
    		local btable = table.create(2^bbits)
    		for occ in enumerate_subsets(bmask) do
    			local idx = magic_index(occ, BISHOP_MAGICS[square + 1], bbits)
    			btable[idx] = classical_bishop_attacks(square, occ, rays)
    		end
    		BISHOP_TABLES[square] = btable
    	end

    	return ROOK_MASKS, BISHOP_MASKS, ROOK_TABLES, BISHOP_TABLES
    end
}

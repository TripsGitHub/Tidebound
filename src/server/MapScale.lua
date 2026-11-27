-- How much bigger the world is built than the hand-designed island shapes.
-- CloverIsland.lua and IslandFields.lua (and the map previews) are drawn at 1x; every
-- island is written into terrain H times wider and V times taller, the islands sit
-- Spread times further apart (open sea between them), and node counts grow with the
-- land area.
local MapScale = {}

MapScale.H = 4 -- island size, horizontal: Clover is about 880 studs across
MapScale.V = 1.5 -- vertical (hills, cliffs, sea floor)
MapScale.Spread = 5.5 -- island positions: about 800 studs of open sea between neighbours
MapScale.Density = 0.45 -- nodes per area compared with the 1x map (1 = same density)

-- Writes the box [x0, x1] x [y0, y1] x [z0, z1] (world studs) into terrain in slabs, so
-- huge islands never build one giant voxel table. For every voxel column, `column` gets
-- its centre (wx, wz) and the bottom height of each voxel (ys) and fills in the
-- material and occupancy of each voxel (mats[j], occ[j]).
function MapScale.writeSlabs(
	terrain: Terrain,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	column: (wx: number, wz: number, ys: { number }, mats: { any }, occ: { number }) -> ()
)
	local RES = 4
	local SLAB = 24 -- voxel columns per slab along x
	local full = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)):ExpandToGrid(RES)
	local lo = full.CFrame.Position - full.Size / 2
	local hi = full.CFrame.Position + full.Size / 2
	local ny, nz = full.Size.Y / RES, full.Size.Z / RES
	local ys = table.create(ny)
	for j = 1, ny do
		ys[j] = lo.Y + (j - 1) * RES
	end
	local x = lo.X
	while x < hi.X do
		local xe = math.min(x + SLAB * RES, hi.X)
		local nx = (xe - x) / RES
		local mats, occ = table.create(nx), table.create(nx)
		for i = 1, nx do
			local mi, oi = table.create(ny), table.create(ny)
			for j = 1, ny do
				mi[j], oi[j] = table.create(nz), table.create(nz)
			end
			mats[i], occ[i] = mi, oi
			local wx = x + (i - 0.5) * RES
			local colM, colO = table.create(ny), table.create(ny)
			for k = 1, nz do
				local wz = lo.Z + (k - 0.5) * RES
				column(wx, wz, ys, colM, colO)
				for j = 1, ny do
					mi[j][k], oi[j][k] = colM[j], colO[j]
				end
			end
		end
		terrain:WriteVoxels(Region3.new(Vector3.new(x, lo.Y, lo.Z), Vector3.new(xe, hi.Y, hi.Z)), RES, mats, occ)
		x = xe
		task.wait() -- keep the server responsive while the world builds
	end
end

return MapScale

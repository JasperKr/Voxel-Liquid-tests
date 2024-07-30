chunkSize = 16
inverseChunkSize = 1 / chunkSize

---@class VoxelWorld
---@field chunkGrid table
---@field id number
---@field chunkType ffi.cdata*
---@field voxelType ffi.cdata*
---@field chunkDef string
---@field voxelDef string
---@field chunkName ffi.cdecl*
---@field voxelName string
---@field updateType string
---@field objects table
---@field isLiquidWorld boolean
---@field solidsVoxelWorld VoxelWorld
---@field lodChunkDef string
---@field lodChunkName ffi.cdecl*
---@field lodVoxelDef string
---@field lodVoxelName string
local VoxelWorldFunctions = {}
local VoxelWorldMeta = {
    __index = VoxelWorldFunctions,
}

function clamp(v, min, max)
    return math.min(math.max(v, min), max)
end

ffi.cdef [[
    typedef struct {
        uint8_t x, y, z;
    } uint8vec3;

    typedef struct {
        uint8_t x, y, z, w;
    } uint8vec4;
]]

VoxelWorlds = newIdIndexedTable()

---@return VoxelWorld
function newVoxelWorld(chunkDef, chunkName, voxelDef, voxelName, updateType, isLiquidWorld, solidsVoxelWorld, lodChunkDef,
                       lodChunkName, lodVoxelDef, lodVoxelName)
    local self = {
        chunkGrid = {},
        id = Renderer.internal.newID(),
    }

    ffi.cdef(voxelDef)
    ffi.cdef(chunkDef)
    if lodChunkDef then
        ffi.cdef(lodVoxelDef)
        ffi.cdef(lodChunkDef)
    end

    self.chunkType = ffi.typeof(chunkName)
    self.voxelType = ffi.typeof(voxelName)
    self.chunkDef = chunkDef
    self.voxelDef = voxelDef
    self.chunkName = chunkName
    self.voxelName = voxelName
    self.lodChunkDef = lodChunkDef
    self.lodChunkName = lodChunkName
    self.lodVoxelDef = lodVoxelDef
    self.lodVoxelName = lodVoxelName
    self.updateType = updateType
    self.objects = newIdIndexedTable()
    self.isLiquidWorld = isLiquidWorld
    self.solidsVoxelWorld = solidsVoxelWorld

    setmetatable(self, VoxelWorldMeta)

    VoxelWorlds:add(self)

    return self
end

function toChunkCoords(x, y, z, size)
    return
        math.floor(x / size) * size,
        math.floor(y / size) * size,
        math.floor(z / size) * size
end

--- Get a chunk from the voxel world
---@param x integer The x coordinate of the chunk
---@param y integer The y coordinate of the chunk
---@param z integer The z coordinate of the chunk
---@param w integer The lod of the chunk
---@return unknown
function VoxelWorldFunctions:getChunk(x, y, z, w)
    if not self.chunkGrid[x] then
        self.chunkGrid[x] = {}
    end

    if not self.chunkGrid[x][y] then
        self.chunkGrid[x][y] = {}
    end

    if not self.chunkGrid[x][y][z] then
        self.chunkGrid[x][y][z] = {}
    end

    if not self.chunkGrid[x][y][z][w] then
        if self.isLiquidWorld then
            if w > 0 then
                local size = bit.rshift(chunkSize, w)
                local voxelCount = math.pow(size, 3)

                self.chunkGrid[x][y][z][w] = {
                    chunk = ffi.new(self.lodChunkName, voxelCount, x, y, z, w,
                        { { 0 } }),
                    vertices = {},
                    indices = {},
                    updateMin = vec3(),
                    updateMax = vec3(size - 1, size - 1, size - 1)
                }
            else
                self.chunkGrid[x][y][z][w] = {
                    chunk = ffi.new(self.chunkName, math.pow(chunkSize, 3), x, y, z, w,
                        { { 0 } }),
                    vertices = {},
                    indices = {},
                    updateMin = vec3(),
                    updateMax = vec3(chunkSize - 1, chunkSize - 1, chunkSize - 1)
                }
            end
        else
            self.chunkGrid[x][y][z][w] = {
                chunk = ffi.new(self.chunkName, x, y, z, { { 0 } }),
                vertices = {},
                indices = {},
            }
        end
    end

    return self.chunkGrid[x][y][z][w]
end

do
    local chunkSizeSqr = chunkSize * chunkSize
    function getVoxelFromChunk(chunk, x, y, z)
        local index = x + y * chunkSize + z * chunkSizeSqr

        return chunk.chunk.voxels[index], index
    end
end

function toInChunkCoords(x, y, z, size)
    return x % size, y % size, z % size
end

function VoxelWorldFunctions:getVoxel(x, y, z, w)
    local size = bit.rshift(chunkSize, w)

    local chunkX, chunkY, chunkZ = toChunkCoords(x, y, z, size)
    local chunk = self:getChunk(chunkX, chunkY, chunkZ, w)

    return getVoxelFromChunk(chunk, toInChunkCoords(x, y, z, size)), chunk
end

local clearNoiseCache
do
    local noiseCache = table.new(0, chunkSize * chunkSize)

    function clearNoiseCache()
        table.clear(noiseCache)
    end

    local randomOffsetX = love.math.random(-100000, 100000)
    local randomOffsetZ = love.math.random(-100000, 100000)

    local scale = 0.25
    ---@diagnostic disable-next-line: undefined-field
    local perlin = love.math.perlinNoise
    function fbm(x, z)
        if not noiseCache[x] then
            noiseCache[x] = {}
        end
        if not noiseCache[x][z] then
            local x2, z2 = x * scale + randomOffsetX, z * scale + randomOffsetZ
            local f = 0.03125
            local a = 1.0
            local t = 0.0
            for i = 1, 5 do
                t = t + a * perlin(f * x2, f * z2)
                f = f * 2.0
                a = a * 0.5
            end

            noiseCache[x][z] = t

            return t
        end

        return noiseCache[x][z]
    end
end

local function isSolid(x, y, z)
    return y < fbm(x, z) * 30.0 - 20
end

function VoxelWorldFunctions:generateChunkTerrain(chunk)
    if self.isLiquidWorld then
        return
    end

    local x, y, z = chunk.chunk.x, chunk.chunk.y, chunk.chunk.z

    for voxelZ = 0, chunkSize - 1 do
        local indexZ = voxelZ * chunkSize * chunkSize
        for voxelX = 0, chunkSize - 1 do
            for voxelY = 0, chunkSize - 1 do
                local index = indexZ + voxelY * chunkSize + voxelX

                local voxel = chunk.chunk.voxels[index]

                if isSolid(x + voxelX, y + voxelY, z + voxelZ) then
                    voxel.type = 1
                end
            end
        end
    end
end

function VoxelWorldFunctions:finalizeTerrain(chunk)
    for voxelX = 0, chunkSize - 1 do
        for voxelY = 0, chunkSize - 1 do
            for voxelZ = 0, chunkSize - 1 do
                local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                if voxel.type == 1 and not isSolid(voxelX + chunk.chunk.x, voxelY + 1 + chunk.chunk.y, voxelZ + chunk.chunk.z) then
                    voxel.type = 2
                end
            end
        end
    end
end

local faceForward = 1
local faceBackward = 2
local faceLeft = 4
local faceRight = 8
local faceUp = 16
local faceDown = 32

local faceDirections = {
    { 0,  0,  -1, faceForward },
    { 0,  0,  1,  faceBackward },
    { -1, 0,  0,  faceLeft },
    { 1,  0,  0,  faceRight },
    { 0,  1,  0,  faceUp },
    { 0,  -1, 0,  faceDown },
}

local faces = {
    { { 0, 0, 0, 0, 0, 0, 0 }, { 1, 0, 0, 0, 1, 0, 0 }, { 1, 1, 0, 0, 1, 1, 0 }, { 0, 1, 0, 0, 0, 1, 0 } }, -- forwards
    { { 0, 0, 1, 0, 0, 0, 1 }, { 1, 0, 1, 0, 1, 0, 1 }, { 1, 1, 1, 0, 1, 1, 1 }, { 0, 1, 1, 0, 0, 1, 1 } }, -- backwards
    { { 0, 0, 0, 0, 0, 0, 2 }, { 0, 0, 1, 0, 1, 0, 2 }, { 0, 1, 1, 0, 1, 1, 2 }, { 0, 1, 0, 0, 0, 1, 2 } }, -- left
    { { 1, 0, 0, 0, 0, 0, 3 }, { 1, 0, 1, 0, 1, 0, 3 }, { 1, 1, 1, 0, 1, 1, 3 }, { 1, 1, 0, 0, 0, 1, 3 } }, -- right
    { { 0, 1, 0, 0, 0, 0, 4 }, { 1, 1, 0, 0, 1, 0, 4 }, { 1, 1, 1, 0, 1, 1, 4 }, { 0, 1, 1, 0, 0, 1, 4 } }, -- up
    { { 0, 0, 0, 0, 0, 0, 5 }, { 1, 0, 0, 0, 1, 0, 5 }, { 1, 0, 1, 0, 1, 1, 5 }, { 0, 0, 1, 0, 0, 1, 5 } }, -- down
}

local faceAll = faceForward + faceBackward + faceLeft + faceRight + faceUp + faceDown

function VoxelWorldFunctions:calculateChunkMeshFacesActive(chunk)
    for voxelZ = 0, chunkSize - 1 do
        local z = voxelZ + chunk.chunk.z
        local indexZ = voxelZ * chunkSize * chunkSize

        for voxelY = 0, chunkSize - 1 do
            local y = voxelY + chunk.chunk.y
            local indexYZ = indexZ + voxelY * chunkSize

            for voxelX = 0, chunkSize - 1 do
                local x = voxelX + chunk.chunk.x
                local voxel = chunk.chunk.voxels[indexYZ + voxelX]

                if voxel.type >= 1 then
                    voxel.facesActive = faceAll

                    for _, face in ipairs(faceDirections) do
                        local neighbour = self:getVoxel(x + face[1], y + face[2], z + face[3], 0)

                        if neighbour.type >= 1 then
                            voxel.facesActive = voxel.facesActive - face[4]
                        end
                    end
                else
                    voxel.facesActive = 0
                end
            end
        end
    end
end

local vertexFormat = {
    { name = "VertexData",     format = "uint8vec4" },
    { name = "VertexTexCoord", format = "int8vec4" },
}

local function generateQuadIndices(quadCount)
    local indices = {}

    for i = 0, quadCount - 1 do
        local baseIndex = i * 4

        table.insert(indices, baseIndex + 1)
        table.insert(indices, baseIndex + 2)
        table.insert(indices, baseIndex + 3)

        table.insert(indices, baseIndex + 1)
        table.insert(indices, baseIndex + 3)
        table.insert(indices, baseIndex + 4)
    end

    return indices
end

do
    local directions = {
        { { 1, 0, 0 }, { 0, 1, 0 } }, -- forwards -> loop X+, then loop Y+
        { { 1, 0, 0 }, { 0, 1, 0 } }, -- backwards -> loop X+, then loop Y+
        { { 0, 0, 1 }, { 0, 1, 0 } }, -- left -> loop Z+, then loop Y+
        { { 0, 0, 1 }, { 0, 1, 0 } }, -- right -> loop Z+, then loop Y+
        { { 1, 0, 0 }, { 0, 0, 1 } }, -- up -> loop X+, then loop Z+
        { { 1, 0, 0 }, { 0, 0, 1 } }, -- down -> loop X+, then loop Z+
    }

    function VoxelWorldFunctions:createVertices(chunk, vertices)
        local index = 0
        local faceCount = 0

        if self.isLiquidWorld then
            for voxelX = 0, chunkSize - 1 do
                for voxelY = 0, chunkSize - 1 do
                    for voxelZ = 0, chunkSize - 1 do
                        local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                        if voxel.type >= 1 then
                            for i, face in ipairs(faces) do
                                local dir = faceDirections[i]
                                if bit.band(voxel.facesActive, bit.lshift(1, i - 1)) > 0 then
                                    faceCount = faceCount + 1

                                    for _, vertex in ipairs(face) do
                                        if i < 5 and vertex[2] == 0 then
                                            local facingVoxel = self:getVoxel(
                                                voxelX + dir[1] + chunk.chunk.x,
                                                voxelY + dir[2] + chunk.chunk.y,
                                                voxelZ + dir[3] + chunk.chunk.z,
                                                0
                                            )

                                            index = index + 1
                                            vertices[index] = {
                                                tonumber(vertex[1] + voxelX),
                                                tonumber(vertex[2] + voxelY),
                                                tonumber(vertex[3] + voxelZ),
                                                tonumber(voxel.type),
                                                vertex[5],
                                                vertex[6],
                                                clamp(tonumber(facingVoxel.waterLevel) / 2, -127, 127),
                                                vertex[7]
                                            }
                                        else
                                            index = index + 1
                                            vertices[index] = {
                                                tonumber(vertex[1] + voxelX),
                                                tonumber(vertex[2] + voxelY),
                                                tonumber(vertex[3] + voxelZ),
                                                tonumber(voxel.type),
                                                vertex[5],
                                                vertex[6],
                                                clamp(tonumber(voxel.waterLevel) / 2 - 127, -127, 127),
                                                vertex[7]
                                            }
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            local voxelsCombined = {}

            -- do greedy meshing
            for voxelZ = 0, chunkSize - 1 do
                local indexZ = voxelZ * chunkSize * chunkSize
                for voxelY = 0, chunkSize - 1 do
                    local indexYZ = indexZ + voxelY * chunkSize
                    for voxelX = 0, chunkSize - 1 do
                        local voxelIndex = indexYZ + voxelX

                        local voxel = chunk.chunk.voxels[voxelIndex]
                        for side, face in ipairs(faces) do
                            local faceBit = bit.lshift(1, side - 1)

                            if voxelsCombined[voxelIndex] and voxelsCombined[voxelIndex][side] then
                                goto continue
                            end

                            if voxel.type ~= 0 and bit.band(voxel.facesActive, faceBit) > 0 then
                                local maxOnFirstAxis = 15
                                local maxOnSecondAxis = -1

                                local directionA = directions[side][1]
                                local directionB = directions[side][2]

                                local otherXB, otherYB, otherZB = voxelX, voxelY, voxelZ

                                for i = 0, 15 do
                                    local otherXA, otherYA, otherZA = otherXB, otherYB, otherZB

                                    local actualMaxOnFirstAxis = -1
                                    for j = 0, maxOnFirstAxis do
                                        if otherXA > 15 or otherYA > 15 or otherZA > 15 then
                                            break
                                        end

                                        local otherVoxel = getVoxelFromChunk(chunk, otherXA, otherYA, otherZA)

                                        if voxel.type ~= otherVoxel.type then
                                            break
                                        end

                                        if bit.band(otherVoxel.facesActive, faceBit) == 0 then
                                            break
                                        end

                                        otherXA = otherXA + directionA[1]
                                        otherYA = otherYA + directionA[2]
                                        otherZA = otherZA + directionA[3]

                                        actualMaxOnFirstAxis = actualMaxOnFirstAxis + 1
                                    end

                                    if i == 0 then
                                        maxOnFirstAxis = actualMaxOnFirstAxis
                                    else
                                        if actualMaxOnFirstAxis ~= maxOnFirstAxis then
                                            break
                                        end
                                    end

                                    otherXA, otherYA, otherZA = otherXB, otherYB, otherZB

                                    for j = 0, maxOnFirstAxis do
                                        local otherVoxel, otherIndex = getVoxelFromChunk(chunk, otherXA, otherYA, otherZA)

                                        otherVoxel.facesActive = otherVoxel.facesActive - faceBit

                                        if not voxelsCombined[otherIndex] then
                                            voxelsCombined[otherIndex] = {}
                                        end
                                        voxelsCombined[otherIndex][side] = true

                                        otherXA = otherXA + directionA[1]
                                        otherYA = otherYA + directionA[2]
                                        otherZA = otherZA + directionA[3]
                                    end

                                    otherXB = otherXB + directionB[1]
                                    otherYB = otherYB + directionB[2]
                                    otherZB = otherZB + directionB[3]

                                    maxOnSecondAxis = maxOnSecondAxis + 1
                                end

                                faceCount = faceCount + 1
                                for _, vertex in ipairs(face) do
                                    local x, y, z = vertex[1], vertex[2], vertex[3]
                                    if x ~= 0 then
                                        x = x + directionA[1] * maxOnFirstAxis + directionB[1] * maxOnSecondAxis
                                    end
                                    if y ~= 0 then
                                        y = y + directionA[2] * maxOnFirstAxis + directionB[2] * maxOnSecondAxis
                                    end
                                    if z ~= 0 then
                                        z = z + directionA[3] * maxOnFirstAxis + directionB[3] * maxOnSecondAxis
                                    end

                                    local u, v = vertex[5], vertex[6]

                                    if u ~= 0 then
                                        u = u + maxOnFirstAxis
                                    end

                                    if v ~= 0 then
                                        v = v + maxOnSecondAxis
                                    end

                                    index = index + 1
                                    vertices[index] = {
                                        tonumber(x + voxelX),
                                        tonumber(y + voxelY),
                                        tonumber(z + voxelZ),
                                        tonumber(voxel.type),
                                        u,
                                        v,
                                        127,
                                        vertex[7]
                                    }
                                end
                            end
                            ::continue::
                        end
                    end
                end
            end
        end

        return index, faceCount
    end
end

function VoxelWorldFunctions:generateChunkVertices(chunk)
    local vertices = {}

    local scale
    if self.isLiquidWorld then
        scale = bit.lshift(1, chunk.chunk.lod)
    else
        scale = 1
    end

    local index, faceCount = self:createVertices(chunk, vertices)

    if not chunk.position then
        chunk.position = vec3(chunk.chunk.x, chunk.chunk.y, chunk.chunk.z)
    else
        print("position already set")
    end
    if not chunk.id then
        chunk.id = tostring(chunk.chunk.x) .. tostring(chunk.chunk.y) .. tostring(chunk.chunk.z)
    else
        print("id already set")
    end
    if faceCount == 0 then
        chunk.drawMesh = false
        return chunk
    end

    chunk.drawMesh = true

    local indices = generateQuadIndices(faceCount)

    local mesh = love.graphics.newMesh(vertexFormat, vertices, "triangles", self.updateType)
    mesh:setVertexMap(indices)

    chunk.mesh = mesh
    chunk.vertices = vertices
    chunk.indices = indices

    return chunk
end

function VoxelWorldFunctions:downSampleChunk(chunk)
    assert(self.isLiquidWorld, "downSampleChunk is only for liquid worlds")

    local scale = bit.lshift(1, chunk.chunk.lod + 1)
    local newChunk = self:getChunk(chunk.chunk.x, chunk.chunk.y, chunk.chunk.z, chunk.chunk.lod + 1)

    local newChunkSize = chunkSize / scale

    for voxelX = 0, newChunkSize - 1 do
        for voxelY = 0, newChunkSize - 1 do
            for voxelZ = 0, newChunkSize - 1 do
                local voxel = getVoxelFromChunk(newChunk, voxelX, voxelY, voxelZ)

                local sum = 0
                local allTheSameLiquid = true

                for x = 0, scale - 1 do
                    for y = 0, scale - 1 do
                        for z = 0, scale - 1 do
                            local oldVoxel = self:getVoxel(
                                voxelX * scale + x + chunk.chunk.x,
                                voxelY * scale + y + chunk.chunk.y,
                                voxelZ * scale + z + chunk.chunk.z,
                                chunk.chunk.lod
                            )

                            if oldVoxel.type ~= 3 then
                                allTheSameLiquid = false
                                break
                            end

                            sum = sum + oldVoxel.waterLevel
                        end

                        if not allTheSameLiquid then
                            break
                        end
                    end

                    if not allTheSameLiquid then
                        break
                    end
                end

                if not allTheSameLiquid then
                    voxel.type = 1
                else
                    voxel.type = 3
                    voxel.waterLevel = sum / (scale * scale * scale)
                end
            end
        end
    end
end

function VoxelWorldFunctions:updateChunkVertices(chunk)
    local vertexCount = #chunk.vertices

    -- local scale = bit.lshift(1, chunk.chunk.lod)
    local index, faceCount = self:createVertices(chunk, chunk.vertices)

    if index == 0 then
        chunk.drawMesh = false
        return nil
    end

    chunk.drawMesh = true

    if index > vertexCount then
        local indices = generateQuadIndices(index / 4)
        local mesh = love.graphics.newMesh(vertexFormat, chunk.vertices, "triangles", self.updateType)
        mesh:setVertexMap(indices)
        chunk.mesh = mesh
        chunk.indices = indices
    else
        local indices = generateQuadIndices(index / 4)

        chunk.mesh:setVertices(chunk.vertices)
        chunk.mesh:setVertexMap(indices)

        chunk.mesh:setDrawRange(1, #indices)
        chunk.indices = indices
    end
end

WorldSize = {
    min = vec3(-3, -1, -3) * chunkSize,
    max = vec3(3, 2, 3) * chunkSize,
}

function VoxelWorldFunctions:generateVoxelWorld()
    self.objects = newIdIndexedTable()

    for x = WorldSize.min.x, WorldSize.max.x, chunkSize do
        for z = WorldSize.min.z, WorldSize.max.z, chunkSize do
            clearNoiseCache()
            for y = WorldSize.min.y, WorldSize.max.y, chunkSize do
                local chunk = self:getChunk(x, y, z, 0)
                self:generateChunkTerrain(chunk)
                self:finalizeTerrain(chunk)
                self:calculateChunkMeshFacesActive(chunk)
                local object = self:generateChunkVertices(chunk)

                assert(object, "object is nil")
                self.objects:add(object)
            end
        end
    end
end

local flowDirections = {
    { 0,  0, -1 },
    { 0,  0, 1 },
    { -1, 0, 0 },
    { 1,  0, 0 },
}

local function updateChunkUpdateLimits(chunk, minX, minY, minZ, maxX, maxY, maxZ)
    minX = minX - chunk.chunk.x
    minY = minY - chunk.chunk.y
    minZ = minZ - chunk.chunk.z

    maxX = maxX - chunk.chunk.x
    maxY = maxY - chunk.chunk.y
    maxZ = maxZ - chunk.chunk.z

    assert(minX <= maxX and minY <= maxY and minZ <= maxZ, "min must be less than max")

    chunk.updateMin:minSeparate(minX, minY, minZ)
    chunk.updateMax:maxSeparate(maxX, maxY, maxZ)
end

function VoxelWorldFunctions:updateWater(chunk, voxel, voxelX, voxelY, voxelZ)
    voxelX = voxelX + chunk.chunk.x
    voxelY = voxelY + chunk.chunk.y
    voxelZ = voxelZ + chunk.chunk.z

    local updated = false

    if voxel.type == 3 and voxel.waterLevel > 0 then
        local voxelBelow, chunkBelow = self:getVoxel(voxelX, voxelY - 1, voxelZ, 0)
        local solidVoxelBelow = self.solidsVoxelWorld:getVoxel(voxelX, voxelY - 1, voxelZ, 0)

        if solidVoxelBelow.type == 0 and (voxelBelow.type == 0 or voxelBelow.type == 3) and voxelBelow.waterLevel < 255 then
            local flowRate = math.ceil(255 - clamp(voxelBelow.waterLevel, 0, 255))
            flowRate = math.min(flowRate, voxel.waterLevel)

            voxelBelow.waterLevel = clamp(voxelBelow.waterLevel + flowRate, 0, 255)
            voxel.waterLevel = clamp(voxel.waterLevel - flowRate, 0, 255)
            voxelBelow.type = 3

            local minX, minY, minZ = voxelX, voxelY - 1, voxelZ
            local maxX, maxY, maxZ = voxelX, voxelY, voxelZ

            updateChunkUpdateLimits(chunkBelow, minX - 1, minY - 1, minZ - 1, maxX + 1, maxY + 1, maxZ + 1)
            updateChunkUpdateLimits(chunk, minX - 1, minY - 1, minZ - 1, maxX + 1, maxY + 1, maxZ + 1)

            updated = true
        else
            local direction = flowDirections[love.math.random(1, 4)]

            local oX, oY, oZ =
                voxelX + direction[1],
                voxelY + direction[2],
                voxelZ + direction[3]

            local otherVoxel, otherChunk = self:getVoxel(oX, oY, oZ, 0)
            local otherSolidVoxel = self.solidsVoxelWorld:getVoxel(oX, oY, oZ, 0)

            local minX, minY, minZ = math.min(voxelX, oX), math.min(voxelY, oY), math.min(voxelZ, oZ)
            local maxX, maxY, maxZ = math.max(voxelX, oX), math.max(voxelY, oY), math.max(voxelZ, oZ)

            updateChunkUpdateLimits(otherChunk, minX - 1, minY - 1, minZ - 1, maxX + 1, maxY + 1, maxZ + 1)
            updateChunkUpdateLimits(chunk, minX - 1, minY - 1, minZ - 1, maxX + 1, maxY + 1, maxZ + 1)

            if otherSolidVoxel.type == 0 and (otherVoxel.type == 0 or otherVoxel.type == 3) then
                if otherVoxel.waterLevel < voxel.waterLevel then
                    updated = true

                    local diff = voxel.waterLevel - otherVoxel.waterLevel
                    local flowRate = math.ceil(diff * 0.5)
                    flowRate = math.min(flowRate, voxel.waterLevel)

                    otherVoxel.waterLevel = clamp(otherVoxel.waterLevel + flowRate, 0, 255)
                    otherVoxel.type = 3
                    voxel.waterLevel = clamp(voxel.waterLevel - flowRate, 0, 255)
                elseif otherVoxel.waterLevel > voxel.waterLevel then
                    updated = true

                    local diff = otherVoxel.waterLevel - voxel.waterLevel
                    local flowRate = math.ceil(diff * 0.5)
                    flowRate = math.min(flowRate, otherVoxel.waterLevel)

                    voxel.waterLevel = clamp(voxel.waterLevel + flowRate, 0, 255)
                    voxel.type = 3
                    otherVoxel.waterLevel = clamp(otherVoxel.waterLevel - flowRate, 0, 255)
                end
            end
        end
    end

    if voxel.type == 3 and voxel.waterLevel == 0 then
        voxel.type = 0

        updateChunkUpdateLimits(chunk, voxelX, voxelY, voxelZ, voxelX, voxelY, voxelZ)

        updated = true
    end

    return updated
end

local curUpdateMin = vec3()
local curUpdateMax = vec3()

function VoxelWorldFunctions:updateVoxelWorld()
    if not self.isLiquidWorld then
        return
    end

    for x = WorldSize.min.x, WorldSize.max.x, chunkSize do
        for y = WorldSize.min.y, WorldSize.max.y, chunkSize do
            for z = WorldSize.min.z, WorldSize.max.z, chunkSize do
                local chunk = self:getChunk(x, y, z, 0)

                curUpdateMin:set(chunk.updateMin:get())
                curUpdateMax:set(chunk.updateMax:get())

                curUpdateMin:maxSeparate(0, 0, 0)
                curUpdateMax:minSeparate(chunkSize - 1, chunkSize - 1, chunkSize - 1)

                chunk.updateMin:set(chunkSize - 1, chunkSize - 1, chunkSize - 1)
                chunk.updateMax:set(0, 0, 0)

                local updatedAny = false

                for voxelX = curUpdateMin.x, curUpdateMax.x do
                    for voxelY = curUpdateMin.y, curUpdateMax.y do
                        for voxelZ = curUpdateMin.z, curUpdateMax.z do
                            local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                            self:updateWater(chunk, voxel, voxelX, voxelY, voxelZ)

                            updatedAny = true
                        end
                    end
                end

                if updatedAny then
                    self:calculateChunkMeshFacesActive(chunk)
                    self:updateChunkVertices(chunk)
                end
            end
        end
    end
end

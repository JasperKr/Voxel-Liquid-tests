local chunkSize = 16
local inverseChunkSize = 1 / chunkSize

---@class VoxelWorld
---@field chunkGrid table
---@field id number
---@field chunkType ffi.cdata*
---@field voxelType ffi.cdata*
---@field chunkDef string
---@field voxelDef string
---@field chunkName string
---@field voxelName string
---@field updateType string
---@field objects table
local VoxelWorldFunctions = {}
local VoxelWorldMeta = {
    __index = VoxelWorldFunctions,
}

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
function newVoxelWorld(chunkDef, chunkName, voxelDef, voxelName, updateType, isLiquidWorld, solidsVoxelWorld)
    local self = {
        chunkGrid = {},
        id = Renderer.internal.newID(),
    }

    ffi.cdef(voxelDef)
    ffi.cdef(chunkDef)

    self.chunkType = ffi.typeof(chunkName)
    self.voxelType = ffi.typeof(voxelName)
    self.chunkDef = chunkDef
    self.voxelDef = voxelDef
    self.chunkName = chunkName
    self.voxelName = voxelName
    self.updateType = updateType
    self.objects = newIdIndexedTable()
    self.isLiquidWorld = isLiquidWorld
    self.solidsVoxelWorld = solidsVoxelWorld

    setmetatable(self, VoxelWorldMeta)

    VoxelWorlds:add(self)

    return self
end

local function round(x)
    return math.floor(x + 0.5)
end

function toChunkCoords(x, y, z)
    return math.floor(x * inverseChunkSize), math.floor(y * inverseChunkSize), math.floor(z * inverseChunkSize)
end

function VoxelWorldFunctions:getChunk(x, y, z)
    if not self.chunkGrid[x] then
        self.chunkGrid[x] = {}
    end

    if not self.chunkGrid[x][y] then
        self.chunkGrid[x][y] = {}
    end

    if not self.chunkGrid[x][y][z] then
        self.chunkGrid[x][y][z] = {
            chunk = ffi.new(self.chunkName, x, y, z, { { 0 } }),
            vertices = {},
            indices = {},
        }
    end

    return self.chunkGrid[x][y][z]
end

local function getVoxelFromChunk(chunk, x, y, z)
    local index = x + y * chunkSize + z * chunkSize * chunkSize

    return chunk.chunk.voxels[index]
end

local function toInChunkCoords(x, y, z)
    return x % chunkSize, y % chunkSize, z % chunkSize
end

function VoxelWorldFunctions:getVoxel(x, y, z)
    local chunkX, chunkY, chunkZ = toChunkCoords(x, y, z)
    local chunk = self:getChunk(chunkX, chunkY, chunkZ)

    return getVoxelFromChunk(chunk, toInChunkCoords(x, y, z))
end

function fbm(x, y, z)
    local G = 0.5
    local f = 0.03125
    local a = 1
    local t = 0
    for i = 1, 6 do
        t = t + a * love.math.perlinNoise(f * x, f * y, f * z)
        f = f * 2
        a = a * G
    end
    return t
end

function VoxelWorldFunctions:generateChunkTerrain(chunk)
    local x, y, z = chunk.chunk.x, chunk.chunk.y, chunk.chunk.z

    for voxelX = 0, chunkSize - 1 do
        for voxelY = 0, chunkSize - 1 do
            for voxelZ = 0, chunkSize - 1 do
                local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                voxel.x = voxelX
                voxel.y = voxelY
                voxel.z = voxelZ

                if self.isLiquidWorld then
                    if voxelY + y * chunkSize < 12 and self.solidsVoxelWorld:getVoxel(voxelX + x * chunkSize, voxelY + y * chunkSize, voxelZ + z * chunkSize).type == 0 then
                        -- voxel.type = 3
                        -- voxel.waterLevel = 256
                    end
                else
                    if voxelY + y * chunkSize < fbm(voxelX + x * chunkSize, 0, voxelZ + z * chunkSize) * 10.0 then
                        voxel.type = 1
                    end
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

                if voxel.type == 1 and self:getVoxel(
                        voxel.x + chunk.chunk.x * chunkSize,
                        voxel.y + 1 + chunk.chunk.y * chunkSize,
                        voxel.z + chunk.chunk.z * chunkSize
                    ).type < 1 then
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

local faceAll = faceForward + faceBackward + faceLeft + faceRight + faceUp + faceDown

function VoxelWorldFunctions:calculateChunkMeshFacesActive(chunk)
    -- ugly but can't be bothered to fix it
    if self.isLiquidWorld then
        for voxelX = 0, chunkSize - 1 do
            for voxelY = 0, chunkSize - 1 do
                for voxelZ = 0, chunkSize - 1 do
                    local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                    if voxel.type >= 1 then
                        local x, y, z = voxel.x + chunk.chunk.x * chunkSize, voxel.y + chunk.chunk.y * chunkSize,
                            voxel.z + chunk.chunk.z * chunkSize

                        voxel.facesActive = faceAll

                        for _, face in ipairs(faceDirections) do
                            local neighbour = self.solidsVoxelWorld:getVoxel(x + face[1], y + face[2], z + face[3])

                            if neighbour.type >= 1 then
                                voxel.facesActive = voxel.facesActive - face[4]
                            else
                                neighbour = self:getVoxel(x + face[1], y + face[2], z + face[3])

                                -- if neighbour.type == 3 and neighbour.waterLevel >= voxel.waterLevel then
                                -- voxel.facesActive = voxel.facesActive - face[4]
                                -- end
                            end
                        end
                    end
                end
            end
        end
    else
        for voxelX = 0, chunkSize - 1 do
            for voxelY = 0, chunkSize - 1 do
                for voxelZ = 0, chunkSize - 1 do
                    local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                    if voxel.type >= 1 then
                        local x, y, z = voxel.x + chunk.chunk.x * chunkSize, voxel.y + chunk.chunk.y * chunkSize,
                            voxel.z + chunk.chunk.z * chunkSize

                        voxel.facesActive = faceAll

                        for _, face in ipairs(faceDirections) do
                            local neighbour = self:getVoxel(x + face[1], y + face[2], z + face[3])

                            if neighbour.type >= 1 then
                                voxel.facesActive = voxel.facesActive - face[4]
                            end
                        end
                    end
                end
            end
        end
    end
end

local vertexFormat = {
    { name = "VertexData",     format = "uint8vec4" },
    { name = "VertexTexCoord", format = "floatvec3" },

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

local faces = {
    { { 0, 0, 0, 0, 0, 0 }, { 1, 0, 0, 0, 1, 0 }, { 1, 1, 0, 0, 1, 1 }, { 0, 1, 0, 0, 0, 1 } }, -- forwards
    { { 0, 0, 1, 0, 0, 0 }, { 1, 0, 1, 0, 1, 0 }, { 1, 1, 1, 0, 1, 1 }, { 0, 1, 1, 0, 0, 1 } }, -- backwards
    { { 0, 0, 0, 0, 0, 0 }, { 0, 0, 1, 0, 1, 0 }, { 0, 1, 1, 0, 1, 1 }, { 0, 1, 0, 0, 0, 1 } }, -- left
    { { 1, 0, 0, 0, 0, 0 }, { 1, 0, 1, 0, 1, 0 }, { 1, 1, 1, 0, 1, 1 }, { 1, 1, 0, 0, 0, 1 } }, -- right
    { { 0, 1, 0, 0, 0, 0 }, { 1, 1, 0, 0, 1, 0 }, { 1, 1, 1, 0, 1, 1 }, { 0, 1, 1, 0, 0, 1 } }, -- up
    { { 0, 0, 0, 0, 0, 0 }, { 1, 0, 0, 0, 1, 0 }, { 1, 0, 1, 0, 1, 1 }, { 0, 0, 1, 0, 0, 1 } }, -- down
}

function VoxelWorldFunctions:generateChunkVertices(chunk)
    local vertices = {}

    for voxelX = 0, chunkSize - 1 do
        for voxelY = 0, chunkSize - 1 do
            for voxelZ = 0, chunkSize - 1 do
                local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                if tonumber(voxel.type) >= 1 then
                    for i, face in ipairs(faces) do
                        if bit.band(voxel.facesActive, 2 ^ (i - 1)) > 0 then
                            for j, vertex in ipairs(face) do
                                if self.isLiquidWorld then
                                    if vertex[2] == 0 then
                                        local dir = faceDirections[i]
                                        local facingVoxel = self:getVoxel(voxelX + dir[1] + chunk.chunk.x * chunkSize,
                                            voxelY + dir[2] + chunk.chunk.y * chunkSize,
                                            voxelZ + dir[3] + chunk.chunk.z * chunkSize)

                                        table.insert(vertices, {
                                            vertex[1] + voxelX,
                                            vertex[2] + voxelY,
                                            vertex[3] + voxelZ,
                                            voxel.type,
                                            vertex[5],
                                            vertex[6],
                                            facingVoxel.waterLevel / 256 + 1.0
                                        })
                                    else
                                        local heightMul = voxel.waterLevel / 256
                                        table.insert(vertices, {
                                            vertex[1] + voxelX,
                                            vertex[2] + voxelY,
                                            vertex[3] + voxelZ,
                                            voxel.type,
                                            vertex[5],
                                            vertex[6],
                                            heightMul
                                        })
                                    end
                                else
                                    table.insert(vertices, {
                                        vertex[1] + voxelX,
                                        vertex[2] + voxelY,
                                        vertex[3] + voxelZ,
                                        voxel.type,
                                        vertex[5],
                                        vertex[6],
                                        1.0
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    chunk.position = vec3(chunk.chunk.x * chunkSize, chunk.chunk.y * chunkSize, chunk.chunk.z * chunkSize)
    chunk.id = tostring(chunk.chunk.x) .. tostring(chunk.chunk.y) .. tostring(chunk.chunk.z)
    if #vertices == 0 then
        return chunk
    end

    local indices = generateQuadIndices(#vertices / 4)

    local mesh = love.graphics.newMesh(vertexFormat, vertices, "triangles", self.updateType)
    mesh:setVertexMap(indices)

    chunk.mesh = mesh
    chunk.vertices = vertices
    chunk.indices = indices

    return chunk
end

---comment
---@param chunk {mesh: love.Mesh, vertices: table, indices: table, position: vec3, id: string}
---@return nil
function VoxelWorldFunctions:updateChunkVertices(chunk)
    local index = 0
    local vertexCount = #chunk.vertices

    for voxelX = 0, chunkSize - 1 do
        for voxelY = 0, chunkSize - 1 do
            for voxelZ = 0, chunkSize - 1 do
                local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                if voxel.type >= 1 then
                    for i, face in ipairs(faces) do
                        local dir = faceDirections[i]
                        if bit.band(voxel.facesActive, 2 ^ (i - 1)) > 0 then
                            for _, vertex in ipairs(face) do
                                if self.isLiquidWorld then
                                    if i < 5 and vertex[2] == 0 then
                                        local facingVoxel = self:getVoxel(
                                            voxelX + dir[1] + chunk.chunk.x * chunkSize,
                                            voxelY + dir[2] + chunk.chunk.y * chunkSize,
                                            voxelZ + dir[3] + chunk.chunk.z * chunkSize
                                        )

                                        index = index + 1

                                        chunk.vertices[index] = {
                                            vertex[1] + voxelX,
                                            vertex[2] + voxelY,
                                            vertex[3] + voxelZ,
                                            voxel.type,
                                            vertex[5],
                                            vertex[6],
                                            facingVoxel.waterLevel / 256 + 1.0
                                        }
                                    else
                                        local heightMul = voxel.waterLevel / 256
                                        index = index + 1

                                        chunk.vertices[index] = {
                                            vertex[1] + voxelX,
                                            vertex[2] + voxelY,
                                            vertex[3] + voxelZ,
                                            voxel.type,
                                            vertex[5],
                                            vertex[6],
                                            heightMul
                                        }
                                    end
                                else
                                    index = index + 1

                                    chunk.vertices[index] = {
                                        vertex[1] + voxelX,
                                        vertex[2] + voxelY,
                                        vertex[3] + voxelZ,
                                        voxel.type,
                                        vertex[5],
                                        vertex[6],
                                        1.0
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if index == 0 then
        return nil
    end

    if index > vertexCount then
        local indices = generateQuadIndices(index / 4)
        local mesh = love.graphics.newMesh(vertexFormat, chunk.vertices, "triangles", self.updateType)
        mesh:setVertexMap(indices)
        chunk.mesh = mesh
        chunk.indices = indices
    else
        chunk.mesh:setVertices(chunk.vertices)
        local indices = generateQuadIndices(index / 4)

        chunk.mesh:setVertexMap(indices)
        chunk.mesh:setDrawRange(1, #indices)
    end
end

function VoxelWorldFunctions:generateVoxelWorld()
    local objects = newIdIndexedTable()
    for x = -1, 1 do
        for y = -0, 2 do
            for z = -1, 1 do
                self:generateChunkTerrain(self:getChunk(x, y, z))
            end
        end
    end

    for x = -1, 1 do
        for y = -0, 2 do
            for z = -1, 1 do
                if not self.isLiquidWorld then
                    self:finalizeTerrain(self:getChunk(x, y, z))
                end

                self:calculateChunkMeshFacesActive(self:getChunk(x, y, z))

                local object = self:generateChunkVertices(self:getChunk(x, y, z))

                if object then
                    objects:add(object)
                end
            end
        end
    end

    self.objects = objects
end

local maxFlowRate = 256
local flowDirections = {
    { 0,  0, -1 },
    { 0,  0, 1 },
    { -1, 0, 0 },
    { 1,  0, 0 },
}

function VoxelWorldFunctions:updateVoxelWorld()
    for x = -1, 1 do
        for y = -0, 2 do
            for z = -1, 1 do
                local chunk = self:getChunk(x, y, z)

                -- if chunk.updateMin.x < chunk.updateMax.x then
                for voxelX = 0, chunkSize - 1 do
                    for voxelY = 0, chunkSize - 1 do
                        for voxelZ = 0, chunkSize - 1 do
                            local voxel = getVoxelFromChunk(chunk, voxelX, voxelY, voxelZ)

                            voxel.waterLevel = math.min(256, voxel.waterLevel)
                            voxel.waterLevel = math.max(0, voxel.waterLevel)

                            if voxel.type == 3 and voxel.waterLevel > 0 then
                                local oX, oY, oZ = voxelX, voxelY - 1,
                                    voxelZ

                                local voxelBelow = self:getVoxel(oX + chunk.chunk.x * chunkSize,
                                    oY + chunk.chunk.y * chunkSize,
                                    oZ + chunk.chunk.z * chunkSize)

                                local solidVoxelBelow = self.solidsVoxelWorld:getVoxel(oX + chunk.chunk.x * chunkSize,
                                    oY + chunk.chunk.y * chunkSize, oZ + chunk.chunk.z * chunkSize)

                                if solidVoxelBelow.type == 0 and (voxelBelow.type == 0 or voxelBelow.type == 3) and voxelBelow.waterLevel < 256 then
                                    local flowRate = math.min(maxFlowRate, 256 - voxelBelow.waterLevel)

                                    voxelBelow.waterLevel = voxelBelow.waterLevel + flowRate
                                    voxel.waterLevel = voxel.waterLevel - flowRate
                                    voxelBelow.type = 3
                                end

                                local direction = flowDirections[love.math.random(1, 4)]

                                oX, oY, oZ = voxelX + direction[1], voxelY + direction[2],
                                    voxelZ + direction[3]

                                local otherVoxel = self:getVoxel(oX + chunk.chunk.x * chunkSize,
                                    oY + chunk.chunk.y * chunkSize,
                                    oZ + chunk.chunk.z * chunkSize)

                                local otherSolidVoxel = self.solidsVoxelWorld:getVoxel(oX + chunk.chunk.x * chunkSize,
                                    oY + chunk.chunk.y * chunkSize, oZ + chunk.chunk.z * chunkSize)

                                if otherSolidVoxel.type == 0 and (otherVoxel.type == 0 or otherVoxel.type == 3) and otherVoxel.waterLevel < voxel.waterLevel then
                                    local diff = voxel.waterLevel - otherVoxel.waterLevel
                                    local flowRate = math.min(maxFlowRate, diff * 0.5)

                                    otherVoxel.waterLevel = otherVoxel.waterLevel + flowRate
                                    otherVoxel.type = 3
                                    voxel.waterLevel = voxel.waterLevel - flowRate
                                end
                            elseif voxel.type == 3 and voxel.waterLevel == 0 then
                                voxel.type = 0
                            end
                        end
                    end
                end

                -- if recordedMax.x >= recordedMin.x or recordedMax.y >= recordedMin.y or recordedMax.z >= recordedMin.z then
                self:calculateChunkMeshFacesActive(chunk)
                self:updateChunkVertices(chunk)
                -- end

                -- chunk.updateMin = recordedMin
                -- chunk.updateMax = recordedMax
                -- end
            end
        end
    end
end

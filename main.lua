ffi = require("ffi")
bit = require("bit")
table.new = require("table.new")
table.clear = require("table.clear")

require("modules.vec")
require("modules.quaternions")


Renderer = {
    internal = {
        shaders = {},
        idCounters = {},
        types = {
            vec4 = vec4().CType,
            vec3 = vec3().CType,
            vec2 = vec2().CType,
            quaternion = quaternion().CType,
        }
    },
    graphics = {
        ---@diagnostic disable-next-line: undefined-field
        skybox = love.graphics.newCubeTexture("skybox.exr"),
    },
    math = {},
    debug = {},
}

require("modules.tables")
require("modules.buffers")
require("modules.camera")
require("modules.math")
require("modules.matrices")
require("modules.shaders")
require("modules.uniforms")
require("modules.graphicsFunctions")
require("modules.graphics")
require("voxels")

local mainRenderTarget = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight(), {
    format = "rgba16f",
    readable = true,
})

local mainDepthTexture = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight(), {
    format = "depth32f",
    readable = true,
})

local depthCopyTexture = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight(), {
    format = "depth32f",
    readable = true,
})

function love.load()
    Renderer.internal.renderer = love.graphics.getRendererInfo()

    Camera = Renderer.graphics.newCamera(vec3(0.0), vec3(0.0), vec2(love.graphics.getDimensions()), "Main camera", 0.1,
        10000.0, {
            highPrecision = true,
            postProcessing = false,
            renderSkybox = true,
            verticalFov = 90.0,
        })

    Camera:use()

    Renderer.internal.shaders.skyboxRenderer:send("SkyboxTexture", Renderer.graphics.skybox)
    Renderer.internal.shaders.skyboxRenderer:send("SkyboxBrightness", { 1, 1, 1 })

    WaterLOD = 0

    SolidsWorld = newVoxelWorld([[
    typedef struct {
        int16_t x, y, z;
        Voxel voxels[4096];
    } Chunk;
    ]], "Chunk", [[
        typedef struct {
            uint8_t x, y, z;
            uint8_t type;
            uint8_t facesActive;
        } Voxel;
    ]], "Voxel", "dynamic", false)

    LiquidsWorld = newVoxelWorld([[
    typedef struct {
        int16_t x, y, z;
        uint8_t lod;
        WaterVoxel voxels[?];
    } WaterChunk;
    ]], "WaterChunk", [[
        typedef struct {
            uint8_t x, y, z;
            uint8_t type;
            uint8_t facesActive;
            uint8_t waterLevel;
        } WaterVoxel;
    ]], "WaterVoxel", "stream", true, SolidsWorld,
        [[
        typedef struct {
            int16_t x, y, z;
            uint8_t lod;
            WaterVoxelLod voxels[?];
        } WaterChunkLod;
    ]], "WaterChunkLod",
        [[
        typedef struct {
            uint8_t x, y, z;
            uint8_t type;
            uint8_t facesActive;
            uint16_t waterLevel;
        } WaterVoxelLod;
    ]], "WaterVoxelLod")

    SolidsWorld:generateVoxelWorld()
    LiquidsWorld:generateVoxelWorld()

    local stoneTexture = love.image.newImageData(16, 16)
    stoneTexture:mapPixel(function(x, y)
        local color = love.math.random() * 0.1 + 0.2
        return color, color, color, 1.0
    end)

    local grassTexture = love.image.newImageData(16, 16)
    grassTexture:mapPixel(function(x, y)
        local color = love.math.random() * 0.15 + 0.6
        return color * 0.44, color * 0.54, color * 0.34, 1.0
    end)

    local waterTexture = love.image.newImageData(16, 16)
    waterTexture:mapPixel(function(x, y)
        local color = love.math.random() * 0.15 + 0.6
        return color * 0.34, color * 0.44, color * 0.54, 0.6
    end)

    local clearTexture = love.image.newImageData(16, 16)
    clearTexture:mapPixel(function(x, y)
        return 0.0, 0.0, 0.0, 0.0
    end)

    local textures = love.graphics.newArrayImage({
        clearTexture,
        stoneTexture,
        grassTexture,
        waterTexture,
        ---@diagnostic disable-next-line: assign-type-mismatch
    }, { mipmaps = "auto" })

    textures:setFilter("linear", "nearest", 16)

    Renderer.internal.shaders.main:send("voxelTextures", textures)

    -- load cubemap

    local path = "cubemaps"

    local irradianceMipCount = 6
    local specularMipCount = 10
    local irradianceSize = 32
    local specularSize = 512

    local imageDatas = {
        specular = {},
        irradiance = {},
    }

    for face = 1, 6 do
        imageDatas.specular[face] = {}
        for mip = 1, specularMipCount do
            local size = bit.rshift(specularSize, mip - 1)
            local dataPath = path .. "/specular/face" .. face .. "/" .. mip
            local data = love.filesystem.read("string", dataPath)
            ---@diagnostic disable-next-line: param-type-mismatch
            table.insert(imageDatas.specular[face], love.image.newImageData(size, size, "rg11b10f", data))
        end

        imageDatas.irradiance[face] = {}
        for mip = 1, irradianceMipCount do
            local size = bit.rshift(irradianceSize, mip - 1)
            local dataPath = path .. "/irradiance/face" .. face .. "/" .. mip
            local data = love.filesystem.read("string", dataPath)
            ---@diagnostic disable-next-line: param-type-mismatch
            table.insert(imageDatas.irradiance[face], love.image.newImageData(size, size, "rg11b10f", data))
        end
    end

    ---@diagnostic disable-next-line: undefined-field
    SpecularCubemap = love.graphics.newCubeTexture(imageDatas.specular, { mipmaps = "auto", linear = true })

    ---@diagnostic disable-next-line: undefined-field
    IrradianceCubemap = love.graphics.newCubeTexture(imageDatas.irradiance, { linear = true })

    Renderer.internal.shaders.main:send("SpecularCubemap", SpecularCubemap)
    Renderer.internal.shaders.main:send("IrradianceCubemap", IrradianceCubemap)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    if key == "up" then
        WaterLOD = WaterLOD + 1
    end

    if key == "down" then
        WaterLOD = math.max(WaterLOD - 1, 0)
    end
end

function love.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(2) then
        local sensitivity = 0.003
        Camera.rotation.x = (Camera.rotation.x + dx * sensitivity) % PI2
        Camera.rotation.y = Renderer.math.clamp(Camera.rotation.y + dy * sensitivity, -PI05, PI05)
    end
end

local function calculateMouseRay(x, y)
    local vx, vy, vz, vw = Camera.inverseProjectionMatrix:vMulSepW1(
        (x / Camera.screenSize[1] - 0.5) * 2.0,
        (y / Camera.screenSize[2] - 0.5) * 2.0,
        1.0
    )

    local ray = {
        position = vec3(),
        direction = vec3(),
    }

    vx, vy, vz = vx / vw, vy / vw, vz / vw
    local wx, wy, wz = Camera.inverseViewMatrix:vMulSepW1(vx, vy, vz)

    ray.position:set(Camera.position:get())
    ray.direction:set(Renderer.math.normalize3(wx, wy, wz))

    return ray
end


function love.mousereleased(x, y, button)
    if button == 2 then
        love.mouse.setRelativeMode(false)
    end
end

function love.mousepressed(x, y, button)
    if button == 2 then
        love.mouse.setRelativeMode(true)
    end
end

local cameraForward = vec3(0.0)
local cameraRight = vec3(0.0)

local function updateCamera(dt)
    if love.keyboard.isDown("lshift") or not love.mouse.isDown(2) then
        return
    end
    local forward = cameraForward
    cameraForward:set(math.sin(-Camera.rotation.x) * math.cos(Camera.rotation.y),
        math.sin(Camera.rotation.y), math.cos(-Camera.rotation.x) * math.cos(Camera.rotation.y))

    local right = cameraRight
    cameraRight:set(math.cos(Camera.rotation.x), 0, math.sin(Camera.rotation.x))

    local speed = 5

    local cameraPosition = Camera:getVecPosition()

    if love.keyboard.isDown("w") then
        mathv.subToA3(cameraPosition, mathv.mulScalar3(forward, (speed * dt), vec3()))
    end
    if love.keyboard.isDown("s") then
        mathv.addToA3(cameraPosition, mathv.mulScalar3(forward, (speed * dt), vec3()))
    end
    if love.keyboard.isDown("space") then
        cameraPosition.y = cameraPosition.y + (speed * dt)
    end
    if love.keyboard.isDown("lctrl") then
        cameraPosition.y = cameraPosition.y - (speed * dt)
    end
    if love.keyboard.isDown("d") then
        mathv.addToA3(cameraPosition, mathv.mulScalar3(right, (speed * dt), vec3()))
    end
    if love.keyboard.isDown("a") then
        mathv.subToA3(cameraPosition, mathv.mulScalar3(right, (speed * dt), vec3()))
    end

    Camera:setVecPosition(cameraPosition)
end

local time = 0.0

local voxelsChecked = {}
local chunksUpdated = {}

function love.update(dt)
    Camera:update()

    if love.mouse.isDown(1, 3) then
        local ray = calculateMouseRay(love.mouse.getPosition())

        table.clear(voxelsChecked)

        local hit, hitX, hitY, hitZ = rayCast(
            ray.position.x, ray.position.y, ray.position.z,
            ray.direction.x, ray.direction.y, ray.direction.z,
            1000,
            1,
            function(x, y, z)
                x, y, z = math.floor(x), math.floor(y), math.floor(z)
                local voxel = { SolidsWorld:getVoxel(x, y, z, 0) }
                table.insert(voxelsChecked, voxel)
                return voxel[1].type ~= 0
            end
        )

        if hit and hitX and hitY and hitZ then
            if love.mouse.isDown(3) then
                hitX, hitY, hitZ = math.floor(hitX), math.floor(hitY), math.floor(hitZ)

                local voxel, chunk = SolidsWorld:getVoxel(hitX, hitY, hitZ, 0)

                if voxel.type ~= 0 then
                    voxel.type = 0

                    SolidsWorld:calculateChunkMeshFacesActive(chunk)
                    SolidsWorld:updateChunkVertices(chunk)

                    table.clear(chunksUpdated)

                    chunksUpdated[chunk] = true

                    for x = -1, 1, 2 do
                        for y = -1, 1, 2 do
                            for z = -1, 1, 2 do
                                local _, otherChunk = SolidsWorld:getVoxel(hitX + x, hitY + y, hitZ + z, 0)

                                if not chunksUpdated[otherChunk] then
                                    chunksUpdated[otherChunk] = true

                                    SolidsWorld:calculateChunkMeshFacesActive(otherChunk)
                                    SolidsWorld:updateChunkVertices(otherChunk)
                                end
                            end
                        end
                    end
                end
            else
                hitX, hitY, hitZ = math.floor(hitX), math.floor(hitY), math.floor(hitZ)

                local previousVoxel = voxelsChecked[#voxelsChecked - 1]
                if not previousVoxel then return end

                local prevX, prevY, prevZ =
                    previousVoxel[1].x + previousVoxel[2].chunk.x,
                    previousVoxel[1].y + previousVoxel[2].chunk.y,
                    previousVoxel[1].z + previousVoxel[2].chunk.z
                local waterVoxel, waterChunk = LiquidsWorld:getVoxel(prevX, prevY, prevZ, 0)

                waterVoxel.type = 3
                waterVoxel.waterLevel = 255

                waterChunk.updateMin:minSeparate(waterVoxel.x, waterVoxel.y, waterVoxel.z)
                waterChunk.updateMax:maxSeparate(waterVoxel.x, waterVoxel.y, waterVoxel.z)
            end
        end
    end

    updateCamera(dt)

    time = time + dt

    if time > 1.0 / 30.0 then
        time = time - 1.0 / 30.0
        LiquidsWorld:updateVoxelWorld()
    end
end

--- Raycast function
---@param x number
---@param y number
---@param z number
---@param dirX number
---@param dirY number
---@param dirZ number
---@param length number
---@param size number
---@param isOccupied fun(x: number, y: number, z: number): boolean
---@return boolean, number?, number?, number?
function rayCast(x, y, z, dirX, dirY, dirZ, length, size, isOccupied)
    local inverseDirX, inverseDirY, inverseDirZ = 1.0 / dirX, 1.0 / dirY, 1.0 / dirZ

    local inverseSize = 1.0 / size

    local i = 0.0
    local checkLimit = (length * inverseSize) * 2.0
    local rayLength = 0.0

    local limiterX = dirX < 0 and math.floor or math.ceil
    local limiterY = dirY < 0 and math.floor or math.ceil
    local limiterZ = dirZ < 0 and math.floor or math.ceil

    while i < checkLimit do
        i = i + 1
        local cx = limiterX(x * inverseSize) * size
        local cy = limiterY(y * inverseSize) * size
        local cz = limiterZ(z * inverseSize) * size

        local px, py, pz = (cx - x) * inverseDirX, (cy - y) * inverseDirY, (cz - z) * inverseDirZ

        local step = math.max(0.0, math.min(px, py, pz, math.abs(rayLength - length))) * 1.001

        rayLength = rayLength + step

        x = x + dirX * step
        y = y + dirY * step
        z = z + dirZ * step

        if isOccupied(x, y, z) then return true, x, y, z end

        if rayLength > length then break end
    end

    return false
end

local worldItems = {}

function love.draw()
    table.clear(worldItems)

    Camera:prepareDraw()

    love.graphics.setCanvas({ mainRenderTarget, depthstencil = mainDepthTexture })
    love.graphics.clear(0.0, 0.0, 0.0, 1.0, true, true)
    love.graphics.setDepthMode("always", false)
    love.graphics.setBlendMode("replace", "premultiplied")

    love.graphics.setShader(Renderer.internal.shaders.skyboxRenderer)
    Renderer.internal.drawFullscreen()

    love.graphics.setDepthMode("lequal", true)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setMeshCullMode("none")
    love.graphics.setShader(Renderer.internal.shaders.main)

    for _, chunk in ipairs(SolidsWorld.objects.items) do
        Renderer.internal.shaders.main:send("Pos", { chunk.position.x, chunk.position.y, chunk.position.z })

        if chunk.mesh and chunk.drawMesh then
            love.graphics.draw(chunk.mesh)
        end
    end

    love.graphics.setDepthMode("always", true)
    ---@diagnostic disable-next-line: param-type-mismatch
    love.graphics.setBlendMode("none")
    love.graphics.setCanvas({ depthstencil = depthCopyTexture })
    love.graphics.setShader(Renderer.internal.shaders.overrideDepth)
    Renderer.internal.shaders.overrideDepth:send("DepthTexture", mainDepthTexture)
    Renderer.internal.drawFullscreen()

    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setCanvas({ mainRenderTarget, depthstencil = mainDepthTexture })
    love.graphics.setShader(Renderer.internal.shaders.main)
    Renderer.internal.shaders.main:send("DepthTexture", depthCopyTexture)

    for _, chunk in ipairs(LiquidsWorld.objects.items) do
        if chunk.mesh and chunk.drawMesh then
            table.insert(worldItems, chunk)
        end
    end

    table.sort(worldItems, function(a, b)
        return Camera.position:distanceSqr(a.position) > Camera.position:distanceSqr(b.position)
    end)

    love.graphics.setDepthMode("less", true)

    for _, chunk in ipairs(worldItems) do
        Renderer.internal.shaders.main:send("Pos", { chunk.position.x, chunk.position.y, chunk.position.z })

        love.graphics.draw(chunk.mesh)
    end

    love.graphics.setCanvas()
    love.graphics.setShader()

    love.graphics.setDepthMode("always", false)

    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.draw(mainRenderTarget, 0, love.graphics.getHeight(), 0, 1, -1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    love.graphics.print("Camera position: " .. tostring(Camera.position), 10, 30)
end

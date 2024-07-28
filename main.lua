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

love.mouse.setRelativeMode(true)

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
        1000.0, {
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
    ]], "Voxel", "static", false)

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
            int waterLevel;
        } WaterVoxel;
    ]], "WaterVoxel", "stream", true, SolidsWorld)

    SolidsWorld:generateVoxelWorld()
    LiquidsWorld:generateVoxelWorld()

    local stoneTexture = love.image.newImageData(16, 16)
    stoneTexture:mapPixel(function(x, y)
        local color = love.math.random() * 0.25 + 0.5
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
    }, { mipmaps = "auto" })

    textures:setFilter("linear", "nearest", 16)

    Renderer.internal.shaders.main:send("voxelTextures", textures)
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

local time = 0

function love.update(dt)
    Camera:update()

    local cx, cy, cz = toChunkCoords(Camera.position.x, Camera.position.y, Camera.position.z)
    local chunk = LiquidsWorld:getChunk(cx, cy, cz, 0)
    local x, y, z = Camera.position:get()
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    local voxel = getVoxelFromChunk(chunk, toInChunkCoords(x, y, z))
    if love.keyboard.isDown("e") then
        voxel.waterLevel = 255
        voxel.type = 3
    end

    updateCamera(dt)

    time = time + dt

    if time > 1 / 30 then
        time = time - 1 / 30
        LiquidsWorld:updateVoxelWorld()
    end
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

        if chunk.mesh then
            love.graphics.draw(chunk.mesh)
        end
    end

    love.graphics.setDepthMode("always", true)
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
        if chunk.mesh then
            table.insert(worldItems, chunk)
        end
    end

    table.sort(worldItems, function(a, b)
        return Camera.position:distanceSqr(a.position) > Camera.position:distanceSqr(b.position)
    end)

    love.graphics.setDepthMode("less", false)

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

--[[
MIT License

Copyright (c) 2023 Jasper

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

Renderer.internal.drawIndex = 0
local graphicsData

function Renderer.internal.precalculateShaderData()
    local numKernels = 64
    local kernels = {}
    local angle = math.pi * (3 - math.sqrt(5)) -- Golden angle in radians
    local n = numKernels                       -- Number of vertices

    for i = 0, n - 1 do
        local z = 1 - (i / n) * 2           -- Elevation
        local radius = math.sqrt(1 - z * z) -- Distance from the z-axis

        local azimuth = angle * i

        local x = math.cos(azimuth) * radius
        local y = math.sin(azimuth) * radius

        -- Now (x, y, z) is a point on the hemisphere
        local scale = i / numKernels
        scale = Renderer.math.mix(0.1, 1.0, scale * scale)
        local sample = TempVec3(x, y, math.abs(z)) * scale

        table.insert(kernels, sample:table())
    end
end

local function sendToShaders(name, ...)
    for i, v in ipairs({
        Renderer.internal.shaders.main,
        Renderer.internal.shaders.transparencyShader,
        Renderer.internal.shaders.gridDrawer,
    }) do
        v:send(name, ...)
    end
end

local format = {
    -- name doesn't do anything, it's just for readability
    { format = "floatvec3", name = "fogColor" },
    { format = "float",     name = "fogCutOffDistance" },
    { format = "floatvec3", name = "fogDensity" },
    { format = "float",     name = "fogHeightFalloff" },
    { format = "float",     name = "iblLuminance" },
    { format = "float",     name = "fogMaxOpacity" },
    { format = "float",     name = "fogStart" },
    { format = "float",     name = "fogInscatteringSize" },
    { format = "float",     name = "fogInscatteringStart" },
    { format = "floatvec4", name = "lightColorIntensity" },
    { format = "floatvec3", name = "lightDirection" },
    { format = "float",     name = "samplesPerMeter" },
    { format = "float",     name = "maxSamples" },
}

local formatSize = 3 + 1 + 3 + 1 + 1 + 1 + 1 + 1 + 1 + 4 + 3 + 1 + 1

Renderer.internal.fogBufferData = table.new(formatSize, 0)

for i = 1, formatSize do
    Renderer.internal.fogBufferData[i] = 0
end

Renderer.internal.fogDataBuffer = love.graphics.newBuffer(format, Renderer.internal.fogBufferData,
    { shaderstorage = true, debugname = "Fog data buffer" })

function Renderer.internal.updateFogSettings(scene, camera)
    local fogSettings = scene.engineData.settings.fog

    local density = fogSettings.fogDensity
    local falloff = 1 / fogSettings.fogHeightFalloff
    local height = fogSettings.fogHeight
    local falloffDensity = -falloff * (camera.position.y - height)

    Renderer.internal.fogBufferData[1] = fogSettings.fogColor[1]
    Renderer.internal.fogBufferData[2] = fogSettings.fogColor[2]
    Renderer.internal.fogBufferData[3] = fogSettings.fogColor[3]

    Renderer.internal.fogBufferData[4] = fogSettings.fogCutOffDistance

    Renderer.internal.fogBufferData[5] = density
    Renderer.internal.fogBufferData[6] = falloffDensity
    Renderer.internal.fogBufferData[7] = density * math.exp(falloffDensity)

    Renderer.internal.fogBufferData[8] = 1 / fogSettings.fogHeightFalloff
    Renderer.internal.fogBufferData[9] = fogSettings.iblLuminance
    Renderer.internal.fogBufferData[10] = fogSettings.fogMaxOpacity
    Renderer.internal.fogBufferData[11] = fogSettings.fogStart
    Renderer.internal.fogBufferData[12] = fogSettings.fogInscatteringSize
    Renderer.internal.fogBufferData[13] = fogSettings.fogInscatteringStart

    Renderer.internal.fogBufferData[14] = fogSettings.lightColorIntensity[1]
    Renderer.internal.fogBufferData[15] = fogSettings.lightColorIntensity[2]
    Renderer.internal.fogBufferData[16] = fogSettings.lightColorIntensity[3]

    Renderer.internal.fogBufferData[17] = fogSettings.lightDirection.x
    Renderer.internal.fogBufferData[18] = fogSettings.lightDirection.y
    Renderer.internal.fogBufferData[19] = fogSettings.lightDirection.z

    Renderer.internal.fogDataBuffer:setArrayData(Renderer.internal.fogBufferData)

    sendToShaders("FogframeUniforms", Renderer.internal.fogDataBuffer)
end

function Renderer.internal.updateFogCameraData(scene, camera)
    local fogSettings = scene.engineData.settings.fog

    local density = fogSettings.fogDensity
    local falloff = 1 / fogSettings.fogHeightFalloff
    local height = fogSettings.fogHeight
    local falloffDensity = -falloff * (camera.position.y - height)

    Renderer.internal.fogBufferData[5] = density
    Renderer.internal.fogBufferData[6] = falloffDensity
    Renderer.internal.fogBufferData[7] = density * math.exp(falloffDensity)

    Renderer.internal.fogDataBuffer:setArrayData(Renderer.internal.fogBufferData)
end

local function drawInstancedObjects()
    love.graphics.setMeshCullMode("none")
    graphicsData.pointDrawer:draw(false, false, true)
    graphicsData.lineDrawer:draw(false, false, true)

    love.graphics.setDepthMode("always", false) -- draw the instanced objects without depth testing so they are always visible

    graphicsData.overlayPointDrawer:draw(false, false, true)
    graphicsData.overlayLineDrawer:draw(false, false, true)

    love.graphics.setDepthMode("less", true) -- reset the depth mode to the default
    love.graphics.setMeshCullMode("back")
end

local function sendToShader(shader, name, variable)
    if not variable then
        shader:send("drawSettings." .. name, false)
    else
        shader:send("drawSettings." .. name, true)
        shader:send("modelMaterial." .. name, variable)
    end
end
local function drawLights(scene, shader)
    love.graphics.setMeshCullMode("none")

    sendToShader(shader, "AlbedoMap", graphicsData.whiteTexture)
    sendToShader(shader, "EmissiveMap", graphicsData.whiteTexture)
    sendToShader(shader, "ReflectanceMap", graphicsData.whiteTexture)
    sendToShader(shader, "EmissiveFactor", { 10, 10, 10 })
    sendToShader(shader, "NormalMap")
    sendToShader(shader, "RoughnessMap")
    sendToShader(shader, "MetallicMap")

    for i, v in ipairs(scene.directionalLights.items) do
        v:draw(shader)
    end

    for i, v in ipairs(scene.spotLights.items) do
        v:draw(shader)
    end

    for i, v in ipairs(scene.pointLights.items) do
        v:draw(shader)
    end

    for i, v in ipairs(scene.areaLights.items) do
        v:draw(shader)
    end

    for i, v in ipairs(scene.sphereLights.items) do
        v:draw(shader)
    end

    love.graphics.setMeshCullMode("back")
end

Renderer.internal.resetScaleTable = { 1, 1, 1 }
Renderer.internal.resetQuatTable = { 0, 0, 0, 1 }

--- draw scene as lights
---@param scene Renderer.scene
---@param drawCode fun(shader: love.Shader, isGeometryShader: boolean, frustum: table)
---@param camera Renderer.camera
local function drawSceneAsLight(scene, drawCode, camera)
    for i, v in ipairs(scene.directionalLights.items) do
        ---@cast v Renderer.directionalLight
        Renderer.internal.drawIndex = Renderer.internal.drawIndex + 1
        v:renderShadowMap(scene, drawCode, camera.useStandardObjectRenderer)
    end
    for i, v in ipairs(scene.spotLights.items) do
        ---@cast v Renderer.spotLight
        Renderer.internal.drawIndex = Renderer.internal.drawIndex + 1
        v:renderShadowMap(scene, drawCode, camera.useStandardObjectRenderer)
    end
end

function Renderer.internal.supplyLightSettings(scene)
    local main = Renderer.internal.shaders.main
    local transparency = Renderer.internal.shaders.transparencyShader

    for i, v in ipairs(scene.spotLights.items) do
        v:supplyShaderData()
    end

    for i, v in ipairs(scene.directionalLights.items) do
        v:supplyShaderData()
    end

    for i, v in ipairs(scene.pointLights.items) do
        v:supplyShaderData()
    end

    for i, v in ipairs(scene.areaLights.items) do
        v:supplyShaderData()
    end

    for i, v in ipairs(scene.sphereLights.items) do
        v:supplyShaderData()
    end

    Renderer.internal.buffers.pointlights:flush()
    Renderer.internal.buffers.spotlights:flush()
    Renderer.internal.buffers.directionallights:flush()
    Renderer.internal.buffers.arealights:flush()
    Renderer.internal.buffers.spherelights:flush()

    main:send("PointLightAmount", #scene.pointLights.items)
    main:send("SpotLightAmount", #scene.spotLights.items)
    main:send("DirectionalLightAmount", #scene.directionalLights.items)
    main:send("AreaLightAmount", #scene.areaLights.items)
    main:send("SphereLightAmount", #scene.sphereLights.items)

    transparency:send("PointLightAmount", #scene.pointLights.items)
    transparency:send("SpotLightAmount", #scene.spotLights.items)
    transparency:send("DirectionalLightAmount", #scene.directionalLights.items)
    transparency:send("AreaLightAmount", #scene.areaLights.items)
    transparency:send("SphereLightAmount", #scene.sphereLights.items)

    main:send("PointLights", Renderer.internal.buffers.pointlights:getBuffer())
    main:send("SpotLights", Renderer.internal.buffers.spotlights:getBuffer())
    main:send("DirectionalLights", Renderer.internal.buffers.directionallights:getBuffer())
    main:send("AreaLights", Renderer.internal.buffers.arealights:getBuffer())
    main:send("SphereLights", Renderer.internal.buffers.spherelights:getBuffer())

    transparency:send("PointLights", Renderer.internal.buffers.pointlights:getBuffer())
    transparency:send("SpotLights", Renderer.internal.buffers.spotlights:getBuffer())
    transparency:send("DirectionalLights", Renderer.internal.buffers.directionallights:getBuffer())
    transparency:send("AreaLights", Renderer.internal.buffers.arealights:getBuffer())
    transparency:send("SphereLights", Renderer.internal.buffers.spherelights:getBuffer())
end

--- draws fog objects
---@param scene Renderer.scene
---@param camera Renderer.camera
---@param groupCount vec3
---@return boolean
function Renderer.internal.drawFogObjects(scene, camera, groupCount)
    table.sort(scene.volumes.items, function(a, b)
        local aDist = Renderer.math.pointAABBDistanceSqrCentered(a.position, a.scale, camera.position)
        local bDist = Renderer.math.pointAABBDistanceSqrCentered(b.position, b.scale, camera.position)
        return aDist > bDist
    end)

    local drawnAnyObjects = false

    for i, v in ipairs(scene.volumes.items) do
        if i > scene.engineData.settings.volumetricLighting.maxVolumesOnScreen then break end

        drawnAnyObjects = v:draw(Renderer.internal.computeShaders.sampleVolumes, camera.frustum, false) or
            drawnAnyObjects

        -- love.graphics.dispatchThreadgroups(Renderer.internal.computeShaders.sampleVolumes, groupCount:get())

        Renderer.internal.shaders.volumetricApply:send("volumeData[" .. i - 1 .. "].boxMin",
            (v.position - v.scale / 2):ttable())
        Renderer.internal.shaders.volumetricApply:send("volumeData[" .. i - 1 .. "].boxMax",
            (v.position + v.scale / 2):ttable())
    end

    return drawnAnyObjects
end

do
    local sortingX, sortingY, sortingZ = 0, 0, 0
    ---@param a Renderer.jolt.body
    ---@param b Renderer.jolt.body
    local function sortingFunction(a, b)
        local aX, aY, aZ = a:getPosition()
        local diffAX, diffAY, diffAZ = aX - sortingX, aY - sortingY, aZ - sortingZ
        local aDist = diffAX * diffAX + diffAY * diffAY + diffAZ * diffAZ

        local bX, bY, bZ = b:getPosition()
        local diffBX, diffBY, diffBZ = bX - sortingX, bY - sortingY, bZ - sortingZ
        local bDist = diffBX * diffBX + diffBY * diffBY + diffBZ * diffBZ

        if math.abs(aDist - bDist) < 0.1 then
            return a.id > b.id
        end

        return aDist < bDist
    end

    --- draws scene objects
    ---@param scene Renderer.scene
    ---@param shader love.Shader
    ---@param passData table
    ---@param inverted boolean
    ---@param position vec3
    function Renderer.internal.drawSceneObjects(scene, shader, passData, inverted, position)
        prof.push("Draw Scene Objects")
        if inverted == nil then inverted = false end

        sortingX, sortingY, sortingZ = position:get()

        prof.push("Sorting time")
        if Renderer.debug.boolean("Do sorting", true) then
            Renderer.internal.sort.insertion_sort(scene.distanceSortedObjects, sortingFunction)
        end
        prof.pop()

        prof.push("Draw time")
        Renderer.internal.resetCurrentMaterial()
        if inverted then
            for index = #scene.distanceSortedObjects, 1, -1 do
                local object = scene.distanceSortedObjects[index]
                object:draw(shader, passData, nil)
            end
        else
            for index = 1, #scene.distanceSortedObjects do
                local object = scene.distanceSortedObjects[index]
                object:draw(shader, passData, nil)
            end
        end
        prof.pop()

        prof.push("Draw instanced time")
        for index, object in ipairs(scene.instancedMeshes.items) do
            ---@cast object Renderer.mesh
            object:drawInstanced(true, false, true)
        end
        prof.pop()

        love.graphics.setShader(shader)

        if passData.geometryPass then
            shader:send("drawSettings.AlbedoMap", true)
            shader:send("drawSettings.NormalMap", false)
            shader:send("drawSettings.RoughnessMap", true)
            shader:send("drawSettings.MetallicMap", true)
            shader:send("drawSettings.OcclusionMap", false)
            shader:send("drawSettings.EmissiveMap", false)
            shader:send("drawSettings.ReflectanceMap", true)
            shader:send("drawSettings.EmissiveFactor", false)

            shader:send("drawSettings.HasSkeleton", false)

            shader:send("modelMaterial.AlbedoMap", graphicsData.whiteTexture)
            shader:send("modelMaterial.RoughnessMap", graphicsData.blackTexture)
            shader:send("modelMaterial.MetallicMap", graphicsData.whiteTexture)
            shader:send("modelMaterial.ReflectanceMap", graphicsData.whiteTexture)

            for index, object in ipairs(scene.lightProbes.items) do
                object:draw(shader, passData)
            end
        end

        prof.pop()
    end
end

function Renderer.internal.drawWireframes(scene, shader)
    love.graphics.setMeshCullMode("none")
    love.graphics.setWireframe(true)

    for i, v in ipairs(scene.directionalLights.items) do
        if v:isWireframeEnabled() then v:drawWireframe(shader) end
    end

    for i, v in ipairs(scene.spotLights.items) do
        if v:isWireframeEnabled() then v:drawWireframe(shader) end
    end

    for i, v in ipairs(scene.volumes.items) do
        if v:isWireframeEnabled() then v:drawWireframe(shader) end
    end

    for i, v in ipairs(scene.lightProbes.items) do
        if Renderer.internal.iWireframe:implements(v) and v:isWireframeEnabled() then v:drawWireframe(shader) end
    end

    love.graphics.setMeshCullMode("back")
    love.graphics.setWireframe(false)
end

local geometryClearTable = {}

for i = 1, 6 do
    table.insert(geometryClearTable, { 0, 0, 0, 0 })
end

table.insert(geometryClearTable, 0)
table.insert(geometryClearTable, 1)

local function mipmapDepthBuffer(camera)
    local shader = Renderer.internal.shaders.blurDepthMin

    local setters = camera.canvasSetters

    ---@type love.Canvas
    local depthstencil = camera.geometryTarget.depthstencil

    shader:send("DepthTexture", depthstencil)
    love.graphics.setBlendMode("none")
    love.graphics.setDepthMode("always", true)

    love.graphics.setShader(shader)
    for i = 2, 5 do
        setters.depthDownSample[i].depthstencil[1] = depthstencil
        love.graphics.setCanvas(setters.depthDownSample[i])

        shader:send("LOD", i - 2)
        shader:send("HalfTexelSize", setters.depthDownSampleHalfTexelSizes[i])
        shader:send("flipY", true)

        love.graphics.drawFromShader("triangles", 3, 1)
    end
end

local geometryDrawSettings = {
    geometryPass = true,
    frustum = nil,
    ignoreCulling = false,
    transparencyPass = false,
    shadowMappingPass = false
}

local transparencyDrawSettings = {
    geometryPass = false,
    frustum = nil,
    ignoreCulling = false,
    transparencyPass = true,
    shadowMappingPass = false
}

local randomDirections = { {}, {}, {}, {}, {}, {}, {}, {} }

--- draws the scene
---@param drawCode fun(shader: love.Shader, isGeometryShader: boolean, frustum: table)
---@param camera Renderer.camera
---@return love.Canvas
---@return love.Canvas
function Renderer.graphics.drawSceneAs(scene, drawCode, camera)
    prof.push("Draw Scene as")

    local mainShader = Renderer.internal.shaders.main
    local geometryShader = Renderer.internal.shaders.geometryShader
    local transparencyShader = Renderer.internal.shaders.transparencyShader

    local setters = camera.canvasSetters

    -- update fog data
    Renderer.internal.updateFogCameraData(scene, camera)

    -- setup graphics
    love.graphics.setColor(1, 1, 1)
    love.graphics.scale(camera.scale[1], camera.scale[2])
    love.graphics.setFrontFaceWinding("cw")
    love.graphics.setMeshCullMode("front")

    prof.push("Shadow mapping")

    -- draw scene as lights
    Renderer.internal.openGL.PushEvent("Draw Lights")
    drawSceneAsLight(scene, drawCode, camera)
    Renderer.internal.openGL.PopEvent()

    love.graphics.setMeshCullMode("back")

    prof.pop()
    prof.push("Draw scene")

    -- draw scene as geometry
    do
        Renderer.internal.openGL.PushEvent("Draw Geometry")
        love.graphics.setShader(geometryShader)
        love.graphics.setBlendMode("none")
        love.graphics.setCanvas(camera.geometryTarget)
        love.graphics.setDepthMode("less", true)
        love.graphics.clear(unpack(geometryClearTable))

        graphicsData.instancedPointIndex = 1
        graphicsData.instancedLineIndex = 1

        Renderer.internal.drawIndex = Renderer.internal.drawIndex + 1
        drawCode(geometryShader, camera.frustum, geometryDrawSettings)
        if camera.useStandardObjectRenderer then
            geometryDrawSettings.frustum = camera.frustum
            Renderer.internal.drawSceneObjects(scene, geometryShader, geometryDrawSettings,
                false,
                camera.position
            )
        end

        geometryShader:send("drawSettings.HasSkeleton", false)

        drawLights(scene, geometryShader)

        Renderer.internal.openGL.PopEvent()
    end

    prof.pop()
    prof.push("mipmap depth buffer")

    Renderer.internal.openGL.PushEvent("Mipmap Depth Buffer")

    mipmapDepthBuffer(camera)

    Renderer.internal.openGL.PopEvent()

    prof.pop()
    prof.push("Draw SSAO")

    -- calculate screen space ambient occlusion
    Renderer.internal.openGL.PushEvent("SSAO")

    do
        -- https://developer.nvidia.com/sites/default/files/akamai/gamedev/docs/BAVOIL_ParticleShadowsAndCacheEfficientPost.pdf#page=56

        -- Deinterleaving
        Renderer.internal.openGL.PushEvent("Draw SSAO Prepass")
        prof.push("SSAO Prepass")
        do
            local prepass = Renderer.internal.shaders.ssaoPrepass

            love.graphics.setDepthMode("always", false)

            prepass:send("DepthTexture", camera.mainRenderTarget.depthstencil)
            -- prepass:send("ScreenSize", { camera.width / 4, camera.height / 4 })

            love.graphics.setShader(prepass)

            love.graphics.origin()

            for i = 1, 4 do
                love.graphics.setCanvas(camera.ssao.targets[i])
                prepass:send("DrawIndex", i - 1)

                Renderer.internal.drawFullscreen()
            end
        end
        prof.pop()
        prof.push("SSAO Apply")

        local ssaoShader = Renderer.internal.shaders.ssao
        Renderer.internal.openGL.PopEvent()
        Renderer.internal.openGL.PushEvent("Draw SSAO")


        ssaoShader:send("PreviousApplyCanvas", camera.ssao.previousApplyCanvas)

        love.graphics.setShader(ssaoShader)

        for i = 1, 16 do
            setters.ssaoApply[i][1][1] = camera.ssao.applyCanvas
            love.graphics.setCanvas(setters.ssaoApply[i])

            for j = 1, 6 do
                local x, y = Renderer.math.normalize2(love.math.random() * 2.0 - 1.0, love.math.random() * 2.0 - 1.0)
                randomDirections[j][1], randomDirections[j][2] = x, y
            end

            ssaoShader:send("State", love.math.random(0, 2 ^ 32 - 1))
            -- ssaoShader:send("RandomDirections", unpack(randomDirections))
            ssaoShader:send("DeinterleavedTexture", camera.ssao.prepassCanvases[i])
            ssaoShader:send("DrawIndex", i - 1)

            -- ssaoShader:send("TexelOffset", setters.ssaoApplyOffset[i])

            Renderer.internal.drawFullscreen()
        end

        prof.pop()
        prof.push("SSAO Postprocess")

        local postProcess = Renderer.internal.shaders.ssaoPostProcess

        love.graphics.setShader(postProcess)

        love.graphics.setCanvas(camera.ssao.combine)

        postProcess:send("PreviousCanvas", camera.ssao.previousCombineCanvas)
        postProcess:send("CurrentDepth", camera.mainRenderTarget.depthstencil)
        postProcess:send("PreviousDepth", camera.previousRenderTarget.depthstencil)

        Renderer.internal.drawFullscreen()

        Renderer.internal.openGL.PopEvent()
        prof.pop()
    end
    Renderer.internal.openGL.PopEvent()

    prof.pop()
    prof.push("Draw cubemaps")

    do
        Renderer.internal.openGL.PushEvent("Draw Cubemaps")

        local shader = Renderer.internal.shaders.cubemaps

        Renderer.internal.sendLightprobeData(shader, camera.position)

        love.graphics.setShader(shader)

        love.graphics.setCanvas(camera.canvasSetters.cubemaps)

        shader:send("DepthTexture", camera.mainRenderTarget.depthstencil)

        Renderer.internal.drawFullscreen()

        love.graphics.setCanvas({ camera.screenSpaceReflections, camera.ssrInfluenceCanvas })

        Renderer.internal.openGL.PopEvent()
    end

    prof.pop()
    prof.push("Draw ssr")

    love.graphics.scale(camera.width / love.graphics.getWidth(), camera.height / love.graphics.getHeight())

    local rnd = love.math.random(0, 2 ^ 32 - 1)

    -- calculate screen space reflections
    if scene.engineData.settings.screenSpaceReflections.enabled then
        local ssrShader = Renderer.internal.shaders.screenSpaceReflections

        love.graphics.setDepthMode("always", false)

        Renderer.internal.openGL.PushEvent("Draw Screen Space Reflections")

        ssrShader:send("DepthTexture", camera.previousRenderTarget.depthstencil)
        ssrShader:send("random", rnd)

        love.graphics.setShader(ssrShader)

        Renderer.internal.drawFullscreen()

        Renderer.internal.openGL.PopEvent()
    end

    prof.pop()

    prof.push("reflections post process")
    do
        local shader = Renderer.internal.shaders.reflectionsPostProcess

        love.graphics.setShader(shader)

        love.graphics.setCanvas(camera.reflectionsPostProcessCanvas)

        shader:send("ReflectionTexture", camera.reflectionCanvas)
        shader:send("SsrTexture", camera.screenSpaceReflections)
        shader:send("SsrInfluenceTexture", camera.ssrInfluenceCanvas)
        shader:send("PreviousReflectedTexture", camera.previousReflectionsPostProcessCanvas)
        shader:send("SsrEnabled", scene.engineData.settings.screenSpaceReflections.enabled)
        shader:send("NormalTexture", camera.geometryTarget[1])
        shader:send("PreviousDepthTexture", camera.previousRenderTarget.depthstencil)

        Renderer.internal.drawFullscreen()

        -- call setCanvas to flush the draw stack
        love.graphics.setCanvas(camera.mainRenderTarget)
    end

    prof.pop()

    prof.push("Draw main")

    -- draw scene as main lighting pass
    do
        Renderer.internal.openGL.PushEvent("Draw Main")

        mainShader:send("DepthTexture", camera.mainRenderTarget.depthstencil)
        mainShader:send("OcclusionTexture", camera.ssao.combine)
        mainShader:send("ReflectionTexture", camera.reflectionsPostProcessCanvas)

        love.graphics.clear(0, 0, 0, 0, false, false)
        love.graphics.setMeshCullMode("back")
        love.graphics.setBlendMode("alpha")
        love.graphics.setShader(mainShader)

        Renderer.internal.supplyLightSettings(scene)

        Renderer.internal.drawFullscreen()

        love.graphics.setDepthMode("less", true)

        Renderer.internal.openGL.PopEvent()
    end

    prof.pop()
    prof.push("Draw instanced")

    -- draw instanced objects (lines and vertices)
    do
        Renderer.internal.openGL.PushEvent("Draw Instanced")

        love.graphics.setShader(Renderer.internal.shaders.instancedDrawShader)

        drawInstancedObjects()

        Renderer.internal.openGL.PopEvent()
    end

    if camera.wireframesEnabled then
        love.graphics.setWireframe(true)
        love.graphics.setMeshCullMode("none")
        love.graphics.setDepthMode("less", false)
        love.graphics.setColor(1, 1, 1)
        local shader = Renderer.internal.shaders.basicVertexShader
        love.graphics.setShader(shader)

        Renderer.internal.drawWireframes(scene, shader)

        love.graphics.setWireframe(false)
        love.graphics.setMeshCullMode("back")
    end

    prof.pop()
    prof.push("Draw grid")

    -- draw grid 1x1m among x and z axis
    if scene.engineData.settings.grid.enabled then
        local gridShader = Renderer.internal.shaders.gridDrawer
        love.graphics.setColor(1, 1, 1)
        love.graphics.setDepthMode("always", false)
        love.graphics.setShader(gridShader)

        gridShader:send("DepthTexture", camera.mainRenderTarget.depthstencil)

        Renderer.internal.drawFullscreen()
    end

    prof.pop()
    prof.push("Draw volumetrics")

    -- draw volumetric lighting
    if scene.engineData.settings.volumetricLighting.enabled then
        Renderer.internal.openGL.PushEvent("Draw Volumetrics")

        Renderer.internal.applyVolumetricLighting(scene, camera)

        Renderer.internal.openGL.PopEvent()
    end

    love.graphics.setMeshCullMode("back")

    prof.pop()
    prof.push("Draw transparent")

    -- draw scene transparent objects
    do
        local shader = Renderer.internal.shaders.transparencyShader

        Renderer.internal.openGL.PushEvent("Draw Transparent Objects")

        transparencyShader:send("DepthTexture", camera.mainRenderTarget.depthstencil)
        transparencyShader:send("PreviousFrame", camera.previousRenderTarget[1])

        love.graphics.setShader(shader)
        love.graphics.setBlendMode("alpha", "alphamultiply")
        love.graphics.setDepthMode("less", false)
        if camera.useStandardObjectRenderer then
            transparencyDrawSettings.frustum = camera.frustum
            Renderer.internal.drawIndex = Renderer.internal.drawIndex + 1
            Renderer.internal.drawSceneObjects(scene, shader, transparencyDrawSettings, true, camera.position)
        end
        Renderer.internal.openGL.PopEvent()
    end

    graphicsData.instancedLineIndex = 1
    graphicsData.instancedPointIndex = 1

    prof.pop()
    prof.pop()

    love.graphics.origin()
    love.graphics.setDepthMode("always", false)
    love.graphics.setMeshCullMode("none")

    Renderer.internal.drawIndex = Renderer.internal.drawIndex % 10000

    return camera.mainRenderTarget[1], camera.mainRenderTarget.depthstencil
end

--- draws the scene
---@param drawCode fun(shader: love.Shader, isGeometryShader: boolean, frustum: table)
---@param camera Renderer.camera
---@return love.Canvas depth depth buffer
function Renderer.graphics.DrawScene(scene, drawCode, camera)
    camera:prepareDraw()

    Renderer.internal.shaders.screenSpaceReflections:send("PreviousFrame", camera.previousRenderTarget[1])

    local canvas, depth = scene:draw(drawCode, camera)

    Renderer.internal.applyPostProcessing(canvas, camera) -- render to main render target

    return depth
end

---draws vertices {x, y, z, size, r, g, b}
---@param vertices table
function Renderer.graphics.points(vertices)
    if not vertices then return end
    local size = love.graphics.getPointSize()
    local lr, lg, lb = love.graphics.getColor()
    for i, v in pairs(vertices) do
        local s = v[4] or size
        local r, g, b = v[5] or lr, v[6] or lg, v[7] or lb
        graphicsData.pointDrawer:addInstance({ { v[1], v[2], v[3] }, { 0, 0, 0, 1 }, { s, s, s }, { r, g, b } })
    end
end

---draws vertices {x, y, z, radius, r, g, b}
function Renderer.graphics.point(x, y, z, radius, r, g, b)
    radius = radius or love.graphics.getPointSize()
    local lg, lb, lr = love.graphics.getColor()

    graphicsData.pointDrawer:addInstance({ { x, y, z }, { 0, 0, 0, 1 }, { radius, radius, radius }, { r or lr, g or lg, b or lb } })
end

--- draws the geometry instead of adding it to the draw stack for instanced rendering
function Renderer.graphics.drawPointDirect(x, y, z, radius)
    radius = radius or love.graphics.getPointSize()
    local shader = love.graphics.getShader()

    shader:send("Pos", { x, y, z })
    shader:send("Scale", { radius, radius, radius })
    shader:send("Quat", Renderer.internal.resetQuatTable)

    love.graphics.draw(graphicsData.sphereMesh)
end

---draws vertices but only from a position so you can use vec3
---@param vertices table
function Renderer.graphics.vecPoints(vertices)
    if not vertices then return end
    local size = love.graphics.getPointSize()
    local r, g, b = love.graphics.getColor()
    for i, v in ipairs(vertices) do
        graphicsData.pointDrawer:addInstance({ { v.x, v.y, v.z }, { 0, 0, 0, 1 }, { size, size, size }, { r, g, b } })
    end
end

---draws vertices {x, y, z, size, r, g, b}
function Renderer.graphics.overlayPoint(x, y, z, size, r, g, b)
    size = size or love.graphics.getPointSize()
    local lg, lb, lr = love.graphics.getColor()

    graphicsData.overlayPointDrawer:addInstance({ { x, y, z }, { 0, 0, 0, 1 }, { size, size, size }, { r or lr, g or lg, b or lb } })
end

function Renderer.math.stripToTriangles(strip)
    local triangles = {}

    local swap = false

    for i = 3, #strip do
        if swap then
            table.insert(triangles, strip[i - 1])
            table.insert(triangles, strip[i - 2])
            table.insert(triangles, strip[i])
        else
            table.insert(triangles, strip[i - 2])
            table.insert(triangles, strip[i - 1])
            table.insert(triangles, strip[i])
        end

        swap = not swap
    end

    return triangles
end

function Renderer.math.fanToTriangles(fan)
    local triangles = {}
    for i = 3, #fan do
        table.insert(triangles, fan[1])
        table.insert(triangles, fan[i])
        table.insert(triangles, fan[i - 1])
    end
    return triangles
end

--- draws a 3D line
---@param x1 number start
---@param y1 number start
---@param z1 number start
---@param x2 number end
---@param y2 number end
---@param z2 number end
---@param width? number width
function Renderer.graphics.line(x1, y1, z1, x2, y2, z2, width)
    local pitch = math.atan2(y1 - y2, Renderer.math.length2(z2 - z1, x2 - x1))
    local quat = Renderer.math.eulerToQuaternion(pitch, math.atan2(x2 - x1, z2 - z1), 0):invert()
    local r, g, b = love.graphics.getColor()
    graphicsData.lineDrawer:addInstance({
        { (x1 + x2) / 2,
            (y1 + y2) / 2,
            (z1 + z2) / 2 },
        { quat.x == 0 and nil or quat.x,
            quat.y == 0 and nil or quat.y,
            quat.z == 0 and nil or quat.z,
            quat.w == 1 and nil or quat.w },
        { width or 0.005,
            width or 0.005,
            Renderer.math.length3(x1 - x2, y1 - y2, z1 - z2) },
        { r,
            g,
            b }
    })
end

--- draws a 3D line
---@param x1 number start
---@param y1 number start
---@param z1 number start
---@param x2 number end
---@param y2 number end
---@param z2 number end
---@param width? number width
function Renderer.graphics.lineDirect(x1, y1, z1, x2, y2, z2, width)
    local pitch = math.atan2(y1 - y2, Renderer.math.length2(z2 - z1, x2 - x1))
    local quat = Renderer.math.eulerToQuaternion(pitch, math.atan2(x2 - x1, z2 - z1), 0)

    local shader = love.graphics.getShader()

    shader:send("Pos", { (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2 })
    shader:send("Quat", quat:ttable())
    shader:send("Scale", { width or 0.005, width or 0.005, Renderer.math.length3(x1 - x2, y1 - y2, z1 - z2) })

    love.graphics.draw(graphicsData.LineMesh)
end

--- draws a 3D box
---@param x number
---@param y number
---@param z number
---@param w number
---@param h number
---@param d number
function Renderer.graphics.cubeDirect(x, y, z, w, h, d)
    local shader = love.graphics.getShader()

    shader:send("Pos", { x, y, z })
    shader:send("Quat", Renderer.internal.resetQuatTable)
    shader:send("Scale", { w * 0.5, h * 0.5, d * 0.5 })

    love.graphics.draw(graphicsData.cubeMesh)
end

--- draws a 3D line
---@param x1 number start
---@param y1 number start
---@param z1 number start
---@param x2 number end
---@param y2 number end
---@param z2 number end
---@param width? number width
function Renderer.graphics.overlayLine(x1, y1, z1, x2, y2, z2, width)
    local pitch = math.atan2(y1 - y2, Renderer.math.length2(z2 - z1, x2 - x1))
    local quat = Renderer.math.eulerToQuaternion(pitch, math.atan2(x2 - x1, z2 - z1), 0):invert()
    local r, g, b = love.graphics.getColor()
    graphicsData.overlayLineDrawer:addInstance({
        { (x1 + x2) / 2,
            (y1 + y2) / 2,
            (z1 + z2) / 2 },
        { quat.x == 0 and nil or quat.x,
            quat.y == 0 and nil or quat.y,
            quat.z == 0 and nil or quat.z,
            quat.w == 1 and nil or quat.w },
        { width or 0.005,
            width or 0.005,
            Renderer.math.length3(x1 - x2, y1 - y2, z1 - z2) },
        { r,
            g,
            b }
    })
end

--- draws a 3D cube
---@param x number
---@param y number
---@param z number
---@param w number
---@param h number
---@param d number
---@param width? number line width
function Renderer.graphics.cube(x, y, z, w, h, d, width)
    Renderer.graphics.line(x, y, z, x, y + h, z, width)
    Renderer.graphics.line(x + w, y + h, z, x + w, y, z, width)
    Renderer.graphics.line(x, y + h, z + d, x, y, z + d, width)
    Renderer.graphics.line(x + w, y + h, z + d, x + w, y, z + d, width)

    Renderer.graphics.line(x, y + h, z, x, y + h, z + d, width)
    Renderer.graphics.line(x, y + h, z, x + w, y + h, z, width)
    Renderer.graphics.line(x + w, y + h, z, x + w, y + h, z + d, width)
    Renderer.graphics.line(x, y + h, z + d, x + w, y + h, z + d, width)

    Renderer.graphics.line(x, y, z, x, y, z + d, width)
    Renderer.graphics.line(x, y, z, x + w, y, z, width)
    Renderer.graphics.line(x + w, y, z, x + w, y, z + d, width)
    Renderer.graphics.line(x, y, z + d, x + w, y, z + d, width)
end

--- draws a 3D arrow
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param width? number line width
function Renderer.graphics.arrow(x1, y1, z1, x2, y2, z2, width)
    local shader = love.graphics.getShader()
    local cullMode = love.graphics.getMeshCullMode()
    if shader then
        local size = Renderer.math.length3(x1 - x2, y1 - y2, z1 - z2)
        local pos = TempVec3(x1 + x2, y1 + y2, z1 + z2) * 0.5
        love.graphics.setMeshCullMode("none")
        local s = width or 0.05
        local pitch = math.atan2(y1 - y2, Renderer.math.length2(z2 - z1, x2 - x1))
        local yaw = math.atan2(x2 - x1, z2 - z1)

        shader:send("Quat", Renderer.math.eulerToQuaternion(pitch, yaw, 0):ttable())
        shader:send("Scale", { s, s, size })
        shader:send("Pos", pos:ttable())

        love.graphics.draw(graphicsData.LineMesh)
        shader:send("Scale", { s, s, s })
        shader:send("Pos", { x2, y2, z2 })

        love.graphics.draw(graphicsData.ArrowMesh)
        shader:send("Scale", Renderer.internal.resetScaleTable)
    end

    love.graphics.setMeshCullMode(cullMode)
end

--- draws an arc
---@param x number
---@param y number
---@param z number
---@param radius number
---@param angleStart number
---@param angleEnd number
---@param angle quaternion
---@param segments any
---@param width any
function Renderer.graphics.arc(x, y, z, radius, angleStart, angleEnd, angle, segments, width)
    local stepSize = math.abs(angleEnd - angleStart) / segments or math.floor(math.abs(angleEnd - angleStart) / PI2 * 32)

    local previousX, previousY, previousZ

    for i = angleStart, angleEnd + stepSize, stepSize do
        local rx, ry, rz = Renderer.math.rotatePositionSeparate(radius * math.cos(i), 0, radius * math.sin(i), angle.x,
            angle.y, angle.z, angle.w)

        rx = rx + x
        ry = ry + y
        rz = rz + z

        if previousX then
            Renderer.graphics.line(previousX, previousY, previousZ, rx, ry, rz, width)
        end

        previousX, previousY, previousZ = rx, ry, rz
    end
end

--- draws an arc
---@param x number
---@param y number
---@param z number
---@param radius number
---@param angleStart number
---@param angleEnd number
---@param angle quaternion
---@param segments any
---@param width any
function Renderer.graphics.overlayArc(x, y, z, radius, angleStart, angleEnd, angle, segments, width)
    local stepSize = math.abs(angleEnd - angleStart) / segments or math.floor(math.abs(angleEnd - angleStart) / PI2 * 32)

    local previousX, previousY, previousZ

    for i = angleStart, angleEnd + stepSize, stepSize do
        local rx, ry, rz = Renderer.math.rotatePositionSeparate(radius * math.cos(i), 0, radius * math.sin(i), angle.x,
            angle.y, angle.z, angle.w)

        rx = rx + x
        ry = ry + y
        rz = rz + z

        if previousX then
            Renderer.graphics.overlayLine(previousX, previousY, previousZ, rx, ry, rz, width)
        end

        previousX, previousY, previousZ = rx, ry, rz
    end
end

--- draws an arc
---@param x number
---@param y number
---@param z number
---@param radius number
---@param angleStart number
---@param angleEnd number
---@param angle quaternion
---@param segments any
---@param width any
function Renderer.graphics.arcDirect(x, y, z, radius, angleStart, angleEnd, angle, segments, width)
    local stepSize = math.abs(angleEnd - angleStart) / segments or math.floor(math.abs(angleEnd - angleStart) / PI2 * 32)

    local previousX, previousY, previousZ

    for i = angleStart, angleEnd + stepSize, stepSize do
        local x1, y1, z1 = Renderer.math.rotatePositionSeparate(radius * math.cos(i), 0.0, radius * math.sin(i), angle.x,
            angle.y, angle.z, angle.w)

        x1, y1, z1 = x1 + x, y1 + y, z1 + z

        if previousX then
            Renderer.graphics.lineDirect(previousX, previousY, previousZ, x1, y1, z1, width)
        end

        previousX, previousY, previousZ = x1, y1, z1
    end
end

function Renderer.internal.drawFullscreen(flip)
    love.graphics.getShader():send("flipY", not (flip == true))
    love.graphics.drawFromShader("triangles", 3, 1)
end

--- Loops over all pixels in an ImageData and calls a function for each pixel.
---@param imageData love.ImageData
---@param func function
function Renderer.graphics.loopPixels(imageData, func)
    for y = 0, imageData:getHeight() - 1 do
        for x = 0, imageData:getWidth() - 1 do
            func(x,
                y,
                imageData:getPixel(x, y)
            )
        end
    end
end

--- draws text position in 3D space
---@param text any
---@param x number
---@param y number
---@param z number
---@param camera Renderer.camera
function Renderer.graphics.print(text, x, y, z, camera)
    local px, py, pz, pw = camera.viewProjectionMatrix:vMulSepW1(x, y, z)
    px, py = px / pw, py / pw
    px, py = px * 0.5 + 0.5, py * 0.5 + 0.5

    px = px * camera.screenSize[1] + Renderer.internal.gui.windowSize.minX
    py = py * camera.screenSize[2] + Renderer.internal.gui.windowSize.minY
    px, py = Renderer.math.round(px), Renderer.math.round(py)

    love.graphics.print(tostring(text), px, py)
end

function Renderer.internal.createSkyboxIrradiancemap()
    local irradianceResolution = Renderer.scene.getCurrentScene().engineData.settings.cubemaps.irradianceMapResolution

    local irradianceCanvas = love.graphics.newCanvas(irradianceResolution,
        irradianceResolution,
        { type = "cube", format = "rg11b10f", debugname = "Irradiance Cube Canvas", linear = true, mipmaps = "manual" })

    local specularResolution = Renderer.scene.getCurrentScene().engineData.settings.cubemaps.resolution

    local specularCanvas = love.graphics.newCanvas(specularResolution,
        specularResolution,
        { type = "cube", format = "rg11b10f", debugname = "Specular Cube Canvas", linear = true, mipmaps = "manual" })

    local currentCamera = Renderer.internal.getCurrentCamera()

    local camera = Renderer.internal.graphicsData.cubeMappingCamera
    camera:use()

    do                      -- draw each face
        local rotations = { -- +x -x +y -y +z -z
            vec3(math.pi / 2, 0, 0),
            vec3(-math.pi / 2, 0, 0),
            vec3(math.pi, math.pi / 2, 0),
            vec3(math.pi, -math.pi / 2, 0),
            vec3(math.pi, 0, 0),
            vec3(0, 0, 0),
        }

        camera:setProjectionSettings(-0.1, 0.1, 0.1, -0.1, 0.1, 10000.0)
        camera:setPosition(vec3())

        Renderer.internal.shaders.cubemapDrawer:send("Brightness",
            Renderer.scene.getCurrentScene().engineData.settings.skybox.brightness)
        Renderer.internal.shaders.cubemapDrawer:send("Lod", 0.0)
        Renderer.internal.shaders.cubemapDrawer:send("environmentMap", Renderer.internal.graphicsData.skybox)
        Renderer.internal.shaders.cubemapDrawer:send("InverseProjectionMatrix", "column", camera.inverseProjectionMatrix)

        for slice = 1, 6 do
            Renderer.internal.openGL.PushEvent("Create Reflective Cubemap Slice " .. slice)

            camera:setRotation(rotations[slice])

            camera:update(true)
            camera:prepareDraw()

            love.graphics.setCanvas(specularCanvas, slice)
            love.graphics.setShader(Renderer.internal.shaders.cubemapDrawer)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.clear(0, 0, 0, 1)

            Renderer.internal.shaders.cubemapDrawer:send("InverseViewMatrix", "column", camera.inverseViewMatrix)
            Renderer.internal.shaders.cubemapDrawer:send("flipX", true)

            Renderer.internal.shaders.cubemapDrawer:send("flipX", true)

            love.graphics.setBlendMode("none")
            Renderer.internal.drawFullscreen()
            love.graphics.origin() -- reset scale
            Renderer.internal.openGL.PopEvent()
        end
    end

    Renderer.internal.createCubemap(irradianceCanvas, specularCanvas, vec3(), false, 1)

    Renderer.internal.skyboxIrradianceMap = irradianceCanvas
    Renderer.internal.skyboxSpecularMap = specularCanvas

    Renderer.internal.writeCubemap(
        specularCanvas,
        irradianceCanvas,
        1
    )

    love.graphics.setCanvas()

    if currentCamera then
        currentCamera:use()
    end
end

Renderer.graphics.compileShaders()

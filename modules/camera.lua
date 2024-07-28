---@class Renderer.camera
---@field mainRenderTarget {[1]: love.Canvas, depthstencil: love.Canvas}
---@field previousRenderTarget {[1]: love.Canvas, depthstencil: love.Canvas}
---@field previousMatrices {viewMatrix: matrix4x4, projectionMatrix: matrix4x4, viewProjectionMatrix: matrix4x4, inverseViewMatrix: matrix4x4, inverseProjectionMatrix: matrix4x4, inverseViewProjectionMatrix: matrix4x4}
---@field renderTargets table<{[1]:love.Canvas, depthstencil: love.Canvas}, {[1]:love.Canvas, depthstencil: love.Canvas}>
---@field swapRenderTargets boolean
---@field geometryTarget table
---@field screenSpaceReflections table
---@field ssao {combine: love.Canvas, applyCanvases: table<love.Canvas>, prepassCanvases: table<love.Canvas>, targets: table<table<love.Canvas>>, applyCanvas: love.Canvas, combineCanvases: table<love.Canvas>, previousCombineCanvas: love.Canvas, previousApplyCanvas: love.Canvas}
---@field volumetricLightingCanvases {volumetricCanvas: love.Canvas, volumetricVerticalBlurCanvas: love.Canvas, volumetricFinalCanvas: love.Canvas}
---@field position vec3
---@field updatedPosition vec3
---@field previousPosition vec3
---@field tablePosition table<number, number, number>
---@field rotation vec3
---@field width number
---@field height number
---@field screenSize table<number, number>
---@field projectionMatrix matrix4x4
---@field inverseProjectionMatrix matrix4x4
---@field rotationMatrix matrix4x4
---@field translationMatrix matrix4x4
---@field viewMatrix matrix4x4
---@field inverseViewMatrix matrix4x4
---@field viewProjectionMatrix matrix4x4
---@field inverseViewProjectionMatrix matrix4x4
---@field useStandardObjectRenderer boolean
---@field renderSkybox boolean
---@field ambientLight table<number, number, number>
---@field projectionData {near: number, far: number, left: number, right: number, top: number, bottom: number}
---@field postProcessing boolean
---@field drawIndex number
---@field fov number
---@field lastFrameData {x: number, y: number, z: number, yaw: number, pitch: number, roll: number}
---@field frustum table
---@field lodOffset number / 2
---@field cachedShaderUniforms table<string, table<string, any>>
---@field name string
---@field id string
---@field savedID string
---@field bloom {thresholdCanvas: love.Canvas, finalCanvas: love.Canvas, downsampleCanvas: love.Canvas}
---@field postProcessingApplyCanvas love.Canvas
---@field canvasSetters table
---@field scale table<number, number>
---@field wireframesEnabled boolean
---@field highPrecision boolean
local cameraFunctions = {}
local cameraMetatable = {
    __index = cameraFunctions
}

local currentCamera

local function calculateSSRLodOffset(verticalFov, height)
    local texelSize1m = math.tan(verticalFov / 2) / height
    local kernelSize = 21
    local sigma0 = (kernelSize + 1) / 6
    local lodOffset = -math.log(texelSize1m * math.sqrt(2) * sigma0, 2)
    return lodOffset
end

Renderer.internal.cameras = newObjectIndexedTable()
---@type Renderer.camera?
Renderer.internal.lastUsedCamera = nil
Renderer.internal.buffers.cameras = Renderer.graphics.newBuffer({
    { name = "ViewProjectionMatrix",        format = "floatmat4x4" },
    { name = "InverseViewProjectionMatrix", format = "floatmat4x4" },
    { name = "ViewMatrix",                  format = "floatmat4x4" },
    { name = "InverseViewMatrix",           format = "floatmat4x4" },
    { name = "ProjectionMatrix",            format = "floatmat4x4" },
    { name = "InverseProjectionMatrix",     format = "floatmat4x4" },
    { name = "Position",                    format = "floatvec3" },
    { name = "Near",                        format = "float" },
    { name = "Far",                         format = "float" },
    { name = "NearMulFar",                  format = "float" },
    { name = "FarMinusNear",                format = "float" },
}, 2, { shaderstorage = true, debugname = "Camera buffer", usage = "dynamic" })

-- uses a lot of resources
---@param position vec3
---@param rotation vec3
---@param screenSize vec2
---@param name string
---@param near number
---@param far number
---@param settings {highPrecision: boolean, createMainRenderTargets: boolean, verticalFov: number, useStandardObjectRenderer: boolean, renderSkybox:boolean, postProcessing:boolean, linear: boolean, wireframesEnabled: boolean}
---@return Renderer.camera
function Renderer.graphics.newCamera(position, rotation, screenSize, name, near, far, settings)
    local settings = settings or {}

    local default = { love.graphics.getDefaultFilter() }
    love.graphics.setDefaultFilter("nearest", "nearest")

    local w = screenSize.x
    local h = screenSize.y

    local highp = settings.highPrecision or false

    local aspectRatio = h / w

    local verticalFov = settings.verticalFov or 90.0
    local fov = verticalFov / 720.0

    local left = -fov
    local right = fov
    local top = aspectRatio * fov
    local bottom = -aspectRatio * fov

    local projectionMatrix = Renderer.graphics.newPerspectiveProjectionMatrix(left, right, top, bottom, near, far)

    local inverseProjectionMatrix = projectionMatrix:invert():transpose()

    local translationMatrix = Renderer.math.newTranslationMatrix(-position)
    local rotationMatrix = Renderer.math.eulerToMatrix(rotation:get())

    local viewMatrix = rotationMatrix * translationMatrix
    local inverseViewMatrix = viewMatrix:invert():transpose()

    local viewProjectionMatrix = viewMatrix * projectionMatrix
    local inverseViewProjectionMatrix = viewProjectionMatrix:invert():transpose()

    local mat = projectionMatrix

    local lodOffset = calculateSSRLodOffset(math.abs(2 * math.atan(1 / mat[2][2])), love.graphics.getHeight())

    local self = setmetatable({
        previousMatrices = {
            viewMatrix = viewMatrix,
            projectionMatrix = projectionMatrix,
            viewProjectionMatrix = viewProjectionMatrix,
            inverseViewMatrix = inverseViewMatrix,
            inverseProjectionMatrix = inverseProjectionMatrix,
            inverseViewProjectionMatrix = inverseViewProjectionMatrix
        },

        swapRenderTargets = false,

        previousPosition = vec3(),
        updatedPosition = vec3(),
        position = position:copy(),
        tablePosition = { position.x, position.y, position.z },
        rotation = rotation,

        width = w,
        height = h,
        screenSize = { w, h },

        projectionMatrix = projectionMatrix,
        inverseProjectionMatrix = inverseProjectionMatrix,

        rotationMatrix = rotationMatrix,
        translationMatrix = translationMatrix,

        viewMatrix = viewMatrix,
        inverseViewMatrix = inverseViewMatrix,

        viewProjectionMatrix = viewProjectionMatrix,
        inverseViewProjectionMatrix = inverseViewProjectionMatrix,

        useStandardObjectRenderer = settings.useStandardObjectRenderer ~= false,
        renderSkybox = settings.renderSkybox ~= false,

        ambientLight = { 0.1, 0.1, 0.1 },

        projectionData = {
            near = near,
            far = far,
            left = left,
            right = right,
            top = top,
            bottom = bottom
        },

        postProcessing = settings.postProcessing ~= false,

        drawIndex = 0,
        fov = verticalFov,

        lastFrameData = {},

        frustum = Renderer.math.frustumFromMatrix(viewProjectionMatrix),
        lodOffset = lodOffset,

        cachedShaderUniforms = {},
        name = name,
        id = Renderer.internal.newID(),

        canvasSetters = {},

        wireframesEnabled = settings.wireframesEnabled == nil and true or settings.wireframesEnabled,
        highPrecision = highp
    }, cameraMetatable)

    self.frustum.points = Renderer.math.frustumCornerPoints(inverseViewProjectionMatrix)

    if settings.postProcessing then
        self.bloom = {
            thresholdCanvas = newCanvas(w, h,
                { format = "rg11b10f", debugname = name .. " Bloom threshold", mipmaps = "manual" }),
        }

        self.bloom.thresholdCanvas:setWrap("clamp", "clamp")
        self.bloom.thresholdCanvas:setFilter("linear", "linear")

        self.bloom.finalCanvas = newCanvas(w, h,
            { format = "rg11b10f", debugname = "Bloom Final Canvas", mipmaps = "manual" })
        self.bloom.finalCanvas:setFilter("linear", "linear")

        self.bloom.downsampleCanvas = self.bloom.thresholdCanvas

        self.postProcessingApplyCanvas = love.graphics.newCanvas(w, h,
            { debugname = "Main render target", mipmaps = "none", linear = false })

        self.exposureApplyCanvas = irradianceCanvas
    end

    self.canvasSetters.cubemaps = { self.reflectionCanvas, self.irradianceCanvas }

    self.canvasSetters.depthDownSample = {}
    self.canvasSetters.depthDownSampleHalfTexelSizes = {}
    self.canvasSetters.ssaoApply = {}
    self.canvasSetters.ssaoApplyOffset = {}

    self.canvasSetters.bloomInverseTexelSizes = {}
    self.canvasSetters.bloomInverseHalfTexelSizes = {}

    for i = 1, 9 do
        table.insert(self.canvasSetters.bloomInverseTexelSizes,
            {
                1 / (self.screenSize[1] / (2 ^ (i - 1))),
                1 / (self.screenSize[2] / (2 ^ (i - 1)))
            })

        table.insert(self.canvasSetters.bloomInverseHalfTexelSizes,
            {
                1 / ((self.screenSize[1] / (2 ^ (i - 1))) * 0.5),
                1 / ((self.screenSize[2] / (2 ^ (i - 1))) * 0.5)
            })
    end

    self.scale = { self.width / love.graphics.getWidth(), self.height / love.graphics.getHeight() }

    self:recalculateProjectionMatrix()

    Renderer.internal.cameras:add(self)

    love.graphics.setDefaultFilter(unpack(default))

    return self
end

--- Updates the camera
---@param alwaysUpdate? boolean
function cameraFunctions:update(alwaysUpdate)
    local pos, rot = self.updatedPosition, self.rotation
    local data = self.lastFrameData

    if data.x == pos.x and data.y == pos.y and data.z == pos.z and data.yaw == rot.x and data.pitch == rot.y and data.roll == rot.z and not alwaysUpdate then
        return
    end

    self.position.x = self.updatedPosition.x
    self.position.y = self.updatedPosition.y
    self.position.z = self.updatedPosition.z

    local ch = math.cos(-self.rotation.x) -- yaw
    local sh = math.sin(-self.rotation.x)
    local ca = math.cos(-self.rotation.z) -- roll
    local sa = math.sin(-self.rotation.z)
    local cb = math.cos(-self.rotation.y) -- pitch
    local sb = math.sin(-self.rotation.y)

    self.rotationMatrix[1][1] = ch * ca
    self.rotationMatrix[1][2] = sh * sb - ch * sa * cb
    self.rotationMatrix[1][3] = ch * sa * sb + sh * cb
    self.rotationMatrix[2][1] = sa
    self.rotationMatrix[2][2] = ca * cb
    self.rotationMatrix[2][3] = -ca * sb
    self.rotationMatrix[3][1] = -sh * ca
    self.rotationMatrix[3][2] = sh * sa * cb + ch * sb
    self.rotationMatrix[3][3] = -sh * sa * sb + ch * cb

    self.translationMatrix[4][1] = -pos.x
    self.translationMatrix[4][2] = -pos.y
    self.translationMatrix[4][3] = -pos.z

    self.translationMatrix:mul(self.rotationMatrix, self.viewMatrix)

    self.viewProjectionMatrix = self.viewMatrix * self.projectionMatrix

    self.viewMatrix:invert(self.inverseViewMatrix):transpose()
    self.viewProjectionMatrix:invert(self.inverseViewProjectionMatrix):transpose()

    self.drawIndex = self.drawIndex % 3600

    data.x, data.y, data.z = pos.x, pos.y, pos.z
    data.yaw, data.pitch, data.roll = rot.x, rot.y, rot.z

    local m = self.viewProjectionMatrix
    local frustum = self.frustum.frustum

    if not frustum[1] then frustum[1] = vec4() end
    if not frustum[2] then frustum[2] = vec4() end
    if not frustum[3] then frustum[3] = vec4() end
    if not frustum[4] then frustum[4] = vec4() end
    if not frustum[5] then frustum[5] = vec4() end
    if not frustum[6] then frustum[6] = vec4() end

    frustum[1]:set(
        m[1][4] + m[1][1],
        m[2][4] + m[2][1],
        m[3][4] + m[3][1],
        m[4][4] + m[4][1]
    )

    frustum[2]:set(
        m[1][4] - m[1][1],
        m[2][4] - m[2][1],
        m[3][4] - m[3][1],
        m[4][4] - m[4][1]
    )

    frustum[3]:set(
        m[1][4] - m[1][2],
        m[2][4] - m[2][2],
        m[3][4] - m[3][2],
        m[4][4] - m[4][2]
    )

    frustum[4]:set(
        m[1][4] + m[1][2],
        m[2][4] + m[2][2],
        m[3][4] + m[3][2],
        m[4][4] + m[4][2]
    )

    frustum[5]:set(
        m[1][4] + m[1][3],
        m[2][4] + m[2][3],
        m[3][4] + m[3][3],
        m[4][4] + m[4][3]
    )

    frustum[6]:set(
        m[1][4] - m[1][3],
        m[2][4] - m[2][3],
        m[3][4] - m[3][3],
        m[4][4] - m[4][3]
    )
end

local formatSizes = {
    ["normal"] = 32,           -- Alias for rgba8, or srgba8 if gamma-correct rendering is enabled.
    ["hdr"] = 64,              -- A format suitable for high dynamic range content - an alias for the rgba16f format, normally.
    ["r8"] = 8,                -- Single-channel (red component) format (8 bpp).
    ["rg8"] = 16,              -- Two channels (red and green components) with 8 bits per channel (16 bpp).
    ["rgba8"] = 32,            -- 8 bits per channel (32 bpp) RGBA. Color channel values range from 0-255 (0-1 in shaders).
    ["srgba8"] = 32,           -- gamma-correct version of rgba8.
    ["r16"] = 16,              -- Single-channel (red component) format (16 bpp).
    ["rg16"] = 32,             -- Two channels (red and green components) with 16 bits per channel (32 bpp).
    ["rgba16"] = 64,           -- 16 bits per channel (64 bpp) RGBA. Color channel values range from 0-65535 (0-1 in shaders).
    ["r16f"] = 16,             -- Floating point single-channel format (16 bpp). Color values can range from [-65504, +65504].
    ["rg16f"] = 32,            -- Floating point two-channel format with 16 bits per channel (32 bpp). Color values can range from [-65504, +65504].
    ["rgba16f"] = 64,          -- Floating point RGBA with 16 bits per channel (64 bpp). Color values can range from [-65504, +65504].
    ["r32f"] = 32,             -- Floating point single-channel format (32 bpp).
    ["rg32f"] = 64,            -- Floating point two-channel format with 32 bits per channel (64 bpp).
    ["rgba32f"] = 128,         -- Floating point RGBA with 32 bits per channel (128 bpp).
    ["la8"] = 16,              -- Same as rg8, but accessed as (L, L, L, A)
    ["rgba4"] = 16,            -- 4 bits per channel (16 bpp) RGBA.
    ["rgb5a1"] = 16,           -- RGB with 5 bits each, and a 1-bit alpha channel (16 bpp).
    ["rgb565"] = 16,           -- RGB with 5, 6, and 5 bits each, respectively (16 bpp). There is no alpha channel in this format.
    ["rgb10a2"] = 32,          -- RGB with 10 bits per channel, and a 2-bit alpha channel (32 bpp).
    ["rg11b10f"] = 32,         -- Floating point RGB with 11 bits in the red and green channels, and 10 bits in the blue channel (32 bpp). There is no alpha channel. Color values can range from [0, +65024].
    ["stencil8"] = 8,          -- No depth buffer and 8-bit stencil buffer.
    ["depth16"] = 16,          -- 16-bit depth buffer and no stencil buffer.
    ["depth24"] = 24,          -- 24-bit depth buffer and no stencil buffer.
    ["depth32f"] = 32,         -- 32-bit float depth buffer and no stencil buffer.
    ["depth24stencil8"] = 32,  -- 24-bit depth buffer and 8-bit stencil buffer.
    ["depth32fstencil8"] = 40, -- 32-bit float depth buffer and 8-bit stencil buffer.
    ["DXT1"] = 4,              -- The DXT1 format. RGB data at 4 bits per pixel (compared to 32 bits for ImageData and regular Images.) Suitable for fully opaque images on desktop systems.
    ["DXT3"] = 8,              -- The DXT3 format. RGBA data at 8 bits per pixel. Smooth variations in opacity do not mix well with this format.
    ["DXT5"] = 8,              -- The DXT5 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on desktop systems.
    ["BC4"] = 4,               -- The BC4 format (also known as 3Dc+ or ATI1.) Stores just the red channel, at 4 bits per pixel.
    ["BC4s"] = 4,              -- The signed variant of the BC4 format. Same as above but pixel values in the texture are in the range of 1 instead of 1 in shaders.
    ["BC5"] = 8,               -- The BC5 format (also known as 3Dc or ATI2.) Stores red and green channels at 8 bits per pixel.
    ["BC5s"] = 8,              -- The signed variant of the BC5 format.
    ["BC6h"] = 8,              -- The BC6H format. Stores half-precision floating-point RGB data in the range of 65504 at 8 bits per pixel. Suitable for HDR images on desktop systems.
    ["BC6hs"] = 8,             -- The signed variant of the BC6H format. Stores RGB data in the range of +65504.
    ["BC7"] = 8,               -- The BC7 format (also known as BPTC.) Stores RGB or RGBA data at 8 bits per pixel.
    ["ETC1"] = 4,              -- The ETC1 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on older Android devices.
    ["ETC2rgb"] = 4,           -- The RGB variant of the ETC2 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on newer mobile devices.
    ["ETC2rgba"] = 8,          -- The RGBA variant of the ETC2 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on newer mobile devices.
    ["ETC2rgba1"] = 4,         -- The RGBA variant of the ETC2 format where pixels are either fully transparent or fully opaque. RGBA data at 4 bits per pixel.
    ["EACr"] = 4,              -- The single-channel variant of the EAC format. Stores just the red channel, at 4 bits per pixel.
    ["EACrs"] = 4,             -- The signed single-channel variant of the EAC format. Same as above but pixel values in the texture are in the range of 1 instead of 1 in shaders.
    ["EACrg"] = 8,             -- The two-channel variant of the EAC format. Stores red and green channels at 8 bits per pixel.
    ["EACrgs"] = 8,            -- The signed two-channel variant of the EAC format.
    ["PVR1rgb2"] = 2,          -- The 2 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 2 bits per pixel. Textures compressed with PVRTC1 formats must be square and power-of-two sized.
    ["PVR1rgb4"] = 4,          -- The 4 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 4 bits per pixel.
    ["PVR1rgba2"] = 2,         -- The 2 bit per pixel RGBA variant of the PVRTC1 format.
    ["PVR1rgba4"] = 4,         -- The 4 bit per pixel RGBA variant of the PVRTC1 format.
    ["ASTC4x4"] = 8,           -- The 4x4 pixels per block variant of the ASTC format. RGBA data at 8 bits per pixel.
    ["ASTC5x4"] = 6.4,         -- The 5x4 pixels per block variant of the ASTC format. RGBA data at 6.4 bits per pixel.
    ["ASTC5x5"] = 5.12,        -- The 5x5 pixels per block variant of the ASTC format. RGBA data at 5.12 bits per pixel.
    ["ASTC6x5"] = 4.27,        -- The 6x5 pixels per block variant of the ASTC format. RGBA data at 4.27 bits per pixel.
    ["ASTC6x6"] = 3.56,        -- The 6x6 pixels per block variant of the ASTC format. RGBA data at 3.56 bits per pixel.
    ["ASTC8x5"] = 3.2,         -- The 8x5 pixels per block variant of the ASTC format. RGBA data at 3.2 bits per pixel.
    ["ASTC8x6"] = 2.67,        -- The 8x6 pixels per block variant of the ASTC format. RGBA data at 2.67 bits per pixel.
    ["ASTC8x8"] = 2,           -- The 8x8 pixels per block variant of the ASTC format. RGBA data at 2 bits per pixel.
    ["ASTC10x5"] = 2.56,       -- The 10x5 pixels per block variant of the ASTC format. RGBA data at 2.56 bits per pixel.
    ["ASTC10x6"] = 2.13,       -- The 10x6 pixels per block variant of the ASTC format. RGBA data at 2.13 bits per pixel.
    ["ASTC10x8"] = 1.6,        -- The 10x8 pixels per block variant of the ASTC format. RGBA data at 1.6 bits per pixel.
    ["ASTC10x10"] = 1.28,      -- The 10x10 pixels per block variant of the ASTC format. RGBA data at 1.28 bits per pixel.
    ["ASTC12x10"] = 1.07,      -- The 12x10 pixels per block variant of the ASTC format. RGBA data at 1.07 bits per pixel.
    ["ASTC12x12"] = 0.89,      -- The 12x12 pixels per block variant of the ASTC format. RGBA data at 0.89 bits per pixel.
}

---@param canvas love.Canvas
local function calculateCanvasMemoryUsage(canvas)
    local width, height = canvas:getPixelDimensions()
    local format = canvas:getFormat()

    local formatSize = formatSizes[format]

    return width * height * formatSize * canvas:getDepth() * canvas:getLayerCount() * canvas:getMipmapCount()
end

function cameraFunctions:calculateVRamUsage()
    local total = 0.0

    for index, value in pairs(self) do
        if type(value) == "userdata" and value:typeOf("Canvas") then
            total = total + calculateCanvasMemoryUsage(value)
        end
    end

    return total
end

function cameraFunctions:getTablePosition()
    self.tablePosition[1] = self.position.x
    self.tablePosition[2] = self.position.y
    self.tablePosition[3] = self.position.z

    return self.tablePosition
end

function cameraFunctions:prepareDraw()
    assert(currentCamera == self, "Camera must be used before calling prepareDraw")

    self.drawIndex = self.drawIndex + 1

    self.swapRenderTargets = not self.swapRenderTargets

    local buffer = Renderer.internal.buffers.cameras

    -- copies the old matrices to camera index 2
    buffer:copyItemTo(1, 2)

    buffer:setWriteIndex(1)

    buffer:write(self.viewProjectionMatrix)
    buffer:write(self.inverseViewProjectionMatrix)
    buffer:write(self.viewMatrix)
    buffer:write(self.inverseViewMatrix)
    buffer:write(self.projectionMatrix)
    buffer:write(self.inverseProjectionMatrix)
    buffer:write(self.position)
    buffer:write(self.projectionData.near)
    buffer:write(self.projectionData.far)
    buffer:write(self.projectionData.near * self.projectionData.far)
    buffer:write(self.projectionData.far - self.projectionData.near)

    buffer:flush()
end

function cameraFunctions:getPosition()
    return self.position:get()
end

function cameraFunctions:getVecPosition()
    return vec3(self.position)
end

function cameraFunctions:setPosition(x, y, z)
    self.updatedPosition:set(x, y, z)
end

function cameraFunctions:setVecPosition(position)
    self.updatedPosition:set(position:get())
end

function cameraFunctions:getRotation()
    return self.rotation:get()
end

function cameraFunctions:setRotation(rotation)
    self.rotation = rotation
end

function cameraFunctions:getScreenSize()
    return self.width, self.height
end

function cameraFunctions:setFov(fov)
    local aspectRatio = self.height / self.width

    local verticalFov = fov / 720.0

    self.fov = fov

    local data = self.projectionData

    data.left = -verticalFov
    data.right = verticalFov
    data.top = aspectRatio * verticalFov
    data.bottom = -aspectRatio * verticalFov

    self:recalculateProjectionMatrix()
end

function cameraFunctions:getFov()
    return self.fov
end

function cameraFunctions:use()
    currentCamera = self
    Renderer.internal.lastUsedCamera = self
    self:updateShaderUniforms()
end

function Renderer.internal.getCurrentCamera()
    return currentCamera
end

function cameraFunctions:updateShaderUniforms()
    for i, shader in pairs(Renderer.internal.shaders) do
        if shader:hasUniform("CameraBuffer") then
            shader:send("CameraBuffer", Renderer.internal.buffers.cameras:getBuffer())
        end
    end
end

function cameraFunctions:recalculateProjectionMatrix()
    self.projectionMatrix = Renderer.graphics.newPerspectiveProjectionMatrix(self.projectionData.left,
        self.projectionData.right, self.projectionData.top, self.projectionData.bottom,
        self.projectionData.near, self.projectionData.far)
    self.inverseProjectionMatrix = self.projectionMatrix:invert():transpose()

    self:updateShaderUniforms()
end

function cameraFunctions:setNear(near)
    self.projectionData.near = near
    self:recalculateProjectionMatrix()
end

function cameraFunctions:getNear()
    return self.projectionData.near
end

function cameraFunctions:setFar(far)
    self.projectionData.far = far
    self:recalculateProjectionMatrix()
end

function cameraFunctions:getFar()
    return self.projectionData.far
end

function cameraFunctions:setProjectionSettings(left, right, top, bottom, near, far)
    self.projectionData.left = left
    self.projectionData.right = right
    self.projectionData.top = top
    self.projectionData.bottom = bottom
    self.projectionData.near = near
    self.projectionData.far = far

    self:recalculateProjectionMatrix()
end

-- serialize camera

function cameraFunctions:serialize()
    local data = {
        position = self.position:get(),
        rotation = self.rotation:get(),
        screenSize = self.screenSize,
        name = self.name,
        near = self.projectionData.near,
        far = self.projectionData.far,
        settings = {
            highPrecision = self.highPrecision,
            createMainRenderTargets = self.mainRenderTarget[1] ~= nil,
            verticalFov = self.fov,
            useStandardObjectRenderer = self.useStandardObjectRenderer,
            renderSkybox = self.renderSkybox,
            postProcessing = self.postProcessing
        },
        id = self.id,
    }

    return data
end

function Renderer.graphics.deserializeCamera(data)
    assert(data, "Invalid camera data")

    local self = Renderer.graphics.newCamera(vec3(data.position), vec3(data.rotation), vec2(data.screenSize), data.name,
        data.near, data.far, data.settings)

    -- don't overwrite the id but save it so we can find the camera later
    self.savedID = data.id

    self:recalculateProjectionMatrix()
end

--- Resizes the canvas
---@param canvas love.Canvas
---@param width number
---@param height number
function Renderer.internal.resizeCanvas(canvas, width, height)
    local debugName = canvas:getDebugName()
    local format = canvas:getFormat()
    local wrap = { canvas:getWrap() }
    local readable = canvas:isReadable()
    local mipmaps = canvas:getMipmapMode()
    local linear = canvas:isFormatLinear()
    local textureType = canvas:getTextureType()
    local layerCount = canvas:getLayerCount()
    local filter = { canvas:getFilter() }

    canvas:release()

    local newCanvas = love.graphics.newCanvas(width, height, layerCount,
        {
            format = format,
            debugname = debugName,
            readable = readable,
            mipmaps = mipmaps,
            linear = linear,
            type = textureType
        })

    newCanvas:setWrap(unpack(wrap))
    newCanvas:setFilter(unpack(filter))

    return newCanvas
end

local resizeCanvas = Renderer.internal.resizeCanvas

function cameraFunctions:resize()
    local width, height = self.width, self.height

    self.geometryTarget[1] = resizeCanvas(self.geometryTarget[1], width, height)
    self.geometryTarget[2] = resizeCanvas(self.geometryTarget[2], width, height)
    self.geometryTarget[3] = resizeCanvas(self.geometryTarget[3], width, height)
    self.geometryTarget[4] = resizeCanvas(self.geometryTarget[4], width, height)
    self.geometryTarget[5] = resizeCanvas(self.geometryTarget[5], width, height)

    self.screenSpaceReflections = resizeCanvas(self.screenSpaceReflections, width / 2, height / 2)
    self.ssrInfluenceCanvas = resizeCanvas(self.ssrInfluenceCanvas, width / 2, height / 2)
    self.reflectionsPostProcessCanvas = resizeCanvas(self.reflectionsPostProcessCanvas, width, height)
    self.previousReflectionsPostProcessCanvas = resizeCanvas(self.previousReflectionsPostProcessCanvas, width, height)

    self.reflectionsCanvases = { self.reflectionsPostProcessCanvas, self.previousReflectionsPostProcessCanvas }

    self.reflectionCanvas = resizeCanvas(self.reflectionCanvas, width, height)
    self.irradianceCanvas = resizeCanvas(self.irradianceCanvas, width, height)

    for i, canvas in ipairs(self.renderTargets) do
        canvas[1] = resizeCanvas(canvas[1], width, height)
        canvas.depthstencil = resizeCanvas(canvas.depthstencil, width, height)
    end

    self.mainRenderTarget = self.renderTargets[1]

    self.geometryTarget.depthstencil = self.renderTargets[1].depthstencil

    self.previousRenderTarget = self.renderTargets[2]

    self.ssao.combine = resizeCanvas(self.ssao.combine, width, height)
    self.ssao.previousCombineCanvas = resizeCanvas(self.ssao.previousCombineCanvas, width, height)

    self.ssao.combineCanvases = { self.ssao.combine, self.ssao.previousCombineCanvas }

    for i = 1, 16 do
        self.ssao.prepassCanvases[i] = resizeCanvas(self.ssao.prepassCanvases[i], width / 4, height / 4)
    end

    self.ssao.applyCanvas = resizeCanvas(self.ssao.applyCanvas, width / 4, height / 4)
    self.ssao.previousApplyCanvas = resizeCanvas(self.ssao.previousApplyCanvas, width / 4, height / 4)

    self.ssao.applyCanvases = {
        self.ssao.applyCanvas,
        self.ssao.previousApplyCanvas
    }

    self.ssao.targets = {}
    for i = 1, 16, 4 do
        table.insert(self.ssao.targets, {
            self.ssao.prepassCanvases[i],
            self.ssao.prepassCanvases[i + 1],
            self.ssao.prepassCanvases[i + 2],
            self.ssao.prepassCanvases[i + 3]
        })
    end

    if self.postProcessing then
        self.bloom.thresholdCanvas = resizeCanvas(self.bloom.thresholdCanvas, width, height)
        self.bloom.finalCanvas = resizeCanvas(self.bloom.finalCanvas, width, height)

        -- self.bloom.downsampleCanvas = resizeCanvas(self.bloom.downsampleCanvas, width, height)
        self.bloom.downsampleCanvas = self.bloom.thresholdCanvas

        self.postProcessingApplyCanvas = resizeCanvas(self.postProcessingApplyCanvas, width, height)

        -- self.exposureApplyCanvas = resizeCanvas(self.exposureApplyCanvas, width, height)
        self.exposureApplyCanvas = self.irradianceCanvas
    end

    local aspectRatio = height / width

    local verticalFov = self.fov / 720.0

    local left = -verticalFov
    local right = verticalFov
    local top = aspectRatio * verticalFov
    local bottom = -aspectRatio * verticalFov

    self.projectionData.left = left
    self.projectionData.right = right
    self.projectionData.top = top
    self.projectionData.bottom = bottom

    self.canvasSetters.cubemaps = { self.reflectionCanvas, self.irradianceCanvas }

    self.canvasSetters.depthDownSample = {}
    self.canvasSetters.depthDownSampleHalfTexelSizes = {}
    self.canvasSetters.ssaoApply = {}
    self.canvasSetters.ssaoApplyOffset = {}

    for i = 2, self.mainRenderTarget.depthstencil:getMipmapCount() do
        self.canvasSetters.depthDownSample[i] = { depthstencil = { mipmap = i } }
        self.canvasSetters.depthDownSampleHalfTexelSizes[i] = {
            0.5 / (self.width / (2 ^ (i - 1))),
            0.5 / (self.height / (2 ^ (i - 1))),
        }
    end

    for i = 1, 16 do
        self.canvasSetters.ssaoApply[i] = { { self.ssao.applyCanvas, layer = i } }

        local x = (i - 1) % 4             -- 0-3
        local y = math.floor((i - 1) / 4) -- 0-3

        table.insert(self.canvasSetters.ssaoApplyOffset, {
            (x / self.screenSize[1]),
            (y / self.screenSize[2])
        })
    end

    self.canvasSetters.bloomInverseTexelSizes = {}

    for i = 1, 9 do
        table.insert(self.canvasSetters.bloomInverseTexelSizes,
            {
                1 / (self.screenSize[1] / (2 ^ (i - 1))),
                1 / (self.screenSize[2] / (2 ^ (i - 1)))
            })
    end

    self:recalculateProjectionMatrix()
end

function cameraFunctions:setScreenSize(width, height)
    if self.width == width and self.height == height then
        return
    end
    self.width = width
    self.height = height
    self.screenSize = { width, height }

    self:resize()
end

function cameraFunctions:getUseStandardObjectRenderer()
    return self.useStandardObjectRenderer
end

function cameraFunctions:setUseStandardObjectRenderer(useStandardObjectRenderer)
    self.useStandardObjectRenderer = useStandardObjectRenderer
end

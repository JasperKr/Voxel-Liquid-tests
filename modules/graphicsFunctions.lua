local timesFFIVertexFormatCreated = 0
local formats = {}

function Renderer.internal.vertexformatToFFIDefinition(format)
    local definition = ""

    for i, v in ipairs(format) do
        definition = definition .. "\t" .. v.format .. " " .. v.name .. ";\n"
    end

    if not formats[definition] then
        local formatName = "vertexFormat" .. timesFFIVertexFormatCreated
        local def = "typedef struct {" ..
            definition .. "} " .. formatName .. ";"
        ffi.cdef(def)

        timesFFIVertexFormatCreated = timesFFIVertexFormatCreated + 1

        formats[definition] = { def, formatName }
    end

    return unpack(formats[definition])
end

---@param mat matrix4x4
function Renderer.graphics.setViewMatrix(mat)
    Renderer.internal.graphicsData.viewMatrix = mat:copy()
end

---@return matrix4x4
function Renderer.graphics.getViewMatrix()
    return Renderer.internal.graphicsData.viewMatrix
end

---@return matrix4x4
function Renderer.graphics.getCameraProjectionMatrix()
    return Renderer.internal.graphicsData.cameraProjectionMatrix:copy()
end

--- Creates a new vertex array
---@param amount number
---@param ... ffi.cdata*? init
---@return ffi.cdata*
function Renderer.internal.newVertexArray(amount, ...)
    return ffi.new("RVertexFormat[?]", amount, ...)
end

function Renderer.internal.newVertex(x, y, z, u, v, normalX, normalY, normalZ, tangentX, tangentY, tangentZ)
    return ffi.new("RVertexFormat",
        ffi.new("floatvec3", x, y, z),
        ffi.new("floatvec2", u, v),
        ffi.new("floatvec3", normalX, normalY, normalZ),
        ffi.new("floatvec3", tangentX, tangentY, tangentZ))
end

--- Creates a new array of indices
---@param amount number
---@param ... ffi.cdata*|number? init
---@return ffi.cdata* data
---@return love.IndexDataType type
function Renderer.internal.newIndexArray(amount, ...)
    if amount > 2 ^ 16 then
        return ffi.new("uint32_t[?]", amount, ...), "uint32"
    else
        return ffi.new("uint16_t[?]", amount, ...), "uint16"
    end
end

---@param position vec3
---@param up vec3
---@param right vec3
---@param size number
---@return ffi.cdata* vertices
---@return ffi.cdata* indices
---@return love.IndexDataType format
function Renderer.graphics.newPlane(position, up, right, size)
    local forward = up:cross(right):normalize()
    size = size / 2
    local verts = {
        position + forward * size + right * size,
        position + forward * size - right * size,
        position - forward * size - right * size,
        position - forward * size + right * size,
    }

    local vertices = Renderer.internal.newVertexArray(4,
        Renderer.internal.newVertex(verts[1].x, verts[1].y, verts[1].z, 0, 0, up.x, up.y, up.z, right.x, right.y, right
            .z),
        Renderer.internal.newVertex(verts[2].x, verts[2].y, verts[2].z, 0, 1, up.x, up.y, up.z, right.x, right.y, right
            .z),
        Renderer.internal.newVertex(verts[3].x, verts[3].y, verts[3].z, 1, 1, up.x, up.y, up.z, right.x, right.y, right
            .z),
        Renderer.internal.newVertex(verts[4].x, verts[4].y, verts[4].z, 1, 0, up.x, up.y, up.z, right.x, right.y, right
            .z)
    )

    local indices, format = Renderer.internal.newIndexArray(6, 0, 1, 2, 0, 2, 3)

    return vertices, indices, format
end

function Renderer.graphics.newOrthographicProjectionMatrix(left, right, top, bottom, near, far)
    return mat4(
        2 / (right - left), 0, 0, -(right + left) / (right - left),
        0, -2 / (top - bottom), 0, -(top + bottom) / (top - bottom),
        0, 0, -2 / (far - near), -(far + near) / (far - near),
        0, 0, 0, 1
    )
end

function Renderer.graphics.newPerspectiveProjectionMatrix(left, right, top, bottom, near, far)
    return mat4(
        (near * 2) / (right - left), 0, (right + left) / (right - left), 0,
        0, -(near * 2) / (top - bottom), (top + bottom) / (top - bottom), 0,
        0, 0, -((far + near) / (far - near)), -(2 * far * near) / (far - near),
        0, 0, -1, 0
    )
end

-- https://google.github.io/filament/Filament.html#sphericalharmonics
local function SHindex(m, l)
    return l * (l + 1) + m
end

--- Computes the spherical harmonics basis for the given direction
---@param SHb table the spherical harmonics basis fills this table
---@param numBands number the number of bands to compute
---@param s vec3 the direction to compute the spherical harmonics basis for
local function computeShBasis(SHb, numBands, s)
    local Pml_2 = 0
    local Pml_1 = 1
    SHb[SHindex(0, 0)] = Pml_1
    for l = 1, numBands - 1 do
        local Pml = ((2 * l - 1) * Pml_1 * s[3] - (l - 1) * Pml_2) / l
        Pml_2 = Pml_1
        Pml_1 = Pml
        SHb[SHindex(0, l)] = Pml
    end
    local Pmm = 1
    for m = 1, numBands - 1 do
        Pmm = (1 - 2 * m) * Pmm
        local Pml_2 = Pmm
        local Pml_1 = (2 * m + 1) * Pmm * s[3]
        SHb[SHindex(-m, m)] = Pml_2
        SHb[SHindex(m, m)] = Pml_2
        if m + 1 < numBands then
            SHb[SHindex(-m, m + 1)] = Pml_1
            SHb[SHindex(m, m + 1)] = Pml_1
            for l = m + 2, numBands - 1 do
                local Pml = ((2 * l - 1) * Pml_1 * s[3] - (l + m - 1) * Pml_2) / (l - m)
                Pml_2 = Pml_1
                Pml_1 = Pml
                SHb[SHindex(-m, l)] = Pml
                SHb[SHindex(m, l)] = Pml
            end
        end
    end
    local Cm = s[1]
    local Sm = s[2]
    for m = 1, numBands - 1 do
        for l = m, numBands - 1 do
            SHb[SHindex(-m, l)] = SHb[SHindex(-m, l)] * Sm
            SHb[SHindex(m, l)] = SHb[SHindex(m, l)] * Cm
        end
        local Cm1 = Cm * s[1] - Sm * s[2]
        local Sm1 = Sm * s[1] + Cm * s[2]
        Cm = Cm1
        Sm = Sm1
    end
end

local bit = require("bit")

local tof = 0.5 / 0x80000000

local function hammersley(i)
    local bits = i

    bits = bit.bor(bit.lshift(bits, 16), bit.rshift(bits, 16))
    bits = bit.bor(bit.lshift(bit.band(bits, 0x55555555), 1), bit.rshift(bit.band(bits, 0xAAAAAAAA), 1))
    bits = bit.bor(bit.lshift(bit.band(bits, 0x33333333), 2), bit.rshift(bit.band(bits, 0xCCCCCCCC), 2))
    bits = bit.bor(bit.lshift(bit.band(bits, 0x0F0F0F0F), 4), bit.rshift(bit.band(bits, 0xF0F0F0F0), 4))
    bits = bit.bor(bit.lshift(bit.band(bits, 0x00FF00FF), 8), bit.rshift(bit.band(bits, 0xFF00FF00), 8))
    return bits * tof
end

local function hemisphereImportanceSampleDggx(u, a)
    local phi = 2.0 * math.pi * u.x
    local cosTheta2 = (1 - u.y) / (1 + (a + 1) * ((a - 1) * u.y))
    local cosTheta = math.sqrt(cosTheta2)
    local sinTheta = math.sqrt(1 - cosTheta2)
    return sinTheta * math.cos(phi), sinTheta * math.sin(phi), cosTheta
end

local function Visibility(NoV, NoL, a)
    -- Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    -- Height-correlated GGX
    local a2 = a * a
    local GGXL = NoV * math.sqrt((NoL - NoL * a2) * NoL + a2)
    local GGXV = NoL * math.sqrt((NoV - NoV * a2) * NoV + a2)
    return 0.5 / (GGXV + GGXL)
end

local function pow5(x)
    local x2 = x * x
    return x2 * x2 * x
end

local saturate = Renderer.math.saturate

local V = vec3()
local L = vec3()
local H = vec3()
local u = vec3()

function Renderer.internal.DFV(NoV, linearRoughness, sampleCount)
    V:set(math.sqrt(1.0 - NoV * NoV), 0.0, NoV)

    local rx, ry = 0.0, 0.0

    local invSampleCount = 1.0 / sampleCount

    for i = 0, sampleCount - 1 do
        local y = hammersley(i)
        u:set(i * invSampleCount, y)
        H:set(hemisphereImportanceSampleDggx(u, linearRoughness))

        L:set(2.0 * V:dot(H) * H - V)

        local VoH = saturate(V:dot(H))
        local NoL = saturate(L.z)
        local NoH = saturate(H.z)

        if NoL > 0 then
            local v = Visibility(NoV, NoL, linearRoughness) * NoL * (VoH / NoH)
            local Fc = pow5(1.0 - VoH)
            rx = rx + v * (1.0 - Fc)
            ry = ry + v * Fc
        end
    end

    -- or 4.0 / sampleCount
    local sample = 4.0 / sampleCount
    return rx * sample, ry * sample
end

function Renderer.internal.sampleBase3HaltonSequence(i)
    local x = 0
    local f = 1
    local invBase = 1.0 / 3.0
    while i > 0 do
        f = f * invBase
        x = x + f * (i % 3)
        i = math.floor(i * invBase)
    end
    return x
end

function Renderer.internal.DFVMultiscatter(NoV, linearRoughness, sampleCount)
    V:set(math.sqrt(1.0 - NoV * NoV), 0.0, NoV)

    local invSampleCount = 1.0 / sampleCount

    local rx, ry = 0.0, 0.0
    for i = 0, sampleCount - 1 do
        u:set(i * invSampleCount, hammersley(i))
        H:set(hemisphereImportanceSampleDggx(u, linearRoughness))

        L:set(2.0 * V:dot(H) * H - V)

        local VoH = saturate(V:dot(H))
        local NoL = saturate(L.z)
        local NoH = saturate(H.z)

        if NoL > 0 then
            local v = Visibility(NoV, NoL, linearRoughness) * NoL * (VoH / NoH)
            local Fc = pow5(1.0 - VoH)
            rx = rx + v * Fc
            ry = ry + v
        end
    end

    local sample = 4.0 / sampleCount
    return rx * sample, ry * sample
end

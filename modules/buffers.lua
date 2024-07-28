Renderer.internal.buffers = {}

local bufferMetatable = {}

---@class Renderer.buffer
---@field buffer love.GraphicsBuffer
---@field componentCount number
---@field data table
---@field updated boolean
---@field format table
---@field componentCountsPerComponent table
---@field engineData table
local bufferFunctions = {}
bufferMetatable.__index = bufferFunctions

local componentCounts = {
    float = 1,
    floatvec2 = 2,
    floatvec3 = 3,
    floatvec4 = 4,
    floatmat2x2 = 4,
    floatmat2x3 = 6,
    floatmat2x4 = 8,
    floatmat3x2 = 6,
    floatmat3x3 = 9,
    floatmat3x4 = 12,
    floatmat4x2 = 8,
    floatmat4x3 = 12,
    floatmat4x4 = 16,
    int32 = 1,
    int32vec2 = 2,
    int32vec3 = 3,
    int32vec4 = 4,
}

--- Wrapper for love.graphics.newBuffer
---@param format table
---@param count number|table
---@param settings table
---@return Renderer.buffer
function Renderer.graphics.newBuffer(format, count, settings)
    local componentCount = 0
    local componentCountsPerComponent = {}
    for i, component in ipairs(format) do
        assert(componentCounts[component.format], "Invalid buffer component format")
        componentCount = componentCount + componentCounts[component.format]
        componentCountsPerComponent[i] = componentCounts[component.format]
    end

    local buffer = love.graphics.newBuffer(format, count, settings)
    local data

    if type(count) == "table" then
        data = count
    else
        data = table.new(count * componentCount, 0)
        for i = 1, count * componentCount do
            data[i] = 0
        end
    end

    return setmetatable({
        buffer = buffer,
        componentCount = componentCount,
        data = data,
        updated = true,
        format = format,
        componentCountsPerComponent = componentCountsPerComponent,
        engineData = {}
    }, bufferMetatable)
end

function bufferFunctions:getBuffer()
    return self.buffer
end

function bufferFunctions:getData()
    return self.data
end

function bufferFunctions:writeItem(index, values)
    local offset = index * self.componentCount
    for i, value in ipairs(values) do
        if self.data[offset + i] ~= value then
            self.data[offset + i] = value
            self.updated = true
        end
    end
end

local writeIndex = 1

--- writes to the buffer iteratively,
--- can be used in a for-loop to write all the data
function bufferFunctions:write(value)
    local t = type(value)
    local RType = Renderer.math.type(value)
    if t == "number" then
        if self.data[writeIndex] ~= value then
            self.data[writeIndex] = value
            self.updated = true
        end
        writeIndex = writeIndex + 1
    elseif RType == "vec2" then
        self:write(value.x)
        self:write(value.y)
    elseif RType == "vec3" then
        self:write(value.x)
        self:write(value.y)
        self:write(value.z)
    elseif RType == "vec4" then
        self:write(value.x)
        self:write(value.y)
        self:write(value.z)
        self:write(value.w)
    elseif RType == "quat" then
        self:write(value.x)
        self:write(value.y)
        self:write(value.z)
        self:write(value.w)
    elseif RType == "mat3" then
        self:write(value[1][1])
        self:write(value[1][2])
        self:write(value[1][3])
        self:write(value[2][1])
        self:write(value[2][2])
        self:write(value[2][3])
        self:write(value[3][1])
        self:write(value[3][2])
        self:write(value[3][3])
    elseif RType == "mat4" then
        self:write(value[1][1])
        self:write(value[1][2])
        self:write(value[1][3])
        self:write(value[1][4])
        self:write(value[2][1])
        self:write(value[2][2])
        self:write(value[2][3])
        self:write(value[2][4])
        self:write(value[3][1])
        self:write(value[3][2])
        self:write(value[3][3])
        self:write(value[3][4])
        self:write(value[4][1])
        self:write(value[4][2])
        self:write(value[4][3])
        self:write(value[4][4])
    elseif t == "table" then
        for i, v in ipairs(value) do
            self:write(v)
        end
    else
        error("Engine Error: Invalid value type")
    end
end

--- sets the write index of the buffer
function bufferFunctions:setWriteIndex(index)
    writeIndex = index
    assert(writeIndex <= #self.data, "Buffer write index out of bounds")
    assert(writeIndex > 0, "Buffer write index out of bounds")
end

--- gets the write index of the buffer
function bufferFunctions:getWriteIndex()
    return writeIndex
end

--- sets the write index of the buffer to the start of an item
function bufferFunctions:setItemWriteIndex(index)
    writeIndex = (index - 1) * self.componentCount + 1
end

function bufferFunctions:flush()
    if self.updated then
        self.buffer:setArrayData(self.data)
        self.updated = false
    end
end

--- copies an item from the buffer to another item
---@param source number
---@param destination number
function bufferFunctions:copyItemTo(source, destination)
    local sourceIndex = (source - 1) * self.componentCount + 1
    local destinationIndex = (destination - 1) * self.componentCount + 1
    for i = 0, self.componentCount - 1 do
        self.data[destinationIndex + i] = self.data[sourceIndex + i]
    end
    self.updated = true
end

function bufferFunctions:getComponentSize()
    return self.componentCount
end

local formatNum = function(num)
    return string.format("%.4f", num)
end

local function drawMatrix(sx, sy, index, data)
    for y = 1, sy do
        local text = ""
        for x = 1, sx do
            index = index + 1
            text = text .. formatNum(data[index])
            text = text .. (x ~= sx and ", " or "")
        end
        Renderer.internal.imgui.Text(text)
    end

    return index
end

-- draws a gui overlay
function bufferFunctions:draw()
    local imgui = Renderer.internal.imgui

    if imgui.IsWindowAppearing() then
        imgui.SetNextItemWidth(love.graphics.getWidth() * 0.75)
    end

    if imgui.Begin("Buffer '" .. self.buffer:getDebugName() .. "' Data") then
        imgui.Text("Element Count: " .. self.buffer:getElementCount())
        imgui.Text("Calculated element stride: " .. self.componentCount * 4)
        imgui.Text("Final element stride: " .. self.buffer:getElementStride())
        imgui.Text("Calculated component amount: " .. self.componentCount)
        imgui.Text("Final size in bytes: " .. self.buffer:getSize())

        if imgui.BeginTable("Buffer Data", #self.format, bit.bor(imgui.ImGuiTableFlags_Borders, imgui.ImGuiTableFlags_SizingFixedFit)) then
            imgui.TableNextRow()
            for i = 1, #self.format do
                imgui.TableSetColumnIndex(i - 1)
                imgui.Text(self.format[i].name or "Unknown")
            end

            imgui.TableSetColumnIndex(0)
            local index = 0
            for row = 1, self.buffer:getElementCount() do
                imgui.TableNextRow()
                for i, form in ipairs(self.format) do
                    local format = form.format
                    imgui.TableSetColumnIndex(i - 1)
                    if format == "floatmat2x2" then
                        index = drawMatrix(2, 2, index, self.data)
                    elseif format == "floatmat2x3" then
                        index = drawMatrix(2, 3, index, self.data)
                    elseif format == "floatmat2x4" then
                        index = drawMatrix(2, 4, index, self.data)
                    elseif format == "floatmat3x2" then
                        index = drawMatrix(3, 2, index, self.data)
                    elseif format == "floatmat3x3" then
                        index = drawMatrix(3, 3, index, self.data)
                    elseif format == "floatmat3x4" then
                        index = drawMatrix(3, 4, index, self.data)
                    elseif format == "floatmat4x2" then
                        index = drawMatrix(4, 2, index, self.data)
                    elseif format == "floatmat4x3" then
                        index = drawMatrix(4, 3, index, self.data)
                    elseif format == "floatmat4x4" then
                        index = drawMatrix(4, 4, index, self.data)
                    else
                        local text = ""
                        for j = 1, self.componentCountsPerComponent[i] do
                            index = index + 1
                            text = text .. formatNum(self.data[index])
                            text = text .. (j ~= self.componentCountsPerComponent[i] and ", " or "")
                        end
                        imgui.Text(text)
                    end
                end
            end
        end
        imgui.EndTable()
    end
    imgui.End()
end

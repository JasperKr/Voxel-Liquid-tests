---@diagnostic disable: return-type-mismatch
local ffi = require("ffi")

---@class vec4
---@field x number|integer
---@field y number|integer
---@field z number|integer
---@field w number|integer
---@operator add: vec4
---@operator sub: vec4
---@operator mul: vec4
---@operator div: vec4
---@operator pow: vec4
---@operator unm: vec4
---@operator len: number
local vec4F = {}

---@class vec3
---@field x number|integer
---@field y number|integer
---@field z number|integer
---@operator add: vec3
---@operator sub: vec3
---@operator mul: vec3
---@operator div: vec3
---@operator pow: vec3
---@operator unm: vec3
---@operator len: number
local vec3F = {}

---@class vec2
---@field x number|integer
---@field y number|integer
---@operator add: vec2
---@operator sub: vec2
---@operator mul: vec2
---@operator div: vec2
---@operator pow: vec2
---@operator unm: vec2
---@operator len: number
local vec2F = {}

local vec4Mt = {
    __index = vec4F,
}
local vec3Mt = {
    __index = vec3F,
}
local vec2Mt = {
    __index = vec2F,
}

local function tracebackCall(name)
    local info = debug.getinfo(3, "Sl")
    LuaPrint(info.short_src .. ":" .. info.currentline .. " " .. name)
end

-- define Renderer's vec4, vec3, vec2 types, with R so they don't conflict with other libraries
ffi.cdef [[
    typedef struct {
        double x;
        double y;
        double z;
        double w;
    } Rvec4;
    typedef struct {
        double x;
        double y;
        double z;
    } Rvec3;
    typedef struct {
        double x;
        double y;
    } Rvec2;
]]


---vector math library
mathv = {}
---returns the vector with the greatest length
---@param ... vec4|vec3|vec2
---@return vec4|vec3|vec2 vector vector with the greatest length
function mathv.max(...)
    local vectors = { ... }
    if #vectors[1] == 4 then
        local maxVector = vectors[1]
        local maxLength = 0
        for i, v in ipairs(vectors) do
            local lengthsqr = v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w
            if lengthsqr > maxLength then
                maxLength = lengthsqr
                maxVector = v
            end
        end
        return maxVector
    elseif #vectors[1] == 3 then
        local maxVector = vectors[1]
        local maxLength = 0
        for i, v in ipairs(vectors) do
            local lengthsqr = v.x * v.x + v.y * v.y + v.z * v.z
            if lengthsqr > maxLength then
                maxLength = lengthsqr
                maxVector = v
            end
        end
        return maxVector
    else
        local maxVector = vectors[1]
        local maxLength = 0
        for i, v in ipairs(vectors) do
            local lengthsqr = v.x * v.x + v.y * v.y
            if lengthsqr > maxLength then
                maxLength = lengthsqr
                maxVector = v
            end
        end
        return maxVector
    end
end

---returns the vector with the smallest length
---@param ... vec4|vec3|vec2
---@return vec4|vec3|vec2 vector vector with the smallest length
function mathv.min(...)
    local vectors = { ... }
    if #vectors[1] == 4 then
        local minVector = vectors[1]
        local minLength = math.huge
        for i, v in ipairs(vectors) do
            local lengthsqr = v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w
            if lengthsqr < minLength then
                minLength = lengthsqr
                minVector = v
            end
        end
        return minVector
    elseif #vectors[1] == 3 then
        local minVector = vectors[1]
        local minLength = math.huge
        for i, v in ipairs(vectors) do
            local lengthsqr = v.x * v.x + v.y * v.y + v.z * v.z
            if lengthsqr < minLength then
                minLength = lengthsqr
                minVector = v
            end
        end
        return minVector
    else
        local minVector = vectors[1]
        local minLength = math.huge
        for i, v in ipairs(vectors) do
            local lengthsqr = v.x * v.x + v.y * v.y
            if lengthsqr < minLength then
                minLength = lengthsqr
                minVector = v
            end
        end
        return minVector
    end
end

---returns the vector with the greatest length per component
---@param ... vec2
---@return vec2 vector vector with the greatest length
function mathv.cmax2(...)
    local vectors = { ... }
    local maxVector = vec2(vectors[1])
    for i = 2, #vectors do
        maxVector.x = math.max(maxVector.x, vectors[i].x)
        maxVector.y = math.max(maxVector.y, vectors[i].y)
    end
    return maxVector
end

---returns the vector with the greatest length per component
---@param ... vec3
---@return vec3 vector vector with the greatest length
function mathv.cmax3(...)
    local vectors = { ... }
    local maxVector = vec3(vectors[1])
    for i = 2, #vectors do
        maxVector.x = math.max(maxVector.x, vectors[i].x)
        maxVector.y = math.max(maxVector.y, vectors[i].y)
        maxVector.z = math.max(maxVector.z, vectors[i].z)
    end
    return maxVector
end

---returns the vector with the greatest length per component
---@param ... vec4
---@return vec4 vector vector with the greatest length
function mathv.cmax4(...)
    local vectors = { ... }
    local maxVector = vec4(vectors[1])
    for i = 2, #vectors do
        maxVector.x = math.max(maxVector.x, vectors[i].x)
        maxVector.y = math.max(maxVector.y, vectors[i].y)
        maxVector.z = math.max(maxVector.z, vectors[i].z)
        maxVector.w = math.max(maxVector.w, vectors[i].w)
    end
    return maxVector
end

---returns the vector with the smallest length per component
---@param ... vec4
---@return vec4 vector vector with the smallest length
function mathv.cmin4(...)
    local vectors = { ... }
    local minVector = vec4(vectors[1])
    for i = 2, #vectors do
        local v = vectors[i]
        minVector.x = math.min(minVector.x, v.x)
        minVector.y = math.min(minVector.y, v.y)
        minVector.z = math.min(minVector.z, v.z)
        minVector.w = math.min(minVector.w, v.w)
    end
    return minVector
end

---@deprecated
function mathv.cmin(...) end

---@deprecated
function mathv.cmax(...) end

---@deprecated
function mathv.abs(vector) end

---returns the vector with the smallest length per component
---@param ... vec3
---@return vec3 vector vector with the smallest length
function mathv.cmin3(...)
    local vectors = { ... }
    local minVector = vec3(vectors[1])
    for i = 2, #vectors do
        local v = vectors[i]
        minVector.x = math.min(minVector.x, v.x)
        minVector.y = math.min(minVector.y, v.y)
        minVector.z = math.min(minVector.z, v.z)
    end
    return minVector
end

---returns the vector with the smallest length per component
---@param ... vec2
---@return vec2 vector vector with the smallest length
function mathv.cmin2(...)
    local vectors = { ... }
    local minVector = vec2(vectors[1])
    for i = 2, #vectors do
        local v = vectors[i]
        minVector.x = math.min(minVector.x, v.x)
        minVector.y = math.min(minVector.y, v.y)
    end
    return minVector
end

---returns the absolute of a vector
---@param vector vec3
---@return vec3 vector absolute vector
function mathv.abs3(vector)
    return vec3(math.abs(vector.x), math.abs(vector.y), math.abs(vector.z))
end

---returns the absolute of a vector
---@param vector vec4
---@return vec4 vector absolute vector
function mathv.abs4(vector)
    return vec4(math.abs(vector.x), math.abs(vector.y), math.abs(vector.z), math.abs(vector.w))
end

---returns the absolute of a vector
---@param vector vec2
---@return vec2 vector absolute vector
function mathv.abs2(vector)
    return vec2(math.abs(vector.x), math.abs(vector.y))
end

local function lerp(angle, target, turnrate)
    local dist = target - angle
    dist = (dist + math.pi) % PI2 - math.pi
    local step = turnrate * love.timer.getDelta()
    if dist <= step then
        angle = target
    else
        if dist < 0 then
            step = -step
        end
        angle = angle + step
    end
    return angle
end

function mathv.lerp4(angle, target, turnrate)
    return vec4(
        lerp(angle.x, target.x, turnrate),
        lerp(angle.y, target.y, turnrate),
        lerp(angle.z, target.z, turnrate),
        lerp(angle.w, target.w, turnrate)
    )
end

function mathv.lerp3(angle, target, turnrate)
    return vec3(
        lerp(angle.x, target.x, turnrate),
        lerp(angle.y, target.y, turnrate),
        lerp(angle.z, target.z, turnrate)
    )
end

function mathv.lerp2(angle, target, turnrate)
    return vec2(
        lerp(angle.x, target.x, turnrate),
        lerp(angle.y, target.y, turnrate)
    )
end

--- returns a vec4
---@param x? number|nil|table
---@param y? number
---@param z? number
---@param w? number
---@return vec4
function vec4(x, y, z, w)
    if not y then
        if type(x) == "table" then
            return ffi.new("Rvec4", x[1] or 0, x[2] or 0, x[3] or 0, x[4] or 0)
        elseif type(x) == "cdata" then
            return ffi.new("Rvec4", x.x or 0, x.y or 0, x.z or 0, x.w or 0)
        else
            x = x or 0
            return ffi.new("Rvec4", x, x, x, x)
        end
    end

    ---@diagnostic disable-next-line: missing-return-value
    return ffi.new("Rvec4", { x or 0, y or 0, z or 0, w or 0 })
end

--- returns a vec3
---@param x? number|nil|table
---@param y? number
---@param z? number
---@return vec3
function vec3(x, y, z)
    if not y then
        if type(x) == "table" then
            return ffi.new("Rvec3", x[1], x[2], x[3])
        elseif type(x) == "cdata" then
            local x1, y1, z1 = x:get() -- using .x, .y, .z can crash: if you supply a vec2, it will try to access .z
            return ffi.new("Rvec3", x1, y1, z1)
        else
            x = x or 0
            return ffi.new("Rvec3", x, x, x)
        end
    end
    ---@diagnostic disable-next-line: missing-return-value
    return ffi.new("Rvec3", x or 0, y or 0, z or 0)
end

--- returns a vec2
---@param x? number|nil|table
---@param y? number
---@return vec2
function vec2(x, y)
    if not y then
        if type(x) == "table" or type(x) == "cdata" then
            return ffi.new("Rvec2", x[1], x[2])
        elseif type(x) == "cdata" then
            return ffi.new("Rvec2", x.x, x.y)
        else
            x = x or 0
            return ffi.new("Rvec2", x, x)
        end
    end
    ---@diagnostic disable-next-line: missing-return-value
    return ffi.new("Rvec2", x or 0, y or 0)
end

---returns the dot product
---@param v vec4
---@return number
function vec4F:dot(v)
    return self.x * v.x + self.y * v.y + self.z * v.z + self.w * v.w
end

---returns the dot product
---@param v vec3
---@return number
function vec3F:dot(v)
    return self.x * v.x + self.y * v.y + self.z * v.z
end

---returns the dot product
---@param v vec2
---@return number
function vec2F:dot(v)
    return self.x * v.x + self.y * v.y
end

---returns the inverse of the vector
---@return vec4
function vec4F:inverse()
    return vec4(1 - self.x, 1 - self.y, 1 - self.z, 1 - self.w)
end

---returns the inverse of the vector
---@return vec3
function vec3F:inverse()
    return vec3(1 - self.x, 1 - self.y, 1 - self.z)
end

---returns the inverse of the vector
---@return vec2
function vec2F:inverse()
    return vec2(1 - self.x, 1 - self.y)
end

---@return number
function vec4F:length()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w)
end

---@return number
function vec3F:length()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

---@return number
function vec2F:length()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

---@return number
function vec4F:lengthSqr()
    return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
end

---@return number
function vec3F:lengthSqr()
    return self.x * self.x + self.y * self.y + self.z * self.z
end

---@return number
function vec2F:lengthSqr()
    return self.x * self.x + self.y * self.y
end

---returns the normalized vector
---@return vec4
function vec4F:normalize()
    local t = self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
    if t == 0 then
        return vec4()
    end
    local invLength = 1 / math.sqrt(t)
    return vec4(
        self.x * invLength,
        self.y * invLength,
        self.z * invLength,
        self.w * invLength
    )
end

---returns the normalized vector
---@return vec3
function vec3F:normalize()
    local t = self.x * self.x + self.y * self.y + self.z * self.z
    if t == 0 then
        return vec3()
    end
    local invLength = 1 / math.sqrt(t)
    return vec3(
        self.x * invLength,
        self.y * invLength,
        self.z * invLength
    )
end

---returns the normalized vector
---@return vec2
function vec2F:normalize()
    local t = self.x * self.x + self.y * self.y
    if t == 0 then
        return vec2()
    end
    local invLength = 1 / math.sqrt(t)
    return vec2(
        self.x * invLength,
        self.y * invLength
    )
end

---returns the sum of the vector
---@return number
function vec4F:sum()
    return self.x + self.y + self.z + self.w
end

---returns the sum of the vector
---@return number
function vec3F:sum()
    return self.x + self.y + self.z
end

---returns the sum of the vector
---@return number
function vec2F:sum()
    return self.x + self.y
end

---sets the vector
---@param x number|vec4|table
---@param y? number
---@param z? number
---@param w? number
function vec4F:set(x, y, z, w)
    if type(x) == "cdata" then
        self.x, self.y, self.z, self.w = x.x, x.y, x.z, x.w
    elseif type(x) == "number" then
        self.x, self.y, self.z, self.w = x or 0, y or 0, z or 0, w or 0
    end
    return self
end

---sets the vector
---@param x number|vec3|table
---@param y? number
---@param z? number
function vec3F:set(x, y, z)
    if type(x) == "cdata" then
        self.x, self.y, self.z = x.x, x.y, x.z
    elseif type(x) == "number" then
        self.x, self.y, self.z = x or 0, y or 0, z or 0
    end
    return self
end

---sets the vector
---@param x number|vec2|table
---@param y? number
function vec2F:set(x, y)
    if type(x) == "cdata" then
        self.x, self.y = x.x, x.y
    elseif type(x) == "number" then
        self.x, self.y = x or 0, y or 0
    end
    return self
end

---returns the cross product
---@param y vec4
---@return vec4 vector with w = 0
function vec4F:cross(y)
    return vec4(
        self.y * y.z - self.z * y.y, self.z * y.x - self.x * y.z, self.x * y.y - self.y * y.x, 0)
end

---returns the cross product
---@param y vec3
---@return vec3
function vec3F:cross(y)
    return vec3(self.y * y.z - y.y * self.z, self.z * y.x - y.z * self.x, self.x * y.y - y.x *
        self.y)
end

---returns the cross product
---@param b vec2
---@return vec2
function vec2F:cross(b)
    return vec2(self.x * b.y - b.x * self.y)
end

---returns the vector in numbers
---@return number x
---@return number y
---@return number z
---@return number w
function vec4F:get()
    return self.x, self.y, self.z, self.w
end

---returns the vector in numbers
---@return number x
---@return number y
---@return number z
function vec3F:get()
    return self.x, self.y, self.z
end

---returns the vector in numbers
---@return number x
---@return number y
function vec2F:get()
    return self.x, self.y
end

vec4F.type = "vec4"
vec3F.type = "vec3"
vec2F.type = "vec2"

---returns a copy of the vector
---@return vec4
function vec4F:copy()
    return vec4(self.x, self.y, self.z, self.w)
end

---returns a copy of the vector
---@return vec3
function vec3F:copy()
    return vec3(self.x, self.y, self.z)
end

---returns a copy of the vector
---@return vec2
function vec2F:copy()
    return vec2(self.x, self.y)
end

function vec4Mt.__tostring(self) -- thank you to EngineerSmith for this function <3
    return "[" .. self.x .. "," .. self.y .. "," .. self.z .. "," .. self.w .. "]"
end

function vec3Mt.__tostring(self)
    return "[" .. self.x .. "," .. self.y .. "," .. self.z .. "]"
end

function vec2Mt.__tostring(self)
    return "[" .. self.x .. "," .. self.y .. "]"
end

---@return vec4
function vec4Mt.__mul(x, y)
    if not x then
        error("1 " .. tostring(x) .. " attempt to perform arithmetic on nil number")
    elseif not y then
        error("2 " .. tostring(y) .. " attempt to perform arithmetic on nil number")
    end
    if type(x) == "cdata" then
        if type(y) == "cdata" then
            return vec4(
                x.x * y.x,
                x.y * y.y,
                x.z * y.z,
                x.w * y.w
            )
        else
            return vec4(
                x.x * y,
                x.y * y,
                x.z * y,
                x.w * y
            )
        end
    else
        return vec4(
            y.x * x,
            y.y * x,
            y.z * x,
            y.w * x
        )
    end
end

---@return vec3
function vec3Mt.__mul(x, y)
    if not x then
        error("1 " .. tostring(x) .. " attempt to perform arithmetic on nil number")
    elseif not y then
        error("2 " .. tostring(y) .. " attempt to perform arithmetic on nil number")
    end
    if type(x) == "cdata" then
        if type(y) == "cdata" then
            return vec3(
                x.x * y.x,
                x.y * y.y,
                x.z * y.z
            )
        else
            return vec3(
                x.x * y,
                x.y * y,
                x.z * y
            )
        end
    else
        return vec3(
            y.x * x,
            y.y * x,
            y.z * x
        )
    end
end

---@return vec2
function vec2Mt.__mul(x, y)
    if not x then
        error("1 " .. tostring(x) .. " attempt to perform arithmetic on nil number")
    elseif not y then
        error("2 " .. tostring(y) .. " attempt to perform arithmetic on nil number")
    end
    if type(x) == "cdata" then
        if type(y) == "cdata" then
            return vec2(
                x.x * y.x,
                x.y * y.y
            )
        else
            return vec2(
                x.x * y,
                x.y * y
            )
        end
    else
        return vec2(
            y.x * x,
            y.y * x
        )
    end
end

---@return vec4
function vec4Mt.__add(x, y)
    if type(x) == "cdata" then
        if type(y) == "cdata" then
            return vec4(
                x.x + y.x,
                x.y + y.y,
                x.z + y.z,
                x.w + y.w
            )
        else
            return vec4(
                x.x + y,
                x.y + y,
                x.z + y,
                x.w + y
            )
        end
    else
        return vec4(
            y.x + x,
            y.y + x,
            y.z + x,
            y.z + x
        )
    end
end

---@return vec3
function vec3Mt.__add(x, y)
    if type(x) == "cdata" then
        if type(y) == "cdata" then
            return vec3(
                x.x + y.x,
                x.y + y.y,
                x.z + y.z
            )
        else
            return vec3(
                x.x + y,
                x.y + y,
                x.z + y
            )
        end
    else
        return vec3(
            y.x + x,
            y.y + x,
            y.z + x
        )
    end
end

---@return vec2
function vec2Mt.__add(x, y)
    if type(x) == "cdata" then
        if type(y) == "cdata" then
            return vec2(
                x.x + y.x,
                x.y + y.y
            )
        else
            return vec2(
                x.x + y,
                x.y + y
            )
        end
    else
        return vec2(
            y.x + x,
            y.y + x
        )
    end
end

---@return vec4
function vec4Mt.__pow(x, y)
    local v = vec4()
    if type(x) == "number" then -- num + vec4
        v.x = x ^ y.x
        v.y = x ^ y.y
        v.z = x ^ y.z
        v.w = x ^ y.w
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            v.x = x.x ^ y.x.x
            v.y = x.y ^ y.x.y
            v.z = x.z ^ y.x.z
            v.w = x.w ^ y.x.w
        else -- vec4 + vec4
            v.x = x.x ^ y.x
            v.y = x.y ^ y.y
            v.z = x.z ^ y.z
            v.w = x.w ^ y.w
        end
    else -- vec4 + num
        v.x = x.x ^ y
        v.y = x.y ^ y
        v.z = x.z ^ y
        v.w = x.w ^ y
    end
    return v
end

---@return vec3
function vec3Mt.__pow(x, y)
    local v = vec3()
    if type(x) == "number" then -- num + vec4
        v.x = x ^ y.x
        v.y = x ^ y.y
        v.z = x ^ y.z
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            v.x = x.x ^ y.x.x
            v.y = x.y ^ y.x.y
            v.z = x.z ^ y.x.z
        else -- vec4 + vec4
            v.x = x.x ^ y.x
            v.y = x.y ^ y.y
            v.z = x.z ^ y.z
        end
    else -- vec4 + num
        v.x = x.x ^ y
        v.y = x.y ^ y
        v.z = x.z ^ y
    end
    return v
end

---@return vec2
function vec2Mt.__pow(x, y)
    local v = vec2()
    if type(x) == "number" then -- num + vec4
        v.x = x ^ y.x
        v.y = x ^ y.y
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            v.x = x.x ^ y.x.x
            v.y = x.y ^ y.x.y
        else -- vec4 + vec4
            v.x = x.x ^ y.x
            v.y = x.y ^ y.y
        end
    else -- vec4 + num
        v.x = x.x ^ y
        v.y = x.y ^ y
    end
    return v
end

---@return vec4
function vec4Mt.__div(x, y)
    if type(x) == "number" then -- num / vec4
        return vec4(
            x / y.x,
            x / y.y,
            x / y.z,
            x / y.w
        )
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            return vec4(
                x.x / y.x.x,
                x.y / y.x.y,
                x.z / y.x.z,
                x.w / y.x.w
            )
        else -- vec4 / vec4
            return vec4(
                x.x / y.x,
                x.y / y.y,
                x.z / y.z,
                x.w / y.w
            )
        end
    else -- vec4 / num
        local z = 1 / y
        return vec4(
            x.x * z,
            x.y * z,
            x.z * z,
            x.w * z
        )
    end
end

---@return vec3
function vec3Mt.__div(x, y)
    if type(x) == "number" then -- num / vec3
        return vec3(
            x / y.x,
            x / y.y,
            x / y.z
        )
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x3 matrix
            return vec3(
                x.x / y.x.x,
                x.y / y.x.y,
                x.z / y.x.z
            )
        else -- vec3 / vec3
            return vec3(
                x.x / y.x,
                x.y / y.y,
                x.z / y.z
            )
        end
    else -- vec3 / num
        local z = 1 / y
        return vec3(
            x.x * z,
            x.y * z,
            x.z * z
        )
    end
end

---@return vec2
function vec2Mt.__div(x, y)
    if type(x) == "number" then -- num / vec2
        return vec2(
            x / y.x,
            x / y.y
        )
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x2 matrix
            return vec2(
                x.x / y.x.x,
                x.y / y.x.y
            )
        else -- vec2 / vec2
            return vec2(
                x.x / y.x,
                x.y / y.y
            )
        end
    else -- vec2 / num
        local z = 1 / y
        return vec2(
            x.x * z,
            x.y * z
        )
    end
end

---@return vec4
function vec4Mt.__sub(x, y)
    if type(x) == "number" then -- num - vec4
        return vec4(
            x - y.x,
            x - y.y,
            x - y.z,
            x - y.w
        )
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            return vec4(
                x.x - y.x.x,
                x.y - y.x.y,
                x.z - y.x.z,
                x.w - y.x.w
            )
        else -- vec4 - vec4
            return vec4(
                x.x - y.x,
                x.y - y.y,
                x.z - y.z,
                x.w - y.w
            )
        end
    else -- vec4 - num
        return vec4(
            x.x - y,
            x.y - y,
            x.z - y,
            x.w - y
        )
    end
end

---@return vec3
function vec3Mt.__sub(x, y)
    if type(x) == "number" then -- num - vec4
        return vec3(
            x - y.x,
            x - y.y,
            x - y.z
        )
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            return vec3(
                x.x - y.x.x,
                x.y - y.x.y,
                x.z - y.x.z
            )
        else -- vec4 - vec4
            return vec3(
                x.x - y.x,
                x.y - y.y,
                x.z - y.z
            )
        end
    else -- vec4 - num
        return vec3(
            x.x - y,
            x.y - y,
            x.z - y
        )
    end
end

---@return vec2
function vec2Mt.__sub(x, y)
    if type(x) == "number" then -- num - vec4
        return vec2(
            x - y.x,
            x - y.y
        )
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            return vec2(
                x.x - y.x.x,
                x.y - y.x.y
            )
        else -- vec4 - vec4
            return vec2(
                x.x - y.x,
                x.y - y.y
            )
        end
    else -- vec4 - num
        return vec2(
            x.x - y,
            x.y - y
        )
    end
end

---@return ffi.cdata*
function vec4Mt.__unm(x)
    return vec4(-x.x, -x.y, -x.z, -x.w)
end

---@return ffi.cdata*
function vec3Mt.__unm(x)
    return vec3(-x.x, -x.y, -x.z)
end

---@return ffi.cdata*
function vec2Mt.__unm(x)
    return vec2(-x.x, -x.y)
end

---@return vec4
function vec4Mt.__mod(x, y)
    local v = vec4()
    if type(x) == "cdata" then
        if type(y) == "cdata" then
            v.x = x.x % y.x
            v.y = x.y % y.y
            v.z = x.z % y.z
            v.w = x.w % y.w
        else
            v.x = x.x % y
            v.y = x.y % y
            v.z = x.z % y
            v.w = x.w % y
        end
    else
        v.x = y.x % x
        v.y = y.y % x
        v.z = y.z % x
        v.w = y.w % x
    end
    return v
end

---@return vec3
function vec3Mt.__mod(x, y)
    local v = vec3()
    if type(x) == "number" then -- num % vec4
        v.x = x % y.x
        v.y = x % y.y
        v.z = x % y.z
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            v.x = x.x % y[1].x
            v.y = x.y % y[1].y
            v.z = x.z % y[1].z
        else -- vec4 + vec4
            v.x = x.x % y.x
            v.y = x.y % y.y
            v.z = x.z % y.z
        end
    else -- vec4 + num
        v.x = x.x % y
        v.y = x.y % y
        v.z = x.z % y
    end
    return v
end

---@return vec2
function vec2Mt.__mod(x, y)
    local v = vec2()
    if type(x) == "number" then -- num % vec4
        v.x = x % y.x
        v.y = x % y.y
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            v.x = x.x % y[1].x
            v.y = x.y % y[1].y
        else -- vec4 + vec4
            v.x = x.x % y.x
            v.y = x.y % y.y
        end
    else -- vec4 + num
        v.x = x.x % y
        v.y = x.y % y
    end
    return v
end

function vec4F:table()
    return { self.x, self.y, self.z, self.w }
end

function vec3F:table()
    return { self.x, self.y, self.z }
end

function vec2F:table()
    return { self.x, self.y }
end

local tempTableAmount = 50
local tempTableMax = tempTableAmount - 1

local tempTables4 = {}
local tempTables4Iterator = 1
for i = 1, tempTableAmount do
    table.insert(tempTables4, {})
end
local tempTables3 = {}
local tempTables3Iterator = 1
for i = 1, tempTableAmount do
    table.insert(tempTables3, {})
end
local tempTables2 = {}
local tempTables2Iterator = 1
for i = 1, tempTableAmount do
    table.insert(tempTables2, {})
end

--- returns the vector in a temporary table
---@return table
function vec4F:ttable()
    tempTables4Iterator = (tempTables4Iterator + 1) % tempTableMax + 1
    tempTables4[tempTables4Iterator][1] = self.x
    tempTables4[tempTables4Iterator][2] = self.y
    tempTables4[tempTables4Iterator][3] = self.z
    tempTables4[tempTables4Iterator][4] = self.w
    return tempTables4[tempTables4Iterator]
end

--- returns the vector in a temporary table
---@return table
function vec3F:ttable()
    tempTables3Iterator = (tempTables3Iterator + 1) % tempTableMax + 1
    tempTables3[tempTables3Iterator][1] = self.x
    tempTables3[tempTables3Iterator][2] = self.y
    tempTables3[tempTables3Iterator][3] = self.z
    return tempTables3[tempTables3Iterator]
end

--- returns the vector in a temporary table
---@return table
function vec2F:ttable()
    tempTables2Iterator = (tempTables2Iterator + 1) % tempTableMax + 1
    tempTables2[tempTables2Iterator][1] = self.x
    tempTables2[tempTables2Iterator][2] = self.y
    return tempTables2[tempTables2Iterator]
end

function vec4F:min(v)
    self.x = math.min(self.x, v.x)
    self.y = math.min(self.y, v.y)
    self.z = math.min(self.z, v.z)
    self.w = math.min(self.w, v.w)
    return self
end

function vec3F:min(v)
    self.x = math.min(self.x, v.x)
    self.y = math.min(self.y, v.y)
    self.z = math.min(self.z, v.z)
    return self
end

function vec2F:min(v)
    self.x = math.min(self.x, v.x)
    self.y = math.min(self.y, v.y)
    return self
end

function vec4F:max(v)
    self.x = math.max(self.x, v.x)
    self.y = math.max(self.y, v.y)
    self.z = math.max(self.z, v.z)
    self.w = math.max(self.w, v.w)
    return self
end

function vec3F:max(v)
    self.x = math.max(self.x, v.x)
    self.y = math.max(self.y, v.y)
    self.z = math.max(self.z, v.z)
    return self
end

function vec2F:max(v)
    self.x = math.max(self.x, v.x)
    self.y = math.max(self.y, v.y)
    return self
end

function vec4F:minSeparate(x, y, z, w)
    self.x = math.min(self.x, x)
    self.y = math.min(self.y, y)
    self.z = math.min(self.z, z)
    self.w = math.min(self.w, w)
    return self
end

function vec3F:minSeparate(x, y, z)
    self.x = math.min(self.x, x)
    self.y = math.min(self.y, y)
    self.z = math.min(self.z, z)
    return self
end

function vec2F:minSeparate(x, y)
    self.x = math.min(self.x, x)
    self.y = math.min(self.y, y)
    return self
end

function vec4F:maxSeparate(x, y, z, w)
    self.x = math.max(self.x, x)
    self.y = math.max(self.y, y)
    self.z = math.max(self.z, z)
    self.w = math.max(self.w, w)
    return self
end

function vec3F:maxSeparate(x, y, z)
    self.x = math.max(self.x, x)
    self.y = math.max(self.y, y)
    self.z = math.max(self.z, z)
    return self
end

function vec2F:maxSeparate(x, y)
    self.x = math.max(self.x, x)
    self.y = math.max(self.y, y)
    return self
end

function vec4F:distance(v)
    return math.sqrt((self.x - v.x) ^ 2 + (self.y - v.y) ^ 2 + (self.z - v.z) ^ 2 + (self.w - v.w) ^ 2)
end

function vec3F:distance(v)
    return math.sqrt((self.x - v.x) ^ 2 + (self.y - v.y) ^ 2 + (self.z - v.z) ^ 2)
end

function vec2F:distance(v)
    return math.sqrt((self.x - v.x) ^ 2 + (self.y - v.y) ^ 2)
end

function vec4F:distanceSqr(v)
    return (self.x - v.x) ^ 2 + (self.y - v.y) ^ 2 + (self.z - v.z) ^ 2 + (self.w - v.w) ^ 2
end

function vec3F:distanceSqr(v)
    return (self.x - v.x) ^ 2 + (self.y - v.y) ^ 2 + (self.z - v.z) ^ 2
end

function vec2F:distanceSqr(v)
    return (self.x - v.x) ^ 2 + (self.y - v.y) ^ 2
end

function vec4F:distanceSep(x, y, z, w)
    return math.sqrt((self.x - x) ^ 2 + (self.y - y) ^ 2 + (self.z - z) ^ 2 + (self.w - w) ^ 2)
end

function vec3F:distanceSep(x, y, z)
    return math.sqrt((self.x - x) ^ 2 + (self.y - y) ^ 2 + (self.z - z) ^ 2)
end

function vec2F:distanceSep(x, y)
    return math.sqrt((self.x - x) ^ 2 + (self.y - y) ^ 2)
end

function vec4F:distanceSqrSep(x, y, z, w)
    return (self.x - x) ^ 2 + (self.y - y) ^ 2 + (self.z - z) ^ 2 + (self.w - w) ^ 2
end

function vec3F:distanceSqrSep(x, y, z)
    return (self.x - x) ^ 2 + (self.y - y) ^ 2 + (self.z - z) ^ 2
end

function vec2F:distanceSqrSep(x, y)
    return (self.x - x) ^ 2 + (self.y - y) ^ 2
end

vec4F.CType = ffi.typeof("Rvec4")
vec3F.CType = ffi.typeof("Rvec3")
vec2F.CType = ffi.typeof("Rvec2")

vec4Mt.__len = 4
vec3Mt.__len = 3
vec2Mt.__len = 2

ffi.metatype("Rvec4", vec4Mt)
ffi.metatype("Rvec3", vec3Mt)
ffi.metatype("Rvec2", vec2Mt)

function mathv.add4(x, y, out)
    out.x = x.x + y.x
    out.y = x.y + y.y
    out.z = x.z + y.z
    out.w = x.w + y.w
    return out
end

function mathv.add3(x, y, out)
    out.x = x.x + y.x
    out.y = x.y + y.y
    out.z = x.z + y.z
    return out
end

function mathv.add2(x, y, out)
    out.x = x.x + y.x
    out.y = x.y + y.y
    return out
end

function mathv.sub4(x, y, out)
    out.x = x.x - y.x
    out.y = x.y - y.y
    out.z = x.z - y.z
    out.w = x.w - y.w
    return out
end

function mathv.sub3(x, y, out)
    out.x = x.x - y.x
    out.y = x.y - y.y
    out.z = x.z - y.z
    return out
end

function mathv.sub2(x, y, out)
    out.x = x.x - y.x
    out.y = x.y - y.y
    return out
end

function mathv.mul4(x, y, out)
    out.x = x.x * y.x
    out.y = x.y * y.y
    out.z = x.z * y.z
    out.w = x.w * y.w
    return out
end

function mathv.mul3(x, y, out)
    out.x = x.x * y.x
    out.y = x.y * y.y
    out.z = x.z * y.z
    return out
end

function mathv.mul2(x, y, out)
    out.x = x.x * y.x
    out.y = x.y * y.y
    return out
end

function mathv.div4(x, y, out)
    out.x = x.x / y.x
    out.y = x.y / y.y
    out.z = x.z / y.z
    out.w = x.w / y.w
    return out
end

function mathv.div3(x, y, out)
    out.x = x.x / y.x
    out.y = x.y / y.y
    out.z = x.z / y.z
    return out
end

function mathv.div2(x, y, out)
    out.x = x.x / y.x
    out.y = x.y / y.y
    return out
end

function mathv.mod4(x, y, out)
    out.x = x.x % y.x
    out.y = x.y % y.y
    out.z = x.z % y.z
    out.w = x.w % y.w
    return out
end

function mathv.mod3(x, y, out)
    out.x = x.x % y
    out.y = x.y % y
    out.z = x.z % y
    return out
end

function mathv.mod2(x, y, out)
    out.x = x.x % y
    out.y = x.y % y
    return out
end

function mathv.pow4(x, y, out)
    out.x = x.x ^ y.x
    out.y = x.y ^ y.y
    out.z = x.z ^ y.z
    out.w = x.w ^ y.w
    return out
end

function mathv.pow3(x, y, out)
    out.x = x.x ^ y.x
    out.y = x.y ^ y.y
    out.z = x.z ^ y.z
    return out
end

function mathv.pow2(x, y, out)
    out.x = x.x ^ y.x
    out.y = x.y ^ y.y
    return out
end

function mathv.unm4(x, out)
    out.x = -x.x
    out.y = -x.y
    out.z = -x.z
    out.w = -x.w
    return out
end

function mathv.unm3(x, out)
    out.x = -x.x
    out.y = -x.y
    out.z = -x.z
    return out
end

function mathv.unm2(x, out)
    out.x = -x.x
    out.y = -x.y
    return out
end

function mathv.addScalar2(x, y, out)
    out.x = x.x + y
    out.y = x.y + y
    return out
end

function mathv.addScalar3(x, y, out)
    out.x = x.x + y
    out.y = x.y + y
    out.z = x.z + y
    return out
end

function mathv.addScalar4(x, y, out)
    out.x = x.x + y
    out.y = x.y + y
    out.z = x.z + y
    out.w = x.w + y
    return out
end

function mathv.subScalar2(x, y, out)
    out.x = x.x - y
    out.y = x.y - y
    return out
end

function mathv.subScalar3(x, y, out)
    out.x = x.x - y
    out.y = x.y - y
    out.z = x.z - y
    return out
end

function mathv.subScalar4(x, y, out)
    out.x = x.x - y
    out.y = x.y - y
    out.z = x.z - y
    out.w = x.w - y
    return out
end

function mathv.mulScalar2(x, y, out)
    out.x = x.x * y
    out.y = x.y * y
    return out
end

function mathv.mulScalar3(x, y, out)
    out.x = x.x * y
    out.y = x.y * y
    out.z = x.z * y
    return out
end

function mathv.mulScalar4(x, y, out)
    out.x = x.x * y
    out.y = x.y * y
    out.z = x.z * y
    out.w = x.w * y
    return out
end

function mathv.divScalar2(x, y, out)
    out.x = x.x / y
    out.y = x.y / y
    return out
end

function mathv.divScalar3(x, y, out)
    out.x = x.x / y
    out.y = x.y / y
    out.z = x.z / y
    return out
end

function mathv.divScalar4(x, y, out)
    out.x = x.x / y
    out.y = x.y / y
    out.z = x.z / y
    out.w = x.w / y
    return out
end

function mathv.modScalar2(x, y, out)
    out.x = x.x % y
    out.y = x.y % y
    return out
end

function mathv.modScalar3(x, y, out)
    out.x = x.x % y
    out.y = x.y % y
    out.z = x.z % y
    return out
end

function mathv.modScalar4(x, y, out)
    out.x = x.x % y
    out.y = x.y % y
    out.z = x.z % y
    out.w = x.w % y
    return out
end

function mathv.powScalar2(x, y, out)
    out.x = x.x ^ y
    out.y = x.y ^ y
    return out
end

function mathv.powScalar3(x, y, out)
    out.x = x.x ^ y
    out.y = x.y ^ y
    out.z = x.z ^ y
    return out
end

function mathv.powScalar4(x, y, out)
    out.x = x.x ^ y
    out.y = x.y ^ y
    out.z = x.z ^ y
    out.w = x.w ^ y
    return out
end

function mathv.subScalar2B(x, y, out)
    out.x = y - x.x
    out.y = y - x.y
    return out
end

function mathv.subScalar3B(x, y, out)
    out.x = y - x.x
    out.y = y - x.y
    out.z = y - x.z
    return out
end

function mathv.subScalar4B(x, y, out)
    out.x = y - x.x
    out.y = y - x.y
    out.z = y - x.z
    out.w = y - x.w
    return out
end

function mathv.divScalar2B(x, y, out)
    out.x = y / x.x
    out.y = y / x.y
    return out
end

function mathv.divScalar3B(x, y, out)
    out.x = y / x.x
    out.y = y / x.y
    out.z = y / x.z
    return out
end

function mathv.divScalar4B(x, y, out)
    out.x = y / x.x
    out.y = y / x.y
    out.z = y / x.z
    out.w = y / x.w
    return out
end

function mathv.modScalar2B(x, y, out)
    out.x = y % x.x
    out.y = y % x.y
    return out
end

function mathv.modScalar3B(x, y, out)
    out.x = y % x.x
    out.y = y % x.y
    out.z = y % x.z
    return out
end

function mathv.modScalar4B(x, y, out)
    out.x = y % x.x
    out.y = y % x.y
    out.z = y % x.z
    out.w = y % x.w
    return out
end

function mathv.powScalar2B(x, y, out)
    out.x = y ^ x.x
    out.y = y ^ x.y
    return out
end

function mathv.powScalar3B(x, y, out)
    out.x = y ^ x.x
    out.y = y ^ x.y
    out.z = y ^ x.z
    return out
end

function mathv.powScalar4B(x, y, out)
    out.x = y ^ x.x
    out.y = y ^ x.y
    out.z = y ^ x.z
    out.w = y ^ x.w
    return out
end

function mathv.addToA2(x, y)
    x.x = x.x + y.x
    x.y = x.y + y.y
    return x
end

function mathv.addToA3(x, y)
    x.x = x.x + y.x
    x.y = x.y + y.y
    x.z = x.z + y.z
    return x
end

function mathv.addToA4(x, y)
    x.x = x.x + y.x
    x.y = x.y + y.y
    x.z = x.z + y.z
    x.w = x.w + y.w
    return x
end

function mathv.subToA2(x, y)
    x.x = x.x - y.x
    x.y = x.y - y.y
    return x
end

function mathv.subToA3(x, y)
    x.x = x.x - y.x
    x.y = x.y - y.y
    x.z = x.z - y.z
    return x
end

function mathv.subToA4(x, y)
    x.x = x.x - y.x
    x.y = x.y - y.y
    x.z = x.z - y.z
    x.w = x.w - y.w
    return x
end

function mathv.mulToA2(x, y)
    x.x = x.x * y.x
    x.y = x.y * y.y
    return x
end

function mathv.mulToA3(x, y)
    x.x = x.x * y.x
    x.y = x.y * y.y
    x.z = x.z * y.z
    return x
end

function mathv.mulToA4(x, y)
    x.x = x.x * y.x
    x.y = x.y * y.y
    x.z = x.z * y.z
    x.w = x.w * y.w
    return x
end

function mathv.divToA2(x, y)
    x.x = x.x / y.x
    x.y = x.y / y.y
    return x
end

function mathv.divToA3(x, y)
    x.x = x.x / y.x
    x.y = x.y / y.y
    x.z = x.z / y.z
    return x
end

function mathv.divToA4(x, y)
    x.x = x.x / y.x
    x.y = x.y / y.y
    x.z = x.z / y.z
    x.w = x.w / y.w
    return x
end

function mathv.modToA2(x, y)
    x.x = x.x % y.x
    x.y = x.y % y.y
    return x
end

function mathv.modToA3(x, y)
    x.x = x.x % y.x
    x.y = x.y % y.y
    x.z = x.z % y.z
    return x
end

function mathv.modToA4(x, y)
    x.x = x.x % y.x
    x.y = x.y % y.y
    x.z = x.z % y.z
    x.w = x.w % y.w
    return x
end

function mathv.powToA2(x, y)
    x.x = x.x ^ y.x
    x.y = x.y ^ y.y
    return x
end

function mathv.powToA3(x, y)
    x.x = x.x ^ y.x
    x.y = x.y ^ y.y
    x.z = x.z ^ y.z
    return x
end

function mathv.powToA4(x, y)
    x.x = x.x ^ y.x
    x.y = x.y ^ y.y
    x.z = x.z ^ y.z
    x.w = x.w ^ y.w
    return x
end

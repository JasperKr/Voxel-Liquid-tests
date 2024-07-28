---@diagnostic disable: return-type-mismatch
local ffi = require("ffi")

ffi.cdef [[
    typedef struct {
        float x, y, z, w;
    } Rquaternion;
]]

local quaternionMetatable = {}
---@class quaternion
---@field x number
---@field y number
---@field z number
---@field w number
local quaternionFunctions = {}

local quaternionPool = {}

quaternionFunctions.pool = quaternionPool
local n = { 2, 3, 1 }
--- returns a quaternion [x,y,z,w]
---@param x? number
---@param y? number
---@param z? number
---@param w? number
---@return quaternion quat
function quaternion(x, y, z, w)
    if #quaternionPool == 0 then
        if not y and type(x) == "cdata" then
            x, y, z, w = x.x, x.y, x.z, x.w
        elseif type(x) == "table" then
            x, y, z, w = x[1], x[2], x[3], x[4]
        end
        return ffi.new("Rquaternion", x or 0, y or 0, z or 0, w or 1)
    else
        local quat = table.remove(quaternionPool)
        if not y and type(x) == "cdata" then
            quat.x, quat.y, quat.z, quat.w = x.x, x.y, x.z, x.w
        elseif type(x) == "table" then
            quat.x, quat.y, quat.z, quat.w = x[1], x[2], x[3], x[4]
        else
            quat.x, quat.y, quat.z, quat.w = x or 0, y or 0, z or 0, w or 1
        end
        return quat
    end
end

local function MatrixToQuaternion(rot)
    local quat = quaternion()
    local trace = rot.x.x + rot.y.y + rot.z.z

    if trace > 0 then
        local s = math.sqrt(trace + 1)
        quat.w = 0.5 * s
        s = 0.5 / s
        quat.x = (rot.y.z - rot.z.y) * s
        quat.y = (rot.z.x - rot.x.z) * s
        quat.z = (rot.x.y - rot.y.x) * s
        quat = quat:normalize()
    else
        local i = 1
        local q = { 0, 0, 0 }

        if rot.y.y > rot.x.x then
            i = 2
        end
        if rot.z.z > rot[i][i] then
            i = 3
        end

        local j = n[i]
        local k = n[j]

        local t = rot[i][i] - rot[j][j] - rot[k][k] + 1
        local s = 0.5 / math.sqrt(t)
        q[i] = s * t
        local w = (rot[k][j] - rot[j][k]) * s
        q[j] = (rot[j][i] + rot[i][j]) * s
        q[k] = (rot[k][i] + rot[i][k]) * s

        quat:set(q.x, q.y, q.z, w)
        quat:normalize()
    end
    return quat
end
---@return quaternion quat
local function EulerToQuaternion(pitch, yaw, roll)
    if type(pitch) == "cdata" then
        yaw = pitch.y
        roll = pitch.z
        pitch = pitch.x
    end
    pitch = pitch * 0.5
    yaw = yaw * 0.5
    roll = roll * 0.5

    local sinX = math.sin(pitch)
    local cosX = math.cos(pitch)
    local sinY = math.sin(yaw)
    local cosY = math.cos(yaw)
    local sinZ = math.sin(roll)
    local cosZ = math.cos(roll)

    return quaternion(
        cosY * sinX * cosZ + sinY * cosX * sinZ,
        sinY * cosX * cosZ - cosY * sinX * sinZ,
        cosY * cosX * sinZ - sinY * sinX * cosZ,
        cosY * cosX * cosZ + sinY * sinX * sinZ
    )
end
local function QuaternionToEuler(quat)
    local case = 1
    local q = quaternion(-quat.x, quat.y, -quat.z, -quat.w)
    local function threeaxisrot(r11, r12, r21, r31, r32)
        return math.atan2(r31, r32), -math.asin(r21), math.atan2(r11, r12)
    end

    if case == "zyx" or case == 1 then
        return threeaxisrot(2 * (q.x * q.y + q.w * q.z),
            q.w * q.w + q.x * q.x - q.y * q.y - q.z * q.z,
            -2 * (q.x * q.z - q.w * q.y),
            2 * (q.y * q.z + q.w * q.x),
            q.w * q.w - q.x * q.x - q.y * q.y + q.z * q.z
        )
    end
    if case == "zxy" or case == 2 then
        return threeaxisrot(-2 * (q.x * q.y - q.w * q.z),
            q.w * q.w - q.x * q.x + q.y * q.y - q.z * q.z,
            2 * (q.y * q.z + q.w * q.x),
            -2 * (q.x * q.z - q.w * q.y),
            q.w * q.w - q.x * q.x - q.y * q.y + q.z * q.z
        )
    end
    if case == "yxz" or case == 3 then
        return threeaxisrot(2 * (q.x * q.z + q.w * q.y),
            q.w * q.w - q.x * q.x - q.y * q.y + q.z * q.z,
            -2 * (q.y * q.z - q.w * q.x),
            2 * (q.x * q.y + q.w * q.z),
            q.w * q.w - q.x * q.x + q.y * q.y - q.z * q.z
        )
    end
    if case == "yzx" or case == 4 then
        return threeaxisrot(-2 * (q.x * q.z - q.w * q.y),
            q.w * q.w + q.x * q.x - q.y * q.y - q.z * q.z,
            2 * (q.x * q.y + q.w * q.z),
            -2 * (q.y * q.z - q.w * q.x),
            q.w * q.w - q.x * q.x + q.y * q.y - q.z * q.z
        )
    end
    if case == "xyz" or case == 5 then
        return threeaxisrot(-2 * (q.y * q.z - q.w * q.x),
            q.w * q.w - q.x * q.x - q.y * q.y + q.z * q.z,
            2 * (q.x * q.z + q.w * q.y),
            -2 * (q.x * q.y - q.w * q.z),
            q.w * q.w + q.x * q.x - q.y * q.y - q.z * q.z
        )
    end
    if case == "xzy" or case == 6 then
        return threeaxisrot(2 * (q.y * q.z + q.w * q.x),
            q.w * q.w - q.x * q.x + q.y * q.y - q.z * q.z,
            -2 * (q.x * q.y - q.w * q.z),
            2 * (q.x * q.z + q.w * q.y),
            q.w * q.w + q.x * q.x - q.y * q.y - q.z * q.z
        )
    end
end

function quaternionMetatable.__tostring(self) -- thank you to EngineerSmith for this function <3
    return "[" .. self.x .. ", " .. self.y .. ", " .. self.z .. ", " .. self.w .. "]"
end

function quaternionFunctions:conjugate()
    return quaternion(-self.x, -self.y, -self.z, self.w)
end

function quaternionFunctions:invert()
    return quaternion(-self.x, -self.y, -self.z, self.w)
end

---@return quaternion quat
function quaternionFunctions:normalize()
    local t = self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
    if t == 0 then
        return quaternion(
            0,
            0,
            0,
            1
        )
    end
    local invLength = 1 / math.sqrt(t)
    return quaternion(
        self.x * invLength,
        self.y * invLength,
        self.z * invLength,
        self.w * invLength
    )
end

function quaternionFunctions:set(x, y, z, w)
    if not y then
        self.x, self.y, self.z, self.w = x.x or x.x, x.y or x.y, x.z or x.z, x.w or x.w
    else
        self.x, self.y, self.z, self.w = x, y, z, w
    end
end

---@return quaternion quat
function quaternionFunctions:cross(y)
    return quaternion(self.y * y.z - y.y * self.z, self.z * y.x - y.z * self.x, self.x * y.y - y.x * self.y)
end

---@return vec3 vec3
function quaternionFunctions:crossVector(y)
    return vec3(self.y * y.z - y.y * self.z, self.z * y.x - y.z * self.x, self.x * y.y - y.x * self.y)
end

---@return vec3 vec3
function quaternionFunctions:crossVectorOut(y, z)
    z:set(self.y * y.z - y.y * self.z, self.z * y.x - y.z * self.x, self.x * y.y - y.x * self.y)
    return z
end

---@return number x
---@return number y
---@return number z
---@return number w
function quaternionFunctions:get()
    return self.x, self.y, self.z, self.w
end

---@return quaternion quat
function quaternionMetatable.__unm(quat)
    return quaternion(-quat.x, -quat.y, -quat.z, quat.w)
    -- / math.sqrt(quat.x * quat.x + quat.y * quat.y + quat.z * quat.z + quat.w * quat.w)
end

quaternionMetatable.__index = quaternionFunctions

---@return quaternion quat
function quaternionMetatable.__add(x, y)
    local v = quaternion()
    if type(x) == "number" then
        v.x = x + y.x
        v.y = x + y.y
        v.z = x + y.z
        v.w = x + y.w
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then
            v.x = x.x + y[1][1]
            v.y = x.y + y[1][2]
            v.z = x.z + y[1][3]
            v.w = x.w + y[1][4]
        else
            v.x = x.x + y.x
            v.y = x.y + y.y
            v.z = x.z + y.z
            v.w = x.w + y.w
        end
    else
        v.x = x.x + y
        v.y = x.y + y
        v.z = x.z + y
        v.w = x.w + y
    end
    return v
end

---@return quaternion quat
function quaternionMetatable.__div(x, y)
    local v = quaternion()
    if type(x) == "number" then -- num / vec
        local z = 1 / x
        v.x = z * y.x
        v.y = z * y.y
        v.z = z * y.z
        v.w = z * y.w
    elseif type(y) == "cdata" then
        if type(y.x) == "cdata" then -- 1x4 matrix
            v.x = x.x / y[1][1]
            v.y = x.y / y[1][2]
            v.z = x.z / y[1][3]
            v.w = x.w / y[1][4]
        else -- vec / vec
            v.x = x.x / y.x
            v.y = x.y / y.y
            v.z = x.z / y.z
            v.w = x.w / y.w
        end
    else -- vec / num
        local z = 1 / y
        v.x = x.x * z
        v.y = x.y * z
        v.z = x.z * z
        v.w = x.w * z
    end
    return v
end

function quaternionFunctions:print()
    print("[" .. self.x .. ", " .. self.y .. ", " .. self.z .. ", " .. self.w .. "]")
end

quaternionFunctions.type = "quaternion"
---@return quaternion quat
function quaternionMetatable.__mul(x, y)
    if not x then
        error("1 " .. tostring(x) .. " attempt to perform arithmetic on nil number")
    elseif not y then
        error("2 " .. tostring(y) .. " attempt to perform arithmetic on nil number")
    end
    if type(x) == "cdata" then
        if type(y) == "cdata" then
            local x1, y1, z1, w1 = x.x, x.y, x.z, x.w
            local x2, y2, z2, w2 = y.x, y.y, y.z, y.w
            return quaternion(
                w1 * x2 + x1 * w2 - y1 * z2 + z1 * y2, --x
                w1 * y2 + x1 * z2 + y1 * w2 - z1 * x2, --y
                w1 * z2 - x1 * y2 + y1 * x2 + z1 * w2, --z
                w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2  --w
            )
        else
            return quaternion(
                x.x * y,
                x.y * y,
                x.z * y,
                x.w * y
            )
        end
    else
        if type(y) == "cdata" then
            return quaternion(
                y.x * x,
                y.y * x,
                y.z * x,
                y.w * x
            )
        else
            -- will never ever get returned since there has to be a quaternion type value to call this function
            -- but the lua language server is being annoying
            return quaternion()
        end
    end
end

---@return quaternion quat
function quaternionFunctions:integrate(quat)
    local v = self * quat
    return (self + v * 0.5):normalize()
end

function quaternionFunctions:quatMul(quat)
    error("quatMul is deprecated, use * instead")
end

---@return quaternion quat
function quaternionFunctions:copy()
    return quaternion(self.x, self.y, self.z, self.w)
end

function quaternionFunctions:table()
    return { self.x, self.y, self.z, self.w }
end

local tempTable = {}

--- returns the quaternion as a temporary table
---@return quaternion quat
function quaternionFunctions:ttable()
    tempTable[1] = self.x
    tempTable[2] = self.y
    tempTable[3] = self.z
    tempTable[4] = self.w
    return tempTable
end

function quaternionFunctions:release()
    table.insert(quaternionPool, self)
    return self
end

quaternionFunctions.CType = ffi.typeof("Rquaternion")

ffi.metatype("Rquaternion", quaternionMetatable)

--- math for quaternions
mathq = {}

function mathq.add(x, y, out)
    out.x = x.x + y.x
    out.y = x.y + y.y
    out.z = x.z + y.z
    out.w = x.w + y.w
    return out
end

function mathq.sub(x, y, out)
    out.x = x.x - y.x
    out.y = x.y - y.y
    out.z = x.z - y.z
    out.w = x.w - y.w
    return out
end

function mathq.mul(x, y, out)
    local x1, y1, z1, w1 = x.x, x.y, x.z, x.w
    local x2, y2, z2, w2 = y.x, y.y, y.z, y.w
    out.x = w1 * x2 + x1 * w2 - y1 * z2 + z1 * y2
    out.y = w1 * y2 + x1 * z2 + y1 * w2 - z1 * x2
    out.z = w1 * z2 - x1 * y2 + y1 * x2 + z1 * w2
    out.w = w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2
    return out
end

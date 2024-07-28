PI2 = math.pi * 2
IPI2 = 1 / PI2
IPI = 1 / math.pi
PI05 = math.pi * 0.5
IPI05 = 1 / PI05

function Renderer.math.clamp(v, min, max)
    return math.min(math.max(v, min), max)
end

function Renderer.math.round(x, i)
    i = i or 0
    i = 10 ^ i
    return math.floor(x * i + 0.5) / i
end

function Renderer.math.saturate(x)
    return math.min(math.max(x, 0.0), 1.0)
end

--- creates vertices for a box
---@param w number
---@param h number
---@param d number
---@param x? number
---@param y? number
---@param z? number
---@return table
function Renderer.internal.boxVerticesFromSize(w, h, d, x, y, z, vertices)
    x = x or 0
    y = y or 0
    z = z or 0
    local verts = {
        { 1,  1,  -1 },
        { 1,  -1, -1 },
        { 1,  1,  1 },
        { 1,  -1, 1 },
        { -1, 1,  -1 },
        { -1, -1, -1 },
        { -1, 1,  1 },
        { -1, -1, 1 } }
    local faceInfo = {
        { 0.625, 0.5 },
        { 0.375, 0.5 },
        { 0.625, 0.75 },
        { 0.375, 0.75 },
        { 0.875, 0.5 },
        { 0.625, 0.25 },
        { 0.125, 0.5 },
        { 0.375, 0.25 },
        { 0.875, 0.75 },
        { 0.625, 1 },
        { 0.625, 0 },
        { 0.375, 0 },
        { 0.375, 1 },
        { 0.125, 0.75 } }

    local triangles = {
        { { 5, 5, 1 },  { 3, 3, 1 },  { 1, 1, 1 } },
        { { 3, 3, 2 },  { 8, 13, 2 }, { 4, 4, 2 } },
        { { 7, 11, 3 }, { 6, 8, 3 },  { 8, 12, 3 } },
        { { 2, 2, 4 },  { 8, 14, 4 }, { 6, 7, 4 } },
        { { 1, 1, 5 },  { 4, 4, 5 },  { 2, 2, 5 } },
        { { 5, 6, 6 },  { 2, 2, 6 },  { 6, 8, 6 } },
        { { 5, 5, 1 },  { 7, 9, 1 },  { 3, 3, 1 } },
        { { 3, 3, 2 },  { 7, 10, 2 }, { 8, 13, 2 } },
        { { 7, 11, 3 }, { 5, 6, 3 },  { 6, 8, 3 } },
        { { 2, 2, 4 },  { 4, 4, 4 },  { 8, 14, 4 } },
        { { 1, 1, 5 },  { 3, 3, 5 },  { 4, 4, 5 } },
        { { 5, 6, 6 },  { 1, 1, 6 },  { 2, 2, 6 } },
    }

    vertices = vertices or {}
    for i, v in ipairs(triangles) do
        local i1, i2, i3 = v[1], v[2], v[3]
        local pos1, pos2, pos3 = verts[i1[1]], verts[i2[1]], verts[i3[1]]
        local nx, ny, nz = Renderer.math.triangleNormal(pos1, pos2, pos3)
        for j = 1, 3 do
            local vert = v[j]
            local pos = verts[vert[1]]
            local info = faceInfo[vert[2]]
            table.insert(vertices,
                { pos[1] * w * 0.5 + x, pos[2] * h * 0.5 + y, pos[3] * d * 0.5 + z, info[1], info[2], nx, ny, nz })
        end
    end
    return vertices
end

function Renderer.internal.aabb(aMinX, aMinY, aMinZ, aMaxX, aMaxY, aMaxZ, bMinX, bMinY, bMinZ, bMaxX, bMaxY, bMaxZ)
    local x_condition = (aMinX - bMaxX) * (bMinX - aMaxX)
    local y_condition = (aMaxY - bMinY) * (bMaxY - aMinY)
    local z_condition = (aMaxZ - bMinZ) * (bMaxZ - aMinZ)
    return math.min(x_condition, y_condition, z_condition) > 0
end

local function printTableInternal(t, floor, names, loopedTables)
    io.write(("  "):rep(#names) .. (names[#names] and names[#names] .. ": " or "") .. "{\n")
    for i, v in pairs(t) do
        if type(v) == "table" then
            if loopedTables[v] then
                io.write(("  "):rep(#names + 1) .. i .. " = Reference to " .. loopedTables[v] .. "\n")
                goto continue
            end
            if v == t or v == _G then
                io.write(("  "):rep(#names + 1) .. i .. " = Reference to self\n")
                goto continue
            end
            if not next(v) then
                io.write(("  "):rep(#names + 1) .. i .. " = {}\n")
                goto continue
            end
            table.insert(names, i)
            loopedTables[v] = table.concat(names, ".")
            printTableInternal(v, floor, names, loopedTables)
            table.remove(names, #names)
        else
            if floor then
                if type(v) == "number" then
                    io.write(("  "):rep(#names + 1) .. i .. " = " .. Renderer.math.round(v) .. "\n")
                else
                    io.write(("  "):rep(#names + 1) .. i .. " = " .. v .. "\n")
                end
            else
                io.write(("  "):rep(#names + 1) .. tostring(i) .. " = " .. tostring(v) .. "\n")
            end
        end
        ::continue::
    end
    io.write(("  "):rep(#names) .. "}\n")
end

local function toTableVal(x)
    if type(x) == "string" then
        return "\"" .. x .. "\""
    else
        return tostring(x)
    end
end

local function TableToStringInternal(t, finalString, names, loopedTables)
    finalString = finalString ..
        ("  "):rep(#names) .. (names[#names] and "[" .. toTableVal(names[#names]) .. "] = " or "") .. "{\n"
    for i, v in pairs(t) do
        if type(v) == "table" then
            if loopedTables[v] then
                finalString = finalString ..
                    ("  "):rep(#names + 1) .. "[" .. toTableVal(i) .. "] = \"Reference to " .. loopedTables[v] .. "\"\n"
                goto continue
            end
            if v == t or v == _G then
                finalString = finalString ..
                    ("  "):rep(#names + 1) .. "[" .. toTableVal(i) .. "] = \"Reference to self\"\n"
                goto continue
            end
            if not next(v) then
                finalString = finalString .. ("  "):rep(#names + 1) .. "[" .. toTableVal(i) .. "] = {}\n"
                goto continue
            end
            table.insert(names, i)
            loopedTables[v] = table.concat(names, ".")
            finalString = TableToStringInternal(v, finalString, names, loopedTables)
            table.remove(names, #names)
        else
            if type(v) == "userdata" or type(v) == "function" or type(v) == "thread" then
                finalString = finalString .. ("  "):rep(#names + 1) .. i .. " = \"" .. type(v) .. "\"\n"
            elseif type(i) == "string" then
                finalString = finalString .. ("  "):rep(#names + 1) .. i .. " = " .. toTableVal(v) .. "\n"
            else
                finalString = finalString ..
                    ("  "):rep(#names + 1) .. "[" .. toTableVal(i) .. "] = " .. toTableVal(v) .. "\n"
            end
        end
        ::continue::
    end
    finalString = finalString .. ("  "):rep(#names) .. "}\n"
    return finalString
end

function Renderer.internal.tableToString(t)
    local names = {}
    if type(t) == "table" then
        return TableToStringInternal(t, "", names, {})
    else
        return tostring(t)
    end
end

function Renderer.internal.printTable(t, floor)
    local names = {}
    if type(t) == "table" then
        printTableInternal(t, floor, names, {})
    else
        io.write(tostring(t) .. "\n")
    end
end

function Renderer.internal.copyTable(t)
    if type(t) == "table" then
        local t2 = {}
        for i, v in pairs(t) do
            if type(v) == "table" then
                t2[i] = Renderer.internal.copyTable(v)
            else
                t2[i] = v
            end
        end
        return t2
    else
        return t
    end
end

function Renderer.math.sign(number)
    return (number > 0 and 1 or (number == 0 and 0 or -1))
end

--[[
    // compute normal
    vec3 capNormal( in vec3 pos, in vec3 a, in vec3 b, in float r )
    {
        vec3  ba = b - a;
        vec3  pa = pos - a;
        float h = clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
        return (pa - h*ba)/r;
    }
]]


--- returns the normal of a capsule at a point
---@param x number
---@param y number
---@param z number
---@param aX number
---@param aY number
---@param aZ number
---@param bX number
---@param bY number
---@param bZ number
---@return number
---@return number
---@return number
function Renderer.math.capsuleNormal(x, y, z, aX, aY, aZ, bX, bY, bZ)
    local baX, baY, baZ = bX - aX, bY - aY, bZ - aZ
    local paX, paY, paZ = x - aX, y - aY, z - aZ
    local h = Renderer.math.clamp(
        Renderer.math.dot(baX, baY, baZ, paX, paY, paZ) / Renderer.math.dot(baX, baY, baZ, baX, baY, baZ), 0.0,
        1.0)
    return Renderer.math.normalize3(paX - h * baX, paY - h * baY, paZ - h * baZ)
end

function Renderer.math.calculateSphereTangent(nx, ny, nz)
    -- Check if the normal is parallel to the up vector
    local tx, ty, tz = Renderer.math.cross(nx, ny, nz, 0, 1, 0)
    if tx * tx + ty * ty + tz * tz < 1e-5 then
        return 1, 0, 0
    else
        return Renderer.math.normalize3(tx, ty, tz)
    end
end

do
    local PI2 = math.pi * 2
    local vertices = {}
    function Renderer.math.uvSphere(radius, segments)
        table.clear(vertices)
        -- precalculate pi * segments and pi / segments
        local piInverseSegments = PI2 / segments
        local halfInverseSegments = math.pi / segments

        -- cos(0) = 1, sin(0) = 0
        local cosR, sinR = 1, 0
        -- redefine the stack variables to be local, this is faster
        -- inverse pi, inverse pi * 2, pi * 0.5
        for r = 0, PI2, piInverseSegments do
            local r2 = r + piInverseSegments
            --math.cos(-PI05) * radius = -1 * radius = -radius, math.sin(PI05) * radius = 0 * radius = 0
            local cosA = math.cos(-PI05)
            local sinA = math.sin(-PI05)
            -- calculate cos(r) and sin(r) for the next iteration
            local cosR2 = math.cos(r2)
            local sinR2 = math.sin(r2)
            for a = -PI05, PI05 - halfInverseSegments, halfInverseSegments do
                local a2 = a + halfInverseSegments

                local cosA2 = math.cos(a2)
                local sinA2 = math.sin(a2)

                table.insert(vertices, {
                    cosR * cosA, -- 0,1
                    sinA,
                    sinR * cosA,
                    r * IPI2,
                    a + PI05 * IPI + 0.5
                })
                table.insert(vertices, {
                    cosR * cosA2, -- 0,0
                    sinA2,
                    sinR * cosA2,
                    r * IPI2,
                    a2 + PI05 * IPI + 0.5
                })
                table.insert(vertices, {
                    cosR2 * cosA, -- 1,1
                    sinA,
                    sinR2 * cosA,
                    r2 * IPI2,
                    a + PI05 * IPI + 0.5
                })

                table.insert(vertices, {
                    cosR * cosA2,
                    sinA2,
                    sinR * cosA2,
                    r * IPI2,
                    a2 + PI05 * IPI + 0.5
                })
                table.insert(vertices, {
                    cosR2 * cosA2,
                    sinA2,
                    sinR2 * cosA2,
                    r2 * IPI2,
                    a2 + PI05 * IPI + 0.5
                })
                table.insert(vertices, {
                    cosR2 * cosA,
                    sinA,
                    sinR2 * cosA,
                    r2 * IPI2,
                    a + PI05 * IPI + 0.5
                })
                -- since cosA2 = cosA + piInverseSegments and we loop to the next iteration we can just set cosA to cosA2
                cosA = cosA2
                sinA = sinA2
            end
            cosR = cosR2
            sinR = sinR2
        end
        local ffiVertices = Renderer.internal.newVertexArray(#vertices)
        local ffiIndices, type = Renderer.internal.newIndexArray(#vertices)
        for i, vertex in ipairs(vertices) do
            local tx, ty, tz = Renderer.math.calculateSphereTangent(vertex[1], vertex[2], vertex[3])
            ffiVertices[i - 1] = Renderer.internal.newVertex(
                vertex[1] * radius, vertex[2] * radius, vertex[3] * radius, -- x, y, z
                vertex[4], vertex[5],                                       -- u, v
                vertex[1], vertex[2], vertex[3],                            -- nx, ny, nz (already normalized)
                tx, ty, tz                                                  -- tx, ty, tz
            )
            ffiIndices[i - 1] = i - 1
        end
        return ffiVertices, ffiIndices, type
    end
end

function Renderer.internal.newID(i)
    i = i or "Global"
    Renderer.internal.idCounters[i] = (Renderer.internal.idCounters[i] or 0) + 1
    return Renderer.internal.idCounters[i] - 1
end

--- mix between two values
---@param i number
---@param v number
---@param w number
---@return number
function Renderer.math.mix(i, v, w)
    return (1 - i) * v + i * w
end

function Renderer.math.cross(x1, y1, z1, x2, y2, z2)
    return y1 * z2 - z1 * y2, z1 * x2 - x1 * z2, x1 * y2 - y1 * x2
end

function Renderer.math.dot(x1, y1, z1, x2, y2, z2)
    return x1 * x2 + y1 * y2 + z1 * z2
end

function Renderer.math.dot2(x1, y1, x2, y2)
    return x1 * x2 + y1 * y2
end

function Renderer.math.dot3(x1, y1, z1, x2, y2, z2)
    return x1 * x2 + y1 * y2 + z1 * z2
end

function Renderer.math.dot4(x1, y1, z1, w1, x2, y2, z2, w2)
    return x1 * x2 + y1 * y2 + z1 * z2 + w1 * w2
end

function Renderer.math.lerp(angle, target, turnrate)
    local dist = target - angle
    dist = (dist + math.pi) % PI2 - math.pi
    local step = turnrate * love.timer.getDelta()
    if math.abs(dist) <= step then
        angle = target
    else
        if dist < 0 then
            step = -step
        end
        angle = angle + step
    end
    return angle
end

function Renderer.math.smoothLerp(angle, target, turnrate)
    local dist = target - angle
    dist = (dist + math.pi) % (math.pi * 2) - math.pi
    local step = turnrate * love.timer.getDelta()
    return angle + step * dist
end

function Renderer.math.pointAABBDistance(min, max, position)
    local q = vec3(math.max(0, math.max(min.x - position.x, position.x - max.x)),
        math.max(0, math.max(min.y - position.y, position.y - max.y)),
        math.max(0, math.max(min.z - position.z, position.z - max.z)))

    local outsideDist = q:length()

    local isInside = position.x >= min.x and position.x <= max.x and position.y >= min.y and position.y <= max.y and
        position.z >= min.z and position.z <= max.z

    if isInside then
        return 0
    else
        return outsideDist
    end
end

function Renderer.math.signedPointAABBDistance(min, max, position)
    local q = vec3(math.max(0, math.max(min.x - position.x, position.x - max.x)),
        math.max(0, math.max(min.y - position.y, position.y - max.y)),
        math.max(0, math.max(min.z - position.z, position.z - max.z)))

    local outsideDist = q:length()

    local isInside = position.x >= min.x and position.x <= max.x and position.y >= min.y and position.y <= max.y and
        position.z >= min.z and position.z <= max.z

    if isInside then
        local distToMin = position - min
        local distToMax = max - position
        local insideDist = math.min(math.min(distToMin.x, distToMax.x), math.min(math.min(distToMin.y, distToMax.y),
            math.min(distToMin.z, distToMax.z)))
        return -insideDist
    else
        return outsideDist
    end
end

function Renderer.math.pointAABBDistanceSqr(min, max, position)
    local q = vec3(math.max(0, math.max(min.x - position.x, position.x - max.x)),
        math.max(0, math.max(min.y - position.y, position.y - max.y)),
        math.max(0, math.max(min.z - position.z, position.z - max.z)))

    local outsideDist = q:lengthSqr()

    local isInside = position.x >= min.x and position.x <= max.x and position.y >= min.y and position.y <= max.y and
        position.z >= min.z and position.z <= max.z

    if isInside then
        return 0
    else
        return outsideDist
    end
end

function Renderer.math.signedPointAABBDistanceSqr(min, max, position)
    local q = vec3(math.max(0, math.max(min.x - position.x, position.x - max.x)),
        math.max(0, math.max(min.y - position.y, position.y - max.y)),
        math.max(0, math.max(min.z - position.z, position.z - max.z)))

    local outsideDist = q:lengthSqr()

    local isInside = position.x >= min.x and position.x <= max.x and position.y >= min.y and position.y <= max.y and
        position.z >= min.z and position.z <= max.z

    if isInside then
        local distToMin = position - min
        local distToMax = max - position
        local insideDist = math.min(math.min(distToMin.x, distToMax.x), math.min(math.min(distToMin.y, distToMax.y),
            math.min(distToMin.z, distToMax.z)))
        return -insideDist * insideDist
    else
        return outsideDist
    end
end

function Renderer.math.pointAABBDistanceSqrSeperate(minX, minY, minZ, maxX, maxY, maxZ, x, y, z)
    local qx = math.max(0, math.max(minX - x, x - maxX))
    local qy = math.max(0, math.max(minY - y, y - maxY))
    local qz = math.max(0, math.max(minZ - z, z - maxZ))

    local outsideDist = qx * qx + qy * qy + qz * qz

    local isInside = x >= minX and x <= maxX and y >= minY and y <= maxY and z >= minZ and z <= maxZ

    if isInside then
        local distToMinX = x - minX
        local distToMinY = y - minY
        local distToMinZ = z - minZ

        local distToMaxX = maxX - x
        local distToMaxY = maxY - y
        local distToMaxZ = maxZ - z

        local insideDist = math.min(math.min(distToMinX, distToMaxX), math.min(math.min(distToMinY, distToMaxY),
            math.min(distToMinZ, distToMaxZ)))

        return -insideDist * insideDist
    else
        return outsideDist
    end
end

function Renderer.math.pointAABBDistanceSqrCentered(boxCenter, scale, position)
    local d = 0
    if position.x < boxCenter.x - scale.x then
        d = d + (position.x - (boxCenter.x - scale.x)) ^ 2
    elseif position.x > boxCenter.x + scale.x then
        d = d + (position.x - (boxCenter.x + scale.x)) ^ 2
    end
    if position.y < boxCenter.y - scale.y then
        d = d + (position.y - (boxCenter.y - scale.y)) ^ 2
    elseif position.y > boxCenter.y + scale.y then
        d = d + (position.y - (boxCenter.y + scale.y)) ^ 2
    end
    if position.z < boxCenter.z - scale.z then
        d = d + (position.z - (boxCenter.z - scale.z)) ^ 2
    elseif position.z > boxCenter.z + scale.z then
        d = d + (position.z - (boxCenter.z + scale.z)) ^ 2
    end
    return d
end

--- switch between functions, select with i
---@param i number
---@param ... function
function Renderer.math.switch(i, ...)
    local t = { ... }
    t[i]()
end

function Renderer.math.point_line_distance(p, v1, v2)
    local AB = v2 - v1
    return (AB:cross(p - v1)):length() / AB:length()
end

do -- define rotation conversions
    -- Other to matrix:

    ---@return matrix4x4 m
    function Renderer.math.eulerToMatrix(pitch, yaw, roll)
        -- this function assumes pitch is about the z-axis rather than the x-axis (??)
        -- so i swapped pitch and roll
        local ch = math.cos(yaw)
        local sh = math.sin(yaw)
        local ca = math.cos(roll)
        local sa = math.sin(roll)
        local cb = math.cos(pitch)
        local sb = math.sin(pitch)

        local m = mat4()
        m[1][1] = ch * ca
        m[1][2] = sh * sb - ch * sa * cb
        m[1][3] = ch * sa * sb + sh * cb
        m[2][1] = sa
        m[2][2] = ca * cb
        m[2][3] = -ca * sb
        m[3][1] = -sh * ca
        m[3][2] = sh * sa * cb + ch * sb
        m[3][3] = -sh * sa * sb + ch * cb

        return m
    end

    ---@return matrix4x4 m
    function Renderer.math.quaternionToMatrix(q)
        local m = mat4()
        m[1][1] = (q.x * q.x - q.y * q.y - q.z * q.z + q.w * q.w)
        m[2][2] = (-q.x * q.x + q.y * q.y - q.z * q.z + q.w * q.w)
        m[3][3] = (-q.x * q.x - q.y * q.y + q.z * q.z + q.w * q.w)

        m[2][1] = 2.0 * (q.x * q.y + q.z * q.w)
        m[1][2] = 2.0 * (q.x * q.y - q.z * q.w)

        m[3][1] = 2.0 * (q.x * q.z - q.y * q.w)
        m[1][3] = 2.0 * (q.x * q.z + q.y * q.w)
        m[3][2] = 2.0 * (q.y * q.z + q.x * q.w)
        m[2][3] = 2.0 * (q.y * q.z - q.x * q.w)

        return m
    end

    -- Other to Quaternion:

    ---@return quaternion quat
    function Renderer.math.eulerToQuaternion(pitch, yaw, roll)
        if type(pitch) == "table" or not pitch or not yaw or not roll then
            error("Renderer.math.eulerToQuaternion: invalid input")
        end
        pitch = pitch * 0.5
        yaw = yaw * 0.5
        roll = roll * 0.5

        local c1 = math.cos(yaw)
        local s1 = math.sin(yaw)

        local c2 = math.cos(roll)
        local s2 = math.sin(roll)

        local c3 = math.cos(pitch)
        local s3 = math.sin(pitch)

        local c1c2 = c1 * c2
        local s1s2 = s1 * s2
        local w = c1c2 * c3 - s1s2 * s3
        local x = c1c2 * s3 + s1s2 * c3
        local y = s1 * c2 * c3 + c1 * s2 * s3
        local z = c1 * s2 * c3 - s1 * c2 * s3
        return quaternion(x, y, z, w)
    end

    ---@return quaternion quat
    function Renderer.math.matrixToQuaternion(m)
        local a = m:transpose()
        local trace = a[1][1] + a[2][2] + a[3][3]
        local q = quaternion()

        if trace > 0 then
            local s = 0.5 / math.sqrt(trace + 1.0)
            q.w = 0.25 / s
            q.x = (a[3][2] - a[2][3]) * s
            q.y = (a[1][3] - a[3][1]) * s
            q.z = (a[2][1] - a[1][2]) * s
        elseif a[1][1] > a[2][2] and a[1][1] > a[3][3] then
            local s = 2.0 * math.sqrt(1.0 + a[1][1] - a[2][2] - a[3][3])
            q.w = (a[3][2] - a[2][3]) / s
            q.x = 0.25 * s
            q.y = (a[1][2] + a[2][1]) / s
            q.z = (a[1][3] + a[3][1]) / s
        elseif a[2][2] > a[3][3] then
            local s = 2.0 * math.sqrt(1.0 + a[2][2] - a[1][1] - a[3][3])
            q.w = (a[1][3] - a[3][1]) / s
            q.x = (a[1][2] + a[2][1]) / s
            q.y = 0.25 * s
            q.z = (a[2][3] + a[3][2]) / s
        else
            local s = 2.0 * math.sqrt(1.0 + a[3][3] - a[1][1] - a[2][2])
            q.w = (a[2][1] - a[1][2]) / s
            q.x = (a[1][3] + a[3][1]) / s
            q.y = (a[2][3] + a[3][2]) / s
            q.z = 0.25 * s
        end

        return q
    end

    -- Other to euler:

    ---@return number pitch
    ---@return number yaw
    ---@return number roll
    function Renderer.math.quaternionToEuler(q)
        local sqw = q.w * q.w
        local sqx = q.x * q.x
        local sqy = q.y * q.y
        local sqz = q.z * q.z
        local unit = sqx + sqy + sqz + sqw -- if normalised is one, otherwise is correction factor
        local test = q.x * q.y + q.z * q.w
        if (test > 0.4999 * unit) then     -- singularity at north pole
            heading = 2 * math.atan2(q.x, q.w)
            attitude = math.pi / 2
            bank = 0
            return bank, heading, attitude
        end
        if (test < -0.4999 * unit) then -- singularity at south pole
            heading = -2 * math.atan2(q.x, q.w)
            attitude = -math.pi / 2
            bank = 0
            return bank, heading, attitude
        end
        heading = math.atan2(2 * q.y * q.w - 2 * q.x * q.z, sqx - sqy - sqz + sqw)
        attitude = math.asin(2 * test / unit)
        bank = math.atan2(2 * q.x * q.w - 2 * q.y * q.z, -sqx + sqy - sqz + sqw)

        -- this function assumes pitch is about the z-axis rather than the x-axis (??)
        return bank, heading, attitude
    end

    ---@return number pitch
    ---@return number yaw
    ---@return number roll
    function Renderer.math.matrixToEuler(m)
        -- Assuming the angles are in radians.
        local heading, attitude, bank
        if m[2][1] > 0.998 then -- singularity at north pole
            heading = math.atan2(m[1][3], m[3][3])
            attitude = math.pi / 2
            bank = 0
        elseif m[2][1] < -0.998 then -- singularity at south pole
            heading = math.atan2(m[1][3], m[3][3])
            attitude = -math.pi / 2
            bank = 0
        else
            heading = math.atan2(-m[3][1], m[1][1])
            bank = math.atan2(-m[2][3], m[2][2])
            attitude = math.asin(m[2][1])
        end

        -- this function assumes pitch is about the z-axis rather than the x-axis (??)
        return bank, heading, attitude
    end
end

--- creates a new translation matrix
---@param position vec3
---@return matrix4x4
function Renderer.math.newTranslationMatrix(position)
    local m = mat4()
    m[4][1] = position.x
    m[4][2] = position.y
    m[4][3] = position.z
    return m
end

local vertices = {
    { -1, -1, -1 },
    { 1,  -1, -1 },
    { 1,  1,  -1 },
    { -1, 1,  -1 },
    { -1, -1, 1 },
    { 1,  -1, 1 },
    { 1,  1,  1 },
    { -1, 1,  1 }
}

---comment
---@param inverseViewProjectionMatrix matrix4x4
---@return table
function Renderer.math.frustumCornerPoints(inverseViewProjectionMatrix)
    local points = {}

    for i, v in ipairs(vertices) do
        points[i] = { inverseViewProjectionMatrix:vMulSepW1(unpack(v)) }

        points[i][1] = points[i][1] / points[i][4]
        points[i][2] = points[i][2] / points[i][4]
        points[i][3] = points[i][3] / points[i][4]
    end

    return points
end

---@param matrix matrix4x4
---@return table
function Renderer.math.frustumFromMatrix(matrix)
    local frustum = {}

    frustum[1] = vec4(
        matrix[1][4] + matrix[1][1],
        matrix[2][4] + matrix[2][1],
        matrix[3][4] + matrix[3][1],
        matrix[4][4] + matrix[4][1]
    )

    frustum[2] = vec4(
        matrix[1][4] - matrix[1][1],
        matrix[2][4] - matrix[2][1],
        matrix[3][4] - matrix[3][1],
        matrix[4][4] - matrix[4][1]
    )

    frustum[3] = vec4(
        matrix[1][4] - matrix[1][2],
        matrix[2][4] - matrix[2][2],
        matrix[3][4] - matrix[3][2],
        matrix[4][4] - matrix[4][2]
    )

    frustum[4] = vec4(
        matrix[1][4] + matrix[1][2],
        matrix[2][4] + matrix[2][2],
        matrix[3][4] + matrix[3][2],
        matrix[4][4] + matrix[4][2]
    )

    frustum[5] = vec4(
        matrix[1][4] + matrix[1][3],
        matrix[2][4] + matrix[2][3],
        matrix[3][4] + matrix[3][3],
        matrix[4][4] + matrix[4][3]
    )

    frustum[6] = vec4(
        matrix[1][4] - matrix[1][3],
        matrix[2][4] - matrix[2][3],
        matrix[3][4] - matrix[3][3],
        matrix[4][4] - matrix[4][3]
    )

    return {
        frustum = frustum,
    }
end

function Renderer.math.frustumAABB(fru, x, y, z, x1, y1, z1)
    local dot = Renderer.math.dot
    for i = 1, 6 do
        local frustum = fru.frustum[i]
        local fx, fy, fz, fw = frustum:get()
        if dot(fx, fy, fz, x, y, z) + fw < 0.0
            and dot(fx, fy, fz, x1, y, z) + fw < 0.0
            and dot(fx, fy, fz, x, y1, z) + fw < 0.0
            and dot(fx, fy, fz, x1, y1, z) + fw < 0.0
            and dot(fx, fy, fz, x, y, z1) + fw < 0.0
            and dot(fx, fy, fz, x1, y, z1) + fw < 0.0
            and dot(fx, fy, fz, x, y1, z1) + fw < 0.0
            and dot(fx, fy, fz, x1, y1, z1) + fw < 0.0 then
            return false
        end
    end

    return true
end

function Renderer.math.frustumFrustum(frustumA, frustumB)
    local dot = Renderer.math.dot
    for i = 1, 6 do
        local frustum = frustumA.frustum[i]
        local fx, fy, fz, fw = frustum:get()
        if dot(fx, fy, fz, unpack(frustumB.points[1])) + fw < 0.0
            and dot(fx, fy, fz, unpack(frustumB.points[2])) + fw < 0.0
            and dot(fx, fy, fz, unpack(frustumB.points[3])) + fw < 0.0
            and dot(fx, fy, fz, unpack(frustumB.points[4])) + fw < 0.0
            and dot(fx, fy, fz, unpack(frustumB.points[5])) + fw < 0.0
            and dot(fx, fy, fz, unpack(frustumB.points[6])) + fw < 0.0
            and dot(fx, fy, fz, unpack(frustumB.points[7])) + fw < 0.0
            and dot(fx, fy, fz, unpack(frustumB.points[68])) + fw < 0.0 then
            return false
        end
    end

    return true
end

---returns a ray that goes from the camera position to the x,y position
---@param x number
---@param y number
---@param camera Renderer.camera
---@return table ray length undefined
function Renderer.math.screenPositionToRay(x, y, camera, outRay)
    local vx, vy, vz, vw = camera.inverseProjectionMatrix:vMulSepW1(
        (x / camera.screenSize[1] - 0.5) * 2.0,
        (y / camera.screenSize[2] - 0.5) * 2.0,
        1.0
    )

    vx, vy, vz = vx / vw, vy / vw, vz / vw
    local wx, wy, wz = camera.inverseViewMatrix:vMulSepW1(vx, vy, vz)

    outRay.position:set(camera.position:get())
    outRay.direction:set(Renderer.math.normalize3(wx, wy, wz))

    return outRay
end

function Renderer.math.length(...)
    local val = { ... }
    if type(val[1]) == "table" then
        if val[1][1] == nil then
            local x, y, z, w = val[1].x or 0, val[1].y or 0, val[1].z or 0, val[1].w or 0
            return math.sqrt(x * x + y * y + z * z + w * w)
        else
            local v = 0
            for _, w in ipairs(val[1]) do v = v + w * w end
            return math.sqrt(v)
        end
    else
        local v = 0
        for _, w in ipairs(val) do v = v + w * w end
        return math.sqrt(v)
    end
end

function Renderer.math.length2(x, y)
    return math.sqrt(x * x + y * y)
end

function Renderer.math.length3(x, y, z)
    return math.sqrt(x * x + y * y + z * z)
end

function Renderer.math.length4(x, y, z, w)
    return math.sqrt(x * x + y * y + z * z + w * w)
end

function Renderer.math.crossVector(v1, v2)
    return vec3(v1.y * v2.z - v1.z * v2.y, v1.z * v2.x - v1.x * v2.z, v1.x * v2.y - v1.y * v2.x)
end

function Renderer.math.dotVector(v1, v2)
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
end

--- Rotate a position using a quaternion and vector math
---@param position vec3
---@param quat quaternion
---@return vec3
function Renderer.math.rotatePosition(position, quat)
    local cx = quat.y * position.z - quat.z * position.y + position.x * quat.w
    local cy = quat.z * position.x - quat.x * position.z + position.y * quat.w
    local cz = quat.x * position.y - quat.y * position.x + position.z * quat.w

    return vec3(position.x + 2 * (quat.y * cz - quat.z * cy),
        position.y + 2 * (quat.z * cx - quat.x * cz),
        position.z + 2 * (quat.x * cy - quat.y * cx))
end

--- Rotate a position using normal variables instead of vectors or quaternions
---@param x number -- position x
---@param y number -- position y
---@param z number -- position z
---@param qx number -- quaternion x
---@param qy number -- quaternion y
---@param qz number -- quaternion z
---@param qw number -- quaternion w
---@return number, number, number
function Renderer.math.rotatePositionSeparate(x, y, z, qx, qy, qz, qw)
    local cx = qy * z - qz * y + x * qw
    local cy = qz * x - qx * z + y * qw
    local cz = qx * y - qy * x + z * qw

    return x + 2 * (qy * cz - qz * cy),
        y + 2 * (qz * cx - qx * cz),
        z + 2 * (qx * cy - qy * cx)
end

--- converts vertices and indices to a triangle list
---@param vertices table
---@param indices table<integer>
function Renderer.math.verticesToTriangles(vertices, indices, triangles)
    if #indices % 3 ~= 0 then
        error("Renderer.math.verticesToTriangles: invalid indices")
    end
    triangles = triangles or {}
    for i = 1, #indices do
        table.insert(triangles, vertices[indices[i]])
    end
    return triangles
end

--- converts vertices and indices to a triangle list
---@param vertices love.ByteData|ffi.cdata*
---@param indices love.ByteData|ffi.cdata*
---@param vertexformat string
---@param indexformat string
function Renderer.math.ffiVerticesToTriangles(vertices, indices, vertexformat, indexformat)
    local CIndexFormat = indexformat == "uint16" and "uint16_t" or
        (indexformat == "uint32" and "uint32_t" or indexformat)

    local Fvertices, Findices, indicesLength
    if type(vertices) == "cdata" then
        Fvertices = vertices
        Findices = indices

        if Findices then
            assert(Findices, "Renderer.math.ffiVerticesToTriangles: invalid indices")
            assert(CIndexFormat, "Renderer.math.ffiVerticesToTriangles: invalid index format")
            indicesLength = ffi.sizeof(Findices) / ffi.sizeof(CIndexFormat)
        end
    else
        Fvertices = ffi.cast(vertexformat .. "*", vertices:getFFIPointer())
        Findices = ffi.cast(CIndexFormat .. "*", indices:getFFIPointer())
        indicesLength = indices:getSize() / ffi.sizeof(CIndexFormat)
    end

    if indicesLength % 3 ~= 0 then
        error("Renderer.math.verticesToTriangles: invalid indices")
    end

    local triangles = love.data.newByteData(indicesLength * ffi.sizeof(vertexformat))

    local trianglesPtr = ffi.cast(vertexformat .. "*", triangles:getFFIPointer())

    for i = 0, indicesLength - 1 do
        trianglesPtr[i] = Fvertices[Findices[i]]
    end

    return triangles
end

function Renderer.math.rotatePositions(...)
    local t = { ... }
    local q = t[#t]
    local vertices = {}
    for i = 1, #t - 1 do
        table.insert(vertices, Renderer.math.rotatePosition(t[i], q))
    end
    return vertices
end

--- Rotate positions using normal variables instead of vectors or quaternions (12x faster than Renderer.math.rotatePosition)
function Renderer.math.rotatePositionsSeparate(...)
    local t = { ... }
    local qx, qy, qz, qw = t[#t][1], t[#t][2], t[#t][3], t[#t][4]
    local vertices = {}
    for i = 1, #t - 1 do
        local x, y, z = t[i][1], t[i][2], t[i][3]
        local cx = qy * z - qz * y + x * qw
        local cy = qz * x - qx * z + y * qw
        local cz = qx * y - qy * x + z * qw

        table.insert(vertices, {
            x + 2 * (qy * cz - qz * cy),
            y + 2 * (qz * cx - qx * cz),
            z + 2 * (qx * cy - qy * cx)
        })
    end
    return vertices
end

--- Rotate positions using normal variables instead of vectors or quaternions (12x faster than Renderer.math.rotatePosition)
function Renderer.math.rotateTablePositionsSeparate(vertices, qx, qy, qz, qw)
    local newPoints = {}
    for i = 1, #vertices do
        local x, y, z = vertices[i][1], vertices[i][2], vertices[i][3]
        local cx = qy * z - qz * y + x * qw
        local cy = qz * x - qx * z + y * qw
        local cz = qx * y - qy * x + z * qw

        table.insert(newPoints, {
            x + 2 * (qy * cz - qz * cy),
            y + 2 * (qz * cx - qx * cz),
            z + 2 * (qx * cy - qy * cx)
        })
    end
    return newPoints
end

--- calculates the triangle normal of a triangle
---@param p1 table point 1
---@param p2 table point 2
---@param p3 table point 3
---@param inverted? boolean invert the normal?
---@return number x
---@return number y
---@return number z
function Renderer.math.triangleNormal(p1, p2, p3, inverted)
    local ux, uy, uz = p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]
    local vx, vy, vz = p3[1] - p1[1], p3[2] - p1[2], p3[3] - p1[3]
    local x = (uy * vz - uz * vy) * (inverted and -1 or 1)
    local y = (uz * vx - ux * vz) * (inverted and -1 or 1)
    local z = (ux * vy - uy * vx) * (inverted and -1 or 1)
    return Renderer.math.normalize3(x, y, z)
end

function Renderer.math.normalize(...)
    local t = { ... }
    if type(t[1]) == "table" then
        t = t[1]
        local d = 0
        for i = 1, #t do
            d = d + t[i] * t[i]
        end
        local d1 = 1 / math.sqrt(d)
        local t2 = {}
        for i = 1, #t do
            if d == 0 then
                t2[i] = 0
            else
                t2[i] = t[i] * d1
            end
        end
        return unpack(t2)
    else
        local d = 0
        for i = 1, #t do
            d = d + t[i] * t[i]
        end
        local d1 = 1 / math.sqrt(d)
        local t2 = {}
        for i = 1, #t do
            if d == 0 then
                t2[i] = 0
            else
                t2[i] = t[i] * d1
            end
        end
        return unpack(t2)
    end
end

function Renderer.math.normalize2(x, y)
    local d = x * x + y * y
    if d == 0 then
        return 0.0, 0.0
    end
    local d1 = 1 / math.sqrt(d)
    return x * d1, y * d1
end

function Renderer.math.normalize3(x, y, z)
    local d = x * x + y * y + z * z
    if d == 0 then
        return 0.0, 0.0, 0.0
    end
    d = 1 / math.sqrt(d)
    return x * d, y * d, z * d
end

function Renderer.math.normalize4(x, y, z, w)
    local d = x * x + y * y + z * z + w * w
    if d == 0 then
        return 0, 0, 0, 0
    end
    local d1 = 1 / math.sqrt(d)
    return x * d1, y * d1, z * d1, w * d1
end

function Renderer.math.closestPointOnTriangle(a, b, c, point)
    local px, py, pz = point[1], point[2], point[3]

    local abX = b[1] - a[1]
    local abY = b[2] - a[2]
    local abZ = b[3] - a[3]

    local acX = c[1] - a[1]
    local acY = c[2] - a[2]
    local acZ = c[3] - a[3]

    local apX = px - a[1]
    local apY = py - a[2]
    local apZ = pz - a[3]

    local d1 = Renderer.math.dot(abX, abY, abZ, apX, apY, apZ)
    local d2 = Renderer.math.dot(acX, acY, acZ, apX, apY, apZ)
    if d1 <= 0 and d2 <= 0 then
        return vec3(a)
    end

    local bpX = px - b[1]
    local bpY = py - b[2]
    local bpZ = pz - b[3]

    local d3 = Renderer.math.dot(abX, abY, abZ, bpX, bpY, bpZ)
    local d4 = Renderer.math.dot(acX, acY, acZ, bpX, bpY, bpZ)
    if d3 >= 0 and d4 <= d3 then
        return vec3(b)
    end

    local vc = d1 * d4 - d3 * d2
    if vc <= 0 and d1 >= 0 and d3 <= 0 then
        local v = d1 / (d1 - d3)
        local temp = TempVec3(abX, abY, abZ) * v
        local point = TempVec3(a) + temp
        return point
    end

    local cpX = px - c[1]
    local cpY = py - c[2]
    local cpZ = pz - c[3]

    local d5 = Renderer.math.dot(abX, abY, abZ, cpX, cpY, cpZ)
    local d6 = Renderer.math.dot(acX, acY, acZ, cpX, cpY, cpZ)
    if d6 >= 0 and d5 <= d6 then
        return vec3(c)
    end

    local vb = d5 * d2 - d1 * d6
    if vb <= 0 and d2 >= 0 and d6 <= 0 then
        local w = d2 / (d2 - d6)
        local temp = TempVec3(acX, acY, acZ) * w
        local point = TempVec3(a) + temp
        return point
    end

    local va = d3 * d6 - d5 * d4
    if va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0 then
        local w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        local vec3C = TempVec3(c)
        local vec3B = TempVec3(b)
        local temp = vec3C - vec3B
        local point = vec3B + temp * w
        return point
    end

    local denom = 1 / (va + vb + vc)
    local v = vb * denom
    local w = vc * denom
    local vec3A = TempVec3(a)
    local vec3AB = TempVec3(abX, abY, abZ)
    local vec3AC = TempVec3(acX, acY, acZ)
    local point = vec3A + vec3AB * v + vec3AC * w
    return point
end

--- closest point between two triangles
---@param a table<number, number, number>
---@param b table<number, number, number>
---@param c table<number, number, number>
---@param d table<number, number, number>
---@param e table<number, number, number>
---@param f table<number, number, number>
---@return vec3
function Renderer.math.closestPointToTriangles(a, b, c, d, e, f)
    local closestPointFromTriA
    local closestDistanceToTriB = math.huge
    for index, vert in ipairs({ a, b, c }) do
        local point = Renderer.math.closestPointOnTriangle(d, e, f, vert)
        local dist = (point - vert):lengthSqr()
        if dist < closestDistanceToTriB then
            closestDistanceToTriB = dist
            closestPointFromTriA = point -- or point
        end
    end
    local closestPointOnTriA = Renderer.math.closestPointOnTriangle(a, b, c, closestPointFromTriA)

    local closestPointFromTriB
    local closestDistanceToTriA = math.huge
    for index, vert in ipairs({ d, e, f }) do
        local point = Renderer.math.closestPointOnTriangle(a, b, c, vert)
        local dist = (point - vert):lengthSqr()
        if dist < closestDistanceToTriA then
            closestDistanceToTriA = dist
            closestPointFromTriB = point -- or point
        end
    end
    local closestPointOnTriB = Renderer.math.closestPointOnTriangle(d, e, f, closestPointFromTriB)

    -- find the triangle that is closest to the avarage contact position
    local averageContactPosition = (closestPointOnTriA + closestPointOnTriB) * 0.5
    local closestTriangleIndex = nil
    local closestDistance = math.huge
    for index, triangle in ipairs({ { a, b, c }, { d, e, f } }) do
        local distance = math.huge
        for vertIndex, vert in ipairs(triangle) do
            local dist = (vert - averageContactPosition):lengthSqr()
            if dist < distance then
                distance = dist
            end
        end
        if distance < closestDistance then
            closestDistance = distance
            closestTriangleIndex = index
        end
    end
    return closestTriangleIndex == 1 and closestPointOnTriA or closestPointOnTriB
end

function Renderer.math.eulerToAxisAngle(pitch, yaw, roll)
    local c1 = math.cos(yaw / 2)
    local s1 = math.sin(yaw / 2)
    local c2 = math.cos(pitch / 2)
    local s2 = math.sin(pitch / 2)
    local c3 = math.cos(roll / 2)
    local s3 = math.sin(roll / 2)
    local c1c2 = c1 * c2
    local s1s2 = s1 * s2
    local w = c1c2 * c3 - s1s2 * s3
    local x = c1c2 * s3 + s1s2 * c3
    local y = s1 * c2 * c3 + c1 * s2 * s3
    local z = c1 * s2 * c3 - s1 * c2 * s3
    local angle = 2 * math.acos(w)
    local norm = 1 / (x * x + y * y + z * z)
    if norm < 0.001 then
        x = 1
        y, z = 0, 0
    else
        norm = math.sqrt(norm);
        x = x * norm
        y = y * norm
        z = z * norm
    end
    return vec4(x, y, z, angle)
end

function Renderer.math.axisAngleToEuler(axisAngle)
    local x, y, z, angle = axisAngle:get()
    local s = math.sin(angle)
    local c = math.cos(angle)
    local t = 1 - c
    if (x * y * t + z * s) > 0.998 then
        yaw = 2 * math.atan2(x * math.sin(angle / 2), math.cos(angle / 2))
        pitch = PI05
        roll = 0
        return pitch, yaw, roll
    end
    if (x * y * t + z * s) < -0.998 then
        yaw = -2 * math.atan2(x * math.sin(angle / 2), math.cos(angle / 2))
        pitch = -PI05
        roll = 0
        return pitch, yaw, roll
    end
    yaw = math.atan2(y * s - x * z * t, 1 - (y * y + z * z) * t)
    pitch = math.asin(x * y * t + z * s)
    roll = math.atan2(x * s - y * z * t, 1 - (x * x + z * z) * t)
    return pitch, yaw, roll
end

function Renderer.math.axisAngleToQuat(axisAngle)
    local angle = axisAngle.w * 0.5
    local sinAngle = math.sin(angle)
    return quaternion(
        axisAngle.x * sinAngle,
        axisAngle.y * sinAngle,
        axisAngle.z * sinAngle,
        math.cos(angle)
    ):normalize()
end

function Renderer.math.quatToAxisAngle(quat)
    local angle = math.acos(quat.w) * 2
    local mul = 1 / math.sqrt(1 - quat.w * quat.w)
    if mul > 1000 then
        return vec4(
            quat.x,
            quat.y,
            quat.z,
            math.cos(angle)
        )
    else
        return vec4(
            quat.x * mul,
            quat.y * mul,
            quat.z * mul,
            math.cos(angle)
        )
    end
end

--- combines strings and numbers into a string
---@param ... any strings and numbers, last argument can be a table with settings {separator = " "}
function Renderer.internal.combine(...)
    local input = { ... }
    local settings = input[#input]
    if type(settings) == "table" then
        table.remove(input, #input)
    else
        settings = {
            seperator = " ",
        }
    end
    local output = ""

    for i = 1, #input do
        if type(input[i]) ~= "string" then
            output = output .. tostring(input[i]) .. (i ~= #input and settings.seperator or "")
        else
            output = output .. input[i] .. (i ~= #input and settings.seperator or "")
        end
    end
end

local acceptedTypes = {
    ["vec2"] = true,
    ["vec3"] = true,
    ["vec4"] = true,
    ["mat3"] = true,
    ["mat4"] = true,
    ["quaternion"] = true,
    ["physicsBody"] = true,
    ["physicsShape"] = true,
    ["spot"] = true,
    ["directional"] = true,
    ["point"] = true,
    ["area"] = true,
    ["volume"] = true,
    ["sphere"] = true,
    ["uiConstraintPoint"] = true,
    ["uiConstraintAxisPoint"] = true,
}

--- returns the type of a variable
---@param x any
---@return "vec2"|"vec3"|"vec4"|"quaternion"|"physicsBody"|"physicsShape"|"unknown"|"spot"|"directional"|"point"|"area"|"volume"|"sphere"|"uiConstraintPoint"|"uiConstraintAxisPoint"|"lightProbe"|"mat3"|"mat4"
function Renderer.math.type(x)
    local t = type(x)
    if t == "cdata" then
        local ct = ffi.typeof(x)

        if ct == Renderer.internal.types.vec2 then
            return "vec2"
        elseif ct == Renderer.internal.types.vec3 then
            return "vec3"
        elseif ct == Renderer.internal.types.vec4 then
            return "vec4"
        elseif ct == Renderer.internal.types.quaternion then
            return "quaternion"
        else
            return "unknown"
        end
    elseif t == "table" then
        -- check for Renderer.jolt.body, Renderer.physicsShape
        if acceptedTypes[x.type] then
            return x.type
        elseif x.type == "AABB light probe" or x.type == "Sphere light probe" or x.type == "Infinite light probe" then
            return "lightProbe"
        else
            return "unknown"
        end
    else
        return "unknown"
    end
end

--- Ray-Torus intersection
---@param r table ray
---@param tor vec2 x: radius, y: ring radius
---@param position vec3 position
---@param quat quaternion rotation
---@return number|nil
function Renderer.math.rayTorus(r, tor, position, quat)
    local ray = {}
    do -- reposition the ray to account for the fact that i can't rotate the torus
        ray.position = Renderer.math.rotatePosition(r.position - position, quat:invert())
        ray.direction = Renderer.math.rotatePosition(r.direction, quat:invert())
    end
    local po = 1.0

    local Ra2 = tor.x * tor.x
    local ra2 = tor.y * tor.y

    local m = Renderer.math.dotVector(ray.position, ray.position)
    local n = Renderer.math.dotVector(ray.position, ray.direction)

    local k = (m - ra2 - Ra2) / 2.0
    local k3 = n
    local k2 = n * n + Ra2 * ray.direction.z * ray.direction.z + k
    local k1 = k * n + Ra2 * ray.position.z * ray.direction.z
    local k0 = k * k + Ra2 * ray.position.z * ray.position.z - Ra2 * ra2

    if math.abs(k3 * (k3 * k3 - k2) + k1) < 0.01 then
        po = -1.0
        local tmp = k1
        k1 = k3
        k3 = tmp
        k0 = 1.0 / k0
        k1 = k1 * k0
        k2 = k2 * k0
        k3 = k3 * k0
    end

    local c2 = 2.0 * k2 - 3.0 * k3 * k3
    local c1 = k3 * (k3 * k3 - k2) + k1
    local c0 = k3 * (k3 * (c2 + 2.0 * k2) - 8.0 * k1) + 4.0 * k0


    c2 = c2 / 3.0
    c1 = c1 * 2.0
    c0 = c0 / 3.0

    local Q = c2 * c2 + c0
    local R = c2 * c2 * c2 - 3.0 * c2 * c0 + c1 * c1

    local h = R * R - Q * Q * Q

    if h >= 0.0 then
        h = math.sqrt(h)
        local v = Renderer.math.sign(R + h) * (math.abs(R + h) ^ (1.0 / 3.0))
        local u = Renderer.math.sign(R - h) * (math.abs(R - h) ^ (1.0 / 3.0))
        s = TempVec3((v + u) + 4.0 * c2, (v - u) * math.sqrt(3.0))
        local y = math.sqrt(0.5 * (s:length() + s.x))
        local x = 0.5 * s.y / y
        local r = 2.0 * c1 / (x * x + y * y)
        local t1 = x - r - k3
        t1 = (po < 0.0) and 2.0 / t1 or t1
        local t2 = -x - r - k3
        t2 = (po < 0.0) and 2.0 / t2 or t2
        local t = math.huge
        if t1 > 0.0 then t = t1 end
        if t2 > 0.0 then t = math.min(t, t2) end
        return t > 0 and t or nil
    end

    local sQ = math.sqrt(Q)
    local w = sQ * math.cos(math.acos(-R / (sQ * Q)) / 3.0)
    local d2 = -(w + c2)
    if d2 < 0.0 then return nil end
    local d1 = math.sqrt(d2)
    local h1 = math.sqrt(w - 2.0 * c2 + c1 / d1)
    local h2 = math.sqrt(w - 2.0 * c2 - c1 / d1)
    local t1 = -d1 - h1 - k3
    t1 = (po < 0.0) and 2.0 / t1 or t1
    local t2 = -d1 + h1 - k3
    t2 = (po < 0.0) and 2.0 / t2 or t2
    local t3 = d1 - h2 - k3
    t3 = (po < 0.0) and 2.0 / t3 or t3
    local t4 = d1 + h2 - k3
    t4 = (po < 0.0) and 2.0 / t4 or t4
    local t = math.huge
    if t1 > 0.0 then t = t1 end
    if t2 > 0.0 then t = math.min(t, t2) end
    if t3 > 0.0 then t = math.min(t, t3) end
    if t4 > 0.0 then t = math.min(t, t4) end
    return t > 0 and t or nil
end

function Renderer.math.rayCapsule(ray, topX, topY, topZ, baseX, baseY, baseZ, radius)
    local dot = Renderer.math.dot
    local baX, baY, baZ = baseX - topX, baseY - topY, baseZ - topZ
    local oaX, oaY, oaZ = ray.position.x - topX, ray.position.y - topY, ray.position.z - topZ
    local baba = dot(baX, baY, baZ, baX, baY, baZ)
    local bard = dot(baX, baY, baZ, ray.direction.x, ray.direction.y, ray.direction.z)
    local baoa = dot(baX, baY, baZ, oaX, oaY, oaZ)
    local rdoa = dot(ray.direction.x, ray.direction.y, ray.direction.z, oaX, oaY, oaZ)
    local oaoa = dot(oaX, oaY, oaZ, oaX, oaY, oaZ)
    local a = baba - bard * bard
    local b = baba * rdoa - baoa * bard
    local c = baba * oaoa - baoa * baoa - radius * radius * baba
    local h = b * b - a * c
    if h >= 0.0 then
        local t = (-b - math.sqrt(h)) / a
        local y = baoa + t * bard
        if y > 0.0 and y < baba then
            return t
        end
        local oc = y <= 0.0 and vec3(oaX, oaY, oaZ) or
            TempVec3(ray.position.x - baseX, ray.position.y - baseY, ray.position.z - baseZ)
        b = dot(ray.direction.x, ray.direction.y, ray.direction.z, oc.x, oc.y, oc.z)
        c = dot(oc.x, oc.y, oc.z, oc.x, oc.y, oc.z) - radius * radius
        h = b * b - c
        if h > 0 then
            return -b - math.sqrt(h)
        end
    end
end

function Renderer.math.rayCylinder(ray, topX, topY, topZ, baseX, baseY, baseZ, radius)
    local dot = Renderer.math.dot
    local baX, baY, baZ = baseX - topX, baseY - topY, baseZ - topZ
    local ocX, ocY, ocZ = ray.position.x - topX, ray.position.y - topY, ray.position.z - topZ
    local baba = dot(baX, baY, baZ, baX, baY, baZ)
    local bard = dot(baX, baY, baZ, ray.direction.x, ray.direction.y, ray.direction.z)
    local baoc = dot(baX, baY, baZ, ocX, ocY, ocZ)
    local k2 = baba - bard * bard
    local k1 = baba * dot(ocX, ocY, ocZ, ray.direction.x, ray.direction.y, ray.direction.z) - baoc * bard
    local k0 = baba * dot(ocX, ocY, ocZ, ocX, ocY, ocZ) - baoc * baoc - radius * radius * baba
    local h = k1 * k1 - k2 * k0
    if h < 0 then
        return
    end
    h = math.sqrt(h)
    local t = (-k1 - h) / k2
    local y = baoc + t * bard

    if y > 0 and y < baba then
        return t, (vec3(ocX, ocY, ocZ) + t * ray.direction - vec3(baX, baY, baZ) * y / baba) / radius
    end

    t = (((y < 0) and 0 or baba) - baoc) / bard
    if math.abs(k1 + k2 * t) < h then
        return t, vec3(baX, baY, baZ) * Renderer.math.sign(y) / math.sqrt(baba)
    end
    return
end

function Renderer.math.raySphere(ray, x, y, z, radius)
    local ox, oy, oz = ray.position.x - x, ray.position.y - y, ray.position.z - z
    local dx, dy, dz = ray.direction.x, ray.direction.y, ray.direction.z

    local a = dx * dx + dy * dy + dz * dz
    local b = 2 * (dx * ox + dy * oy + dz * oz)
    local c = ox * ox + oy * oy + oz * oz - radius * radius
    local d = b * b - 4 * a * c

    if (d >= 0) then
        local dist = (-b - math.sqrt(d)) / (2 * a)

        if (dist >= 0) then
            local hitPos = ray.position + ray.direction * dist
            local normal = hitPos - TempVec3(x, y, z)
            return dist, hitPos, normal:normalize()
        end
    end
end

--- checks if a ray intersects with an AABB
---@param rayX number
---@param rayY number
---@param rayZ number
---@param rayDirX number
---@param rayDirY number
---@param rayDirZ number
---@param minX number box minimum bounds
---@param minY number
---@param minZ number
---@param maxX number box maximum bounds
---@param maxY number
---@param maxZ number
---@return boolean, number, number #hit, distance, depth
function Renderer.math.rayAABB(rayX, rayY, rayZ, rayDirX, rayDirY, rayDirZ, minX, minY, minZ, maxX, maxY, maxZ)
    local t0X, t0Y, t0Z = (minX - rayX) / rayDirX, (minY - rayY) / rayDirY, (minZ - rayZ) / rayDirZ
    local t1X, t1Y, t1Z = (maxX - rayX) / rayDirX, (maxY - rayY) / rayDirY, (maxZ - rayZ) / rayDirZ
    local tminX, tminY, tminZ = math.min(t0X, t1X), math.min(t0Y, t1Y), math.min(t0Z, t1Z)
    local tmaxX, tmaxY, tmaxZ = math.max(t0X, t1X), math.max(t0Y, t1Y), math.max(t0Z, t1Z)

    local tNear = math.max(tminX, tminY, tminZ, 0.0)
    local tFar = math.min(tmaxX, tmaxY, tmaxZ)

    return tFar - tNear > 0, tNear, tFar - tNear
end

--- same as Renderer.math.rayAABB but with 1 / rayDir instead of rayDir
---@param rayX number
---@param rayY number
---@param rayZ number
---@param rayIDirX number
---@param rayIDirY number
---@param rayIDirZ number
---@param minX number box minimum bounds
---@param minY number
---@param minZ number
---@param maxX number box maximum bounds
---@param maxY number
---@param maxZ number
---@return boolean, number, number #hit, distance, depth
function Renderer.math.rayAABBInverse(rayX, rayY, rayZ, rayIDirX, rayIDirY, rayIDirZ, minX, minY, minZ, maxX, maxY, maxZ)
    local t0X, t0Y, t0Z = (minX - rayX) * rayIDirX, (minY - rayY) * rayIDirY, (minZ - rayZ) * rayIDirZ
    local t1X, t1Y, t1Z = (maxX - rayX) * rayIDirX, (maxY - rayY) * rayIDirY, (maxZ - rayZ) * rayIDirZ
    local tminX, tminY, tminZ = math.min(t0X, t1X), math.min(t0Y, t1Y), math.min(t0Z, t1Z)
    local tmaxX, tmaxY, tmaxZ = math.max(t0X, t1X), math.max(t0Y, t1Y), math.max(t0Z, t1Z)

    local tNear = math.max(tminX, tminY, tminZ, 0.0)
    local tFar = math.min(tmaxX, tmaxY, tmaxZ)

    return tFar - tNear > 0, tNear, tFar - tNear
end

function Renderer.math.triangleTangent(p1, p2, p3)
    local edge1X, edge1Y, edge1Z = p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]
    local edge2X, edge2Y, edge2Z = p3[1] - p1[1], p3[2] - p1[2], p3[3] - p1[3]

    local deltaUV1X, deltaUV1Y = p2[4] - p1[4], p2[5] - p1[5]
    local deltaUV2X, deltaUV2Y = p3[4] - p1[4], p3[5] - p1[5]

    local f = 1.0 / (deltaUV1X * deltaUV2Y - deltaUV2X * deltaUV1Y)

    local tangentX = f * (deltaUV2Y * edge1X - deltaUV1Y * edge2X)
    local tangentY = f * (deltaUV2Y * edge1Y - deltaUV1Y * edge2Y)
    local tangentZ = f * (deltaUV2Y * edge1Z - deltaUV1Y * edge2Z)

    local i = 1 / math.sqrt(tangentX * tangentX + tangentY * tangentY + tangentZ * tangentZ)

    return tangentX * i, tangentY * i, tangentZ * i
end

function Renderer.math.newScaleMatrix(scale)
    local mat = mat4()
    mat[1][1] = scale.x
    mat[2][2] = scale.y
    mat[3][3] = scale.z
    return mat
end

function Renderer.math.scaleFromMatrix(matrix)
    return Renderer.math.length3(matrix[1][1], matrix[1][2], matrix[1][3]),
        Renderer.math.length3(matrix[2][1], matrix[2][2], matrix[2][3]),
        Renderer.math.length3(matrix[3][1], matrix[3][2], matrix[3][3])
end

function Renderer.math.slerp(qa, qb, t)
    local qm = quaternion()
    local cosHalfTheta = qa.w * qb.w + qa.x * qb.x + qa.y * qb.y + qa.z * qb.z
    if math.abs(cosHalfTheta) >= 1.0 then
        qm.w = qa.w
        qm.x = qa.x
        qm.y = qa.y
        qm.z = qa.z
        return qm
    end
    local halfTheta = math.acos(cosHalfTheta)
    local sinHalfTheta = math.sqrt(1.0 - cosHalfTheta * cosHalfTheta)
    if math.abs(sinHalfTheta) < 0.001 then
        qm.w = (qa.w * 0.5 + qb.w * 0.5)
        qm.x = (qa.x * 0.5 + qb.x * 0.5)
        qm.y = (qa.y * 0.5 + qb.y * 0.5)
        qm.z = (qa.z * 0.5 + qb.z * 0.5)
        return qm
    end
    local ratioA = math.sin((1 - t) * halfTheta) / sinHalfTheta
    local ratioB = math.sin(t * halfTheta) / sinHalfTheta
    qm.w = (qa.w * ratioA + qb.w * ratioB)
    qm.x = (qa.x * ratioA + qb.x * ratioB)
    qm.y = (qa.y * ratioA + qb.y * ratioB)
    qm.z = (qa.z * ratioA + qb.z * ratioB)
    return qm
end

function Renderer.math.newTransform(translation, rotation, scale)
    local scaleMatrix = mat4({
        { scale.x, 0,       0,       0 },
        { 0,       scale.y, 0,       0 },
        { 0,       0,       scale.z, 0 },
        { 0,       0,       0,       1 }
    })

    local rotationMatrix = Renderer.math.quaternionToMatrix(rotation)

    local rotationScaleMatrix = rotationMatrix * scaleMatrix

    rotationScaleMatrix[4][1] = translation.x
    rotationScaleMatrix[4][2] = translation.y
    rotationScaleMatrix[4][3] = translation.z

    return rotationScaleMatrix
end

function Renderer.math.fromGLTFQuaternion(...)
    local pitch, yaw, roll = Renderer.math.quaternionToEuler(quaternion(...))

    --[[
        X- right, Y+ up, Z+ forward
        to
        X+ right, Y+ up, Z- forward
    ]]

    yaw = -yaw
    roll = -roll

    return Renderer.math.eulerToQuaternion(pitch, yaw, roll)
end

function Renderer.math.newGLTFTransform(translation, rotation, scale)
    local scaleMatrix = mat4({
        scale.x, 0, 0, 0,
        0, scale.y, 0, 0,
        0, 0, scale.z, 0,
        0, 0, 0, 1
    })

    local rotationMatrix = Renderer.math.quaternionToMatrix(Renderer.math.fromGLTFQuaternion(rotation))

    local translationMatrix = mat4()

    --[[
        X- right, Y+ up, Z+ forward
        to
        X+ right, Y+ up, Z- forward
    ]]

    translationMatrix[4][1] = translation.x
    translationMatrix[4][2] = translation.y
    translationMatrix[4][3] = -translation.z

    return scaleMatrix * rotationMatrix * translationMatrix
end

local function rayTriangle(rayX, rayY, rayZ, rayDirX, rayDirY, rayDirZ, aX, aY, aZ, bX, bY, bZ, cX, cY, cZ)
    local dot = Renderer.math.dot
    local cross = Renderer.math.cross

    local ABx = bX - aX
    local ABy = bY - aY
    local ABz = bZ - aZ

    local ACx = cX - aX
    local ACy = cY - aY
    local ACz = cZ - aZ

    local normalX, normalY, normalZ = cross(ABx, ABy, ABz, ACx, ACy, ACz)

    local AOx = rayX - aX
    local AOy = rayY - aY
    local AOz = rayZ - aZ

    local DAOx, DAOy, DAOz = cross(AOx, AOy, AOz, rayDirX, rayDirY, rayDirZ)

    local det = -dot(rayDirX, rayDirY, rayDirZ, normalX, normalY, normalZ)
    local invDet = 1 / det

    local dist = dot(AOx, AOy, AOz, normalX, normalY, normalZ) * invDet
    local u = dot(ACx, ACy, ACz, DAOx, DAOy, DAOz) * invDet
    local v = -dot(ABx, ABy, ABz, DAOx, DAOy, DAOz) * invDet

    local w = 1 - u - v
    local hit = det > 10 ^ -6 and dist >= 0 and u >= 0 and v >= 0 and w >= 0

    if hit then
        local hitX = rayX + rayDirX * dist
        local hitY = rayY + rayDirY * dist
        local hitZ = rayZ + rayDirZ * dist

        return dist, hitX, hitY, hitZ, u, v, w
    end
end

function Renderer.math.rayAABB(minX, minY, minZ, maxX, maxY, maxZ, rayX, rayY, rayZ, rayDirX, rayDirY, rayDirZ)
    local inside = true

    local quadrantX = 0
    local quadrantY = 0
    local quadrantZ = 0

    local maxT = {}
    local candidatePlaneX = 0
    local candidatePlaneY = 0
    local candidatePlaneZ = 0

    if rayX < minX then
        quadrantX = 1
        candidatePlaneX = minX
        inside = false
    elseif rayX > maxX then
        quadrantX = 0
        candidatePlaneX = maxX
        inside = false
    else
        quadrantX = 2
    end

    if rayY < minY then
        quadrantY = 1
        candidatePlaneY = minY
        inside = false
    elseif (rayY > maxY) then
        quadrantY = 0
        candidatePlaneY = maxY
        inside = false
    else
        quadrantY = 2
    end

    if rayZ < minZ then
        quadrantZ = 1
        candidatePlaneZ = minZ
        inside = false
    elseif rayZ > maxZ then
        quadrantZ = 0
        candidatePlaneZ = maxZ
        inside = false
    else
        quadrantZ = 2
    end

    if inside then
        return true
    end

    if quadrantX ~= 2 and rayDirX ~= 0 then
        maxT[1] = (candidatePlaneX - rayX) / rayDirX
    else
        maxT[1] = -1.0
    end
    if quadrantY ~= 2 and rayDirY ~= 0 then
        maxT[2] = (candidatePlaneY - rayY) / rayDirY
    else
        maxT[2] = -1.0
    end
    if quadrantZ ~= 2 and rayDirZ ~= 0 then
        maxT[3] = (candidatePlaneZ - rayZ) / rayDirZ
    else
        maxT[3] = -1.0
    end

    local whichPlane = 1
    if maxT[whichPlane] < maxT[2] then
        whichPlane = 2
    end
    if maxT[whichPlane] < maxT[3] then
        whichPlane = 3
    end
    local coord = {}

    if maxT[whichPlane] < 0 then
        return false
    end

    if whichPlane ~= 1 then
        coord.x = rayX + maxT[whichPlane] * rayDirX
        if coord.x < minX or coord.x > maxX then
            return false
        end
    else
        coord.x = candidatePlaneX
    end

    if whichPlane ~= 2 then
        coord.y = rayY + maxT[whichPlane] * rayDirY
        if coord.y < minY or coord.y > maxY then
            return false
        end
    else
        coord.y = candidatePlaneY
    end

    if whichPlane ~= 3 then
        coord.z = rayZ + maxT[whichPlane] * rayDirZ
        if coord.z < minZ or coord.z > maxZ then
            return false
        end
    else
        coord.z = candidatePlaneZ
    end

    return true
end

function Renderer.math.rayMesh(mesh, meshPosition, meshQuaternion, meshScale, position, direction)
    local hitDistance = -1
    local rayPosition = position - meshPosition

    local rayHitX = 0
    local rayHitY = 0
    local rayHitZ = 0

    local hitNormalX = 0
    local hitNormalY = 0
    local hitNormalZ = 0

    local rayX, rayY, rayZ = rayPosition:get()
    local qx, qy, qz, qw = meshQuaternion:get()

    local sx, sy, sz = meshScale.x, meshScale.y, meshScale.z

    local vertices = mesh.ffiVertices
    for i = 0, mesh.vertices:getSize() / ffi.sizeof(mesh.ffiFormat) - 1, 3 do
        local a, b, c = vertices[i], vertices[i + 1], vertices[i + 2]

        local aX = a.VertexPosition.x * sx
        local aY = a.VertexPosition.y * sy
        local aZ = a.VertexPosition.z * sz

        local bX = b.VertexPosition.x * sx
        local bY = b.VertexPosition.y * sy
        local bZ = b.VertexPosition.z * sz

        local cX = c.VertexPosition.x * sx
        local cY = c.VertexPosition.y * sy
        local cZ = c.VertexPosition.z * sz

        aX, aY, aZ = Renderer.math.rotatePositionSeparate(aX, aY, aZ, qx, qy, qz, qw)
        bX, bY, bZ = Renderer.math.rotatePositionSeparate(bX, bY, bZ, qx, qy, qz, qw)
        cX, cY, cZ = Renderer.math.rotatePositionSeparate(cX, cY, cZ, qx, qy, qz, qw)

        local minX, minY, minZ = math.min(aX, bX, cX), math.min(aY, bY, cY), math.min(aZ, bZ, cZ)
        local maxX, maxY, maxZ = math.max(aX, bX, cX), math.max(aY, bY, cY), math.max(aZ, bZ, cZ)

        if Renderer.math.rayAABB(minX, minY, minZ, maxX, maxY, maxZ, rayX, rayY, rayZ, direction.x, direction.y, direction.z) then
            local dist, x, y, z, u, v, w = rayTriangle(
                rayX, rayY, rayZ, direction.x, direction.y, direction.z, aX, aY, aZ, bX, bY, bZ, cX, cY, cZ)
            if dist ~= nil and dist < hitDistance then
                hit = true
                hitDistance = dist

                rayHitX = x
                rayHitY = y
                rayHitZ = z

                local normalX = a.VertexNormal.x * w + b.VertexNormal.x * u + c.VertexNormal.x * v
                local normalY = a.VertexNormal.y * w + b.VertexNormal.y * u + c.VertexNormal.y * v
                local normalZ = a.VertexNormal.z * w + b.VertexNormal.z * u + c.VertexNormal.z * v

                hitNormalX, hitNormalY, hitNormalZ = Renderer.math.rotatePositionSeparate(
                    normalX, normalY, normalZ, qx, qy, qz, qw)
            end
        end
    end
    if hit then
        return hitDistance, rayHitX + meshPosition.x, rayHitY + meshPosition.y, rayHitZ + meshPosition.z,
            hitNormalX, hitNormalY, hitNormalZ
    end
end

function Renderer.math.rayPolygon(vertices, meshPosition, meshQuaternion, meshScale, position, direction)
    local hitDistance = -1
    local rayPosition = position - meshPosition

    local rayHitX = 0
    local rayHitY = 0
    local rayHitZ = 0

    local hitNormalX = 0
    local hitNormalY = 0
    local hitNormalZ = 0

    local rayX, rayY, rayZ = rayPosition:get()
    local qx, qy, qz, qw = meshQuaternion:get()

    local sx, sy, sz = meshScale.x, meshScale.y, meshScale.z

    for i = 1, #vertices, 3 do
        local a, b, c = vertices[i], vertices[i + 1], vertices[i + 2]

        local aX = a[1] * sx
        local aY = a[2] * sy
        local aZ = a[3] * sz

        local bX = b[1] * sx
        local bY = b[2] * sy
        local bZ = b[3] * sz

        local cX = c[1] * sx
        local cY = c[2] * sy
        local cZ = c[3] * sz

        aX, aY, aZ = Renderer.math.rotatePositionSeparate(aX, aY, aZ, qx, qy, qz, qw)
        bX, bY, bZ = Renderer.math.rotatePositionSeparate(bX, bY, bZ, qx, qy, qz, qw)
        cX, cY, cZ = Renderer.math.rotatePositionSeparate(cX, cY, cZ, qx, qy, qz, qw)

        local minX, minY, minZ = math.min(aX, bX, cX), math.min(aY, bY, cY), math.min(aZ, bZ, cZ)
        local maxX, maxY, maxZ = math.max(aX, bX, cX), math.max(aY, bY, cY), math.max(aZ, bZ, cZ)

        if Renderer.math.rayAABB(minX, minY, minZ, maxX, maxY, maxZ, rayX, rayY, rayZ, direction.x, direction.y, direction.z) then
            local dist, x, y, z, u, v, w = rayTriangle(
                rayX, rayY, rayZ, direction.x, direction.y, direction.z, aX, aY, aZ, bX, bY, bZ, cX, cY, cZ)
            if dist ~= nil and dist < hitDistance then
                hit = true
                hitDistance = dist

                rayHitX = x
                rayHitY = y
                rayHitZ = z

                local normalX = a[6] * w + b[6] * u + c[6] * v
                local normalY = a[7] * w + b[7] * u + c[7] * v
                local normalZ = a[8] * w + b[8] * u + c[8] * v

                hitNormalX, hitNormalY, hitNormalZ = Renderer.math.rotatePositionSeparate(
                    normalX, normalY, normalZ, qx, qy, qz, qw)
            end
        end
    end
    if hit then
        return hitDistance, rayHitX + meshPosition.x, rayHitY + meshPosition.y, rayHitZ + meshPosition.z,
            hitNormalX, hitNormalY, hitNormalZ
    end
end

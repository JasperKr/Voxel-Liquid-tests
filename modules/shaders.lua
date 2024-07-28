function Renderer.internal.calculateGaussianKernel(kernelSize)
    local sigma = kernelSize * 0.25
    local kernel = {}
    local sum = 0
    for y = -kernelSize / 2, kernelSize / 2 do
        for x = -kernelSize / 2, kernelSize / 2 do
            local value = (1 / (2 * 3.14159265359 * sigma * sigma)) * math.exp(-((x * x + y * y) / (2 * sigma * sigma)))
            sum = sum + value
            kernel[(y + 2) * kernelSize + (x + 2)] = value
        end
    end
    for i = 1, kernelSize * kernelSize do
        kernel[i] = kernel[i] / sum
    end
    return kernel
end

local defaultIncludePaths = { "Shaders/" }

local colors = {
    ["red"] = "\27[31m",
    ["green"] = "\27[32m",
    ["yellow"] = "\27[33m",
    ["blue"] = "\27[34m",
    ["magenta"] = "\27[35m",
    ["cyan"] = "\27[36m",
    ["white"] = "\27[37m",
    ["reset"] = "\27[0m"
}


local function coloredString(str, color)
    return colors[color] .. str .. colors["reset"]
end

function Renderer.internal.addDefaultIncludePath(path)
    table.insert(defaultIncludePaths, path)
end

local function lines(str)
    ---@type integer|nil
    local pos = 1;
    return function()
        if not pos then return nil end
        local p1, p2 = string.find(str, "\n", pos, true)
        local line
        if p1 then
            line = str:sub(pos, p1 - 1)
            pos = p2 + 1
        else
            line = str:sub(pos)
            pos = nil
        end
        return line
    end
end

local function addLineToPreviousIncludes(t, lines)
    for i, v in ipairs(t) do
        v[2] = v[2] + lines
        v[3] = v[3] + lines
        addLineToPreviousIncludes(v[4], lines)
    end
end

local cachedShaders = {}

local function loadShaderFile(shaderFile, fileName, depth, enableCache)
    if depth > 20 then
        error("shader: [ " ..
            fileName .. " ] compilation failed\n" .. "too many includes, did you write a recursive include?", 2)
    end

    if cachedShaders[fileName] and enableCache then
        return
            cachedShaders[fileName].file,
            cachedShaders[fileName].data,
            cachedShaders[fileName].totalLines
    end

    local found = false
    local iterator

    local name, finalFile = "", ""

    if not shaderFile then
        -- shader provided as filename

        -- check if the file exists in any of the default include paths
        for i = 0, #defaultIncludePaths do
            local tempName

            -- if i == 0, then start at the root directory
            if i == 0 then
                tempName = fileName
            else
                tempName = defaultIncludePaths[i] .. fileName
            end


            if love.filesystem.getInfo(tempName) ~= nil then
                local _, tempIterator = pcall(love.filesystem.lines, tempName)
                if found then
                    error("shader: [ " ..
                        tempName ..
                        " ] compilation failed\n" ..
                        "double include or two shaders with the same name under a different default filepath: " ..
                        fileName,
                        2)
                end
                name = tempName
                iterator = tempIterator
                found = true
            end
        end
    else
        -- shader provided as string

        iterator = lines(shaderFile)
        name = fileName
        found = true
    end

    local shaderData = { name, 1, 1, {} } -- {name, startLine, endLine, {includedFiles}}
    local lineIndex = 0
    local words = {}

    -- if the shader file was not found, return an error
    if not found then
        print("couldn't find shader file: [ " .. name .. " ] compilation failed")
        finalFile = finalFile .. "couldn't find shader file: [ " .. name .. " ] compilation failed\n"
        goto continue
    end


    for line in iterator do
        table.clear(words)
        for word in string.gmatch(line, "%S+") do
            table.insert(words, word)
        end

        if words[1] == "#include" then
            local includeFileName = string.match(words[2], '[^"]+')
            local shaderLines, includedFileData, lineAmount = loadShaderFile(nil, includeFileName, depth + 1, enableCache)
            -- lines, data about the included file {name, startLine, endLine, {includedFiles}} within the included file,
            -- amount of lines in the included file(s)
            finalFile = finalFile .. shaderLines .. "\n"

            local includedShaders = shaderData[4] -- get included files table

            -- check for double includes

            for i, v in ipairs(includedShaders) do
                if v[1] == includeFileName then
                    error("shader: [ " .. name .. " ] compilation failed\n" .. "double include: " .. includeFileName, 2)
                end
            end

            -- add included file data to the current file data
            table.insert(includedShaders, includedFileData) -- add included file data to the current file data

            -- add the current line index to the included file data
            addLineToPreviousIncludes({ includedFileData }, lineIndex) -- add the current line index to the included file data

            lineIndex = lineIndex + lineAmount
            -- increase line index by the amount of lines in the included file
        elseif words[1] == "#defineFromLua" then
            -- command is wrapped in a string so we can use spaces, so only use stuff after the first " and before the last "
            local afterFirstQuote = line:sub(line:find('"', nil, true) + 1)
            local command = afterFirstQuote:sub(1, afterFirstQuote:find('"', nil, true) - 1)

            local name = words[2]
            local ret, err = loadstring("return " .. command)
            if not ret then
                error("Shader compilation failed due to const define variable [ " .. name .. " ].\nError: " .. err)
            end
            local newLine = "#define " .. name .. " " .. ret()
            finalFile = finalFile .. newLine .. "\n"
        else
            finalFile = finalFile .. line .. "\n"
        end
        lineIndex = lineIndex + 1
    end
    ::continue::

    shaderData[3] = lineIndex

    cachedShaders[fileName] = {
        file = finalFile,
        data = shaderData,
        totalLines = lineIndex
    }

    return finalFile, shaderData, lineIndex
end

local function findErrorFile(t, line)
    for _, v in ipairs(t) do
        if line >= v[2] and line <= v[3] then
            local fileName, startLine, endLine, included = findErrorFile(v[4], line)
            if fileName then
                return fileName, startLine, endLine, included
            end
            return v[1], v[2], v[3], v[4]
        end
    end
end

local function findErrorLine(err, includedFiles, shaderFile, name, errorPos)
    local i = 0
    local prevLine = ""
    local errorLine = ""
    if errorPos == -1 then error("shader: " .. name .. "\n" .. err, 2) end
    -- find the line before the error line and the error line
    for line in lines(shaderFile) do
        i = i + 1
        if i == errorPos - 1 then
            prevLine = line
        end
        if i == errorPos then
            errorLine = line
            break
        end
    end

    local fileName, startLine, endLine, included = findErrorFile({ includedFiles }, errorPos)
    -- subtract all included files from the errorPos that are before the errorPos in the file

    -- catch #ifdef / #endif's that weren't closed, the error won't be on any lines in any file
    if not included then
        error("shader: [ " .. name .. " ] compilation failed\n" .. "couldn't find error in file" .. "\n" ..
            err)
    end

    local newErrorPos = errorPos
    for i, v in ipairs(included) do
        if v[3] < errorPos then
            newErrorPos = newErrorPos - (v[3] - v[2]) - 1
        end
    end
    errorPos = newErrorPos - startLine + 1
    return errorPos, prevLine, errorLine, fileName
end

Renderer.internal.shaderUniforms = {}

function Renderer.internal.addDefaultShaderUniform(name, ...)
    table.insert(Renderer.internal.shaderUniforms, { name, ... })
end

Renderer.internal.errorOnShaderFailure = true

Renderer.internal.addDefaultShaderUniform("gaussianKernel", unpack(Renderer.internal.calculateGaussianKernel(5)))
local defaultShaderPaths = { "Renderer/Graphics/Shaders/" }

--- Creates a new shader object from a file or a string.
---@param name string filepath or string of the shader
---@param options? {debugname: string, enableCache:boolean} options for the shader
---@return love.Shader
function Renderer.graphics.newShader(name, options)
    local providedFilename = string.sub(name, -5) == ".glsl"

    options = options or {}

    do
        if not love.filesystem.getInfo(name) and providedFilename then
            for i = 1, #defaultShaderPaths do
                if love.filesystem.getInfo(defaultShaderPaths[i] .. name) then
                    name = defaultShaderPaths[i] .. name
                    break
                end
            end
        end
    end

    local shaderFile, includedFiles, totalLines

    if providedFilename then
        shaderFile, includedFiles, totalLines = loadShaderFile(nil, name, 0, options.enableCache ~= false)
    else
        shaderFile, includedFiles, totalLines = loadShaderFile(name, options.debugname, 0, options.enableCache ~= false)
    end

    local status, warning = love.graphics.validateShader(true, shaderFile)
    if not status then
        -- if the shader failed to compile, get error info

        -- create shader file, without file caches, since that messes up the error line
        if providedFilename then
            shaderFile, includedFiles, totalLines = loadShaderFile(nil, name, 0, false)
        else
            shaderFile, includedFiles, totalLines = loadShaderFile(name, options.debugname, 0, false)
        end

        status, warning = love.graphics.validateShader(true, shaderFile)

        if not providedFilename then
            if Renderer.internal.errorOnShaderFailure then
                error("[NoTraceback]\nShader: " .. coloredString('"' .. "src/" .. name, "green") .. "\n\n" ..
                    warning, 2)
            else
                print("\nShader: src/" .. name .. "\n\n" .. warning, 2)
            end
        end

        -- error in the combined shader file
        local globalErrorPos = 0
        local i = 0
        for line in lines(warning) do
            i = i + 1

            -- the error line occurs on the 3rd line of the warning
            if i == 3 then
                local words = {}
                for word in line:gmatch "([^%s]+)" do
                    table.insert(words, word)
                end
                local pos = words[2]:gsub(":", "")
                globalErrorPos = tonumber(pos) or -1
                break
            end
        end

        -- get the file and the error line relative to the file
        local errorPos, prevLine, errorLine, fileName = findErrorLine(warning, includedFiles,
            shaderFile, name, globalErrorPos)

        local errorName = name

        if fileName ~= name then
            errorName = fileName
        end

        if Renderer.internal.errorOnShaderFailure then
            error("[NoTraceback]\nShader: " .. coloredString('"' .. "src/" .. errorName .. ":" ..
                    errorPos, "green") .. "\n\n" .. (fileName ~= name and ("Included in " .. name .. "\n") or "") ..
                coloredString("previous line, " .. (errorPos - 1) .. ": " .. prevLine .. "\n" ..
                    "error line, " .. errorPos .. ": " .. errorLine, "cyan") .. "\n" .. "\n" ..
                warning, 2)
        else
            print("\nShader: src/" .. errorName .. ":" ..
                errorPos .. "\n\n" .. (fileName ~= name and ("Included in " .. name .. "\n") or "") ..
                "previous line, " .. (errorPos - 1) .. ": " .. prevLine .. "\n" ..
                "error line, " .. errorPos .. ": " .. errorLine .. "\n" .. "\n" ..
                warning, 2)
        end
    end

    local shader = love.graphics.newShader(shaderFile, options)

    for i, data in ipairs(Renderer.internal.shaderUniforms) do
        if shader:hasUniform(data[1]) then
            shader:send(unpack(data))
        end
    end
    return shader
end

function Renderer.graphics.compileShaders()
    cachedShaders = {}

    Renderer.internal.shaders.main = Renderer.graphics.newShader("main.glsl",
        { debugname = "Main shader" }) or Renderer.internal.shaders.main
    Renderer.internal.shaders.skyboxRenderer = Renderer.graphics.newShader("skyboxRenderer.glsl",
        { debugname = "Skybox shader" }) or Renderer.internal.shaders.skyboxRenderer
end

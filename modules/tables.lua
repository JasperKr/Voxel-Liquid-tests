local indexedTableMetatable = {}
---@class iDIndexedTable
---@field indexTable table
local iDIndexedTableFunctions = { indexTable = {}, items = {} }

---@return iDIndexedTable
function newIdIndexedTable()
    local t = {
        indexTable = {},
        items = {},
    }
    setmetatable(t, indexedTableMetatable)
    return t
end

indexedTableMetatable.__index = function(t, k)
    return iDIndexedTableFunctions[k] or t.items[k]
end

indexedTableMetatable.__len = function(t)
    return #t.items
end

local objectIndexedTableMetatable = {}
---@class objectIndexedTable
---@field indexTable table
local objectIndexedTableFunctions = { indexTable = {}, items = {} }

---@return objectIndexedTable
function newObjectIndexedTable()
    return setmetatable({ indexTable = {}, items = {} }, objectIndexedTableMetatable)
end

objectIndexedTableMetatable.__index = function(t, k)
    return objectIndexedTableFunctions[k] or t.items[k]
end

objectIndexedTableMetatable.__len = function(t)
    return #t.items
end

function iDIndexedTableFunctions:add(v)
    assert(v.id, "Object doesn't have an id")
    assert(not self.indexTable[v.id], "Object with id " .. v.id .. " already exists")
    table.insert(self.items, v)
    self.indexTable[v.id] = #self.items
end

function iDIndexedTableFunctions:get(id)
    return self.items[self.indexTable[id]]
end

---removes something from the table
---@param index number
function iDIndexedTableFunctions:remove(index)
    -- get the object at the index
    local w = self.items[index]

    -- if the object is the last object in the table, we can just remove it
    if index == #self.items then
        table.remove(self.items, index)
        self.indexTable[w.id] = nil
    else
        -- get the index and object of the last object in the table
        local lastIndex = #self.items
        local lastObject = self.items[lastIndex]

        -- swap the object at the index with the last object
        self.items[index] = lastObject
        self.indexTable[lastObject.id] = index

        -- remove the last object
        self.indexTable[w.id] = nil
        table.remove(self.items, #self.items)
    end
end

function iDIndexedTableFunctions:removeAsObject(v)
    -- if the object is valid and has an id
    if v and v.id then
        local index = self.indexTable[v.id]

        -- if the object is in the table
        if index then
            -- if the object is the last object in the table, we can just remove it
            if index == #self.items then
                self.indexTable[v.id] = nil
                return table.remove(self.items, index)
            else
                -- get the index and object of the last object in the table
                local lastObject = self.items[#self.items]
                self.items[index] = lastObject

                -- if the last object has a valid id, update the index table
                if lastObject then
                    self.indexTable[lastObject.id] = index
                end

                -- remove the object from the index table and the table
                self.indexTable[v.id] = nil
                return table.remove(self.items, #self.items)
            end
        end
    end
end

function iDIndexedTableFunctions:removeById(id)
    -- if the id is valid
    if id then
        self:remove(self.indexTable[id])
    end
end

function objectIndexedTableFunctions:add(v)
    table.insert(self.items, v)
    self.indexTable[v] = #self.items
end

---removes something from the table
---@param i number
function objectIndexedTableFunctions:remove(i)
    local w = self.items[i]
    if i == #self.items then
        self.indexTable[w] = nil
        return table.remove(self.items, i)
    else
        local lastIndex = #self.items
        local lastObject = self.items[lastIndex]
        self.items[i] = lastObject
        self.indexTable[lastObject] = i
        self.indexTable[w] = nil
        return table.remove(self.items, #self.items)
    end
end

function objectIndexedTableFunctions:removeAsObject(v)
    if v then
        local i = self.indexTable[v]
        if i then
            if i == #self.items then
                self.indexTable[v] = nil
                return table.remove(self.items, i)
            else
                local lastObject = self.items[#self.items]
                self.items[i] = lastObject
                if lastObject then
                    self.indexTable[lastObject] = i
                end
                self.indexTable[v] = nil
                return table.remove(self.items, #self.items)
            end
        end
    end
end

--- pops the last object from the table
function objectIndexedTableFunctions:pop()
    local i = #self.items
    local w = self.items[i]
    self.indexTable[w] = nil
    return table.remove(self.items, i)
end

function objectIndexedTableFunctions:clear()
    self.items = {}
    self.indexTable = {}
end

function iDIndexedTableFunctions:clear()
    self.items = {}
    self.indexTable = {}
end

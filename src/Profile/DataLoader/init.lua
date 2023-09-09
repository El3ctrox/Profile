--!strict

--// Packages
local DataHandler = require(script.DataHandler)
type DataHandler = DataHandler.DataHandler

type table = { [any]: any }

--// Component
local DataLoader = {}
local dataLoaders = setmetatable({}, { __mode = "k" })

--// Local Functions
local function xtypeof(value: any): string
    
    return if typeof(value) == "table" then rawget(value, "type") else typeof(value)
end

--// Functions
function DataLoader.new<loaded, serialized>(default: loaded?)
    
    local meta = { __metatable = "locked" }
    local self = setmetatable({ type = "DataLoader", kind = "abstract" }, meta)
    local handler: DataHandler?
    
    self.defaultData = defaultData
    self.isUnique = false
    
    self.isOptional = false
    self.canCorrect = false
    self.canPanic = false
    
    --// Methods
    function self:setUniqueDefaultData(_defaultData: serialized & table): DataLoader<loaded, serialized>
        
        self.defaultData = _defaultData
        self.isUnique = true
        return self
    end
    function self:setDefaultData(_defaultData: serialized): DataLoader<loaded, serialized>
        
        return self
    end
    function self:getDefaultData(): serialized
        
        return if self.isUnique
            then table.clone(self.defaultData)
            else self.defaultData
    end
    
    function self:handle(container: Instance?): DataHandler
        
        container = container or Instance.new("Folder")
        assert(not handler, `already handled`)
        
        handler = DataHandler.wrap(container)
        self:_wrapHandler(handler)
        
        dataLoaders[container] = self
        return handler
    end
    function self:getHandler(): DataHandler
        
        return handler
    end
    
    function self:enableCorrection(): DataLoader<loaded, serialized>
        
        self.canCorrect = true
        return self
    end
    function self:enablePanic(): DataLoader<loaded, serialized>
        
        self.canPanic = true
        return self
    end
    function self:optional(): DataLoader<loaded, serialized>
        
        self.isOptional = true
        return self
    end
    
    function self:correct(data: any): loaded?
        
        return data
    end
    function self:check(data: any)
    end
    
    function self:deserialize(data: serialized): loaded
    end
    function self:serialize(value: loaded): serialized
    end
    
    function self:load(data: serialized|any): loaded?
        
        if self.canCorrect and not pcall(self.check, self, data) then
            
            data = self:correct(data) or default
        end
        
        if self.canPanic then self:check(data) end
        if not data then return end
        
        return self:deserialize(data)
    end
    function self:save(data: loaded): serialized
        
        return self:serialize(data)
    end
    
    function self:_wrapHandler(_handler: DataHandler)
    end
    
    --// Meta
    function self:__tostring()
        
        return `DataLoader.{self.kind}()`
    end
    
    --// End
    return self
end

function DataLoader.array<loadedElement, serializedElement>(
    valuesLoader: DataLoader<loadedElement, serializedElement>?,
    minLength: number?, maxLength: number?
): DataLoader<{loadedElement}, {serializedElement}>
    
    valuesLoader = valuesLoader or DataLoader.new()
    
    type array = {loadedElement}
    type data = {serializedElement}
    
    local self = DataLoader.new()
    self.kind = "array"
    self.min = minLength
    self.max = maxLength
    
    --// Override Methods
    function self:check(data)
        
        assert(typeof(data) == "table", `array expected`)
        assert(not minLength or #data >= minLength, `a minimum of {minLength} elements expected`)
        assert(not maxLength or #data <= maxLength, `a maximum of {maxLength} elements expected`)
        
        for _,value in ipairs(data) do
            
            valuesLoader:check(value)
        end
    end
    function self:correct(data)
        
        for index, value in ipairs(data) do
            
            if pcall(valuesLoader.check, valuesLoader, value) then return end
            
            local correction = self:correct(value)
            if correction then
                
                data[index] = correction
            else
                
                table.remove(data, index)
            end
        end
        
        return data
    end
    
    function self:deserialize(data: data): array
        
        local array = {}
        
        for _,value in ipairs(data) do
            
            local loadedValue = valuesLoader:load(value)
            table.insert(array, loadedValue)
        end
        
        return array
    end
    function self:serialize(array: array): data
        
        local data = {}
        
        for _,loadedValue in ipairs(array) do
            
            local value = valuesLoader:save(loadedValue)
            table.insert(data, value)
        end
        
        return data
    end
    
    --// End
    return self
end
function DataLoader.set<loadedKey, loadedValue, serializedKey, serializedValue>(
    indexLoader: DataLoader<loadedKey, serializedKey>?,
    valueLoader: DataLoader<loadedValue, serializedValue>?
): DataLoader<{[loadedKey]: loadedValue}, {{ index: serializedKey, value: serializedValue }}>
    
    type set = { [loadedKey]: loadedValue }
    type entry = { index: serializedKey, value: serializedValue }
    type data = { entry }
    
    local self = DataLoader.array(
        DataLoader.struct{
            index = indexLoader,
            value = valueLoader,
        }
    )
    self.kind = "set"
    
    --// Override Methods
    function self:deserialize(data: data): set
        
        local set = {}
        
        for index, value in data do
            
            local loadedIndex = indexLoader:load(index)
            if not loadedIndex then continue end
            
            local loadedValue = valueLoader:load(value)
            set[loadedIndex] = loadedValue
        end
        
        return set
    end
    function self:serialize(set: set): data
        
        local data = {}
        
        for index, value in set do
            
            table.insert(data, { index = indexLoader:save(index), value = valueLoader:save(value) })
        end
        
        return data
    end
    
    --// End
    return self
end
function DataLoader.struct<loaded>(struct: loaded & { [string]: any })
    
    local defaultStruct: loaded = {}
    local loaders = {}
    
    for index, default in struct do
        
        if xtypeof(default) == "DataLoader" then
            
            loaders[index] = default
            defaultStruct[index] = default.default
        else
            
            loaders[index] = DataLoader.new(default)
            defaultStruct[index] = default
        end
    end
    
    local self = DataLoader.new(defaultStruct)
    self.kind = "struct"
    
    --// Override Methods
    local super = self.setDefaultData
    function self:setDefaultData(_defaultData: any?)
        
        super(self, if _defaultData == nil then defaultData else _defaultData)
    end
    
    local super = self.setUniqueDefaultData
    function self:setUniqueDefaultData(_defaultData: Instance|table?)
        
        super(self, if _defaultData == nil then defaultData else _defaultData)
    end
    
    function self:check(data)
        
        assert(typeof(data) == "table", `table expected`)
        
        print(loaders)
        
        for index, loader in loaders do
            
            loader:check(data[index])
        end
    end
    function self:correct(data)
        
        if typeof(data) ~= "table" then return end
        
        local corrections = {}  -- logs corrections here instead apply changes without know if was possible correct all fields
        
        for index, loader in loaders do
            
            if pcall(loader.check, loader, data[index]) then continue end
            
            local correction = loader:correct(data[index])
            if not correction then return end
            
            corrections[index] = correction
        end
        
        for index, correction in corrections do
            
            data[index] = correction
        end
        
        return data
    end
    
    function self:deserialize(data)
        
        local values = {}
        
        for index, loader in loaders do
            
            values[index] = loader:deserialize(data[index])
        end
        
        return values
    end
    function self:serialize(values)
        
        local data = {}
        
        for index, loader in loaders do
            
            data[index] = loader:serialize(values[index])
        end
        
        return data
    end
    
    --// End
    return self
end

function DataLoader.string(default: string?, minLength: number?, maxLength: number?): DataLoader<string, string>
    
    local self = DataLoader.new(default)
    self.kind = "string"
    self.min = minLength
    self.max = maxLength
    
    --// Override Methods
    function self:check(data)
        
        assert(typeof(data) == "string", `string expected`)
        assert(not minLength or #data >= minLength, `a minimum of {minLength} characters expected`)
        assert(not maxLength or #data <= maxLength, `a maximum of {maxLength} characters expected`)
    end
    function self:parse(data)
        
        if data == nil then return end
        return tostring(data)
    end
    
    --// End
    return self
end
function DataLoader.integer(default: number?, min: number?, max: number?): DataLoader<number, number>
    
    local self = DataLoader.number(
        default and math.floor(default),
        min and math.floor(min),
        max and math.floor(max)
    )
    self.kind = "integer"
    
    --// Override Methods
    local super = self.check
    function self:check(data)
        
        super(self, data)
        assert(data % 1 == 0, `integer cant have decimal cases`)
    end
    
    local super = self.check
    function self:correct(data)
        
        data = super(self, data)
        if not data then return end
        
        return math.clamp(math.floor(data), min, max)
    end
    
    --// End
    return self
end
function DataLoader.number(default: number?, min: number?, max: number?): DataLoader<number, number>
    
    local self = DataLoader.new(default)
    self.kind = "number"
    self.min = min
    self.max = max
    
    --// Override Methods
    function self:check(data)
        
        assert(typeof(data) == "number", `number expected`)
        assert(not min or data >= min, `a number >= {min} expected`)
        assert(not max or data <= max, `a number <= {max} expected`)
    end
    function self:correct(data)
        
        if typeof(data) == "string" then data = tonumber(data)
        elseif typeof(data) ~= "number" then return end
        
        return math.clamp(data, min, max)
    end
    
    --// End
    return self
end
function DataLoader.boolean(default: boolean?): DataLoader<boolean, boolean>
    
    local self = DataLoader.new(default)
    self.kind = "boolean"
    
    --// Methods
    function self:check(data)
        
        assert(typeof(data) == "boolean", `boolean expected`)
    end
    function self:correct(data)
        
        return if data then true else false
    end
    
    --// End
    return self
end

function DataLoader.color(default: Color3?): DataLoader<Color3, { R: number, G: number, B: number }>
    
    type data = { R: number, G: number, B: number }
    
    local self = DataLoader.struct{
        R = DataLoader.integer(0),
        G = DataLoader.integer(0),
        B = DataLoader.integer(0)
    }
    self.kind = "Color3"
    
    --// Override Methods
    local super = self.deserialize
    function self:deserialize(data: data): Color3
        
        data = super(self, data)
        return Color3.fromRGB(data.R, data.G, data.B)
    end
    function self:serialize(color: Color3): data
        
        return { R = color.R, G = color.G, B = color.B }
    end
    
    --// End
    if default then self:setDefaultData{ R = default.R, G = default.G, B = default.B } end
    return self
end

--// End
export type DataLoader<loadedType, storedType> = typeof(DataLoader.new())
return DataLoader
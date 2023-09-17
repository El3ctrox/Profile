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
    
    return if typeof(value) == "table" then rawget(value, "type") or "table" else typeof(value)
end

--// Functions
function DataLoader.new<loaded, serialized>(defaultData: serialized?)
    
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
        
        self.defaultData = _defaultData
        self.isUnique = false
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
    
    function self:enableDiscart(): DataLoader<loaded, serialized>
        
        self.defaultData = nil
        self.isUnique = false
        return self
    end
    function self:optional(): DataLoader<loaded, serialized>
        
        self.isOptional = true
        return self
    end
    
    function self:correct(data: any): loaded?
        
        return data
    end
    function self:tryCheck(data: any): boolean
        
        return pcall(self.check, self, data)
    end
    function self:check(data: any)
    end
    
    function self:deserialize(data: serialized): loaded
        
        return data
    end
    function self:serialize(value: loaded): serialized
        
        return value
    end
    
    function self:load(data: serialized|any): loaded?
        
        if self.canCorrect and not self:tryCheck(data) then
            
            data = self:correct(data)
        end
        if self.defaultData ~= nil and not self:tryCheck(data) then
            
            data = self:getDefaultData()
        end
        if self.isOptional and data == nil then
            
            return
        end
        
        if self.canPanic then self:check(data)
            elseif not self:tryCheck(data) then return
        end
        
        return self:deserialize(data)
    end
    function self:save(data: loaded): serialized
        
        return self:serialize(data)
    end
    
    function self:_wrapHandler(_handler: DataHandler)
    end
    
    --// Meta
    function meta:__tostring()
        
        return `DataLoader.{self.kind}(`
            .."should "..(if self.canCorrect then "correct" else "abort")..", "
            .."should "..(if self.canPanic then "panic" else "be quiet")..", "
            .."default: "..(tostring(self:getDefaultData()))
            ..")"
    end
    
    --// End
    return self, meta
end

function DataLoader.array<loadedElement, serializedElement>(
    elementLoader: DataLoader<loadedElement, serializedElement>?,
    minLength: number?, maxLength: number?
): DataLoader<{loadedElement}, {serializedElement}>
    
    elementLoader = elementLoader or DataLoader.new()
    
    type array = {loadedElement}
    type data = {serializedElement}
    
    local self = DataLoader.new()
    self.kind = "array"
    self.min = minLength
    self.max = maxLength
    
    self.element = elementLoader
    
    --// Override Methods
    function self:check(data)
        
        assert(typeof(data) == "table", `array expected`)
        assert(not minLength or #data >= minLength, `a minimum of {minLength} elements expected`)
        assert(not maxLength or #data <= maxLength, `a maximum of {maxLength} elements expected`)
        
        for _,value in ipairs(data) do
            
            elementLoader:check(value)
        end
    end
    function self:correct(data)
        
        if typeof(data) ~= "table" then return end
        
        for index, value in ipairs(data) do
            
            if elementLoader:tryCheck(value) then return end
            
            local correction = elementLoader:correct(value)
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
            
            local loadedValue = elementLoader:deserialize(value)
            table.insert(array, loadedValue)
        end
        
        return array
    end
    function self:serialize(array: array): data
        
        local data = {}
        
        for _,loadedValue in ipairs(array) do
            
            local value = elementLoader:serialize(loadedValue)
            table.insert(data, value)
        end
        
        return data
    end
    
    --// End
    self:setUniqueDefaultData({})
    return self
end
function DataLoader.set<loadedKey, loadedValue, serializedKey, serializedValue>(
    indexLoader: DataLoader<loadedKey, serializedKey>?,
    valueLoader: DataLoader<loadedValue, serializedValue>?
): DataLoader<{[loadedKey]: loadedValue}, {{ index: serializedKey, value: serializedValue }}>
    
    type set = { [loadedKey]: loadedValue }
    type pair = { index: serializedKey, value: serializedValue }
    type data = { pair }
    
    local pairLoader = DataLoader.struct{
        index = indexLoader,
        value = valueLoader,
    }
    local self = DataLoader.array(pairLoader)
    self.kind = "set"
    self.index = indexLoader
    self.value = valueLoader
    self.pair = pairLoader
    
    --// Override Methods
    function self:deserialize(data: data): set
        
        local set = {}
        
        for index, value in data do
            
            local deserializedIndex = indexLoader:deserialize(index)
            if not deserializedIndex then continue end
            
            local deserializedValue = valueLoader:deserialize(value)
            set[deserializedIndex] = deserializedValue
        end
        
        return set
    end
    function self:serialize(set: set): data
        
        local data = {}
        
        for index, value in set do
            
            table.insert(data, { index = indexLoader:serialize(index), value = valueLoader:serialize(value) })
        end
        
        return data
    end
    
    --// End
    return self
end
function DataLoader.struct<loaded>(_loaders: { [string]: any })
    
    local self = DataLoader.new()
    self.kind = "struct"
    
    --// Setup
    local defaultData: loaded = {}
    local loaders = {} :: { [string]: DataLoader<any, any> }
    
    for index, value in _loaders do
        
        if xtypeof(value) == "DataLoader" then
            
            local loader = value
            
            defaultData[index] = loader.defaultData
            loaders[index] = loader
            self[index] = loader
        else
            
            local loader = DataLoader.new(value)
            
            defaultData[index] = value
            loaders[index] = loader
            self[index] = loader
        end
    end
    
    --// Override Methods
    function self:check(data)
        
        assert(typeof(data) == "table", `table expected`)
        
        for index, loader in loaders do
            
            if loader.isOptional then continue end
            loader:check(data[index])
        end
    end
    function self:correct(data)
        
        if typeof(data) ~= "table" then return end
        
        local corrections = {}  -- logs corrections here instead apply changes without know if was possible correct all fields
        
        for index, loader in loaders do
            
            if loader:tryCheck(data[index]) then continue end
            
            local correction = loader:correct(data[index]) or loader:getDefaultData()
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
    self:setUniqueDefaultData(defaultData)
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
    
    local super = self.correct
    function self:correct(data)
        
        data = super(self, data)
        if not data then return end
        
        return math.floor(data)
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
        
        if typeof(data) == "string" then data = tonumber(data) end
        if typeof(data) ~= "number" then return end
        
        return math.clamp(data, min or -math.huge, max or math.huge)
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
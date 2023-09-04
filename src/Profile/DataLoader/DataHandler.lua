--// Packages
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local wrapper = require(ReplicatedStorage.Packages.Wrapper)

type table = { [string]: any }

--// Component
local DataHandler = {}
local dataHandlers = setmetatable({}, { __mode = "k" })

--// Functions
type dataLoader = { load: (any, table) -> table, save: (any, table) -> table }

function DataHandler.wrap(container: Instance, dataLoader: dataLoader)
    
    local self, meta = wrapper(container)
    self.data = nil :: any?
    
    --// Methods
    function self:load(data: table)
        
        self.data = dataLoader:load(data)
        
        for index, value in data do
            
            self[index] = value
        end
    end
    function self:save()
        
        return dataLoader:save(self.data)
    end
    
    --// Behaviour
    function meta:__tostring()
        
        return `wrapper DataHandler.{self.kind}({self.data})`
    end
    
    --// End
    dataHandlers[container] = self
    return self
end

--// End
export type DataHandler = typeof(DataHandler.wrap(Instance.new("Folder")))
return DataHandler
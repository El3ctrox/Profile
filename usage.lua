local Players = game:GetService("Players")
local PlayerInventory = {}
local PlayerEconomy = {}
local PlayerProfile = {}
local ProfileStore = {}
local DataLoader = {}
local wrapper


local profileStore = ProfileStore.get("Player")
local dataLoadings = setmetatable({}, { __mode = "k" })
local dataHandlers = setmetatable({}, { __mode = "k" })

function PlayerProfile.wrap(player: Player)
    
    local profile = profileStore:wrap(player, player.UserId)
    local self = profile.dataLoader:getHandler()
    
    local dataLoading = profile:activateAsync()
    dataLoadings[player] = dataLoading
    
    player.Destroying:Connect(function() dataLoading:cancel() end)
    
    local success = dataLoading:await()
    dataLoadings[player] = nil
    
    if success then dataHandlers[player] = self end
    return self
end
function PlayerProfile.awaitPreviewOffline(userId: number)

    local dataContainer = Instance.new("Folder")
    dataContainer.Name = Players:GetNameFromUserIdAsync(userId)

    local profile = profileStore:wrap(dataContainer, userId)
end


function PlayerEconomy.wrap(player: Player)
    
    local playerProfile = PlayerProfile.get(player)
    
    --// Self
    local dataLoader = playerProfile.dataLoader:index("economy", DataLoader.dict{
        storedMoney = 0,
        money = 0,
    })
    local self = dataLoader:handle()
    
    --// Global Updates
    function playerProfile.globalUpdate.ReceiveMoney(update, amount: number, senderName: string?)
        
        self.storedMoney += amount
        print(`you gained {amount} from {senderName or "us"}`)
    end
    function self:awaitTransfer(targetId: number, amount: number)
        
        assert(self.storedMoney > amount, `not enought stored money`)
        
        local targetProfiler = playerProfile.previewOfflinePlayerAsync(targetId):expect()
    end
    
    --// Methods
    function self:withdraw(amount: number)
        
        assert(self.storedMoney >= amount, `not enought stored money`)
        
        self.stored -= amount
        self.money += amount
    end
    function self:store(amount: number)
        
        assert(self.money >= amount, `not enought money`)
        
        self.stored += amount
        self.money -= amount
    end
    
    --// End
    return self
end

local ItemModels = {}
local Item = {}

function Item.new(name: string, data: table?)
    
    local asset = ItemModels[name]
    local model = asset:Clone()
    
    local dataLoader = DataLoader.dict():recipient(model):load(data)
    dataLoader.name = name
    dataLoader.amount = 0
end
function Item.loader()
    
    local self = DataLoader.new():onBadData("parse")
    self.kind = "Item"
    
    function self:check(data)
        
        assert(typeof(data) == "table", `table expected`)
        assert(typeof(data.name) == "string", `(name) string expected`)
        assert(typeof(data.amount) == "number" and data.amount % 1 == 0, `(amount) integer expected`)
    end
    function self:onLoad(data)
        
        return Item.new(data.name, data)
    end
    
    return self
end

function PlayerInventory:wrap(player: Player)
    
    local dataLoader = player.dataLoader:index("inventory", DataLoader.dict())
    local self = dataLoader:handle()
    
    dataLoader.items = DataLoader.array(Item.loader():onBadData("skip"))
    local items = dataLoader.items:handle()
    
    --// Methods
    function self:removeItem(item)
        
        local removedItem = items:removeValue(item)
        if removedItem then item:unowned() end
    end
    function self:addItem(item)
        
        item:owned(self)
        items:add(item)
    end
    function self:findItem(item)
        
        return items:find(item) ~= nil
    end
    function self:getItems()
        
        return items:all()
    end
    
    return self
end
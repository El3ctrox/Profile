local function match(data, pattern: { [any]: any })
    
    if typeof(pattern) == "table" then
        
        if typeof(data) ~= "table" then return false end
        
        for index, patternValue in pattern do
            
            if not match(data[index], patternValue) then return false end
        end
        
        for index in data do
            
            if pattern[index] == nil then return false end
        end
        
        return true
        
    elseif typeof(pattern) == "string" then
        
        return typeof(data) == "string" and pattern:match(data)
    else
        
        return data == pattern
    end
end

return function()
    
    local DataLoader = require(script.Parent)
    
    describe("array data loader", function()
        
        local itemsLoader = DataLoader.array(DataLoader.string("unknown"))
        
        it("should load all elements", function()
            
            local data = { "sword", "apple" }
            local items = itemsLoader:load(data)
            
            expect(match(items, { "sword", "apple" })).to.be.ok()
        end)
        
        it("should load default data when miss element", function()
            
            local data = { "string", 10, "cavalo" }
            local items = itemsLoader:load(data)
            
            expect(match(items, {})).to.be.ok()
        end)
        it("should load default data when miss data", function()
            
            local items = itemsLoader:load("not a array")
            expect(match(items, {})).to.be.ok()
        end)
        it("shouldnt give same default data address", function()
            
            local defaultItems1 = itemsLoader:load()
            local defaultItems2 = itemsLoader:load()
            
            expect(defaultItems1).to.be.ok()
            expect(defaultItems2).to.be.ok()
            expect(defaultItems1).never.to.be.equal(defaultItems2)
        end)
        
        it("should discart all if some miss element", function()
            
            itemsLoader:shouldDiscart()
            
            local data = { "armor", 5, "cavalo" }
            local items = itemsLoader:load(data)
            
            expect(match(items, {})).to.be.ok()
        end)
        it("should discart when miss data", function()
            
            itemsLoader:shouldDiscart()
            
            local color = itemsLoader:load("not a array")
            expect(color).to.be.equal(nil)
        end)
        
        it("should correct discarting miss elements", function()
            
            itemsLoader:shouldCorrect()
            itemsLoader.element:shouldDiscart()
            
            local data = { "armor", 5, "cavalo" }
            local items = itemsLoader:load(data)
            
            expect(match(items, { "armor", "cavalo" })).to.be.ok()
            expect(match(data, { "armor", "cavalo" })).to.be.ok()
        end)
        it("should correct converting miss elements", function()
            
            itemsLoader:shouldCorrect()
            itemsLoader.element:shouldCorrect()
            
            local data = { "armor", 5, "cavalo" }
            local items = itemsLoader:load(data)
            
            expect(match(items, { "armor", "5", "cavalo" })).to.be.ok()
            expect(match(data, { "armor", "5", "cavalo" })).to.be.ok()
        end)
    end)
    describe("struct data loader", function()
        
        local itemLoader = DataLoader.struct{
            name = DataLoader.string("unknown"),
            level = DataLoader.integer(1),
            color = DataLoader.color(Color3.new())
        }
        
        it("should load all fields", function()
            
            local data = { name = "sword", level = 2, color = { R = 0, G = 255, B = 50 } }
            local item = itemLoader:load(data)
            
            expect(match(item, { name = "sword", level = 2, color = Color3.fromRGB(0, 255, 50) }))
        end)
        
        it("should load default data when miss field", function()
            
            local data = { name = nil, level = 3, color = { R = 0, G = 0, B = 0 } }
            local item = itemLoader:load(data)
            
            expect(match(item, { level = 1, color = Color3.new() })).to.be.ok()
        end)
        it("should load default data when miss data", function()
            
            local item = itemLoader:load("not a table")
            expect(match(item, { name = "unknown", level = 1, color = Color3.new() })).to.be.ok()
        end)
        it("shouldnt give same default data address", function()
            
            local defaultItem1 = itemLoader:load(nil)
            local defaultItem2 = itemLoader:load(nil)
            
            expect(defaultItem1).to.be.ok()
            expect(defaultItem2).to.be.ok()
            expect(defaultItem1).never.to.be.equal(defaultItem2)
        end)
        
        it("should discart when miss field", function()
            
            itemLoader:shouldDiscart()
            
            local data = { name = nil, level = 3, color = { R = 0, G = 0, B = 0 } }
            local item = itemLoader:load(data)
            
            expect(item).to.be.equal(nil)
        end)
        it("shouldnt discart when miss optional field", function()
            
            itemLoader:shouldDiscart()
            itemLoader.name:optional()
            
            local data = { name = nil, level = 3, color = { R = 0, G = 0, B = 0 } }
            local item = itemLoader:load(data)
            
            expect(match(item, { level = 3, color = Color3.new() })).to.be.ok()
        end)
        it("should discart when miss data", function()
            
            itemLoader:shouldDiscart()
            
            local item = itemLoader:load("not a table")
            expect(item).to.be.equal(nil)
        end)
        
        it("should correct filling missing fields", function()
            
            itemLoader:shouldCorrect()
            
            local data = { name = "sword", level = 1 }
            local item = itemLoader:load(data)
            
            expect(match(item, {
                name = "sword",
                level = 1,
                color = Color3.new()
            })).to.be.ok()
            expect(match(data, {
                name = "sword",
                level = 1,
                color = { R = 0, G = 0, B = 0 }
            })).to.be.ok()
        end)
        it("should correct converting missing fields", function()
            
            itemLoader:shouldCorrect()
            
            local data = { name = "potion", level = "3", color = { R = 0, G = 0, B = 0 } }
            local item = itemLoader:load(data)
            
            expect(match(item, { name = "potion", level = 3, color = Color3.new() })).to.be.ok()
        end)
        
        it("should add a field", function()
            
            itemLoader.damage = 0
            
            local item = itemLoader:load{ damage = nil, name = "sword" }
            
            expect(match(item, { damage = 0, name = "sword", level = 1, color = Color3.new() })).to.be.ok()
        end)
        it("should add a loader", function()
            
            itemLoader.owners = DataLoader.array(
                DataLoader.integer()
            )
            
            local item = itemLoader:load{ owners = nil, name = "sword" }
            
            expect(match(item, { owners = {}, damage = 0, name = "sword", level = 1, color = Color3.new() })).to.be.ok()
        end)
    end)
    
    describe("set data loader", function()
        
        local setLoader = DataLoader.set(
            DataLoader.integer(),
            DataLoader.string("unknown")
        )
        
        it("should load data", function()
            
            local data = {
                { index = 1, value = "sword" },
                { index = 3, value = "apple" },
                { index = 10, value = "armor" },
            }
            local inventory = setLoader:load(data)
            
            expect(match(inventory, {
                [1] = "sword",
                [3] = "apple",
                [10] = "armor"
            })).to.be.ok()
        end)
        
        it("should load default data when miss pair", function()
            
            local data = {
                { index = 1, value = "sword" },
                { index = "maxItems", value = 5 },
                { index = 10, value = "armor" },
                { index = 15, value = 15 },
            }
            local inventory = setLoader:load(data)
            
            expect(match(inventory, {})).to.be.ok()
        end)
        it("should load default data when miss data", function()
            
            local set = setLoader:load("not a set")
            expect(match(set, {})).to.be.ok()
        end)
        it("shouldnt give same default data address", function()
            
            local defaultSet1 = setLoader:load()
            local defaultSet2 = setLoader:load()
            
            expect(defaultSet1).to.be.ok()
            expect(defaultSet2).to.be.ok()
            expect(defaultSet1).never.to.be.equal(defaultSet2)
        end)
        
        it("should discart all if some miss pair", function()
            
            setLoader:shouldDiscart()
            
            local data = {
                { index = 1, value = "sword" },
                { index = "maxItems", value = 5 },
                { index = 10, value = "armor" },
                { index = 15, value = 15 },
            }
            local inventory = setLoader:load(data)
            
            expect(inventory).to.be.equal(nil)
        end)
        it("should discart when miss data", function()
            
            setLoader:shouldDiscart()
            
            local set = setLoader:load("not a set")
            expect(set).to.be.equal(nil)
        end)
        
        it("should correct converting miss pairs", function()
            
            setLoader:shouldCorrect()
            setLoader.pair:shouldCorrect()
            
            local data = {
                { index = 1, value = "sword" },
                { index = "2", value = true },
                { index = 10, value = "armor" },
            }
            local inventory = setLoader:load(data)
            
            expect(match(inventory, {
                [1] = "sword",
                [2] = "true",
                [10] = "armor",
            })).to.be.ok()
            expect(match(data, {
                { index = 1, value = "sword" },
                { index = 2, value = "true" },
                { index = 10, value = "armor" },
            })).to.be.ok()
        end)
        it("should correct discarting miss pairs", function()
            
            setLoader:shouldCorrect()
            setLoader.pair:shouldDiscart()
            
            local data = {
                { index = 1, value = "sword" },
                { index = 10, value = "armor" },
                { index = "maxItems", value = 5 },
            }
            local inventory = setLoader:load(data)
            
            expect(match(inventory, {
                [1] = "sword",
                [10] = "armor"
            })).to.be.ok()
            expect(match(data, {
                { index = 1, value = "sword" },
                { index = 10, value = "armor" },
            })).to.be.ok()
        end)
    end)
    describe("Color3 data loader", function()
        
        local colorLoader = DataLoader.color(Color3.new(0, 1, 0))
        
        it("should load RGB(2, 3, 4)", function()
            
            local data = { R = 2, G = 3, B = 4 }
            local color = colorLoader:load(data)
            
            expect(typeof(color)).to.be.equal("Color3")
            expect(color.R*255).to.be.near(data.R, .1)
            expect(color.G*255).to.be.near(data.G, .1)
            expect(color.B*255).to.be.near(data.B, .1)
        end)
        
        it("should load default data when miss field", function()
            
            local data = { R = 255, G = nil, B = 0 }
            local color = colorLoader:load(data)
            
            expect(color).to.be.equal(Color3.new(0, 1, 0))
        end)
        it("should load default data when miss data", function()
            
            local color = colorLoader:load("not a color")
            
            expect(color).to.be.equal(Color3.new(0, 1, 0))
        end)
        
        it("should discart when miss field", function()
            
            colorLoader:shouldDiscart()
            
            local data = { R = "255", G = 255, B = 0 }
            local color = colorLoader:load(data)
            
            expect(color).to.be.equal(nil)
        end)
        it("should discart when miss data", function()
            
            colorLoader:shouldDiscart()
            
            local color = colorLoader:load("not a color")
            expect(color).to.be.equal(nil)
        end)
        
        it("should correct filling missing fields", function()
            
            colorLoader:shouldCorrect()
            
            local data = { R = 50, G = 255 }
            local color = colorLoader:load(data)
            
            expect(color).to.be.equal(Color3.fromRGB(50, 255, 0))
            expect(data.B).to.be.equal(0)
        end)
        it("should correct converting miss fields", function()
            
            colorLoader:shouldCorrect()
            
            local data = { R = "255", G = 50, B = 10 }
            local color = colorLoader:load(data)
            
            expect(color).to.be.equal(Color3.fromRGB(255, 50, 10))
            expect(data.R).to.be.equal(255)
        end)
    end)
end
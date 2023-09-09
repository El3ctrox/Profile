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
    
    describe("Color3 data loader", function()
        
        local colorLoader = DataLoader.color()
            :enableCorrection()
        
        it("should load RGB(2, 3, 4)", function()
            
            local data = { R = 2, G = 3, B = 4 }
            local color = colorLoader:load(data)
            
            expect(typeof(color)).to.be.equal("Color3")
            expect(color.R*255).to.be.near(data.R, .1)
            expect(color.G*255).to.be.near(data.G, .1)
            expect(color.B*255).to.be.near(data.B, .1)
        end)
        it("should fill missing fields", function()
            
            local data = { R = 50, G = 255 }
            local color = colorLoader:load(data)
            
            expect(typeof(color)).to.be.equal("Color3")
            expect(color.B).to.be.equal(0)
            expect(data.B).to.be.equal(0)
        end)
        it("should convert missing fields", function()
            
            local data = { R = "255", G = 50, B = 10 }
            local color = colorLoader:load(data)
            
            expect(typeof(color)).to.be.equal("Color3")
            expect(color.R*255).to.be.near(255, .1)
            expect(color.G*255).to.be.near(50, .1)
            expect(color.B*255).to.be.near(10, .1)
            
            expect(data.R).to.be.equal(255)
        end)
        it("should discart without default data", function()
            
            local color = colorLoader:load(nil)
            expect(color).to.be.equal(nil)
        end)
    end)
    
    describe("array data loader", function()
        
        local itemsLoader = DataLoader.array(DataLoader.string())
        
        it("should load all elements", function()
            
            local data = { "sword", "apple" }
            local items = itemsLoader:load(data)
            
            expect(match(items, { "sword", "apple" })).to.be.ok()
        end)
        it("should discart all if some bad element", function()
            
            local data = { "armor", 5, "cavalo" }
            local items = itemsLoader:load(data)
            
            expect(items).to.be.equal(nil)
        end)
        
        it("should discart just bad elements", function()
            
            itemsLoader:enableCorrection()
            
            local data = { "armor", 5, "cavalo" }
            local items = itemsLoader:load(data)
            
            expect(match(items, { "armor", "cavalo" })).to.be.ok()
            expect(match(data, { "armor", "cavalo" })).to.be.ok()
        end)
        it("should discart when miss data", function()
            
            itemsLoader:enableCorrection()
            
            local color = itemsLoader:load("not a array")
            expect(color).to.be.equal(nil)
        end)
        
        it("should load default data", function()
            
            itemsLoader:setUniqueDefaultData({})
            
            local items = itemsLoader:load(nil)
            expect(match(items, {})).to.be.ok()
        end)
        it("shouldnt give same default data address", function()
            
            itemsLoader:setUniqueDefaultData({})
            
            local defaultItems1 = itemsLoader:load()
            local defaultItems2 = itemsLoader:load()
            
            expect(defaultItems1).to.be.ok()
            expect(defaultItems2).to.be.ok()
            expect(defaultItems1).never.to.be.equal(defaultItems2)
        end)
    end)
    
    describe("set data loader", function()
        
        local setLoader = DataLoader.set(
            DataLoader.integer(),
            DataLoader.string()
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
            }))
        end)
        it("should discart all if some bad pair", function()
            
            local data = {
                { index = 1, value = "sword" },
                { index = "maxItems", value = 5 },
                { index = 10, value = "armor" },
                { index = 15, value = 15 },
            }
            local inventory = setLoader:load(data)
            
            expect(inventory).to.be.equal(nil)
        end)
        
        it("should discart bad indexes", function()
            
            setLoader:enableCorrection()
            
            local data = {
                { index = 1, value = "sword" },
                { index = "maxItems", value = 5 },
                { index = 10, value = "armor" },
                { index = 15, value = 15 },
            }
            local inventory = setLoader:load(data)
            
            expect(match(inventory, {
                [1] = "sword",
                [10] = "armor"
            }))
            expect(match(data, {
                { index = 1, value = "sword" },
                { index = 10, value = "armor" },
            }))
        end)
        it("should discart when miss data", function()
            
            setLoader:enableCorrection()
            
            local set = setLoader:load("not a set")
            expect(set).to.be.equal(nil)
        end)
        
        it("should load default data", function()
            
            setLoader:setUniqueDefaultData({})
            
            local set = setLoader:load(nil)
            expect(match(set, {})).to.be.ok()
        end)
        it("shouldnt give same default data address", function()
            
            setLoader:setUniqueDefaultData({})
            
            local defaultSet1 = setLoader:load()
            local defaultSet2 = setLoader:load()
            
            expect(defaultSet1).to.be.ok()
            expect(defaultSet2).to.be.ok()
            expect(defaultSet1).never.to.be.equal(defaultSet2)
        end)
    end)
    
    describe("struct data loader", function()
        
        local itemLoader = DataLoader.struct{
            name = DataLoader.string(),
            level = DataLoader.integer(1),
            color = DataLoader.color(Color3.new())
        }
        
        it("should load all fields", function()
            
            local data = { name = "sword", level = 2, color = { R = 0, G = 255, B = 50 } }
            local item = itemLoader:load(data)
            
            expect(match(item, { name = "sword", level = 2, color = Color3.fromRGB(0, 255, 50) }))
        end)
        it("should discart all if some bad field", function()
            
            local data = { name = "sword", level = 1 }
            local item = itemLoader:load(data)
            
            expect(item).to.be.equal(nil)
        end)
        
        it("should fill missing fields", function()
            
            itemLoader:enableCorrection()
            
            local data = { name = "sword", level = 1 }
            local item = itemLoader:load(data)
            
            expect(match(item, {
                name = "sword",
                level = 1,
                color = Color3.new()
            }))
            expect(match(data, {
                name = "sword",
                level = 1,
                color = { R = 0, G = 0, B = 0 }
            }))
        end)
        it("should discart when miss a required field", function()
            
            itemLoader:enableCorrection()
            
            local data = { level = 3, color = { R = 0, G = 0, B = 0 } }
            local item = itemLoader:load(data)
            
            expect(item).to.be.equal(nil)
        end)
        it("should discart when miss data", function()
            
            itemLoader:enableCorrection()
            
            local item = itemLoader:load("not a table")
            expect(item).to.be.equal(nil)
        end)
        
        it("should consider fields to inferring default data", function()
            
            itemLoader:setUniqueDefaultData()
            itemLoader.name:optional()
            
            local item = itemLoader:load(nil)
            expect(match(item, { level = 1, color = Color3.new() })).to.be.ok()
        end)
        it("shouldnt give same default data address", function()
            
            itemLoader:setUniqueDefaultData()
            itemLoader.name:optional()
            
            local defaultItem1 = itemLoader:load()
            local defaultItem2 = itemLoader:load()
            
            expect(defaultItem1).to.be.ok()
            expect(defaultItem2).to.be.ok()
            expect(defaultItem1).never.to.be.equal(defaultItem2)
        end)
    end)
end
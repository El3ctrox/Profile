return function()
    
    local ProfileStore = require(script.Parent.Parent)
    local playersProfileStore = ProfileStore.get("Players") -- cached
    
    it("should cache profile by name", function()
        
        local playersProfileStore2 = ProfileStore.get("Players")
        
        expect(playersProfileStore).never.be.equal(playersProfileStore2)
    end)
    
    describe(":loadAsync()", function()
        
        it("can be refreshed", function()
            
            local profile = playersProfileStore:get("profile1") -- automaticly :loadAsync()
            
            task.wait(5)
            profile:refreshAsync()
        end)
        it("can overwrite without activated", function()
            
            local profile = playersProfileStore:get("profile2")
            
            profile.data.b = 10
            profile:overwriteAsync()
        end)
        
        it("should keep pending cache", function()
            
            local profile = playersProfileStore:get("profile3")
            
            local loading1 = profile:loadAsync()
            local loading2 = profile:loadAsync()
            
            expect(loading1).to.be.equals(loading2)
        end)
        it("should keep resolved cache", function()
            
            local profile = playersProfileStore:get("profile4")
            
            local loading1 = profile:loadAsync()
            loading1:await()
            
            local loading2 = profile:loadAsync()
            expect(loading1).to.be.equals(loading2)
        end)
        it("should retry when fail cached loading", function()
            
            local profile = playersProfileStore:get("profile5")
            
            local loading1 = profile:loadAsync()
            loading1:_reject("generic error")
            
            local loading2 = profile:loadAsync()
            expect(loading1).never.be.equal(loading2)
        end)
    end)
    describe(":activateAsync()", function()
        
        it("cant be refreshed", function()
            
            local profile = playersProfileStore:get("profile1") -- automaticly :loadAsync()
            
            task.wait(5)
            local success = profile:refreshAsync():await()
            
            expect(success).to.be.ok()
        end)
        it("can be saved", function()
            
            local profile = playersProfileStore:get("profile2")
            
            profile.data.b = 10
            profile:saveAsync()
        end)
        it("can be saved with :overwrite", function()
            
            local profile = playersProfileStore:get("profile2")
            
            profile.data.b = 10
            profile:overwriteAsync()
        end)
        
        it("should keep pending cache", function()
            
            local profile = playersProfileStore:get("profile3")
            
            local loading1 = profile:activateAsync()
            local loading2 = profile:activateAsync()
            
            expect(loading1).to.be.equals(loading2)
        end)
        it("should keep resolved cache", function()
            
            local profile = playersProfileStore:get("profile4")
            
            local loading1 = profile:activateAsync()
            loading1:await()
            
            local loading2 = profile:activateAsync()
            expect(loading1).to.be.equals(loading2)
        end)
        it("should retry when fail cached loading", function()
            
            local profile = playersProfileStore:get("profile5")
            
            local loading1 = profile:activateAsync()
            loading1:_reject("generic error")
            
            local loading2 = profile:activateAsync()
            expect(loading1).never.be.equal(loading2)
        end)
    end)
end
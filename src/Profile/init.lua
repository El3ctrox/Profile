--!strict

--// Packages
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataLoader = require(ReplicatedStorage.Packages.DataLoader)

-- local ProfileService = require(ReplicatedStorage.Packages.ProfileService)
type ProfileStore = table   -- ProfileService.ProfileStore
type ActiveUpdate = table   -- ProfileService.ActiveUpdate

local Promise = require(ReplicatedStorage.Packages.Promise)
type Promise = table    -- Promise.Promise

local GlobalUpdate = require(script.GlobalUpdate)
type GlobalUpdate = GlobalUpdate.GlobalUpdate

type table = { [string]: any }

--// Component
local Profile = {}

--// Functions
function Profile.new(profileEntry: string|any, profileStore: ProfileStore)
    
    profileEntry = tostring(profileEntry)
    
    local meta = { __metatable = "locked" }
    local self = setmetatable({ type = "Profile" }, meta)
    
    local dataLoader = DataLoader.struct{}
    local dataHandlers = setmetatable({}, { __mode = "k" })
    local updateHandlers = {} :: { [string]: (globalUpdate: GlobalUpdate) -> () }
    local globalUpdates = {} :: { [number]: GlobalUpdate }
    local loadedProfile: Profile?
    
    self.globalUpdate = updateHandlers
    self.dataLoader = dataLoader
    self.data = nil :: table?
    
    --// Methods
    local function getGlobalUpdate(updateId: number, updateData: table, activeUpdate: ActiveUpdate?): GlobalUpdate
        
        assert(loadedProfile, `profile must to be loaded`)
        
        local globalUpdate = globalUpdates[updateId]
            or GlobalUpdate.new(loadedProfile, updateId, updateData, activeUpdate)
        
        globalUpdates[updateId] = globalUpdate
        return globalUpdate
    end
    local function handleGlobalUpdates(profile: Profile)
        
        local function handleLockedUpdate(updateId, updateData)
            
            local updateHandler = updateHandlers[updateData.type]
            if not updateHandler then return end
            
            local globalUpdate = getGlobalUpdate(updateId, updateData)
            if not pcall(updateHandler, globalUpdate) then return end
            
            if self:isActive() then globalUpdate:clear() end
        end
        local function handleActiveUpdate(updateId, updateData)
            
            local globalUpdate = getGlobalUpdate(updateId, updateData)
            if self:isActive() then globalUpdate:lock() end
        end
        
        profile.GlobalUpdates:ListenToNewActiveUpdate(handleActiveUpdate)
        profile.GlobalUpdates:ListenToNewLockedUpdate(handleLockedUpdate)
        
        for _,update in profile.GlobalUpdates:GetLockedUpdates() do
            
            handleLockedUpdate(update[1], update[2])
        end
    end
    
    function self:activateUpdate(type: string, data: table)
        
        profileStore:GlobalUpdateProfileAsync(
            profileEntry,
            function(activeUpdate)
                
                local safeData = table.clone(data)
                safeData.type = type
                
                activeUpdate:AddActiveUpdate(safeData)
            end
        )
    end
    function self:getLockedUpdatesAsync(): Promise
        
        return Promise.try(function()
            
            if not loadedProfile then self:previewAsync():expect() end
            assert(loadedProfile, `impossible fail: luau intellisense fix`)
            
            return loadedProfile.GlobalUpdates:GetLockedUpdates()
        end)
    end
    function self:getActiveUpdatesAsync(): Promise
        
        return Promise.try(function()
            
            if not loadedProfile then self:previewAsync():expect() end
            assert(loadedProfile, `impossible fail: luau intellisense fix`)
            
            return loadedProfile.GlobalUpdates:GetLockedUpdates()
        end)
    end
    
    type notReleasedHandler = (placeId: number, gameJobId: string) -> "Steal"|"Repeat"|"Cancel"|"ForceLoad"
    function self:activateAsync(notReleaseHandler: "Steal"|"ForceLoad"|notReleasedHandler?): Promise
        
        return Promise.new(function(resolve, reject, onCancel)
            
            local hasCancelled = false
            onCancel(function() hasCancelled = true end)
            
            loadedProfile = profileStore:LoadProfileAsync(profileEntry, notReleaseHandler)
            
            assert(loadedProfile, `has not possible load profile({self})`)
            if hasCancelled then return loadedProfile:Release() end
            
            local data = loadedProfile.Data
            local loadedData = dataLoader:load(data)
            
            for _,dataHandler in dataHandlers do dataHandler:set(loadedData) end
            self.data = data
            
            handleGlobalUpdates(loadedProfile)
            resolve(data)
        end)
    end
    function self:previewAsync(version: string?): Promise
        
        return Promise.new(function(resolve, reject, onCancel)
            
            local hasCancelled = false
            onCancel(function() hasCancelled = true end)
            
            assert(not self:isActive(), `unable to preview a active profile`)
            
            loadedProfile = profileStore:ViewProfileAsync(profileEntry, version)
            if hasCancelled then return end
            
            assert(loadedProfile, `hasnt possible preview profile({self})`)
            
            local data = loadedProfile.Data
            local loadedData = dataLoader:load(data)
            
            for _,dataHandler in dataHandlers do dataHandler:set(loadedData) end
            self.data = data
            
            resolve(data)
        end)
    end
    function self:getDataAsync(): Promise
        
        return Promise.new(function(resolve, reject, onCancel)
            
            if not loadedProfile then
                
                local promise = self:previewAsync()
                onCancel(function() promise:cancel() end)
                
                promise:expect()
            end
            
            resolve(self.data)
        end)
    end
    
    function self:overwriteAsync(): Promise
        
        return Promise.try(function()
            
            assert(loadedProfile and not self:isActive(), `profile must to be viewing`)
            
            loadedProfile:OverwriteAsync()
        end)
    end
    function self:releaseAsync(): Promise
        
        return Promise.new(function(resolve)
            
            assert(loadedProfile and self:isActive(), `profile must to be active`)
            
            loadedProfile:Release()
            loadedProfile:ListenToHopReady(resolve)
        end)
    end
    function self:saveAsync(): Promise
        
        return Promise.try(function()
            
            assert(loadedProfile and self:isActive(), `profile must to be active`)
            
            loadedProfile:Save()
        end)
    end
    
    function self:queryVersions(sortDirection: Enum.SortDirection, minimumDate: number, maximumDate: number)--: ProfileVersionQuery
        
        return profileStore:ProfileVersionQuery(profileEntry, sortDirection, minimumDate, maximumDate)
    end
    function self:getProfile(): Profile?
        
        return loadedProfile
    end
    function self:isActive(): boolean
        
        if not loadedProfile then return false end
        return loadedProfile:IsActive()
    end
    
    function self:handle(container: Instance)
        
        local handler = dataLoader:handle(container)
        
        dataHandlers[container] = handler
        return handler
    end
    function self:findHandler(container: Instance)
        
        return dataHandlers[container]
    end
    function self:getHandler(container: Instance)
        
        return self:findHandler(container) or self:handle(container)
    end
    
    --// End
    return self
end

--// End
export type Profile = typeof(Profile.wrap())
return Profile
--!strict

--// Packages
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataLoader = require(ReplicatedStorage.Packages.DataLoader)
---@diagnostic disable-next-line: undefined-type
type DataHandler = DataLoader.DataHandler<table, table>
---@diagnostic disable-next-line: undefined-type
type DataLoader = DataLoader.DataLoader<table, table>

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
    self.dataLoader = dataLoader :: DataLoader
    self.dataHandler = nil :: DataHandler?
    
    --// Utils
    type notReleasedHandler = (placeId: number, gameJobId: string) -> "Repeat"|"Cancel"|notReleasedOption
    type notReleasedOption = "Steal"|"ForceLoad"
    
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
    local function previewAsync(version: string?)
        
        return Promise.new(function(resolve, reject, onCancel)
            
            local hasCancelled = false
            onCancel(function() hasCancelled = true end)
            
            assert(not self:isActive(), `unable to preview a active profile`)
            loadedProfile = profileStore:ViewProfileAsync(profileEntry, version)
            
            assert(loadedProfile, `hasnt possible preview profile({self})`)
            if hasCancelled then return end
            
            resolve(loadedProfile.data)
        end)
    end
    local function activateAsync(notReleasedHandler: notReleasedOption|notReleasedHandler)
        
        return Promise.new(function(resolve, reject, onCancel)
            
            local hasCancelled = false
            onCancel(function() hasCancelled = true end)
            
            loadedProfile = profileStore:LoadProfileAsync(profileEntry, notReleasedHandler)
            
            assert(loadedProfile, `has not possible activate profile({self})`)
            if hasCancelled then return loadedProfile:Release() end
            
            resolve(loadedProfile.data)
        end)
    end
    local function loadData(data)
        
        local loadedData = DataLoader:load(data)
        for _,dataHandler in dataHandlers do dataHandler:set(loadedData) end
    end
    
    --// Caches
    local previewingVersions = {} :: { [string]: Promise }
    local handlingActiveProfile: Promise?
    local loadingProfile: Promise?  -- previewing or activated profile
    local loadingData: Promise?
    
    --// Cached Methods
    function self:previewVersionAsync(version: string): Promise
        
        if not previewingVersions[version] then
            
            previewingVersions[version] = previewAsync(version)
        end
        
        return previewingVersions[version]
    end
    function self:previewLatestAsync(): Promise
        
        if not loadingProfile then
            
            loadingProfile = previewAsync()
            handlingActiveProfile = nil
            loadingData = nil
        end
        
        return loadingProfile
    end
    function self:activateAsync(notReleasedHandler: notReleasedOption|notReleasedHandler?): Promise
        
        if not self:isActive() then
            
            loadingProfile = activateAsync(notReleasedHandler)
            loadingData = nil
        end
        if not loadingData then
            
            loadingData = loadingProfile:andThenCall(loadData)
            handlingActiveProfile = nil
        end
        if not handlingActiveProfile then
            
            handlingActiveProfile = loadingData:tap(handleGlobalUpdates)
        end
        
        return handlingActiveProfile
    end
    function self:refreshAsync(): Promise
        
        loadingProfile = self:previewLatestAsync()
        loadingData = loadingProfile:andThenCall(loadData)
        
        if self:isActive() then
            
            loadingData:tap(handleGlobalUpdates)
        end
        
        return loadingData
    end
    function self:loadAsync(): Promise
        
        if not loadingProfile then
            
            loadingProfile = self:previewLatestAsync()
            loadingData = nil
        end
        if not loadingData then
            
            loadingData = loadingProfile:andThenCall(loadData)
            handlingActiveProfile = nil
        end
        
        return loadingData
    end
    
    --// Methods
    function self:activateUpdate(type: string, data: table)
        
        profileStore:GlobalUpdateProfileAsync(
            profileEntry,
            function(updateHandler)
                
                local safeData = table.clone(data)
                safeData.type = type
                
                updateHandler:AddActiveUpdate(safeData)
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
    
    function self:overwriteAsync(): Promise
        
        return Promise.try(function()
            
            assert(loadedProfile, `profile must to be loaded`)
            
            if loadedProfile:IsActive() then
                
                loadedProfile:Save()
            else
                
                loadedProfile:OverwriteAsync()
            end
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
    function self:isActive(): boolean
        
        if not loadedProfile then return false end
        return loadedProfile:IsActive()
    end
    function self:isLoaded(): boolean
        
        return loadingProfile and loadingProfile:getStatus() == Promise.Status.Resolved
    end
    
    function self:wrapHandler(container: Instance?)
        
        if container then
            
            self.dataHandler = dataLoader:handle(container)
            
        elseif self.dataHandler then
            
            self.dataHandler:unwrap()
        end
        
        return self.dataHandler
    end
    
    --// End
    return self
end

--// End
export type Profile = typeof(Profile.wrap())
return Profile
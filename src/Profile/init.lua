--!strict

--// Packages
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataLoader = require(ReplicatedStorage.Packages.DataLoader)
type DataHandler = table    -- DataLoader.DataHandler<table, table>
type DataLoader = table -- DataLoader.DataLoader<table, table>

-- local ProfileService = require(ReplicatedStorage.Packages.ProfileService)
type ProfileStore = table   -- ProfileService.ProfileStore
type ActiveUpdate = table   -- ProfileService.ActiveUpdate
type pureProfile = table    -- ProfileService.Profile

local Promise = require(ReplicatedStorage.Packages.Promise)
type Promise<Value...> = typeof(Promise.new())    -- Promise.Promise

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
    
    self.globalUpdate = updateHandlers
    self.dataLoader = dataLoader :: DataLoader
    self.dataHandler = nil :: DataHandler?
    
    --// Utils
    type notReleasedHandler = (placeId: number, gameJobId: string) -> "Repeat"|"Cancel"|notReleasedOption
    type notReleasedOption = "Steal"|"ForceLoad"
    
    local function getGlobalUpdate(activeProfile: pureProfile, updateId: number, updateData: table, activeUpdate: ActiveUpdate?): GlobalUpdate
        
        assert(activeProfile, `profile must to be loaded`)
        
        local globalUpdate = globalUpdates[updateId]
            or GlobalUpdate.new(activeProfile, updateId, updateData, activeUpdate)
        
        globalUpdates[updateId] = globalUpdate
        return globalUpdate
    end
    local function handleGlobalUpdates(profile: pureProfile)
        
        local function handleLockedUpdate(updateId, updateData)
            
            local updateHandler = updateHandlers[updateData.type]
            if not updateHandler then return end
            
            local globalUpdate = getGlobalUpdate(profile, updateId, updateData)
            if not pcall(updateHandler, globalUpdate) then return end
            
            if self:isActive() then globalUpdate:clear() end
        end
        local function handleActiveUpdate(updateId, updateData)
            
            local globalUpdate = getGlobalUpdate(profile, updateId, updateData)
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
            
            local loadedProfile = profileStore:ViewProfileAsync(profileEntry, version)
            assert(loadedProfile, `hasnt possible preview profile({self})`)
            
            if onCancel() then return end
            resolve(loadedProfile)
        end)
    end
    local function activateAsync(notReleasedHandler: notReleasedOption|notReleasedHandler)
        
        return Promise.new(function(resolve, reject, onCancel)
            
            local activatedProfile = profileStore:LoadProfileAsync(profileEntry, notReleasedHandler)
            assert(activatedProfile, `has not possible activate profile({self})`)
            
            if onCancel() then return activatedProfile:Release() end
            resolve(activatedProfile)
        end)
    end
    local function loadData(profile)
        
        local data = profile.data
        local loadedData = dataLoader:load(data)
        
        for _,dataHandler in dataHandlers do dataHandler:set(loadedData) end
    end
    
    --// Caches
    local previewingVersions = {} :: { [string]: Promise }
    local profileHandling: Promise<pureProfile>?
    local lastProfileLoading: Promise<pureProfile>?  -- rollback if fail to load new profile
    local profileLoading: Promise<pureProfile>?
    local lastDataLoading: Promise<table>?   -- rollback if fail to load new data
    local dataLoading: Promise<table>?
    local activation = false
    
    --// Cached Methods
    function self:previewVersionAsync(version: string): Promise<pureProfile>
        
        if not previewingVersions[version] then
            
            previewingVersions[version] = previewAsync(version)
        end
        
        return previewingVersions[version]
    end
    function self:previewLatestAsync(): Promise<pureProfile>
        
        return previewAsync()
    end
    
    function self:activateAsync(notReleasedHandler: notReleasedOption|notReleasedHandler?): Promise<table>
        
        if not activation or activation:getStatus() == Promise.Status.Rejected then
            
            local newLoading; newLoading = activateAsync(notReleasedHandler)
                :tap(function() lastProfileLoading = newLoading end)
                :catch(function() profileLoading = lastProfileLoading end)
            
            profileLoading = newLoading
            activation = newLoading
            dataLoading = nil
        end
        if not dataLoading then
            
            local newDataLoading; newDataLoading = profileLoading:andThen(loadData)
                :tap(function() lastDataLoading = newDataLoading end)
                :catch(function() dataLoading = lastDataLoading end)
            
            dataLoading = newDataLoading
            profileHandling = nil
        end
        if not profileHandling then
            
            profileHandling = profileLoading
                :tap(function() dataLoading:await() end)
                :tap(handleGlobalUpdates)
        end
        
        return profileHandling
    end
    function self:refreshAsync(): Promise<table>
        
        assert(not self:isActive(), `isnt possible refresh a active profile (i need a solution for it)`)
        
        local newLoading; newLoading = previewAsync()
            :tap(function() lastProfileLoading = newLoading end)
            :catch(function() profileLoading = lastProfileLoading end)
        
        local newDataLoading; newDataLoading = profileLoading:andThen(loadData)
            :tap(function() lastDataLoading = newDataLoading end)
            :catch(function() dataLoading = lastDataLoading end)
        
        profileLoading = newLoading
        dataLoading = newDataLoading
        return dataLoading
    end
    function self:loadAsync(): Promise<table>
        
        if not profileLoading or profileLoading:getStatus() == Promise.Status.Rejected then
            
            local newLoading; newLoading = previewAsync()
                :tap(function() lastProfileLoading = newLoading end)
                :catch(function() profileLoading = lastProfileLoading end)
            
            profileLoading = newLoading
            dataLoading = nil
        end
        if not dataLoading then
            
            local newDataLoading; newDataLoading = profileLoading:andThen(loadData)
                :tap(function() lastDataLoading = newDataLoading end)
                :catch(function() dataLoading = lastDataLoading end)
            
            dataLoading = newDataLoading
            profileHandling = nil
        end
        
        return dataLoading
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
    function self:getLockedUpdatesAsync(): Promise<{GlobalUpdate}>
        
        return profileLoading:andThen(function(profile)
            
            return profile.GlobalUpdates:GetLockedUpdates()
        end)
    end
    function self:getActiveUpdatesAsync(): Promise<{GlobalUpdate}>
        
        return profileLoading:andThen(function(profile)
            
            return profile.GlobalUpdates:GetActiveUpdates()
        end)
    end
    
    function self:overwriteAsync(): Promise
        
        return profileLoading:andThen(function(profile)
            
            if profile:IsActive() then
                
                profile:Save()
            else
                
                profile:OverwriteAsync()
            end
        end)
    end
    function self:releaseAsync(): Promise
        
        return Promise.new(function(resolve)
            
            assert(activation, `profile hasnt activated`)
            
            local profile = activation:expect()
            if profileHandling then profileHandling:await() end
            
            profile:Release()
            profile:ListenToHopReady(resolve)
            
            profileLoading = nil
            activation = nil
        end)
    end
    function self:saveAsync(): Promise
        
        return profileLoading:andThen(function(profile)
            
            assert(profile:IsActive(), `profile must to be active`)
            profile:Save()
        end)
    end
    
    function self:queryVersions(sortDirection: Enum.SortDirection, minimumDate: number, maximumDate: number)--: ProfileVersionQuery
        
        return profileStore:ProfileVersionQuery(profileEntry, sortDirection, minimumDate, maximumDate)
    end
    function self:isActive(): boolean
        
        local isLoaded, profile = profileLoading:now():await()
        return isLoaded and profile:IsActive() or false
    end
    function self:isLoaded(): boolean
        
        return profileLoading and profileLoading:getStatus() == Promise.Status.Resolved
    end
    
    function self:wrapHandler(container: Instance?)
        
        assert(not self.dataHandler, `already exists a handler wrapped for this profile`)
        
        if container then
            
            self.dataHandler = dataLoader:wrapHandler(container)
            container.Destroying:Once(function() self.dataHandler = nil end)
            
        elseif self.dataHandler then
            
            self.dataHandler:unwrap()
        end
        
        return self.dataHandler
    end
    
    --// End
    self:loadAsync()
    return self
end

--// End
export type Profile = typeof(Profile.wrap())
return Profile
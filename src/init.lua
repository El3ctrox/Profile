--!strict

--// Packages
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local wrapper = require(ReplicatedStorage.Packages.Wrapper)

local Promise = require(ReplicatedStorage.Packages.Promise)
type Promise = typeof(Promise.new())

local ProfileService = require(ReplicatedStorage.Packages.ProfileService)
type ProfileVersionQuery = { NextAsync: (self: unwrappedProfile) -> unwrappedProfile? }
type unwrappedProfile = table    -- ProfileService.Profile
type ActiveUpdate = table

local Profile = require(script.Profile)
type Profile = Profile.Profile

type table = { [string]: any }

--// Component
local ProfileStore = {}
local profileStores = setmetatable({}, { __mode = "k" })

--// Functions
function ProfileStore.new(profileStoreName: string)
    
    local profileStore = ProfileService.GetProfileStore(profileStoreName, {})
    
    local meta = { __metatable = "locked" }
    local self = setmetatable({ type = "ProfileStore" }, meta)
    local profiles = setmetatable({}, { __mode = "k" })
    
    self.name = profileStoreName
    
    --// Methods
    function self:query(profileEntry: string|any, sortDirection: Enum.SortDirection, minimumDate: number, maximumDate: number): ProfileVersionQuery
        
        profileEntry = tostring(profileEntry)
        return profileStore:ProfileVersionQuery(profileEntry, sortDirection, minimumDate, maximumDate)
    end
    function self:find(profileEntry: string|any): Profile?
        
        profileEntry = tostring(profileEntry)
        return profiles[profileEntry]
    end
    function self:get(profileEntry: string|any): Profile
        
        return self:find(profileEntry) or self:_new(profileEntry)
    end
    
    --// Protected
    function self:_new(profileEntry: string|any): Profile
        
        profileEntry = tostring(profileEntry)
        
        local profile = Profile.new(profileEntry, profileStore)
        profiles[profileEntry] = profile
        
        return profile
    end
    
    --// End
    profileStores[profileStoreName] = self
    return self
end
function ProfileStore.find(profileStoreName: string): ProfileStore?
    
    return profileStores[profileStoreName]
end
function ProfileStore.get(profileStoreName: string): ProfileStore
    
    return ProfileStore.find(profileStoreName) or ProfileStore.new(profileStoreName)
end

--// End
export type ProfileStore = typeof(ProfileStore.new(""))
return ProfileStore
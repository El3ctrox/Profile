--!strict

--// Packages
--local ProfileService = require(script.Parent.Parent.Parent.ProfileService)
type ActiveUpdate = table
type Profile = table

type table = { [string]: any }

--// Component
local GlobalUpdate = {}

--// Functions
function GlobalUpdate.new(profile: Profile, id: number, data: table, activeUpdate: ActiveUpdate?)
	
	local meta = { __metatable = "locked" }
	local self = setmetatable({ type = "GlobalUpdate" }, meta)
	self.isLocked = activeUpdate == nil
	self.isActive = activeUpdate ~= nil
	self.isCleared = false
	self.id = id
	
	--// Methods
	function self:setData(newData: table)
		
		assert(activeUpdate, `attempt to change a locked update`)
		
		activeUpdate:ChangeActiveUpdate(self.id, newData)
		data = newData
	end
	function self:getData()
		
		return data
	end
	
	function self:lock()
		
		assert(profile:IsActive(), `profile must to be active to lock a update`)
		
		profile.GlobalUpdates:LockActiveUpdate(self.id)
		self.isActive = false
		self.isLocked = true
	end
	function self:clear()
		
		assert(profile:IsActive(), `profile must to be active to clear a locked update`)
		
		if self.isActive then
			
			activeUpdate:ClearActiveUpdate(self.id)
			self.isActive = false
		else
			
			profile.GlobalUpdates:ClearLockedUpdate(self.id)
			self.isLocked = false
		end
		
		self.isCleared = true
	end
	
	--// End
	return self
end

--// End
export type GlobalUpdate = typeof(GlobalUpdate.new({}, 1, {}))
return GlobalUpdate
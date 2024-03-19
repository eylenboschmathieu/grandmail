local addon, core = ...

core.Mixins = {
	WidgetPoolMixin = {},
}

-- WidgetPool
	function core.Mixins.WidgetPoolMixin:OnLoad(parent, backgroundTemplate, creationFunc, acquireFunc, releaseFunc)
		self.activeWidgets = {}
		self.inactiveWidgets = {}
		self.nActiveWidgets = 0
		
		self.parent = parent
		self.backgroundTemplate = backgroundTemplate
		
		self.creationFunc = creationFunc
		self.acquireFunc = acquireFunc
		self.releaseFunc = releaseFunc
	end
	
	function core.Mixins.WidgetPoolMixin:Acquire(...)
		local nInactiveWidgets = #self.inactiveWidgets
		local widget
		if nInactiveWidgets > 0 then
			widget = self.inactiveWidgets[nInactiveWidgets]
			self.inactiveWidgets[nInactiveWidgets] = nil
		else
			widget = self.creationFunc()
		end
		
		self.nActiveWidgets = self.nActiveWidgets + 1
		self.activeWidgets[widget] = true
		if self.acquireFunc then
			self.acquireFunc(widget, ...)
		end
		
		return widget
	end
	
	function core.Mixins.WidgetPoolMixin:Release(widget)
		assert(self.activeWidgets[widget])
		
		self.inactiveWidgets[#self.inactiveWidgets + 1] = widget
		self.activeWidgets[widget] = nil
		self.nActiveWidgets = self.nActiveWidgets - 1
		if self.releaseFunc then
			self.releaseFunc(widget)
		end
	end
	
	function core.Mixins.WidgetPoolMixin:Reset()
		for widget in pairs(self.activeWidgets) do
			self:Release(widget)
		end
	end
	
	function core.Mixins.WidgetPoolMixin:GetNumActiveWidgets()
		return self.nActiveWidgets
	end
	
	function core.Mixins.WidgetPoolMixin:GetNumInactiveWidgets()
		return #self.inactiveWidgets
	end
	
	function core.Mixins.WidgetPoolMixin:GetNumTotalWidgets()
		return self:GetNumActiveWidgets() + self:GetNumInactiveWidgets()
	end
	
	function core.Mixins.WidgetPoolMixin:EnumerateActiveWidgets()
		print("-- Active Widgets")
		local i = 0
		for k,v in pairs(self.activeWidgets) do
			i = i + 1
			print(k)
		end
		if i == 0 then print("No active widgets") end
	end
	
	function core.Mixins.WidgetPoolMixin:EnumerateInactiveWidgets()
		print("-- Inactive Widgets")
		if #self.inactiveWidgets == 0 then
			print("No inactive widgets")
		else
			for i,v in ipairs(self.inactiveWidgets) do
				print(i,v)
			end
		end
	end
	
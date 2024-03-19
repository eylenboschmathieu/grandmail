local addon, core = ...
local L = core.L

TopLevel = CreateFrame("FRAME", nil, core.OrdersFrame:GetScrollChild())
TopLevel.CollapseButton = CreateFrame("BUTTON", nil, TopLevel, "BackdropTemplate")
TopLevel.EditButton = CreateFrame("BUTTON", nil, TopLevel, "BackdropTemplate")
TopLevel.AndButton = CreateFrame("BUTTON", nil, TopLevel, "BackdropTemplate")
TopLevel.OrButton = CreateFrame("BUTTON", nil, TopLevel, "BackdropTemplate")
TopLevel.NotButton = CreateFrame("BUTTON", nil, TopLevel, "BackdropTemplate")
TopLevel.FilterButton = CreateFrame("BUTTON", nil, TopLevel, "BackdropTemplate")
TopLevel.DeleteButton = CreateFrame("BUTTON", nil, TopLevel, "BackdropTemplate")
TopLevel.FilterSelection = CreateFrame("FRAME", nil, TopLevel, "BackdropTemplate")

--[[================

	Constants

==================]]

local ENUM_CONSUMABLE = Enum.ItemClass.Consumable
local ENUM_GEM = Enum.ItemClass.Gem
local ENUM_ITEM_ENHANCEMENT = Enum.ItemClass.ItemEnhancement
local ENUM_TRADEGOODS = Enum.ItemClass.Tradegoods
local ENUM_RECIPE = Enum.ItemClass.Recipe

------

core.OrdersFrame.TopLevel = TopLevel
core.Entries = {}
local Filters = {}
core.Filters = Filters

local AssociatedFrame = false
local AssociatedFrame_Filter = false

core.CorrectionList = {
-- BFA
	[158327] = {8, 12},
	[158203] = {8, 12},
	[158377] = {8, 12},
	[158212] = {8, 12},
	
-- SL
	[172921] = {8, 12},
	[172920] = {8, 12},
	
-- Dragonflight
	-- Scopes
	[198310] = {8, 12},
	[198311] = {8, 12},
	[198312] = {8, 12},
	[198313] = {8, 12},
	[198314] = {8, 12},
	[198315] = {8, 12},
	[198316] = {8, 12},
	[198317] = {8, 12},
	[198318] = {8, 12},
	
	-- Medallion Setting
	[192992] = {8, 1},
	[192993] = {8, 1},
	[192994] = {8, 1},
	
	--Armor Kits
	[193556] = {8, 8}, -- Frosted [0]
	[193560] = {8, 8}, -- Frosted [1]
	[193564] = {8, 8}, -- Frosted [2]
	[193557] = {8, 8}, -- Fierce [0]
	[193561] = {8, 8}, -- Fierce [1]
	[193565] = {8, 8}, -- Fierce [2]
	[193559] = {8, 8}, -- Reinforced [0]
	[193563] = {8, 8}, -- Reinforced [1]
	[193567] = {8, 8}, -- Reinforced [2]
	
	-- Spellthread
	[194008] = {8, 8}, -- Vibrant [0]
	[194009] = {8, 8}, -- Vibrant [1]
	[194010] = {8, 8}, -- Vibrant [2]
	[194011] = {8, 8}, -- Frozen [0]
	[194012] = {8, 8}, -- Frozen [1]
	[194013] = {8, 8}, -- Frozen [2]
	[194014] = {8, 8}, -- Temporal [0]
	[194015] = {8, 8}, -- Temporal [1]
	[194016] = {8, 8} -- Temporal [2]
}

local function UpdateFrameHeight(self)
	local height, nSub = 32, 30
	if self.isCollapsed then
		self.texture1:SetHeight(2)
	else
		for i,v in ipairs(self.Children) do
			height = height + v:GetHeight()
		end
		
		if #self.Children > 0 then
			local h = self.Children[#self.Children]:GetHeight()
			if h > 32 then
				nSub = nSub + (h - 32)
			end
		end
		self.texture1:SetHeight(height - nSub)
	end
	
	self:SetHeight(height)
	if self:GetParent().UpdateFrameHeight then
		self:GetParent():UpdateFrameHeight()
	end
end

local FramePool = core.CreateWidgetPool(TopLevel,
	function()
	-- Used for AND, OR, and NOT groups
		local frame = CreateFrame("FRAME", nil, nil, "BackdropTemplate")
				
		frame:SetBackdrop(core.defaultBackdrop)
		frame:SetBackdropColor(0, 0, 0, 0)
		frame:SetBackdropBorderColor(0, 0, 0, 0)
		frame:SetClipsChildren(true)
		
		frame.Children = {}
		frame.isCollapsed = false
		frame.groupLevel = false
		frame.groupType = false
		frame.hasAmountFilter = false
		frame.UpdateFrameHeight = UpdateFrameHeight
		
		local tex = frame:CreateTexture()
		frame.texture1 = tex;
		tex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
		tex:SetSize(2, 2)
		tex:SetPoint("TOPLEFT", 10, -15)
		
		tex = frame:CreateTexture()
		frame.texture2 = tex;
		tex:SetTexture("Interface\\AddOns\\GrandMail\\minus-button.blp")
		tex:SetSize(12, 12)
		tex:SetPoint("TOPLEFT", 5, -10)
		tex:SetDrawLayer("ARTWORK", 1)
		
		tex = frame:CreateTexture()
		frame.texture3 = tex;
		tex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
		tex:SetSize(4, 2)
		tex:SetPoint("TOPLEFT", 0, -15)
		
	-- Title
		frame.Title = frame:CreateFontString()
		frame.Title:SetPoint("TOPLEFT", 24, -8)
		frame.Title:SetJustifyH("LEFT")
		frame.Title:SetJustifyV("MIDDLE")

		frame.Title:SetTextColor(1, 1, 1, 1)
		frame.Title:SetFont(core.fontPath, 16, "")
		frame.Title:SetText(L["OR"])
		
		frame:SetScript("OnEnter", function(self)
			TopLevel:UpdatePopupButtons(true, self)	
		end)
		frame:SetScript("OnLeave", function(self)
			TopLevel:UpdatePopupButtons(false)
		end)

		return frame
	end,
	function(frame) -- Acquire
		--print(string.format("    GetGroup: %s", tostring(frame)))
		frame.Children = {}
	end,
	function(frame) -- Release
		--print("    ReleaseGroup:", frame)
		frame:Hide()
		frame.groupType = false
		frame.groupLevel = false
		frame.isCollapsed = false
		frame.hasAmountFilter = false
		frame.texture2:SetTexture("Interface\\AddOns\\GrandMail\\minus-button.blp")
	end)
core.FramePool = FramePool

local FilterPool = core.CreateWidgetPool(nil, 
function()
	local frame = CreateFrame("FRAME", nil, nil, "BackdropTemplate")
			
	frame:SetHeight(32)
	frame:SetBackdrop(core.defaultBackdrop)
	frame:SetBackdropColor(.1, .1, .4, .2)
	frame:SetBackdropBorderColor(0, 0, 0, 0)
	frame:SetClipsChildren(true)
	
	frame.groupType = 4 
	frame.filterType = false -- Name, Amount, etc
	frame.FilterData = false -- Name string, N amount, item sub-type, etc
	
	local tex = frame:CreateTexture()
	frame.texture1 = tex;
	tex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
	tex:SetSize(4, 2)
	tex:SetPoint("TOPLEFT", 0, -15)
	
	tex = frame:CreateTexture()
	frame.texture2 = tex;
	tex:SetTexture("Interface\\Icons\\Trade_Engineering")
	tex:SetTexCoord(.16, .84, .16, .84)
	tex:SetDrawLayer("ARTWORK", 1)
	tex:SetSize(12, 12)
	tex:SetPoint("TOPLEFT", 5, -10)
	
-- Title
	frame.Title = frame:CreateFontString()
	frame.Title:SetFont(core.fontPath, 16, "")
	frame.Title:SetPoint("TOPLEFT", 24, -8)
	frame.Title:SetJustifyH("LEFT")
	frame.Title:SetJustifyV("MIDDLE")
	frame.Title:SetTextColor(1, 1, 1, 1)
	frame.Title:SetText(" ")
	
	frame:SetScript("OnEnter", function(self)
		TopLevel:UpdatePopupButtons(true, self)	
	end)
	frame:SetScript("OnLeave", function(self)
		TopLevel:UpdatePopupButtons(false)
	end)

	return frame
end,
nil,
function(frame)
	frame:Hide()
	frame.Title:SetText("")
	frame.filterType = false
	frame.FilterData = false
	frame:SetBackdropColor(.1, .1, .4, .2)
end)
core.FilterPool = FilterPool

local function CreateGroup(groupType, parent)
	if core.State == "FILTER_CREATE" or core.State == "FILTER_EDIT" then
		UIErrorsFrame:AddExternalErrorMessage(L["CONFIGURE_FILTER"])
		return
	end
	
	if parent.groupType == 3 and (#parent.Children == 1 or groupType == 3) then
		UIErrorsFrame:AddExternalErrorMessage(L["INVALID_GROUP_OR_FILTER1"])
		return
	end

	if parent.groupLevel == 10 then
		UIErrorsFrame:AddExternalErrorMessage(L["COMPLEXITY_LIMIT"])
		return
	end

	local nChildren, hookFrame, dstAnchor, xOffset, yOffset = #parent.Children + 1
	local frame = FramePool:Acquire()
	
	parent.Children[nChildren] = frame
	
	if nChildren == 1 then
		hookFrame = parent
		dstAnchor = "TOPLEFT"
		xOffset = 12
		yOffset = -32
	else
		hookFrame = parent.Children[nChildren - 1]
		dstAnchor = "BOTTOMLEFT"
		xOffset = 0
		yOffset = 0
	end
	
	local groupString
	if groupType == 1 then
		groupString = L["AND"]
	elseif groupType == 2 then
		groupString = L["OR"]
	elseif groupType == 3 then
		groupString = L["NOT"]
	end
	
	frame.Title:SetText(groupString)
	frame:SetParent(parent)
	frame:SetWidth(parent:GetWidth() - 12)
	frame:SetPoint("TOPLEFT", hookFrame, dstAnchor, xOffset, yOffset)
	frame:SetFrameLevel(parent:GetFrameLevel() + 1)
	frame.groupLevel = parent.groupLevel + 1
	frame.groupType = groupType
	
	-- print(string.format("GroupLevel: %d, GroupType: %d", frame.groupLevel, frame.groupType))
	
	frame:UpdateFrameHeight()
	frame:Show()
	
	return frame
end
core.Entries.CreateGroup = CreateGroup

local function ToggleFilter(frame)
	--print(string.format("    ToggleFilter(%s, %s)", core.State, tostring(TopLevel.EditButton.FilterInEdit)))
	if core.State == "ENTRY_EDIT" then
		core.State = "FILTER_EDIT"
		frame:SetBackdropColor(.1, .4, .1, .4)
		TopLevel.EditButton.FilterInEdit = frame
	elseif core.State == "FILTER_CREATE" then
		if TopLevel.EditButton.FilterInEdit ~= frame then
			return -- Can't edit another filter when in the process of creating one
		end
	elseif TopLevel.EditButton.FilterInEdit and TopLevel.EditButton.FilterInEdit ~= frame then -- Close the already open filter before editing this one
		TopLevel.EditButton.FilterInEdit:SetBackdropColor(.1, .1, .4, .2)
		frame:SetBackdropColor(.1, .4, .1, .4)
		ToggleFilter(TopLevel.EditButton.FilterInEdit)
		core.State = "FILTER_EDIT"
		TopLevel.EditButton.FilterInEdit = frame
	elseif core.State == "FILTER_EDIT" then
		core.State = "ENTRY_EDIT"
		TopLevel.EditButton.FilterInEdit:SetBackdropColor(.1, .1, .4, .2)
		TopLevel.EditButton.FilterInEdit = false
	end
	
	local filterType = frame.filterType
	local filter = Filters[filterType]
	if core.State == "FILTER_EDIT" or core.State == "FILTER_CREATE" then
		filter:LoadData(frame) -- Set the frames config widgets to frame.filterData
		AssociatedFrame_Filter = frame
		filter:SetParent(frame)
		local x, y = unpack(filter.offsets)
		filter:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
		frame:SetHeight(filter.height)
		if filterType < 3 then -- Name or number
			filter:SetWidth(frame:GetWidth() - 45)
		end
		frame.Title:SetText("")
		filter:Show()
	else
		if core.State ~= "ENTRY_LOAD" then
			filter:SaveData(frame)
			AssociatedFrame_Filter = false
			filter:Hide()
		end
		local str, h = filter:ToString(frame)
		frame:SetHeight(h or 32)
		frame.Title:SetText(str)
		frame.Title:Show()
		frame:Show()
		-- print(string.format("  Str: %s, Height: %d", str or "nil", h or -1)) 
	end
	frame:GetParent():UpdateFrameHeight()
end

local function CreateFilter(parent, filterType, data)
	if core.State == "FILTER_CREATE" or core.State == "FILTER_EDIT" then
		UIErrorsFrame:AddExternalErrorMessage(L["CONFIGURE_FILTER"])
		return
	end
	
	if parent.groupType == 3 and #parent.Children == 1 then
		UIErrorsFrame:AddExternalErrorMessage(L["INVALID_GROUP_OR_FILTER2"])
		return
	end
	
	if not (core.State == "ENTRY_LOAD") then
		core.State = "FILTER_CREATE"
	end
	
	local nChildren, hookFrame, dstAnchor, xOffset, yOffset = #parent.Children + 1
	
	local filterFrame = FilterPool:Acquire()
	parent.Children[nChildren] = filterFrame
	
	if nChildren == 1 then
		hookFrame = parent
		dstAnchor = "TOPLEFT"
		xOffset = 12
		yOffset = -32
	else
		hookFrame = parent.Children[nChildren - 1]
		dstAnchor = "BOTTOMLEFT"
		xOffset = 0
		yOffset = 0
	end
	
	filterFrame:SetParent(parent)
	filterFrame:SetWidth(parent:GetWidth() - 12)
	filterFrame:SetPoint("TOPLEFT", hookFrame, dstAnchor, xOffset, yOffset)
	filterFrame:SetFrameLevel(parent:GetFrameLevel() + 1)
	
	if filterType then -- Loaded from memory
		if filterType == 2 then filterFrame:GetParent().hasAmountFilter = true end
		filterFrame.texture2:Show()
		filterFrame.filterType = filterType
		Filters[filterType]:SaveData(filterFrame, data)
		ToggleFilter(filterFrame)
	else -- Created by player
		filterFrame:SetHeight(256)
		filterFrame:SetBackdropColor(.1, .4, .1, .4)
		local FilterSelection = TopLevel.FilterSelection
		FilterSelection:SetWidth(filterFrame:GetWidth())
		FilterSelection:SetHeight(256)
		AssociatedFrame_Filter = filterFrame
		FilterSelection:SetPoint("TOPLEFT", filterFrame)
		FilterSelection:Show()
		
		TopLevel.EditButton.FilterInEdit = filterFrame
	end
	
	parent:UpdateFrameHeight()
	filterFrame:Show()
end
core.Entries.CreateFilter = CreateFilter

local function OnLeave(self)
	self:SetBackdropBorderColor(0, 0, 0, 0)
	if GetMouseFocus() ~= AssociatedFrame_Filter then
		TopLevel:UpdatePopupButtons(false)
	end
end

--[[================

	User Interface

==================]]

do -- TopLevel
	TopLevel:SetSize(core.OrdersFrame.ScrollFrame:GetWidth(), 32)
	TopLevel:SetPoint("TOPLEFT", core.OrdersFrame:GetScrollChild())
	TopLevel:SetClipsChildren(true)
	TopLevel:Hide()
	
	TopLevel.Children = {}
	TopLevel.isCollapsed = false
	TopLevel.CurrentEntry = false
	TopLevel.groupLevel = 0 -- Top Level
	TopLevel.groupType = 2 -- OR
	TopLevel.UpdateFrameHeight = UpdateFrameHeight
	
	local tex = TopLevel:CreateTexture()
	TopLevel.texture1 = tex;
	tex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
	tex:SetSize(2, 2)
	tex:SetPoint("TOPLEFT", 10, -15)
	
	tex = TopLevel:CreateTexture()
	TopLevel.texture2 = tex;
	tex:SetTexture("Interface\\AddOns\\GrandMail\\plus-button.blp")
	tex:SetTexture("Interface\\AddOns\\GrandMail\\minus-button.blp") -- Set both of these so the texture gets loaded
	tex:SetSize(12, 12)
	tex:SetPoint("TOPLEFT", 5, -10)
	tex:SetDrawLayer("ARTWORK", 1)
	
	function TopLevel:UpdatePopupButtons(show, widget)
		if show then
			if widget.groupType < 4 then -- Group
				self.CollapseButton:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, -9)
				self.AndButton:SetPoint("LEFT", widget.Title, "RIGHT", 8, 0)
				
				AssociatedFrame = widget
					
				self.CollapseButton:Show()
				self.AndButton:Show()
				self.OrButton:Show()
				self.NotButton:Show()
				self.FilterButton:Show()
			else -- Filter
				self.EditButton:SetPoint("TOPLEFT", widget, "TOPLEFT", 5, -10)
				self.EditButton.AssociatedFrame = widget
				self.EditButton:Show()
			end
			
			if not widget.groupLevel or widget.groupLevel > 0 then -- Can't remove the top level 'OR'
				self.DeleteButton:SetPoint("TOPRIGHT", widget, "TOPRIGHT", -6, -6)
				self.DeleteButton.AssociatedFrame = widget
				self.DeleteButton:Show()
			end
		else
			local gmf = GetMouseFocus()
			if gmf ~= self.CollapseButton and gmf ~= self.EditButton and gmf ~= self.AndButton and gmf ~= self.OrButton and gmf ~= self.NotButton and gmf ~= self.FilterButton and gmf ~= self.DeleteButton then
				AssociatedFrame = false
				
				self.CollapseButton:Hide()
				self.EditButton:Hide()
				self.AndButton:Hide()
				self.OrButton:Hide()
				self.NotButton:Hide()
				self.FilterButton:Hide()
				self.DeleteButton:Hide()
			end
		end
	end
	
	TopLevel:SetScript("OnEnter", function(self)
		self:UpdatePopupButtons(true, self)	
	end)
	TopLevel:SetScript("OnLeave", function(self)
		self:UpdatePopupButtons(false)
	end)
	TopLevel:SetScript("OnShow", UpdateFrameHeight)

-- Title
	TopLevel.Title = TopLevel:CreateFontString()
	TopLevel.Title:SetPoint("TOPLEFT", 24, -8)
	TopLevel.Title:SetJustifyH("LEFT")
	TopLevel.Title:SetJustifyV("MIDDLE")

	TopLevel.Title:SetTextColor(1, 1, 1, 1)
	TopLevel.Title:SetFont(core.fontPath, 16, "")
	TopLevel.Title:SetText(L["OR"])
end

do -- CollapseButton
	TopLevel.CollapseButton:SetSize(14, 14)
	TopLevel.CollapseButton:SetBackdrop(core.defaultBackdrop)
	TopLevel.CollapseButton:SetBackdropColor(0, 0, 0, 0)
	TopLevel.CollapseButton:SetBackdropBorderColor(0, 0, 0, 0)
	TopLevel.CollapseButton:SetFrameLevel(500)
	TopLevel.CollapseButton:Hide()
	
	TopLevel.CollapseButton:SetScript("OnEnter", core.Scripts.OnEnter)
	TopLevel.CollapseButton:SetScript("OnLeave", OnLeave)
	TopLevel.CollapseButton:SetScript("OnClick", function(self)
		if AssociatedFrame.isCollapsed then
			AssociatedFrame.isCollapsed = false
			AssociatedFrame.texture2:SetTexture("Interface\\AddOns\\GrandMail\\minus-button.blp")
			for i,v in ipairs(AssociatedFrame.Children) do
				v:Show()
			end
		else
			AssociatedFrame.isCollapsed = true
			AssociatedFrame.texture2:SetTexture("Interface\\AddOns\\GrandMail\\plus-button.blp")
			for i,v in ipairs(AssociatedFrame.Children) do
				v:Hide()
			end
		end
		AssociatedFrame:UpdateFrameHeight()
	end)
end

do -- EditButton
	TopLevel.EditButton:SetSize(14, 14)
	TopLevel.EditButton:SetPoint("TOPLEFT", -4, -4)
	TopLevel.EditButton:SetBackdrop(core.defaultBackdrop)
	TopLevel.EditButton:SetBackdropColor(0, 0, 0, 0)
	TopLevel.EditButton:SetBackdropBorderColor(0, 0, 0, 0)
	TopLevel.EditButton:SetFrameLevel(500)
	TopLevel.EditButton:Hide()
	
	TopLevel.EditButton.AssociatedFrame = false
	TopLevel.EditButton.FilterInEdit = false
	
	TopLevel.EditButton:SetScript("OnEnter", core.Scripts.OnEnter)
	TopLevel.EditButton:SetScript("OnLeave", OnLeave)
	TopLevel.EditButton:SetScript("OnClick", function(self)
		ToggleFilter(self.AssociatedFrame)
	end)
end

do -- AndButton
	TopLevel.AndButton:SetSize(48, 20)
	TopLevel.AndButton:SetBackdrop(core.defaultBackdrop)
	TopLevel.AndButton:SetBackdropColor(.4, .4, .4, .2)
	TopLevel.AndButton:SetBackdropBorderColor(0, 0, 0, 1)
	TopLevel.AndButton:SetFrameLevel(500)
	TopLevel.AndButton:Hide()
	
	TopLevel.AndButton:SetText(L["AND"])
	local fs = TopLevel.AndButton:GetFontString()
	fs:SetFont(core.fontPath, 12)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetPoint("CENTER", 0, 0)
	
	TopLevel.AndButton:SetScript("OnEnter", core.Scripts.OnEnter)
	TopLevel.AndButton:SetScript("OnLeave", OnLeave)
	TopLevel.AndButton:SetScript("OnClick", function(self)
		CreateGroup(1, AssociatedFrame)
	end)
end

do -- OrButton
	TopLevel.OrButton:SetSize(48, 20)
	TopLevel.OrButton:SetPoint("LEFT", TopLevel.AndButton, "RIGHT", 8, 0)
	TopLevel.OrButton:SetBackdrop(core.defaultBackdrop)
	TopLevel.OrButton:SetBackdropColor(.4, .4, .4, .2)
	TopLevel.OrButton:SetBackdropBorderColor(0, 0, 0, 1)
	TopLevel.OrButton:SetFrameLevel(500)
	TopLevel.OrButton:Hide()
	
	TopLevel.OrButton:SetText(L["OR"])
	local fs = TopLevel.OrButton:GetFontString()
	fs:SetFont(core.fontPath, 12)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetPoint("CENTER", 0, 0)
	
	TopLevel.OrButton:SetScript("OnEnter", core.Scripts.OnEnter)
	TopLevel.OrButton:SetScript("OnLeave", OnLeave)
	TopLevel.OrButton:SetScript("OnClick", function(self)
		CreateGroup(2, AssociatedFrame)
	end)
end

do -- NotButton
	TopLevel.NotButton:SetSize(48, 20)
	TopLevel.NotButton:SetPoint("LEFT", TopLevel.OrButton, "RIGHT", 8, 0)
	TopLevel.NotButton:SetBackdrop(core.defaultBackdrop)
	TopLevel.NotButton:SetBackdropColor(.4, .4, .4, .2)
	TopLevel.NotButton:SetBackdropBorderColor(0, 0, 0, 1)
	TopLevel.NotButton:SetFrameLevel(500)
	TopLevel.NotButton:Hide()
	
	TopLevel.NotButton:SetText(L["NOT"])
	local fs = TopLevel.NotButton:GetFontString()
	fs:SetFont(core.fontPath, 12)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetPoint("CENTER", 0, 0)
	
	TopLevel.NotButton:SetScript("OnEnter", core.Scripts.OnEnter)
	TopLevel.NotButton:SetScript("OnLeave", OnLeave)
	TopLevel.NotButton:SetScript("OnClick", function(self)
		CreateGroup(3, AssociatedFrame)
	end)
end

do -- FilterButton
	TopLevel.FilterButton:SetSize(64, 20)
	TopLevel.FilterButton:SetPoint("LEFT", TopLevel.NotButton, "RIGHT", 8, 0)
	TopLevel.FilterButton:SetBackdrop(core.defaultBackdrop)
	TopLevel.FilterButton:SetBackdropColor(.4, .4, .4, .2)
	TopLevel.FilterButton:SetBackdropBorderColor(0, 0, 0, 1)
	TopLevel.FilterButton:SetFrameLevel(500)
	TopLevel.FilterButton:Hide()
	
	TopLevel.FilterButton:SetText(FILTER)
	local fs = TopLevel.FilterButton:GetFontString()
	fs:SetFont(core.fontPath, 12)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetPoint("CENTER", 0, 0)
	
	TopLevel.FilterButton:SetScript("OnEnter", core.Scripts.OnEnter)
	TopLevel.FilterButton:SetScript("OnLeave", OnLeave)
	TopLevel.FilterButton:SetScript("OnClick", function(self)
		CreateFilter(AssociatedFrame)
	end)
end

do -- DeleteButton
	TopLevel.DeleteButton:SetSize(18, 18)
	TopLevel.DeleteButton:SetBackdrop(core.defaultBackdrop)
	TopLevel.DeleteButton:SetBackdropColor(.4, .4, .4, .2)
	TopLevel.DeleteButton:SetBackdropBorderColor(0, 0, 0, 1)
	TopLevel.DeleteButton:SetFrameLevel(500)
	TopLevel.DeleteButton:Hide()
	
	local tex1 = TopLevel.DeleteButton:CreateTexture()
	TopLevel.DeleteButton.texture1 = tex1;
	tex1:SetTexture(READY_CHECK_NOT_READY_TEXTURE)
	tex1:SetSize(16, 16)
	tex1:SetPoint("LEFT", 1, 0)
	
	TopLevel.DeleteButton.AssociatedFrame = false
	
	local function DeleteFilter(associatedFrame)
		-- If the frame being deleted is the filter currently being edited, hide the filter and set state to ENTRY_EDIT
		if TopLevel.EditButton.FilterInEdit == associatedFrame and (core.State == "FILTER_CREATE" or core.State == "FILTER_EDIT") then
			core.State = "ENTRY_EDIT"
			TopLevel.FilterSelection:Hide()
			if associatedFrame.filterType then -- associatedFrame has no filterType when we're still selecting what filter we want
				Filters[associatedFrame.filterType]:Hide()
			end
			TopLevel.EditButton.FilterInEdit = false
		end
		associatedFrame.Title:SetText("")
		FilterPool:Release(associatedFrame)
	end
	
	TopLevel.DeleteButton:SetScript("OnEnter", core.Scripts.OnEnter)
	TopLevel.DeleteButton:SetScript("OnLeave", OnLeave)
	TopLevel.DeleteButton:SetScript("OnClick", function(self)
		local parent = self.AssociatedFrame:GetParent()
		
		if self.AssociatedFrame.filterType == 2 then
			self.AssociatedFrame:GetParent().hasAmountFilter = nil
		end
		
		for i,child in ipairs(parent.Children) do
			if self.AssociatedFrame == child then
				if parent.Children[i + 1] then
					parent.Children[i + 1]:ClearAllPoints()
					parent.Children[i + 1]:SetPoint(child:GetPoint())
				end
				
				if self.AssociatedFrame.groupType < 4 then -- Clean up all the children when deleting this group
					local function Cleanup(f)
						for i,frame in ipairs(f.Children) do
							if frame.groupType < 4 then
								Cleanup(frame)
								FramePool:Release(frame)
							else
								DeleteFilter(frame)
							end
							f.Children[i] = nil
						end
					end
					Cleanup(self.AssociatedFrame)
					FramePool:Release(self.AssociatedFrame)
				else
					DeleteFilter(self.AssociatedFrame)
				end
				
				table.remove(parent.Children, i)
				self.AssociatedFrame = false
				parent:UpdateFrameHeight()
				TopLevel.DeleteButton:Hide()
				
				break
			end
		end
	end)
end

do -- FilterSelection
	TopLevel.FilterSelection:Hide()
	
	-- TopLevel.FilterSelection.AssociatedFrame = false
	
-- Modify these whenever filters are added / removed
	local ITEM_TYPE_INDEX = 8
	local FIRST_ITEM_TYPE_INDEX = ITEM_TYPE_INDEX + 1 -- Index of the first item type, which is consumable
	local GEM_INDEX = ITEM_TYPE_INDEX + 2
	local ITEM_TYPES = 8
	
	function TopLevel.FilterSelection:OnClick(filterType)
		if filterType == 0 then -- Item Type
			TopLevel.FilterSelection:SetHeight(ITEM_TYPES * 32)
			AssociatedFrame_Filter:SetHeight(ITEM_TYPES * 32)
			AssociatedFrame_Filter:GetParent():UpdateFrameHeight()
			for i,v in ipairs(TopLevel.FilterSelection) do
				if i < FIRST_ITEM_TYPE_INDEX then
					v:Hide()
				else
					v:Show()
				end
			end
		else
			if filterType == 2 then -- Amount
				if AssociatedFrame_Filter:GetParent().groupType ~= 1 then -- the 'AND' group
					UIErrorsFrame:AddExternalErrorMessage(L["INVALID_GROUP_OR_FILTER3"])
					return
				end
				
				if AssociatedFrame_Filter:GetParent().hasAmountFilter then
					UIErrorsFrame:AddExternalErrorMessage(L["INVALID_GROUP_OR_FILTER4"])
					return
				else
					AssociatedFrame_Filter:GetParent().hasAmountFilter = true
				end
			end
			self:Hide()
			AssociatedFrame_Filter.filterType = filterType
			AssociatedFrame_Filter.filterData = Filters[filterType].initValue
			AssociatedFrame_Filter.texture2:Show()
			ToggleFilter(AssociatedFrame_Filter)
			core.State = "FILTER_EDIT"	
		end
	end

	TopLevel.FilterSelection:SetScript("OnShow", function(self)
		AssociatedFrame_Filter.texture2:Hide()
		local w = self:GetWidth()
		--self:SetHeight(256)
		for i,filterSelector in ipairs(self) do
			filterSelector:SetWidth(w)
			if i < FIRST_ITEM_TYPE_INDEX then
				filterSelector:Show()
			else
				filterSelector:Hide()
			end
		end
	end)
	
	local function OnEnter(self)
		self:GetFontString():SetTextColor(1, 0, 1, 1)
	end
	local function OnLeave(self)
		self:GetFontString():SetTextColor(1, 1, 1, 1)
		GameTooltip:Hide()
	end
	local function OnClick(self)
		self:GetParent():OnClick(self.filterType)
		GameTooltip:Hide()
	end

	local filters = { -- Localized filter string, Filter index
		{AUCTION_HOUSE_SEARCH_BAR_NAME_LABEL, 1},
		{AUCTION_HOUSE_QUANTITY_LABEL, 2},
		{EXPANSION_FILTER_TEXT, 3},
		{AUCTION_HOUSE_FILTER_CATEGORY_RARITY, 4},
		{PET_BATTLE_STAT_QUALITY, 5},
		{STAT_AVERAGE_ITEM_LEVEL, 6},
		{TRANSMOGRIFY, 7},
		{L["ITEM_TYPE"], 0},
		{GetItemClassInfo(ENUM_CONSUMABLE), 8},
		{GetItemClassInfo(ENUM_GEM), 9},
		{GetItemClassInfo(ENUM_ITEM_ENHANCEMENT), 10},
		{string.format("%s: %s", AUCTION_HOUSE_FILTER_CATEGORY_EQUIPMENT, AUCTION_CATEGORY_ARMOR), 11},
		{GetSpellInfo(76271), 12},
		{string.format("%s: %s", AUCTION_HOUSE_FILTER_CATEGORY_EQUIPMENT, AUCTION_CATEGORY_WEAPONS), 13},
		{GetItemClassInfo(ENUM_TRADEGOODS), 14},
		{GetItemClassInfo(ENUM_RECIPE), 15}
	}
	for i=1,#filters do
		local btn = CreateFrame("BUTTON", nil, TopLevel.FilterSelection, "BackdropTemplate")
		TopLevel.FilterSelection[i] = btn
		btn:SetHeight(32)
		btn:SetText(filters[i][1])
		
		local hookFrame, dstAnchor = (i == 1 or i == FIRST_ITEM_TYPE_INDEX) and TopLevel.FilterSelection or TopLevel.FilterSelection[i - 1], (i == 1 or i == FIRST_ITEM_TYPE_INDEX) and "TOPLEFT" or "BOTTOMLEFT"
		
		btn:SetPoint("TOPLEFT", hookFrame, dstAnchor)
		
		local fs = btn:GetFontString()
		fs:SetFont(core.fontPath, 16)
		fs:SetJustifyH("LEFT")
		fs:SetTextColor(1, 1, 1, 1)
		fs:SetPoint("LEFT", 32, 0)
		
		btn.filterType = filters[i][2]
		
		if i == GEM_INDEX then -- Gems
			btn:SetScript("OnEnter", function(self)
				self:GetFontString():SetTextColor(1, 0, 1, 1)
				GameTooltip:SetOwner(self, "ANCHOR_LEFT")
				GameTooltip:AddLine(L["UNRELIABLE_GEMS"])
				GameTooltip:Show()
			end)
		else
			btn:SetScript("OnEnter", OnEnter)
		end
		btn:SetScript("OnLeave", OnLeave)
		btn:SetScript("OnClick", OnClick)
	end
end

--[[=========

	FILTERS
	
===========]]

local function Factory_CheckButton(text, parent, xOffset, yOffset, tooltipText)
	local btn = CreateFrame("CHECKBUTTON", nil, parent, "BackdropTemplate")
	btn:SetSize(16, 16)
	btn:SetBackdrop(core.defaultBackdrop)
	btn:SetBackdropColor(.4, .4, .4, .8)
	btn:SetBackdropBorderColor(0, 0, 0, 1)
	btn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	btn:SetPushedTextOffset(0, 0)
	btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset or 0, yOffset or 0)
	
	btn:SetText(text or " ")
	local fs = btn:GetFontString()
	fs:SetFont(core.fontPath, 16, "")
	fs:ClearAllPoints()
	fs:SetPoint("LEFT", btn, "RIGHT", 8, 0)
	
	if tooltipText then
		btn.TooltipText = tooltipText
		btn.TooltipAnchor = "ANCHOR_LEFT"
	end
	
	btn:SetScript("OnEnter", core.Scripts.OnEnter)
	btn:SetScript("OnLeave", core.Scripts.OnLeave)
	
	return btn
end

do -- Name [1]
	local Frame = CreateFrame("EDITBOX", nil, nil, "BackdropTemplate")
	Filters[1] = Frame
	Frame:SetHeight(24)
	Frame:SetJustifyH("LEFT")
	Frame:SetBackdrop(core.defaultBackdrop)
	Frame:SetBackdropColor(.8, .8, .8, .1)
	Frame:SetBackdropBorderColor(0, 0, 0, 1)
	Frame:SetTextInsets(4, 4, 0, 0)
	Frame:SetAutoFocus(false)
	Frame:SetNumeric(false)
	Frame:SetFont(core.fontPath, 16, "")
	Frame:Hide()
	
	Frame.offsets = {20, -4}
	Frame.height = 32
	Frame.initValue = ""
	
	Frame:SetScript("OnShow", function(self)
		self:RegisterEvent("ITEM_LOCKED")
		self:HighlightText()
		self:SetFocus()
	end)
	Frame:SetScript("OnHide", function(self)
		self:UnregisterEvent("ITEM_LOCKED")
	end)
	Frame:SetScript("OnEnterPressed", function(self)
		ToggleFilter(AssociatedFrame_Filter)
	end)
	Frame:SetScript("OnEvent", function(self, event, bagID, slotIndex)
		if event == "ITEM_LOCKED" and bagID and slotIndex then
			local ii = C_Container.GetContainerItemInfo(bagID, slotIndex)
			if ii and ii.itemID then
				ClearCursor()
				Frame:SetText(C_Item.GetItemNameByID(ii.itemID))
				ToggleFilter(AssociatedFrame_Filter)
				self:ClearFocus()
			end
		end
	end)
	 
	Frame.ToString = function(self, frame)
		return string.format("%s: %s",NAME, frame.filterData)
	end
	Frame.SaveData = function(self, frame, data) -- Sets the filterData of the frame to the data argument when loading from db, or from the frames config widgets
		frame.filterData = data or self:GetText()
	end	
	Frame.LoadData = function(self, frame, flag) -- Returns the frames filterData when flag is true, or set the frames config widgets to the frames frameData
		if flag then
			return frame.filterData
		else
			self:SetText(frame.filterData)
		end
	end
end

do -- Amount [2] -- Quantity
	local Frame = CreateFrame("EDITBOX", nil, nil, "BackdropTemplate")
	Filters[2] = Frame
	Frame:SetHeight(24)
	Frame:SetJustifyH("LEFT")
	Frame:SetBackdrop(core.defaultBackdrop)
	Frame:SetBackdropColor(.8, .8, .8, .1)
	Frame:SetBackdropBorderColor(0, 0, 0, 1)
	Frame:SetTextInsets(4, 4, 0, 0)
	Frame:SetAutoFocus(false)
	-- Frame:SetNumeric(true) -- Won't allow negative numbers, symbols like - and . are stripped
	Frame:SetFont(core.fontPath, 16, "")
	Frame:Hide()
	
	Frame.offsets = {20, -4}
	Frame.height = 32
	Frame.initValue = ""
	
	Frame:SetScript("OnShow", function(self)
		self:HighlightText()
		self:SetFocus()
	end)
	Frame:SetScript("OnEnterPressed", function(self)
		local n = tonumber(self:GetText())
		if n then
			ToggleFilter(AssociatedFrame_Filter)
		else
			self:SetText("")
		end
	end)
	Frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Send the specified amount of items.\nSending 0 sends none of the items.\nA negative value sends all but the specified amount.")
		GameTooltip:Show()
	end)
	Frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	
	Frame.ToString = function(self, frame)
		return string.format("%s: %s", AUCTION_HOUSE_QUANTITY_LABEL, frame.filterData)
	end
	Frame.SaveData = function(self, frame, data) -- Sets the filterData of the frame to the data argument when loading from db, or from the frames config widgets
		frame.filterData = data or tonumber(self:GetText()) or 0
	end
	Frame.LoadData = function(self, frame, flag) -- Returns the frames filterData when flag is true, or set the frames config widgets to the frames frameData
		if flag then
			return tostring(frame.filterData)
		else
			self:SetText(frame.filterData)
		end
	end
end

do -- Expansion [3]
	local Frame = CreateFrame("FRAME", nil, nil, "Krozu_RangeScrollBar_Fontstring")
	Filters[3] = Frame
	Frame.isNumeric = false
	Frame.StringTable = {
		[0] = EXPANSION_NAME0,
		EXPANSION_NAME1,
		EXPANSION_NAME2,
		EXPANSION_NAME3,
		EXPANSION_NAME4,
		EXPANSION_NAME5,
		EXPANSION_NAME6,
		EXPANSION_NAME7,
		EXPANSION_NAME8,
		EXPANSION_NAME9
	}
	Frame.offsets = {64, -36}
	Frame.height = 96
	Frame.initValue = {0, #Frame.StringTable}
	
	Frame:Init(Frame.initValue[1], Frame.initValue[2])
	Frame:SetBackdropColor(.2, .2, .2)
	Frame:SetBackdropBorderColor(0, 0, 0)
	Frame:SetThumbColor(unpack(core.classColour))
	Frame:SetThumbWidth(16)
	
	Frame.ToString = function(self, frame)
		local f,t = unpack(frame.filterData) -- From, To
		if f == t then
			return string.format("%s: %s", EXPANSION_FILTER_TEXT, self.StringTable[f])
		else
			return string.format(L["FROM_TO"], EXPANSION_FILTER_TEXT, self.StringTable[f], self.StringTable[t]), 64
		end
	end
	Frame.SaveData = function(self, frame, data)
		local f,t
		if data then
			f,t = bit.band(data, 0xf), bit.rshift(data, 4)
		else
			f,t = self:GetValues()
		end
		frame.filterData = {f,t}
	end
	Frame.LoadData = function(self, frame, flag)
		local f,t = unpack(frame.filterData)
		if flag then
			return tostring(f + bit.lshift(t, 4))
		else
			self:SetValues(f, t)
		end
	end
	
-- Scroll scripts
	Frame.SliderLow:SetScript("OnValueChanged", function(self, value)
		local p = self:GetParent()
		if value > p.SliderHigh:GetValue() then
			self:SetValue(p.SliderHigh:GetValue())
			return
		end
		p.TextLow:SetText("From: "..p.StringTable[value])
	end)
	Frame.SliderHigh:SetScript("OnValueChanged", function(self, value)
		local p = self:GetParent()
		if value < p.SliderLow:GetValue() then
			self:SetValue(p.SliderLow:GetValue())
			return
		end
		p.TextHigh:SetText("To: "..p.StringTable[value])
	end)
end

do -- Rarity [4]
	local Frame = CreateFrame("FRAME", nil, nil, "Krozu_RangeScrollBar_Fontstring")
	Filters[4] = Frame
	Frame.isNumeric = false
	Frame.StringTable = {
		[0] = ITEM_QUALITY0_DESC,
		ITEM_QUALITY1_DESC,
		ITEM_QUALITY2_DESC,
		ITEM_QUALITY3_DESC,
		ITEM_QUALITY4_DESC,
		ITEM_QUALITY5_DESC,
	}
	Frame.offsets = {64, -36}
	Frame.height = 96
	Frame.initValue = {0, #Frame.StringTable}
	
	Frame:Init(Frame.initValue[1], Frame.initValue[2])
	Frame:SetBackdropColor(.2, .2, .2)
	Frame:SetBackdropBorderColor(0, 0, 0)
	Frame:SetThumbColor(unpack(core.classColour))
	Frame:SetThumbWidth(18)

	Frame.ToString = function(self, frame)
		local f,t = unpack(frame.filterData) -- From, To
		if f == t then
			return string.format("%s: \124c%s%s\124r", RARITY, select(4, GetItemQualityColor(f)), self.StringTable[f])
		else
			return string.format("%s: \124c%s%s\124r -> \124c%s%s\124r", RARITY, select(4, GetItemQualityColor(f)), self.StringTable[f], select(4, GetItemQualityColor(t)), self.StringTable[t])
		end
	end
	Frame.SaveData = function(self, frame, data)
		local f,t
		if data then
			f,t = bit.band(data, 0xf), bit.rshift(data, 4)
		else
			f,t = self:GetValues()
		end
		frame.filterData = {f,t}
	end
	Frame.LoadData = function(self, frame, flag)
		local f,t = unpack(frame.filterData)
		if flag then
			return tostring(f + bit.lshift(t, 4))
		else
			self:SetValues(f, t)
		end
	end
	
-- Scroll scripts
	Frame.SliderLow:SetScript("OnValueChanged", function(self, value)
		local p = self:GetParent()
		if value > p.SliderHigh:GetValue() then
			self:SetValue(p.SliderHigh:GetValue())
			return
		end
		p.TextLow:SetText(string.format("From: \124c%s%s\124r", select(4, GetItemQualityColor(value)), p.StringTable[value]))
	end)
	Frame.SliderHigh:SetScript("OnValueChanged", function(self, value)
		local p = self:GetParent()
		if value < p.SliderLow:GetValue() then
			self:SetValue(p.SliderLow:GetValue())
			return
		end
		p.TextHigh:SetText(string.format("To: \124c%s%s\124r", select(4, GetItemQualityColor(value)), p.StringTable[value]))
	end)
end

do -- Quality [5]
	local Frame = CreateFrame("FRAME", nil, nil, "Krozu_RangeScrollBar_Fontstring")
	Filters[5] = Frame
	Frame.isNumeric = false
	Frame.offsets = {64, -36}
	Frame.height = 96
	Frame.initValue = {1, 5}
	
	Frame:Init(Frame.initValue[1], Frame.initValue[2])
	Frame:SetBackdropColor(.2, .2, .2)
	Frame:SetBackdropBorderColor(0, 0, 0)
	Frame:SetThumbColor(unpack(core.classColour))
	Frame:SetThumbWidth(34)
	
	Frame.ToString = function(self, frame)
		local f,t = unpack(frame.filterData) -- From, To
		if f == t then
			return string.format("%s: \124A:%s:15:15::-1\124a", QUALITY, Professions.GetIconForQuality(f, true))
		else
			return string.format("%s: \124A:%s:15:15::-1\124a-> \124A:%s:15:15::-1\124a", QUALITY, Professions.GetIconForQuality(f, true), Professions.GetIconForQuality(t, true))
		end
	end
	Frame.SaveData = function(self, frame, data)
		local f,t
		if data then
			f,t = bit.band(data, 0x7), bit.rshift(data, 3)
		else
			f,t = self:GetValues()
		end
		frame.filterData = {f,t}
	end
	Frame.LoadData = function(self, frame, flag)
		local f,t = unpack(frame.filterData)
		if flag then
			return tostring(f + bit.lshift(t, 3))
		else
			self:SetValues(f, t)
		end
	end
	
-- Scroll scripts
	Frame.SliderLow:SetScript("OnValueChanged", function(self, value)
		local p = self:GetParent()
		if value > p.SliderHigh:GetValue() then
			self:SetValue(p.SliderHigh:GetValue())
			return
		end
		p.TextLow:SetText(string.format(L["FROM_ICON"], Professions.GetIconForQuality(value, true)))
	end)
	Frame.SliderHigh:SetScript("OnValueChanged", function(self, value)
		local p = self:GetParent()
		if value < p.SliderLow:GetValue() then
			self:SetValue(p.SliderLow:GetValue())
			return
		end
		p.TextHigh:SetText(string.format(L["TO_ICON"], Professions.GetIconForQuality(value, true)))
	end)
end

do -- Item Level [6]
	local Frame = CreateFrame("FRAME", nil, nil, "Krozu_RangeScrollBar_Editbox")
	Filters[6] = Frame
	Frame.isNumeric = false
	Frame.offsets = {64, -36}
	Frame.height = 96
	Frame.initValue = {0, 800}
	
	Frame:Init(Frame.initValue[1], Frame.initValue[2], 5) -- Min, Max, Step(1)
	Frame:SetBackdropColor(.2, .2, .2)
	Frame:SetBackdropBorderColor(0, 0, 0)
	Frame:SetEditBoxBackdropColor(.3, .3, .3)
	Frame:SetEditBoxBackdropBorderColor(0, 0, 0)
	Frame:SetThumbColor(unpack(core.classColour))
	Frame:SetThumbWidth(16)
	
	Frame.ToString = function(self, frame)
		local f,t = unpack(frame.filterData)
		if f == t then
			return string.format("%s: %d", STAT_AVERAGE_ITEM_LEVEL, f)
		else
			return string.format("%s: %d -> %d", STAT_AVERAGE_ITEM_LEVEL, f, t)
		end
	end
	Frame.SaveData = function(self, frame, data)
		local f,t
		if data then
			f,t = bit.band(data, 0x3ff), bit.rshift(data, 10)
		else
			f,t = self:GetValues()
		end
		frame.filterData = {f, t}
	end
	Frame.LoadData = function(self, frame, flag)
		local f,t = unpack(frame.filterData)
		if flag then
			return tostring(f + bit.lshift(t, 10))
		else
			self:SetValues(f, t)
		end
	end
end

do -- Transmog [7]
	local Frame = CreateFrame("CHECKBUTTON", nil, nil, "BackdropTemplate")
	Filters[7] = Frame
	Frame:SetSize(16, 16)
	Frame:SetBackdrop(core.defaultBackdrop)
	Frame:SetBackdropColor(.4, .4, .4, .8)
	Frame:SetBackdropBorderColor(0, 0, 0, 1)
	Frame:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	Frame:SetPushedTextOffset(0, 0)
	Frame:Hide()
	
	Frame:SetText(string.format("%s: ", L["IS_TRANSMOG_KNOWN"]))
	local fs = Frame:GetFontString()
	fs:SetFont(core.fontPath, 16, "")
	fs:ClearAllPoints()
	fs:SetPoint("RIGHT", Frame, "LEFT", -8, 0)

	Frame.offsets = {Frame:GetFontString():GetStringWidth() + 28, -8}
	Frame.height = 32
	Frame.initValue = false
	
	Frame.ToString = function(self, frame)
		return string.format("%s: %s", L["IS_TRANSMOG_KNOWN"], frame.filterData and YES or NO)
	end
	Frame.SaveData = function(self, frame, data)
		local isChecked
		if data then
			isChecked = data == 1 and true or false
		else
			isChecked = self:GetChecked()
		end
		frame.filterData = isChecked
	end
	Frame.LoadData = function(self, frame, flag)
		if flag then
			return frame.filterData and "1" or "0"
		else
			self:SetChecked(frame.filterData)
		end
	end
end

do -- Consumable [8]
	local Frame = CreateFrame("FRAME", nil, nil, nil)
	Filters[8] = Frame
	Frame:SetSize(128, 96)
	Frame:Hide()
	
	Frame.offsets = {0, 0}
	Frame.height = 96
	Frame.ItemClassID = ENUM_CONSUMABLE
	Frame.initValue = 0
	
	Frame.ToString = function(self, frame)
		local str, height = L["ITEM_TYPE"]..": "..GetItemClassInfo(self.ItemClassID), 2
		local filterData = frame.filterData
		if filterData == 0 then -- Nothing is filtered
			str = str..L["NO_FILTERS_APPLIED"]
			height = height + 1
		else
			for i=1,#self do
				if bit.band(filterData, bit.lshift(1, i-1)) > 0 then
					str = str.."\n  "..self[i]:GetFontString():GetText()
					height = height + 1
				end
			end
		end
		return str, height * 16
	end
	Frame.SaveData = function(self, frame, data)
		local hex
		if data then
			hex = data
		else
			hex = 0
			for i=1,#self do
				hex = hex + (self[i]:GetChecked() and bit.lshift(1, i-1) or 0)
			end
		end
		frame.filterData = hex
	end
	Frame.LoadData = function(self, frame, flag)
		local filterData = frame.filterData
		if flag then
			return tostring(filterData)
		else
			for i=1,#self do
				self[i]:SetChecked(bit.band(filterData, bit.lshift(1, i-1)) > 0)
			end
		end
	end

	Frame[1] = Factory_CheckButton(GetItemSubClassInfo(ENUM_CONSUMABLE, 1), Frame, 32, -8)
	Frame[2] = Factory_CheckButton(GetItemSubClassInfo(ENUM_CONSUMABLE, 2), Frame, 182, -8)
	Frame[3] = Factory_CheckButton(GetItemSubClassInfo(ENUM_CONSUMABLE, 3).." & Phial", Frame, 32, -40)
	Frame[4] = Factory_CheckButton(GetItemSubClassInfo(ENUM_CONSUMABLE, 5), Frame, 182, -40)
	Frame[5] = Factory_CheckButton(GetItemSubClassInfo(ENUM_CONSUMABLE, 9), Frame, 32, -72)
	Frame[6] = Factory_CheckButton(GetItemSubClassInfo(ENUM_CONSUMABLE, 8), Frame, 182, -72)
end

do -- Gems [9]
--[[
	GEM ORDER
		Element:
			Air
			Earth
			Fire
			Frost
			Primal
		Color:
			Ysemerald		Haste
			Alexstraszite	Critical Strike
			Neltharite		Mastery
			Malygite		Versatility
			Nozdorite		Stamina
			
		Pre-Dragonflight:
			Int
			Agi
			Strength
			Stamina
			Spirit
			Crit
			Mastery
			Haste
			Vers
]]
	local Frame = CreateFrame("FRAME", nil, nil, nil)
	Filters[9] = Frame
	Frame:SetSize(128, 1216)
	Frame:Hide()
	
	Frame.offsets = {0, 0}
	Frame.height = 1216 -- (6 gem categories + 32 gem 'types') * 32
	Frame.itemClassID = ENUM_GEM
	Frame.initValue = 0
	
	Frame:SetScript("OnShow", function(self)
		self:SetHeight(self.height)
	
		-- Collapse the groups
		self.Air.Collapse.isCollapsed = false
		self.Earth.Collapse.isCollapsed = false
		self.Fire.Collapse.isCollapsed = false
		self.Frost.Collapse.isCollapsed = false
		self.Primalist.Collapse.isCollapsed = false
		self.Old.Collapse.isCollapsed = false
		
		self.Air.Collapse:Click()
		self.Earth.Collapse:Click()
		self.Fire.Collapse:Click()
		self.Frost.Collapse:Click()
		self.Primalist.Collapse:Click()
		self.Old.Collapse:Click()
	end)
	
	Frame.ToString = function(self, frame)
		local str, height = L["ITEM_TYPE"]..": "..GetItemClassInfo(self.itemClassID), 2
		local filterData = frame.filterData
		if filterData == 0 then -- Nothing is filtered
			str = str..L["NO_FILTERS_APPLIED"]
			height = height + 1
		else
			for i=1,#self do
				if bit.band(filterData, bit.lshift(1, i-1)) > 0 then
					str = str.."\n  "..self[i]:GetFontString():GetText()
					height = height + 1
				end
			end
		end
		
		return str, height * 16
	end
	Frame.SaveData = function(self, frame, data)
		local hex
		if data then
			hex = data
		else
			hex = 0
			for i=1,#self do
				hex = hex + (self[i]:GetChecked() and bit.lshift(1, i-1) or 0)
			end
		end
		frame.filterData = hex
	end
	Frame.LoadData = function(self, frame, flag)
		local filterData = frame.filterData
		if flag then
			return tostring(filterData)
		else
			for i=1,#self do
				self[i]:SetChecked(bit.band(filterData, bit.lshift(1, i-1)) > 0)
			end
			
			self.Air:SetChecked(bit.band(filterData, 0x1F) == 0x1F)
			self.Earth:SetChecked(bit.band(filterData, 0x3E0) == 0x3E0)
			self.Fire:SetChecked(bit.band(filterData, 0x7C00) == 0x7C00)
			self.Frost:SetChecked(bit.band(filterData, 0xF8000) == 0xF8000)
			self.Primalist:SetChecked(bit.band(filterData, 0xF00000) == 0xF00000)
		end
	end

	local function Element_OnClick(self)
		local checked = self:GetChecked()
		
		for i=self.frameID,self.frameID + self.gemCount - 1 do
			Frame[i]:SetChecked(checked)
		end
	end
	
	local function Collapse_OnClick(self)
		local parent = self:GetParent()
		local show = self.isCollapsed
		local newFrameHeight = Frame:GetHeight() + (show and 1 or -1) * (parent.gemCount * 32)
		
		for i=parent.frameID, parent.frameID + parent.gemCount - 1 do -- Show/Hide gems
			Frame[i]:SetShown(show)
		end
		
		if show then
			if self.nextInLine then
				self.nextInLine:SetPoint("TOP", parent, "TOP", 0, -((parent.gemCount + 1) * 32))
			end
			self.texture:SetTexCoord(.453125,.640625,.015625,.203125)
		else
			if self.nextInLine then
				self.nextInLine:SetPoint("TOP", parent, "TOP", 0, -32)
			end
			self.texture:SetTexCoord(.453125,.640625,.203125,.015625)
		end
		
		self.isCollapsed = not show
		
		-- print(Frame:GetHeight(), newFrameHeight)
		Frame:SetHeight(newFrameHeight) -- Update the filter height
		AssociatedFrame_Filter:SetHeight(newFrameHeight) -- Update the frame height
		AssociatedFrame_Filter:GetParent():UpdateFrameHeight() -- Update the height in the whole chain up to TopLevel
	end
	
	local xOffset = 16
	local recipeIDs = { -- Pull the gem names from the game
	-- Air
		374461,
		374455,
		374442,
		374457,
		374447,
	-- Earth
		374459,
		374453,
		374443,
		374448,
		374462,
	-- Fire
		374446,
		374450,
		374445,
		374456,
		374460,
	-- Frost
		374458,
		374449,
		374463,
		374454,
		374444,
	-- Primal
		374465,
		374467,
		374468,
		374470
	}
		
	local function GetGemName(index)
		local recipeInfo = C_TradeSkillUI.GetRecipeSchematic(recipeIDs[index], false)
		return recipeInfo and recipeInfo.name or "nil"
	end
	local function Factory_Dropdown(frame, id, gemCount)
		if id ~= 1 then
			frame:ClearAllPoints()
		end
		frame.frameID = id -- Starting index for element
		frame.gemCount = gemCount
		frame:SetScript("OnClick", Element_OnClick)
		
		local Collapse = CreateFrame("BUTTON", nil, frame, "BackdropTemplate")
		frame.Collapse = Collapse
		Collapse:SetSize(16, 16)
		Collapse:SetPoint("LEFT", frame:GetFontString(), "RIGHT", 4, 0)
		Collapse:SetBackdrop(core.defaultBackdrop)
		Collapse:SetBackdropColor(0, 0, 0, 0)
		Collapse:SetBackdropBorderColor(0, 0, 0, 1)
		
		local tex = Collapse:CreateTexture()
		Collapse.texture = tex;
		tex:SetTexture("Interface\\Buttons\\SquareButtonTextures")
		tex:SetWidth(12)
		tex:SetHeight(12)
		tex:SetPoint("CENTER")
		
		Collapse.isCollapsed = false
		
		Collapse:SetScript("OnEnter", core.Scripts.OnEnter)
		Collapse:SetScript("OnLeave", core.Scripts.OnLeave)
		Collapse:SetScript("OnClick", Collapse_OnClick)
	end

-- Air
	Frame.Air = Factory_CheckButton(L["AIR"], Frame, 32, -8)
	Factory_Dropdown(Frame.Air, 1, 5)
	
	Frame[1] = Factory_CheckButton(GetGemName(1), Frame.Air, xOffset, -160, "++ Haste")
	Frame[2] = Factory_CheckButton(GetGemName(2), Frame.Air, xOffset, -32, "++ Critical Strike and + Haste")
	Frame[3] = Factory_CheckButton(GetGemName(3), Frame.Air, xOffset, -64, "++ Versatility and + Haste")
	Frame[4] = Factory_CheckButton(GetGemName(4), Frame.Air, xOffset, -96, "++ Stamina and + Haste")
	Frame[5] = Factory_CheckButton(GetGemName(5), Frame.Air, xOffset, -128, "++ Mastery and + Haste")
	
-- Earth
	Frame.Earth = Factory_CheckButton("\124cFF805B4D"..L["EARTH"], Frame)
	Factory_Dropdown(Frame.Earth, 6, 5)
	
	Frame[6] = Factory_CheckButton(GetGemName(6), Frame.Earth, xOffset, -96, "++ Stamina and + Mastery")
	Frame[7] = Factory_CheckButton(GetGemName(7), Frame.Earth, xOffset, -32, "++ Mastery")
	Frame[8] = Factory_CheckButton(GetGemName(8), Frame.Earth, xOffset, -64, "++ Haste and ++ Mastery")
	Frame[9] = Factory_CheckButton(GetGemName(9), Frame.Earth, xOffset, -128, "++ Critical Strike and + Mastery")
	Frame[10] = Factory_CheckButton(GetGemName(10), Frame.Earth, xOffset, -160, "++ Versatility and + Mastery")
	
-- Fire
	Frame.Fire = Factory_CheckButton("\124cFFF95B19"..L["FIRE"], Frame)
	Factory_Dropdown(Frame.Fire, 11, 5)

	Frame[11] = Factory_CheckButton(GetGemName(11), Frame.Fire, xOffset, -128, "++ Versatility and + Critical Strike")
	Frame[12] = Factory_CheckButton(GetGemName(12), Frame.Fire, xOffset, -32, "++ Haste and + Critical Strike")
	Frame[13] = Factory_CheckButton(GetGemName(13), Frame.Fire, xOffset, -64, "++ Critical Strike")
	Frame[14] = Factory_CheckButton(GetGemName(14), Frame.Fire, xOffset, -96, "++ Stamina and + Critical Strike")
	Frame[15] = Factory_CheckButton(GetGemName(15), Frame.Fire, xOffset, -160, "++ Mastery and + Critical Strike")
	
-- Frost
	Frame.Frost = Factory_CheckButton("\124cFF1C90E1"..L["FROST"], Frame)
	Factory_Dropdown(Frame.Frost, 16, 5)
	
	Frame[16] = Factory_CheckButton(GetGemName(16), Frame.Frost, xOffset, -96, "++ Haste and + Versatility")
	Frame[17] = Factory_CheckButton(GetGemName(17), Frame.Frost, xOffset, -128, "++ Critical Strike and + Versatility")
	Frame[18] = Factory_CheckButton(GetGemName(18), Frame.Frost, xOffset, -160, "++ Stamina and + Versatility")
	Frame[19] = Factory_CheckButton(GetGemName(19), Frame.Frost, xOffset, -32, "++ Versatility")
	Frame[20] = Factory_CheckButton(GetGemName(20), Frame.Frost, xOffset, -64, "++ Mastery and + Versatility")
	
-- Primalist
	Frame.Primalist = Factory_CheckButton("\124cFFA335EE"..L["PRIMALIST"], Frame)
	Factory_Dropdown(Frame.Primalist, 21, 4)
	
	Frame[21] = Factory_CheckButton(GetGemName(21), Frame.Primalist, xOffset, -64, "++ Primary Stat and + Haste")
	Frame[22] = Factory_CheckButton(GetGemName(22), Frame.Primalist, xOffset, -32, "++ Primary Stat and + Critical Strike")
	Frame[23] = Factory_CheckButton(GetGemName(23), Frame.Primalist, xOffset, -96, "++ Primary Stat and + Versatility")
	Frame[24] = Factory_CheckButton(GetGemName(24), Frame.Primalist, xOffset, -128, "++ Primary Stat and + Mastery")
	
-- Pre-Dragonflight
	Frame.Old = Factory_CheckButton("\124cFFFF00FF"..L["PRE_DRAGONFLIGHT"], Frame)
	Factory_Dropdown(Frame.Old, 25, 8)
	
	Frame[25] = Factory_CheckButton(SPEC_FRAME_PRIMARY_STAT_INTELLECT, Frame.Old, xOffset, -32, "++ "..SPEC_FRAME_PRIMARY_STAT_INTELLECT)
	Frame[26] = Factory_CheckButton(SPEC_FRAME_PRIMARY_STAT_AGILITY, Frame.Old, xOffset, -64, "++ "..SPEC_FRAME_PRIMARY_STAT_AGILITY)
	Frame[27] = Factory_CheckButton(SPEC_FRAME_PRIMARY_STAT_STRENGTH, Frame.Old, xOffset, -96, "++ "..SPEC_FRAME_PRIMARY_STAT_STRENGTH)
	Frame[28] = Factory_CheckButton(GetItemSubClassInfo(3, 3), Frame.Old, xOffset, -128, "++ "..GetItemSubClassInfo(3, 3))
	-- Frame[29] = Factory_CheckButton("Spirit", Frame.Old, xOffset, -160, "++ Spirit")
	Frame[29] = Factory_CheckButton(GetItemSubClassInfo(3, 5), Frame.Old, xOffset, -160, "++ "..GetItemSubClassInfo(3, 5))
	Frame[30] = Factory_CheckButton(GetItemSubClassInfo(3, 6), Frame.Old, xOffset, -192, "++ "..GetItemSubClassInfo(3, 6))
	Frame[31] = Factory_CheckButton(GetItemSubClassInfo(3, 7), Frame.Old, xOffset, -224, "++ "..GetItemSubClassInfo(3, 7))
	Frame[32] = Factory_CheckButton(GetItemSubClassInfo(3, 8), Frame.Old, xOffset, -256, "++ "..GetItemSubClassInfo(3, 8))
	
-- Set nextInLine variables
	Frame.Air.Collapse.nextInLine = Frame.Earth
	Frame.Earth.Collapse.nextInLine = Frame.Fire
	Frame.Fire.Collapse.nextInLine = Frame.Frost
	Frame.Frost.Collapse.nextInLine = Frame.Primalist
	Frame.Primalist.Collapse.nextInLine = Frame.Old
end

do -- Item Enchancements [10]
	local Frame = CreateFrame("FRAME", nil, nil, nil)
	Filters[10] = Frame
	Frame:SetSize(128, 224)
	Frame:Hide()
	
	Frame.offsets = {0, 0}
	Frame.height = 224
	Frame.ItemClassID = ENUM_ITEM_ENHANCEMENT
	Frame.initValue = 0
				
	Frame.ToString = function(self, frame)
		local str, height = "Item Type: "..GetItemClassInfo(self.ItemClassID), 2
		local filterData = frame.filterData
		if filterData == 0 then -- Nothing is filtered
			str = str.."\n  No filters are applied"
			height = height + 1
		else
			for i=1,#self do
				if bit.band(filterData, bit.lshift(1, i-1)) > 0 then
					str = str.."\n  "..self[i]:GetFontString():GetText()
					height = height + 1
				end
			end
		end
		return str, height * 16
	end
	Frame.SaveData = function(self, frame, data)
		local hex
		if data then
			hex = data
		else
			hex = 0
			for i=1,#self do
				hex = hex + (self[i]:GetChecked() and bit.lshift(1, i-1) or 0)
			end
		end
		frame.filterData = hex
	end
	Frame.LoadData = function(self, frame, flag)
		local data = frame.filterData
		if flag then
			return tostring(data)
		else
			for i=1,#self do
				self[i]:SetChecked(bit.band(data, bit.lshift(1, i-1)) > 0)
			end
		end
	end
	
	Frame[1] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 0), Frame, 32, -8) -- Head
	Frame[2] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 1), Frame, 224, -8) -- Neck
	Frame[3] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 2), Frame, 32, -40) -- Shoulder
	Frame[4] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 3), Frame, 224, -40) -- Cloak
	Frame[5] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 4), Frame, 32, -72) -- Chest
	Frame[6] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 5), Frame, 224, -72) -- Wrist
	Frame[7] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 6), Frame, 32, -104) -- Hands
	Frame[8] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 7), Frame, 224, -104) -- Waist
	Frame[9] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 8), Frame, 32, -136) -- Legs
	Frame[10] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 9), Frame, 224, -136) -- Feet
	Frame[11] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 10), Frame, 32, -168) -- Finger
	Frame[12] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 11), Frame, 224, -168) -- Weapon
	Frame[13] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 12), Frame, 32, -200) -- TwoHandedWeapon
	Frame[14] = Factory_CheckButton(GetItemSubClassInfo(ENUM_ITEM_ENHANCEMENT, 13), Frame, 224, -200) -- Offhand
end

do -- Armor Slot [11]
	local Frame = CreateFrame("FRAME", nil, nil, nil)
	Filters[11] = Frame
	Frame:SetSize(128, 192)
	Frame:Hide()
	
	Frame.offsets = {0, 0}
	Frame.height = 192
	Frame.ItemClassID = 30
	Frame.initValue = 0
	
	Frame.ToString = function(self, frame)
		local str, height = L["ITEM_TYPE"]..": "..L["ARMOR_SLOTS"], 2
		local filterData = frame.filterData
		if filterData == 0 then -- Nothing is filtered
			str = str..L["NO_FILTERS_APPLIED"]
			height = height + 1
		else
			for i=1,#self do
				if bit.band(filterData, bit.lshift(1, i-1)) > 0 then
					str = str.."\n  "..self[i]:GetFontString():GetText()
					height = height + 1
				end
			end
		end
		return str, height * 16
	end
	Frame.SaveData = function(self, frame, data)
		local hex
		if data then
			hex = data
		else
			hex = 0
			for i=1,#self do
				hex = hex + (self[i]:GetChecked() and bit.lshift(1, i-1) or 0)
			end
		end
		frame.filterData = hex
	end
	Frame.LoadData = function(self, frame, flag)
		local data = frame.filterData
		if flag then
			return tostring(data)
		else
			for i=1,#self do
				self[i]:SetChecked(bit.band(data, bit.lshift(1, i-1)) > 0)
			end
		end
	end

	Frame[1] = Factory_CheckButton(GetItemSubClassInfo(8, 0), Frame, 32, -8) -- Head
	Frame[2] = Factory_CheckButton(GetItemSubClassInfo(8, 1), Frame, 224, -8) -- Neck
	Frame[3] = Factory_CheckButton(GetItemSubClassInfo(8, 2), Frame, 32, -40) -- Shoulder
	Frame[4] = Factory_CheckButton(GetItemSubClassInfo(8, 3), Frame, 224, -40) -- Cloak
	Frame[5] = Factory_CheckButton(GetItemSubClassInfo(8, 4), Frame, 32, -72) -- Chest
	Frame[6] = Factory_CheckButton(GetItemSubClassInfo(8, 5), Frame, 224, -72) -- Wrist
	Frame[7] = Factory_CheckButton(GetItemSubClassInfo(8, 6), Frame, 32, -104) -- Hands
	Frame[8] = Factory_CheckButton(GetItemSubClassInfo(8, 7), Frame, 224, -104) -- Waist
	Frame[9] = Factory_CheckButton(GetItemSubClassInfo(8, 8), Frame, 32, -136) -- Legs
	Frame[10] = Factory_CheckButton(GetItemSubClassInfo(8, 9), Frame, 224, -136) -- Feet
	Frame[11] = Factory_CheckButton(GetItemSubClassInfo(8, 10), Frame, 32, -168) -- Finger
	Frame[12] = Factory_CheckButton(INVTYPE_TRINKET, Frame, 224, -168) -- Trinket
end

do -- Armor Type [12]
	local Frame = CreateFrame("FRAME", nil, nil, nil)
	Filters[12] = Frame
	Frame:SetSize(128, 64)
	Frame:Hide()
	
	Frame.offsets = {0, 0}
	Frame.height = 64
	Frame.ItemClassID = 4
	Frame.initValue = 0
	
	Frame.ToString = function(self, frame)
		local str, height = L["ITEM_TYPE"]..": "..ARMOR, 2
		local filterData = frame.filterData
		if filterData == 0 then -- Nothing is filtered
			str = str..L["NO_FILTERS_APPLIED"]
			height = height + 1
		else
			for i=1,#self do
				if bit.band(filterData, bit.lshift(1, i-1)) > 0 then
					str = str.."\n  "..self[i]:GetFontString():GetText()
					height = height + 1
				end
			end
		end
		return str, height * 16
	end
	Frame.SaveData = function(self, frame, data)
		local hex
		if data then
			hex = data
		else
			hex = 0
			for i=1,#self do
				hex = hex + (self[i]:GetChecked() and bit.lshift(1, i-1) or 0)
			end
		end
		frame.filterData = hex
	end
	Frame.LoadData = function(self, frame, flag)
		local data = frame.filterData
		if flag then
			return tostring(data)
		else
			for i=1,#self do
				self[i]:SetChecked(bit.band(data, bit.lshift(1, i-1)) > 0)
			end
		end
	end

	Frame[1] = Factory_CheckButton(GetItemSubClassInfo(4, 1), Frame, 32, -8) -- Cloth
	Frame[2] = Factory_CheckButton(GetItemSubClassInfo(4, 2), Frame, 182, -8) -- Leather
	Frame[3] = Factory_CheckButton(GetItemSubClassInfo(4, 3), Frame, 32, -40) -- Mail
	Frame[4] = Factory_CheckButton(GetItemSubClassInfo(4, 4), Frame, 182, -40) -- Plate
end

do -- Weapon Type [13]
	local Frame = CreateFrame("FRAME", nil, nil, nil)
	Filters[13] = Frame
	Frame:SetSize(128, 288)
	Frame:Hide()
	
	Frame.offsets = {0, 0}
	Frame.height = 288
	Frame.ItemClassID = 2
	Frame.initValue = 0
	
	Frame.ToString = function(self, frame)
		local str, height = L["ITEM_TYPE"]..": "..L["WEAPON_SLOTS"], 2
		local filterData = frame.filterData
		if filterData == 0 then -- Nothing is filtered
			str = str..L["NO_FILTERS_APPLIED"]
			height = height + 1
		else
			for i=1,#self do
				if bit.band(filterData, bit.lshift(1, i-1)) > 0 then
					str = str.."\n  "..self[i]:GetFontString():GetText()
					height = height + 1
				end
			end
		end
		return str, height * 16
	end
	Frame.SaveData = function(self, frame, data)
		local hex
		if data then
			hex = data
		else
			hex = 0
			for i=1,#self do
				hex = hex + (self[i]:GetChecked() and bit.lshift(1, i-1) or 0)
			end
		end
		frame.filterData = hex
	end
	Frame.LoadData = function(self, frame, flag)
		local data = frame.filterData
		if flag then
			return tostring(data)
		else
			for i=1,#self do
				self[i]:SetChecked(bit.band(data, bit.lshift(1, i-1)) > 0)
			end
		end
	end

	Frame[1] = Factory_CheckButton(GetItemSubClassInfo(2, 7), Frame, 32, -8) -- One-handed Swords
	Frame[2] = Factory_CheckButton(GetItemSubClassInfo(2, 8), Frame, 224, -8) -- Two-handed Swords
	Frame[3] = Factory_CheckButton(GetItemSubClassInfo(2, 0), Frame, 32, -40) -- One-handed Axes
	Frame[4] = Factory_CheckButton(GetItemSubClassInfo(2, 1), Frame, 224, -40) -- Two-handed Axes
	Frame[5] = Factory_CheckButton(GetItemSubClassInfo(2, 4), Frame, 32, -72) -- One-Handed Maces
	Frame[6] = Factory_CheckButton(GetItemSubClassInfo(2, 5), Frame, 224, -72) -- Two-Handed Maces
	Frame[7] = Factory_CheckButton(GetItemSubClassInfo(2, 10), Frame, 32, -104) -- Staves
	Frame[8] = Factory_CheckButton(GetItemSubClassInfo(2, 19), Frame, 224, -104) -- Wands
	Frame[9] = Factory_CheckButton(GetItemSubClassInfo(2, 2), Frame, 32, -136) -- Bows
	Frame[10] = Factory_CheckButton(GetItemSubClassInfo(2, 18), Frame, 224, -136) -- Crossbows
	Frame[11] = Factory_CheckButton(GetItemSubClassInfo(2, 3), Frame, 32, -168) -- Guns
	Frame[12] = Factory_CheckButton(GetItemSubClassInfo(2, 6), Frame, 224, -168) -- Polearms
	Frame[13] = Factory_CheckButton(GetItemSubClassInfo(2, 9), Frame, 32, -200) -- Warglaives
	Frame[14] = Factory_CheckButton(GetItemSubClassInfo(2, 15), Frame, 224, -200) -- Daggers
	Frame[15] = Factory_CheckButton(GetItemSubClassInfo(2, 13), Frame, 32, -232) -- Fist Weapons
	Frame[16] = Factory_CheckButton(SHIELDSLOT, Frame, 224, -232) -- Shield
	Frame[17] = Factory_CheckButton(INVTYPE_WEAPONOFFHAND, Frame, 32, -268) -- Offhand
end

do -- Tradeskills [14]
	local Frame = CreateFrame("FRAME", nil, nil, nil)
	Filters[14] = Frame
	Frame:SetSize(128, 192)
	Frame:Hide()
	
	Frame.offsets = {0, 0}
	Frame.height = 192
	Frame.ItemClassID = ENUM_TRADEGOODS
	Frame.initValue = 0
	
	Frame.ToString = function(self, frame)
		local str, height = L["ITEM_TYPE"]..": "..GetItemClassInfo(self.ItemClassID), 2
		local filterData = frame.filterData
		if filterData == 0 then -- Nothing is filtered
			str = str.."\n  No filters are applied"
			height = height + 1
		else		
			for i=1,#self do
					if bit.band(filterData, bit.lshift(1, i-1)) > 0 then
						str = str.."\n  "..self[i]:GetFontString():GetText()
						height = height + 1
					end
				end
			end
		return str, height * 16
	end
	Frame.SaveData = function(self, frame, data)
		local hex
		if data then
			hex = data
		else
			hex = 0
			for i=1,#self do
				hex = hex + (self[i]:GetChecked() and bit.lshift(1, i-1) or 0)
			end
		end
		frame.filterData = hex
	end
	Frame.LoadData = function(self, frame, flag)
		local data = frame.filterData
		if flag then
			return tostring(data)
		else
			for i=1,#self do
				self[i]:SetChecked(bit.band(data, bit.lshift(1, i-1)) > 0)
			end
		end
	end

	Frame[1] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 5), Frame, 32, -8) -- Cloth
	Frame[2] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 6), Frame, 224, -8) -- Leather
	Frame[3] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 7), Frame, 32, -40) -- Metal & Stone
	Frame[4] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 9), Frame, 224, -40) -- Herb
	Frame[5] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 12), Frame, 32, -72) -- Enchanting
	Frame[6] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 16), Frame, 224, -72) -- Inscription
	Frame[7] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 4), Frame, 32, -104) -- Jewelcrafting
	Frame[8] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 8), Frame, 224, -104) -- Cooking
	Frame[9] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 10), Frame, 32, -136) -- Elemental
	Frame[10] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 11), Frame, 224, -136) -- Other
	Frame[11] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 18), Frame, 32, -168) -- Optional Reagents
	Frame[12] = Factory_CheckButton(GetItemSubClassInfo(ENUM_TRADEGOODS, 19), Frame, 224, -168) -- Finishing Reagents
end

do  -- Recipe [15]
	local Frame = CreateFrame("FRAME", nil, nil, nil)
	Filters[15] = Frame
	Frame:SetSize(128, 128)
	Frame:Hide()
	
	Frame.offsets = {0, 0}
	Frame.height = 128
	Frame.ItemClassID = ENUM_RECIPE
	Frame.initValue = 0
	
	Frame.ToString = function(self, frame)
		local str, height = L["ITEM_TYPE"]..": "..GetItemClassInfo(self.ItemClassID), 2
		local filterData = frame.filterData
		if filterData == 0 then -- Nothing is filtered
			str = str..L["NO_FILTERS_APPLIED"]
			height = height + 1
		else
			for i=1,#self do
				if bit.band(filterData, bit.lshift(1, i-1)) > 0 then
					str = str.."\n  "..self[i]:GetFontString():GetText()
					height = height + 1
				end
			end
		end
		return str, height * 16
	end
	Frame.SaveData = function(self, frame, data)
		local hex
		if data then
			hex = data
		else
			hex = 0
			for i=1,#self do
				hex = hex + (self[i]:GetChecked() and bit.lshift(1, i-1) or 0)
			end
		end
		frame.filterData = hex
	end
	Frame.LoadData = function(self, frame, flag)
		local data = frame.filterData
		if flag then
			return tostring(data)
		else
			for i=1,#self do
				self[i]:SetChecked(bit.band(data, bit.lshift(1, i-1)) > 0)
			end
		end
	end

	Frame[1] = Factory_CheckButton(GetItemSubClassInfo(ENUM_RECIPE, 1), Frame, 32, -8) -- Leatherworking
	Frame[2] = Factory_CheckButton(GetItemSubClassInfo(ENUM_RECIPE, 2), Frame, 224, -8) -- Tailoring
	Frame[3] = Factory_CheckButton(GetItemSubClassInfo(ENUM_RECIPE, 3), Frame, 32, -40) -- Engineering
	Frame[4] = Factory_CheckButton(GetItemSubClassInfo(ENUM_RECIPE, 4), Frame, 224, -40) -- Blacksmithing
	Frame[5] = Factory_CheckButton(GetItemSubClassInfo(ENUM_RECIPE, 6), Frame, 32, -72) -- Alchemy
	Frame[6] = Factory_CheckButton(GetItemSubClassInfo(ENUM_RECIPE, 8), Frame, 224, -72) -- Enchanting
	Frame[7] = Factory_CheckButton(GetItemSubClassInfo(ENUM_RECIPE, 10), Frame, 32, -104) -- Jewelcrafting
	Frame[8] = Factory_CheckButton(GetItemSubClassInfo(ENUM_RECIPE, 11), Frame, 224, -104) -- Inscription
end

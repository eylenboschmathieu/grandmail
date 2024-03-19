local addon, core = ...
-- Example at the bottom of the file

-- ScrollFrame auto updates when its scrollchild changes size (or wherever setpoint is for child objects)
Krozu_ScrollFrame_Mixin = {}

function Krozu_ScrollFrame_Mixin:GetScrollChild()
	return self.ScrollFrame.Scrollchild
end

function Krozu_ScrollFrame_Mixin:SetScrollStep(scrollStep)
	self.ScrollFrame.ScrollBar.scrollStep = scrollStep
	self.ScrollFrame.ScrollBar:SetValueStep(scrollStep)
end

function Krozu_ScrollFrame_Mixin:SetValue(value)
	self.ScrollFrame.ScrollBar:SetValue(value)
end

function Krozu_ScrollFrame_Mixin:GetMinMaxValues()
	return self.ScrollFrame.ScrollBar:GetMinMaxValues()
end

function Krozu_ScrollFrame_OnLoad(self)
	self:SetBackdrop(core.defaultBackdrop)
	self:SetBackdropBorderColor(0, 0, 0, .5)
		
	self.ScrollFrame.noScrollThumb = true
	self.ScrollFrame.noScrollBar = true
end

function Krozu_ScrollFrameScrollBar_OnLoad(self)
	self:SetBackdrop(core.defaultBackdrop)
	self:SetBackdropColor(0, 0, 0, 0)
	self:SetBackdropBorderColor(0, 0, 0, .5)
	
	self.ThumbTexture:SetVertexColor(unpack(core.classColour))
end

function Krozu_ScrollFrameScrollBar_OnMinMaxChanged(self, low, high)
	if floor(low) == floor(high) then
		self.ThumbTexture:Hide()
	else
		self.ThumbTexture:Show()
	end
end

function Krozu_ScrollFrameScrollButton_OnLoad(self)
	self:SetBackdrop(core.defaultBackdrop)
	self:SetBackdropColor(0, 0, 0, 0)
	self:SetBackdropBorderColor(0, 0, 0, .5)
end

function Krozu_ScrollFrameScrollButton_OnEnter(self)
	self:SetBackdropBorderColor(unpack(core.classColour))
end

function Krozu_ScrollFrameScrollButton_OnLeave(self)
	self:SetBackdropBorderColor(0, 0, 0, 1)
end

function Krozu_ScrollFrameScrollButton_OnDisable(self)
	self.tex:SetDesaturated(true)
end

function Krozu_ScrollFrameScrollButton_OnEnable(self)
	self.tex:SetDesaturated(false)
end

--[[
/run local w,h=KROZU_C:GetSize() print(math.floor(w+.5),math.floor(h+.5))

KROZU_F = CreateFrame("Frame", nil, UIParent, "Krozu_Scrollframe")
KROZU_F:SetPoint("CENTER", UIParent, "CENTER", -400, 0)
local nButtons = 20
local buttonHeight = 26
local nButtonsShown = 8
local offset = 4
local c = KROZU_F:GetScrollChild()

local buttonHeightWithOffset = buttonHeight + offset

KROZU_F:SetSize(120, nButtonsShown * buttonHeightWithOffset + offset)
c:SetHeight(nButtons * buttonHeightWithOffset + offset) -- this needs to be set to ensure the proper padding at the bottom
KROZU_F:SetBackdropColor(0, 0, 0, 0)
KROZU_F:SetScrollStep(buttonHeightWithOffset)
c.Buttons = {}
for i=0, nButtons-1 do
	local f = CreateFrame("Frame", nil, c, "BackdropTemplate")
	f:SetSize(96, buttonHeight)
	f:SetPoint("TOPLEFT", 4, -offset - buttonHeightWithOffset * i)
	f:SetBackdrop(core.defaultBackdrop)
	f:SetBackdropBorderColor(0, 0, 0, 1)
	f:SetBackdropColor(1, 1, 1, .3)
	f:Show()
	table.insert(c.Buttons, f)
end
]]
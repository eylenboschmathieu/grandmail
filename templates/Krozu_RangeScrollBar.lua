local addon, core = ...

local PerfectBorders = 768 / string.match(GetCVar("gxWindowedResolution"), "%d+x(%d+)") / GetCVar("uiScale")
local PerfectScale = function(ScaleObject)
	return PerfectBorders*math.floor(ScaleObject / PerfectBorders)
end

core.defaultBackdrop = {
	bgFile = [[Interface\BUTTONS\WHITE8X8]],
	edgeFile = [[Interface\BUTTONS\WHITE8X8]],
	tile = false,
	tileSize = 0,
	edgeSize = 1,
	insets = { 
		left = 0,
		top = 0,
		right = 0,
		bottom = 0
	}
}

core.defaultBackdropThick = {
	bgFile = [[Interface\BUTTONS\WHITE8X8]],
	edgeFile = [[Interface\BUTTONS\WHITE8X8]],
	tile = false,
	tileSize = 0,
	edgeSize = 2,
	insets = { 
		left = 0,
		top = 0,
		right = 0,
		bottom = 0
	}
}
core.fontPath = "Interface\\AddOns\\GrandMail\\CONSOLA.ttf"

-- General RangeScrollBarMixin

local function RangeScrollBar_Init(self, low, high, valueStep)
	self:SetMinMaxValues(low, high)
	
	valueStep = valueStep or 1
	
	self.SliderLow.scrollStep = valueStep
	self.SliderLow:SetValueStep(valueStep)
	self.SliderHigh.scrollStep = valueStep
	self.SliderHigh:SetValueStep(valueStep)
	
	-- Need to attach the extra textures here, its struggling somewhat in the xml file
	-- Thumb needs a value assigned to it so it gets created
	-- This happens after trying to set the point in the xml file, I think?
	self.SliderLow.ThumbExt:ClearAllPoints()
	self.SliderHigh.ThumbExt:ClearAllPoints()
	self.SliderLow.ThumbExt:SetPoint("TOPLEFT", self.SliderLow.Thumb, "BOTTOMLEFT")
	self.SliderHigh.ThumbExt:SetPoint("BOTTOMRIGHT", self.SliderHigh.Thumb, "TOPRIGHT")
	
	self.SliderLow:SetBackdrop(core.defaultBackdrop)
	self.SliderHigh:SetBackdrop(core.defaultBackdrop)
end

Krozu_RangeScrollBar_Mixin = {}

function Krozu_RangeScrollBar_Mixin:SetMinMaxValues(low, high)
	self.SliderLow:SetMinMaxValues(low, high)
	self.SliderHigh:SetMinMaxValues(low, high)
end

function Krozu_RangeScrollBar_Mixin:GetMinMaxValues()
	return self.SliderLow:GetMinMaxValues()
end

function Krozu_RangeScrollBar_Mixin:GetValues()
	return self.SliderLow:GetValue(), self.SliderHigh:GetValue()
end

function Krozu_RangeScrollBar_Mixin:SetValues(low, high) 
	local l, h = self:GetValues()
	if low > h then
		self.SliderHigh:SetValue(high)
		self.SliderLow:SetValue(low)
	else
		self.SliderLow:SetValue(low)
		self.SliderHigh:SetValue(high)
	end
end

function Krozu_RangeScrollBar_Mixin:SetBackdropColor(r, g, b, a)
	a = a or 1
	self.SliderLow:SetBackdropColor(r, g, b, a)
	self.SliderHigh:SetBackdropColor(r, g, b, a)
end

function Krozu_RangeScrollBar_Mixin:SetBackdropBorderColor(r, g, b, a)
	a = a or 1
	self.SliderLow:SetBackdropBorderColor(r, g, b, a)
	self.SliderHigh:SetBackdropBorderColor(r, g, b, a)
end

function Krozu_RangeScrollBar_Mixin:SetThumbColor(r, g, b, a)
	a = a or 1
	self.SliderLow.Thumb:SetVertexColor(r, g, b, a)
	self.SliderLow.ThumbExt:SetVertexColor(r, g, b, a)
	self.SliderHigh.Thumb:SetVertexColor(r, g, b, a)
	self.SliderHigh.ThumbExt:SetVertexColor(r, g, b, a)
end

function Krozu_RangeScrollBar_Mixin:SetThumbWidth(width)
	self.SliderLow.Thumb:SetWidth(width)
	self.SliderHigh.Thumb:SetWidth(width)
end

-- RangeScrollBarMixin with EditBox

Krozu_RangeScrollBarEditBox_Mixin = {}

function Krozu_RangeScrollBarEditBox_Mixin:Init(low, high, valueStep)
	RangeScrollBar_Init(self, low, high, valueStep)

	self.EditBoxLow:SetBackdrop(core.defaultBackdrop)
	self.EditBoxHigh:SetBackdrop(core.defaultBackdrop)
	
	self.EditBoxLow:SetJustifyH("CENTER")
	self.EditBoxHigh:SetJustifyH("CENTER")
end

function Krozu_RangeScrollBarEditBox_Mixin:SetEditBoxBackdropColor(r, g, b, a)
	a = a or 1
	self.EditBoxLow:SetBackdropColor(r, g, b, a)
	self.EditBoxHigh:SetBackdropColor(r, g, b, a)
end

function Krozu_RangeScrollBarEditBox_Mixin:SetEditBoxBackdropBorderColor(r, g, b, a)
	a = a or 1
	self.EditBoxLow:SetBackdropBorderColor(r, g, b, a)
	self.EditBoxHigh:SetBackdropBorderColor(r, g, b, a)
end

-- RangeScrollBarScripts with EditBox

function Krozu_RangeScrollBarEditBoxLow_OnValueChanged(self, value)
	local p = self:GetParent()
	if value > p.SliderHigh:GetValue() then
		self:SetValue(p.SliderHigh:GetValue())
		return
	end
	p.EditBoxLow:SetText(value)
end

function Krozu_RangeScrollBarEditBoxHigh_OnValueChanged(self, value)
	local p = self:GetParent()
	if value < p.SliderLow:GetValue() then
		self:SetValue(p.SliderLow:GetValue())
		return
	end
	p.EditBoxHigh:SetText(value)
end

function Krozu_RangeScrollBarEditBoxLow_OnEnterPressed(self)
	local p = self:GetParent()
	local low = p:GetMinMaxValues()
	local n = tonumber(self:GetText()) or low
	if n < low then
		n = low
	elseif n > p.SliderHigh:GetValue() then
		n = p.SliderHigh:GetValue()
	end
	self:SetText(n)
	p.SliderLow:SetValue(n)
end
	
function Krozu_RangeScrollBarEditBoxHigh_OnEnterPressed(self)
	local p = self:GetParent()
	local _, high = p:GetMinMaxValues()
	local n = tonumber(self:GetText()) or high
	if n > high then
		n = high
	elseif n < p.SliderLow:GetValue() then
		n = p.SliderLow:GetValue()
	end
	self:SetText(n)
	p.SliderHigh:SetValue(n)
end

-- RangeScrollBarMixin with Fontstrings

Krozu_RangeScrollBarFontstring_Mixin = {}

function Krozu_RangeScrollBarFontstring_Mixin:Init(low, high, step)
	RangeScrollBar_Init(self, low, high, step or 1)
end

-- RangeScrollBarScripts with Fontstrings

function Krozu_RangeScrollBarFontstringLow_OnValueChanged(self, value)
	local p = self:GetParent()
	if value > p.SliderHigh:GetValue() then
		self:SetValue(p.SliderHigh:GetValue())
		return
	end
	if p.StringTable then
		p.TextLow:SetText("From: "..p.StringTable[value])
	else
		p.TextLow:SetText("From: "..value)
	end
end

function Krozu_RangeScrollBarFontstringHigh_OnValueChanged(self, value)
	local p = self:GetParent()
	if value < p.SliderLow:GetValue() then
		self:SetValue(p.SliderLow:GetValue())
		return
	end
	if p.StringTable then
		p.TextHigh:SetText("To: "..p.StringTable[value])
	else
		p.TextHigh:SetText("To: "..value)
	end
end

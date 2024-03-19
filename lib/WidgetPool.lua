local addon, core = ...

function core.CreateWidgetPool(parent, createFunc, acquireFunc, releaseFunc)
	local pool = CreateFromMixins(core.Mixins.WidgetPoolMixin)
	pool:OnLoad(parent, "BackdropTemplate", createFunc, acquireFunc, releaseFunc)
	return pool
end
-- Library Version
local MAJOR, MINOR = 1, 0

local SniperTips = LibStub:NewLibrary("SniperTips-1.0", MAJOR, MINOR);

if not SniperTips then
  return	-- already loaded and no upgrade necessary
end

SniperTips.handlers = SniperTips.handlers or {}
SniperTips.handlers.items = SniperTips.handlers.items or {}

if not SniperTips.frame then
    SniperTips.frame=CreateFrame("Frame", SniperTips)
end

local tooltipTypes = {
	"GameTooltip",
	"ItemRefTooltip",
};

-- Options without TipTac. If the base TipTac addon is used, the global TipTac_Config table is used instead
local cfg = {
	if_enable = true,
	if_infoColor = { 0.2, 0.6, 1 },
	if_itemQualityBorder = true,

	if_showCurrencyId = true,					-- Az: no option for this added to TipTac/options yet!
	if_showAchievementIdAndCategory = false,	-- Az: no option for this added to TipTac/options yet!
	if_showIcon = true,
	if_smartIcons = true,
	if_borderlessIcons = false,
	if_iconSize = 42,
};

local tipsToAddIcon = tooltipTypes;
local tipDataAdded = {};	-- Sometimes, OnTooltipSetItem/Spell is called before the tip has been filled using SetHyperlink, we use the array to test if the tooltip has had data added

function SniperTips:GetVersion()
  return MAJOR, MINOR
end

function SniperTips:AddItemHandler(Addon)
  table.insert(SniperTips.handlers.items, Addon.name)
end

-- OnTooltipSetItem
local function OnTooltipSetItem(self,...)
	if (cfg.if_enable) and (not tipDataAdded[self]) then
		local _, link = self:GetItem();
		if (link) then
			local linkType, id = link:match("H?(%a+):(%d+)");
			if (id) then
        tipDataAdded[self] = linkType;
				SniperTips:HandleItem(self,link,linkType,id);
			end
		end
	end
end

local function OnTooltipCleared(self)
	tipDataAdded[self] = nil;
	if (self.SetIconTextureAndText) then
		self:SetIconTextureAndText();
	end
end

-- Resolve the tooltips from _G
local function ResolveGlobalNamedObjects(tipTable)
	local resolved = {};
	for index, tipName in ipairs(tipTable) do
		-- lookup the global object from this name, assign false if nonexistent, to preserve the table entry
		local tip = (_G[tipName] or false);

		-- Check if this object has already been resolved. This can happen for thing like AtlasLoot, which sets AtlasLootTooltip = GameTooltip
		if (resolved[tip]) then
			tip = false;
		elseif (tip) then
			resolved[tip] = index;
		end

		-- Assign the resolved object or false back into the table array
		tipTable[index] = tip;
	end
end

-- HOOK: ItemRefTooltip + GameTooltip: SetHyperlink
local function SetHyperlink_Hook(self,hyperLink)
	if (cfg.if_enable) and (not tipDataAdded[self]) then
		local refString = hyperLink:match("|H([^|]+)|h") or hyperLink;
		local linkType = refString:match("^[^:]+");
    -- Call Tip Type Func
		-- if (LinkTypeFuncs[linkType]) and (self:NumLines() > 0) then
		-- 	tipDataAdded[self] = "hyperlink";
		-- 	LinkTypeFuncs[linkType](self,refString,(":"):split(refString));
		-- end
	end
end

-- Frame Management

function SniperTips.frame:DoHooks()
	for index, tip in ipairs(tooltipTypes) do
		if (type(tip) == "table") and (type(tip.GetObjectType) == "function") and (tip:GetObjectType() == "GameTooltip") then
			-- if (tipsToAddIcon[tip:GetName()]) then
			-- 	self:CreateTooltipIcon(tip);
			-- end
			hooksecurefunc(tip,"SetHyperlink",SetHyperlink_Hook);
			tip:HookScript("OnTooltipSetItem",OnTooltipSetItem);
			tip:HookScript("OnTooltipCleared",OnTooltipCleared);
		end
	end
end

function SniperTips.frame:OnApplyConfig()
	local gameFont = GameFontNormal:GetFont();
	for index, tip in ipairs(tooltipTypes) do
		if (type(tip) == "table") and (tipsToAddIcon[tip:GetName()]) and (tip.ttIcon) then
			if (cfg.if_showIcon) then
				tip.ttIcon:SetSize(cfg.if_iconSize,cfg.if_iconSize);
				tip.ttCount:SetFont(gameFont,(cfg.if_iconSize / 3),"OUTLINE");
				tip.SetIconTextureAndText = SetIconTextureAndText;
				if (cfg.if_borderlessIcons) then
					tip.ttIcon:SetTexCoord(0.07,0.93,0.07,0.93);
				else
					tip.ttIcon:SetTexCoord(0,1,0,1);
				end
			elseif (tip.SetIconTextureAndText) then
				tip.ttIcon:Hide();
				tip.SetIconTextureAndText = nil;
			end
		end
	end
end

SniperTips.frame:SetScript("OnEvent",function(self,event,...)
	-- What tipsToModify to use, TipTac's main addon, or our own?
	if (TipTac and TipTac.tipsToModify) then
		tooltipTypes = TipTac.tipsToModify;
	else
		ResolveGlobalNamedObjects(tooltipTypes)
	end

	-- Use TipTac settings if installed
	if (TipTac_Config) then
		cfg = TipTac_Config;
	end

	-- Hook tips and apply settings
	SniperTips.frame:DoHooks();
	SniperTips.frame:OnApplyConfig();

	-- Cleanup; we no longer need to receive any events
	SniperTips.frame:UnregisterAllEvents();
	SniperTips.frame:SetScript("OnEvent",nil);
end);

SniperTips.frame:SetScript("OnUpdate", OnUpdate);

SniperTips.frame:RegisterEvent("VARIABLES_LOADED");

-- Other Addon Stuff

function SniperTips:HandleItem(self,link,linkType,id)
  local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
  itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
  isCraftingReagent = GetItemInfo(link);

  for _, addonName in ipairs(SniperTips.handlers.items) do
    a = LibStub("AceAddon-3.0"):GetAddon(addonName);
    a:HandleItem(self, itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
    itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
    isCraftingReagent)
    --handler(GetItemInfo(link))
  end
end

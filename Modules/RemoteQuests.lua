local SorhaQuestLog = LibStub("AceAddon-3.0"):GetAddon("SorhaQuestLog")
local L = LibStub("AceLocale-3.0"):GetLocale("SorhaQuestLog")
local MODNAME = "RemoteQuestsTracker"
local RemoteQuestsTracker = SorhaQuestLog:NewModule(MODNAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0", "LibSink-2.0")

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local fraMinionAnchor = nil
local blnMinionInitialized = false
local blnMinionUpdating = false

local strButtonPrefix = MODNAME .. "Button"
local intNumberUsedButtons = 0

local tblButtonCache = {}
local tblUsingButtons = {}

local strMinionTitleColour = "|cffffffff"

local intRemoteQuestButtonWidth = 224
local intRemoteQuestButtonHeight = 72
local intLastCountRemoteQuests = 0

local dicOutlines = {
	[""] = NONE,
	["OUTLINE"] = L["Outline"],
	["THICKOUTLINE"] = L["Thick Outline"],
	["MONOCHROMEOUTLINE"] = L["Monochrome Outline"],
}



--Defaults
local db
local dbCore
local defaults = {
	profile = {
		MinionParent = "UIParent",
		MinionLocation = {X = 0, Y = 0, Point = "CENTER", RelativePoint = "CENTER"},
		MinionScale = 1,
		MinionLocked = false,
		MinionWidth = 4,
		MoveTooltipsRight = false,
		ShowTitle = true,
		AutoHideTitle = false,
		OverrideDisplay = false,
		Fonts = {
			-- Scenario minion title font
			MinionTitleFontSize = 11,
			MinionTitleFont = "framd",
			MinionTitleFontOutline = "",
			MinionTitleFontShadowed = true,
		},
		Colours = {
			MinionTitleColour = {r = 0, g = 1, b = 0, a = 1},
			MinionBackGroundColour = {r = 0.5, g = 0.5, b = 0.5, a = 0},
			MinionBorderColour = {r = 0.5, g = 0.5, b = 0.5, a = 0},
		}
	}
}

--Options
local options
local function getOptions()
	if not options then
		options = {
			name = L["Remote Quests"],
			type = "group",
			childGroups = "tab",
			order = 1,
			arg = MODNAME,
			args = {
				Main = {
					name = "Main",
					type = "group",
					order = 1,
					args = {
						enabled = {
							order = 1,
							type = "toggle",
							name = L["Enable Minion"],
							get = function() return SorhaQuestLog:GetModuleEnabled(MODNAME) end,
							set = function(info, value) 
								SorhaQuestLog:SetModuleEnabled(MODNAME, value) 
								RemoteQuestsTracker:MinionAnchorUpdate(false)
							end,
						},
						MinionLockedToggle = {
							name = L["Lock Minion"],
							type = "toggle",
							get = function() return db.MinionLocked end,
							set = function()
								db.MinionLocked = not db.MinionLocked
								RemoteQuestsTracker:MinionAnchorUpdate(false)
							end,
							order = 2,
						},
						ShowTitleToggle = {
							name = L["Show Minion Title"],
							type = "toggle",
							width = "full",
							get = function() return db.ShowTitle end,
							set = function()
								db.ShowTitle = not db.ShowTitle
								RemoteQuestsTracker:UpdateMinion()
							end,
							order = 3,
						},
						AutoHideTitleToggle = {
							name = L["Auto Hide Minion Title"],
							desc = L["Hide the title when there is nothing to display"],
							type = "toggle",
							width = "full",
							disabled = function() return not(db.ShowTitle) end,
							get = function() return db.AutoHideTitle end,
							set = function()
								db.AutoHideTitle = not db.AutoHideTitle
								RemoteQuestsTracker:UpdateMinion(false)
							end,
							order = 4,
						},
						MinionSizeSlider = {
							order = 6,
							name = L["Minion Scale"],
							desc = L["Adjust the scale of the minion"],
							type = "range",
							min = 0.5, max = 2, step = 0.05,
							isPercent = false,
							get = function() return db.MinionScale end,
							set = function(info, value)
								db.MinionScale = value
								RemoteQuestsTracker:UpdateMinion()
							end,
						},
						MinionWidth = {
							order = 7,
							name = L["Width"],
							desc = L["Adjust the width of the minion"],
							type = "range",
							min = 150, max = 600, step = 1,
							isPercent = false,
							get = function() return db.MinionWidth end,
							set = function(info, value)
								db.MinionWidth = value
								RemoteQuestsTracker:UpdateMinion()
							end,
						},
						MinionParent = {
							name = L["Minion Anchor Point"],
							desc = L["The minion to anchor this minion to"],
							type = "select",
							order = 8,
							values = function() return SorhaQuestLog:GetPossibleParents(fraMinionAnchor)end,
							get = function() return db.MinionParent  end,
							set = function(info, value)							
								db.MinionParent = value
								if (value ~= "UIParent") then
									db.OverrideDisplay = false;
								end
								RemoteQuestsTracker:UpdateMinion()
							end,
						},
						OverrideDisplayToggle = {
							name = L["Always Show"],
							desc = L["Shows the minion even if SQL is set to hidden. Only works if not anchored to another minion"],
							type = "toggle",
							disabled = function() return not (db.MinionParent == "UIParent") end,
							get = function() return db.OverrideDisplay end,
							set = function()
								db.OverrideDisplay = not db.OverrideDisplay
								RemoteQuestsTracker:MinionAnchorUpdate(false)
							end,
							order = 9,
						},
					}
				},
				Fonts = {
					name = "Fonts",
					type = "group",
					order = 5,
					args = {
						HeaderTitleFont = {
							name = L["Minion Title Font Settings"],
							type = "header",
							order = 41,
						},
						MinionTitleFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 42,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.MinionTitleFont end,
							set = function(info, value)
								db.Fonts.MinionTitleFont = value
								RemoteQuestsTracker:UpdateMinion()
							end,
						},
						MinionTitleFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 43,
							values = dicOutlines,
							get = function() return db.Fonts.MinionTitleFontOutline end,
							set = function(info, value)
								db.Fonts.MinionTitleFontOutline = value
								RemoteQuestsTracker:UpdateMinion()
							end,
						},
						MinionTitleFontSizeSelect = {
							order = 44,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.MinionTitleFontSize end,
							set = function(info, value)
								db.Fonts.MinionTitleFontSize = value
								RemoteQuestsTracker:UpdateMinion()
							end,
						},
						MinionTitleFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.MinionTitleFontShadowed end,
							set = function()
								db.Fonts.MinionTitleFontShadowed = not db.Fonts.MinionTitleFontShadowed
								RemoteQuestsTracker:UpdateMinion()
							end,
							order = 45,
						},						
					}
				},
				Colours = {
					name = "Colours",
					type = "group",
					order = 6,
					args = {
						HeaderColourSettings = {
							name = L["Colour Settings"],
							type = "header",
							order = 80,
						},
						MinionTitleColour = {
							name = L["Minion Title"],
							desc = L["Sets the color for Minion Title"],
							type = "color",
							width = "full",
							hasAlpha = true,
							get = function() return db.Colours.MinionTitleColour.r, db.Colours.MinionTitleColour.g, db.Colours.MinionTitleColour.b, db.Colours.MinionTitleColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.MinionTitleColour.r = r
									db.Colours.MinionTitleColour.g = g
									db.Colours.MinionTitleColour.b = b
									db.Colours.MinionTitleColour.a = a
									RemoteQuestsTracker:HandleColourChanges()
								end,
							order = 81,
						},
						MinionBackGroundColour = {
							name = L["Background Colour"],
							desc = L["Sets the color of the minions background"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.MinionBackGroundColour.r = r
									db.Colours.MinionBackGroundColour.g = g
									db.Colours.MinionBackGroundColour.b = b
									db.Colours.MinionBackGroundColour.a = a
									RemoteQuestsTracker:HandleColourChanges()
								end,
							order = 85,
						},
						MinionBorderColour = {
							name = L["Border Colour"],
							desc = L["Sets the color of the minions border"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.MinionBorderColour.r = r
									db.Colours.MinionBorderColour.g = g
									db.Colours.MinionBorderColour.b = b
									db.Colours.MinionBorderColour.a = a
									RemoteQuestsTracker:HandleColourChanges()
								end,
							order = 86,
						},
					}
				},
			}
		}
	end


	return options
end

--Inits
function RemoteQuestsTracker:OnInitialize()
	self.db = SorhaQuestLog.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	dbCore = SorhaQuestLog.db.profile
	self:SetEnabledState(SorhaQuestLog:GetModuleEnabled(MODNAME))
	SorhaQuestLog:RegisterModuleOptions(MODNAME, getOptions, L["Remote Quests Tracker"])
	
	self:UpdateColourStrings()
	self:MinionAnchorUpdate(true)
end

function RemoteQuestsTracker:OnEnable()
	-- Hook for remote quest entry being added
	self:SecureHook("AutoQuestPopupTracker_AddPopUp")

	-- Hook for remote quest entry being removed
	self:SecureHook("AutoQuestPopupTracker_RemovePopUp")
	self:UpdateMinion()
end

function RemoteQuestsTracker:OnDisable()
	--Unhook
	self:UpdateMinion()
end

function RemoteQuestsTracker:Refresh()
	db = self.db.profile
	dbCore = SorhaQuestLog.db.profile
	
	self:HandleColourChanges()
	self:MinionAnchorUpdate(true)
end

--Events/handlers
function RemoteQuestsTracker:AutoQuestPopupTracker_AddPopUp(...)
	if (blnMinionUpdating == false) then
		blnMinionUpdating = true
		self:ScheduleTimer("UpdateMinion", 1)
	end
end

function RemoteQuestsTracker:AutoQuestPopupTracker_RemovePopUp(...)
	if (blnMinionUpdating == false) then
		self:UpdateMinion()
	end	
end

--Buttons
function RemoteQuestsTracker:GetMinionButton()
	local objButton = tremove(tblButtonCache)
	if (objButton == nil) then
		intNumberUsedButtons = intNumberUsedButtons + 1
		objButton = CreateFrame("SCROLLFRAME", strButtonPrefix .. intNumberUsedButtons, UIParent, "AutoQuestPopUpBlockTemplate");		
	end
	
	objButton:Show()
	return objButton
end

function RemoteQuestsTracker:RecycleMinionButton(objButton)
	objButton:SetParent(UIParent)
	objButton:SetScale(1)
	objButton:ClearAllPoints()

	objButton:SetScript("OnUpdate", nil)	
	objButton.index = 0
	objButton:SetHeight(80)
	objButton.totalTime = 0
	objButton.slideInTime = 0
	objButton.type=""
	objButton.ScrollChild.QuestionMark:Hide();
	objButton.ScrollChild.Exclamation:Hide();
	objButton.ScrollChild.TopText:SetText("");
	objButton.ScrollChild.BottomText:SetText("");
	objButton.ScrollChild.BottomText:Hide();
	objButton.ScrollChild.QuestName:SetText("");
	objButton.ScrollChild.Shine:Hide();
	objButton.ScrollChild.IconShine:Hide();
	objButton.questId = nil;

	objButton:Hide()

	tinsert(tblButtonCache, objButton)
end

--Minion
function RemoteQuestsTracker:CreateMinionLayout() 

	fraMinionAnchor = SorhaQuestLog:doCreateFrame("FRAME","SQLRemoteQuestsAnchor",UIParent,200,20,1,"BACKGROUND",1, db.MinionLocation.Point, UIParent, db.MinionLocation.RelativePoint, db.MinionLocation.X, db.MinionLocation.Y, 1)
	fraMinionAnchor:SetMovable(true)
	fraMinionAnchor:SetClampedToScreen(true)
	fraMinionAnchor:RegisterForDrag("LeftButton")
	fraMinionAnchor:SetScript("OnDragStart", fraMinionAnchor.StartMoving)
	fraMinionAnchor:SetScript("OnDragStop",  function(self)
		fraMinionAnchor:StopMovingOrSizing()
		local strPoint, tempB, strRelativePoint, intPosX, intPosY = fraMinionAnchor:GetPoint()
		db.MinionLocation.Point = strPoint
		db.MinionLocation.RelativePoint = strRelativePoint
		db.MinionLocation.X = intPosX
		db.MinionLocation.Y = intPosY
	end)
	fraMinionAnchor:SetScript("OnEnter", function(self) 
		if (dbCore.Main.ShowHelpTooltips == true) then
			if (db.MoveItemsAndTooltipsRight == true) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);
			else 
				GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, 0);
			end
			
			GameTooltip:SetText(L["Remote Quests Minion Anchor"], 0, 1, 0, 1);
			GameTooltip:AddLine(L["Drag this to move the Remote Quests minion when it is unlocked."], 1, 1, 1, 1);
			GameTooltip:AddLine(L["You can disable help tooltips in general settings"], 0.5, 0.5, 0.5, 1);
			
			GameTooltip:Show();
		end
	end)
	fraMinionAnchor:SetScript("OnLeave", function(self) 
		GameTooltip:Hide()
	end)
	
	fraMinionAnchor:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 5}})
	fraMinionAnchor:SetBackdropColor(0, 0, 0, 0)
	fraMinionAnchor:SetBackdropBorderColor(0, 0, 0, 0)

	-- Fontstring for title "Remote Quests"
	fraMinionAnchor.objFontString = fraMinionAnchor:CreateFontString(nil, "OVERLAY");
	fraMinionAnchor.objFontString:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT",0, 0);
	fraMinionAnchor.objFontString:SetFont(LSM:Fetch("font", db.Fonts.MinionTitleFont), db.Fonts.MinionTitleFontSize, db.Fonts.MinionTitleFontOutline)
	if (db.Fonts.MinionTitleFontShadowed == true) then
		fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	fraMinionAnchor.objFontString:SetJustifyH("LEFT")
	fraMinionAnchor.objFontString:SetJustifyV("TOP")
	fraMinionAnchor.objFontString:SetText("");
	fraMinionAnchor.objFontString:SetShadowOffset(1, -1)
	
	fraMinionAnchor.BorderFrame = SorhaQuestLog:doCreateFrame("FRAME","SQLRemoteQuestsMinionBorder", fraMinionAnchor, 100,20,1,"BACKGROUND",1, "TOPLEFT", fraMinionAnchor, "TOPLEFT", -6, 6, 1)
	fraMinionAnchor.BorderFrame:SetBackdrop({bgFile = LSM:Fetch("background", dbCore.BackgroundTexture), tile = false, tileSize = 16,	edgeFile = LSM:Fetch("border", dbCore.BorderTexture), edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 3}})
	fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a)
	fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a)
	fraMinionAnchor.BorderFrame:Show()
	
	fraMinionAnchor.BottomFrame = SorhaQuestLog:doCreateFrame("FRAME","SQLRemoteQuestsMinionBottom", fraMinionAnchor, db.MinionWidth,20,1,"BACKGROUND",1, "TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0, 1)
	
	blnMinionInitialized = true
	self:MinionAnchorUpdate(false)
end

function RemoteQuestsTracker:UpdateMinion()
	blnMinionUpdating = true
	
	-- If Achievement Minion is not Initialized then do so
	if (blnMinionInitialized == false) then
		self:CreateMinionLayout()
	end
	if (self:IsVisible() == false) then
		blnMinionUpdating = false
		return ""
	end
	
	local parent = fraMinionAnchor:GetParent();
	if (parent) then
		if (parent:GetName() ~= db.MinionParent) then
			if (_G[db.MinionParent]) then
				fraMinionAnchor:SetParent(db.MinionParent);	
			else 
				fraMinionAnchor:SetParent(UIParent);			
			end

			self:MinionAnchorUpdate(true);
		end
	end
	
	
	-- Release all used buttons
	for k, objButton in pairs(tblUsingButtons) do
		self:RecycleMinionButton(objButton)
	end
	wipe(tblUsingButtons)
	
	-- Get Number of Auto Quests
	local numAutoQuestPopUps = GetNumAutoQuestPopUps();
	

	local blnNothingShown = false
	local intLargestWidth = 0

	-- Show title if enabled	
	if (db.ShowTitle == true and (db.AutoHideTitle == false or (db.AutoHideTitle == true and (numAutoQuestPopUps > 0)))) then
		fraMinionAnchor.objFontString:SetFont(LSM:Fetch("font", db.Fonts.MinionTitleFont), db.Fonts.MinionTitleFontSize, db.Fonts.MinionTitleFontOutline)
		if (db.Fonts.MinionTitleFontShadowed == true) then
			fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
		else
			fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
		end
		
		fraMinionAnchor.objFontString:SetText(strMinionTitleColour .. L["Remote Quests Minion Title"])
		if (intLargestWidth < fraMinionAnchor.objFontString:GetStringWidth()) then
			intLargestWidth = fraMinionAnchor.objFontString:GetStringWidth()
		end
		
	else
		blnNothingShown = true
		fraMinionAnchor.objFontString:SetText("")
	end	
	
	if (numAutoQuestPopUps > 0) then
		local intButtonWidth = intRemoteQuestButtonWidth * db.MinionScale
		if (intLargestWidth < intButtonWidth) then
			intLargestWidth = intButtonWidth
		end
	end
	
	local intYPosition = (db.Fonts.MinionTitleFontSize / db.MinionScale)
	for i=1, numAutoQuestPopUps do
		local questID, popUpType = GetAutoQuestPopUp(i);
		local questTitle, level, suggestedGroup, isHeader, _, isComplete, isDaily = GetQuestLogTitle(GetQuestLogIndexByID(questID));
		
		if ( isComplete and isComplete > 0 ) then
			isComplete = true;
		else
			isComplete = false;
		end	

		if (questTitle and questTitle ~= "") then
			local objButton = self:GetMinionButton();
			objButton:SetScale(db.MinionScale)
			objButton:SetParent(fraMinionAnchor);
			objButton.index = i;
			objButton.id = questID;

			if (isComplete and popUpType == "COMPLETE") then
				objButton.ScrollChild.QuestionMark:Show();
				objButton.ScrollChild.Exclamation:Hide();
				if ( IsQuestTask(questID) ) then
					objButton.ScrollChild.TopText:SetText(QUEST_WATCH_POPUP_CLICK_TO_COMPLETE_TASK);
				else
					objButton.ScrollChild.TopText:SetText(QUEST_WATCH_POPUP_CLICK_TO_COMPLETE);
				end
				objButton.ScrollChild.BottomText:Hide();
				objButton.ScrollChild.TopText:SetPoint("TOP", 0, -15);

				if (objButton.ScrollChild.QuestName:GetStringWidth() > objButton.ScrollChild.QuestName:GetWidth()) then
					objButton.ScrollChild.QuestName:SetPoint("TOP", 0, -25);
				else
					objButton.ScrollChild.QuestName:SetPoint("TOP", 0, -29);
				end
				objButton.popUpType="COMPLETED";

			elseif (popUpType == "OFFER") then
				objButton.ScrollChild.QuestionMark:Hide();
				objButton.ScrollChild.Exclamation:Show();
				objButton.ScrollChild.TopText:SetText(QUEST_WATCH_POPUP_QUEST_DISCOVERED);
				objButton.ScrollChild.BottomText:Show();
				objButton.ScrollChild.BottomText:SetText(QUEST_WATCH_POPUP_CLICK_TO_VIEW);
				objButton.ScrollChild.TopText:SetPoint("TOP", 0, -9);
				objButton.ScrollChild.QuestName:SetPoint("TOP", 0, -20);
				objButton.ScrollChild.FlashFrame:Hide();
				objButton.popUpType="OFFER";
			end
			objButton:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, -intYPosition);
			objButton.ScrollChild.QuestName:SetText(questTitle);
			objButton.questId = questID;
			objButton.init = true;

			local SLIDE_DATA = { startHeight = 0, endHeight = 68, duration = 0.4, onFinishFunc = AutoQuestPopupTracker_OnFinishSlide };
			ObjectiveTracker_SlideBlock(objButton, SLIDE_DATA);
			
			-- if (i > intLastCountRemoteQuests) then
			-- 	objButton.ScrollChild.Shine:Hide();
			-- 	objButton.totalTime = 0;
			-- 	objButton.slideInTime = 0.4;
			-- 	objButton:SetHeight(1);


			-- 	local SLIDE_DATA = { startHeight = 0, endHeight = 68, duration = 0.4, onFinishFunc = AutoQuestPopupTracker_OnFinishSlide };

			-- 	objButton:SetScript("OnUpdate", RemoteQuestButton_OnUpdate);
			-- end
			
			intYPosition = intYPosition + intRemoteQuestButtonHeight
			
			tinsert(tblUsingButtons,objButton)			
		end
	end
	
	
	-- Border/Background
	if (blnNothingShown == true) then
		fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, 0)
		fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, 0)		
	else
		fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a)
		fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a)	
		fraMinionAnchor.BorderFrame:SetWidth(intLargestWidth + 12)
		fraMinionAnchor.BorderFrame:SetHeight((intYPosition * db.MinionScale) + 2 + fraMinionAnchor:GetHeight()/2)
	end
	
	intLastCountRemoteQuests = numAutoQuestPopUps

	fraMinionAnchor.BottomFrame:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, -intYPosition);
	fraMinionAnchor.BottomFrame:SetWidth(fraMinionAnchor:GetWidth());
	blnMinionUpdating = false


	
	if (numAutoQuestPopUps > #tblUsingButtons) then
		if (blnMinionUpdating == false) then
			blnMinionUpdating = true
			self:ScheduleTimer("UpdateMinion", 1)
		end
	end
end 

-- Remote Quest functions
local function RemoteQuestButton_OnUpdate(block, elasped)
	local startHeight = 0;
	local endHeight = 0;
	local duration = 0.4;

	local height = 75;
	local scrollStart = 80;
	local scrollEnd =-5;
	local offset = 0
	
	-- The first pop-up needs to include the WATCHFRAME_TYPE_OFFSET in the animation
	if (frame.index == 1) then
		height = height + offset;
		scrollEnd = scrollEnd - offset;
	end
	
	frame.totalTime = frame.totalTime+timestep;
	if (frame.totalTime > frame.slideInTime) then
		frame.totalTime = frame.slideInTime;
	end
	
	local scrollPos = scrollEnd;
	if (frame.slideInTime and frame.slideInTime > 0) then
		height = height*(frame.totalTime/frame.slideInTime);
		scrollPos = scrollStart + (scrollEnd-scrollStart)*(frame.totalTime/frame.slideInTime);
	end
	frame:SetHeight(height);
	frame:SetVerticalScroll(floor(scrollPos+0.5));
	if (frame.totalTime >= frame.slideInTime) then
		frame:SetScript("OnUpdate", nil);
		if (blnMinionUpdating == false) then
			blnMinionUpdating = true
			RemoteQuestsTracker:ScheduleTimer("UpdateMinion", 0.5)
		end
		frame.ScrollChild.Shine:Show();
		frame.ScrollChild.IconShine:Show();
		frame.ScrollChild.Shine.Flash:Play();
		frame.ScrollChild.IconShine.Flash:Play();
	end
end

--Uniform
function RemoteQuestsTracker:MinionAnchorUpdate(blnMoveAnchors) -- Updates backgrounds and visibility of scenario quests minion anchor frame
	-- Scenarios Quests
	if (blnMinionInitialized == false) then
		if (self:IsVisible() == true) then
			self:CreateMinionLayout()
		end
	end	
	
	if (blnMinionInitialized == true) then
		-- Enable/Disable movement	
		if (db.MinionLocked == false) then
			fraMinionAnchor:EnableMouse(true)
		else
			fraMinionAnchor:EnableMouse(false)
		end
		
		-- Show/Hide Quest Minion
		if (self:IsVisible() == true) then
			fraMinionAnchor:Show()
			if (dbCore.Main.ShowAnchors == true and db.MinionLocked == false) then
				fraMinionAnchor:SetBackdropColor(0, 1, 0, 1)
			else
				fraMinionAnchor:SetBackdropColor(0, 1, 0, 0)
			end
			
			if (blnMinionUpdating == false) then
				self:UpdateMinion()
			end
		else
			fraMinionAnchor:Hide()
		end
		
		fraMinionAnchor.BorderFrame:SetBackdrop({bgFile = LSM:Fetch("background", dbCore.BackgroundTexture), tile = false, tileSize = 16,	edgeFile = LSM:Fetch("border", dbCore.BorderTexture), edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 3}})

		-- Set position to stored position
		if (blnMoveAnchors == true) then
			fraMinionAnchor:ClearAllPoints()
			local isUIParent = false;
			if (db.MinionParent == "UIParent" or fraMinionAnchor:GetParent() == UIParent) then
				isUIParent = true;
			end

			if (isUIParent == true) then
				fraMinionAnchor:SetPoint(db.MinionLocation.Point, UIParent, db.MinionLocation.RelativePoint, db.MinionLocation.X, db.MinionLocation.Y);
			else
				fraMinionAnchor:SetPoint("TOPLEFT", db.MinionParent,"TOPLEFT", 0, -4);
			end
			fraMinionAnchor:SetScale(db.MinionScale);
		end
	end
end

function RemoteQuestsTracker:UpdateColourStrings()
	strMinionTitleColour = format("|c%02X%02X%02X%02X", 255, db.Colours.MinionTitleColour.r * 255, db.Colours.MinionTitleColour.g * 255, db.Colours.MinionTitleColour.b * 255);
end

function RemoteQuestsTracker:HandleColourChanges()
	self:UpdateColourStrings()
	if (self:IsVisible() == true) then
		if (blnMinionUpdating == false) then
			blnMinionUpdating = true
			self:ScheduleTimer("UpdateMinion", 0.1)
		end
	end
end

function RemoteQuestsTracker:ToggleLockState()
	db.MinionLocked = not db.MinionLocked
end

function RemoteQuestsTracker:IsVisible()
	if (self:IsEnabled() == true and (dbCore.Main.HideAll == false or db.OverrideDisplay == true)) then
		return true
	end
	return false	
end

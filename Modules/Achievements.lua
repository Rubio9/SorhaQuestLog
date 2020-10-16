local SorhaQuestLog = LibStub("AceAddon-3.0"):GetAddon("SorhaQuestLog")
local L = LibStub("AceLocale-3.0"):GetLocale("SorhaQuestLog")
local MODNAME = "AchievementTracker"
local AchievementsTracker = SorhaQuestLog:NewModule(MODNAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0", "LibSink-2.0")

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
local strAchievementTitleColour = "|cffffffff"
local strAchievementDescriptionColour = "|cffffffff"
local strAchievementObjectiveColour = "|cffffffff"
local strAchievementObjectiveDoneColour = "|cff33ff33"
local strAchievementObjectiveUndoneColour = "|cffDD2222"

local intLastAchievementTimerUpdateTime = 0
local intNumAchievementTimers = 0
local tblAchievementTimers = {}

local achievementsData = nil;

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
		MinionWidth = 220,
		MinionCollapseToLeft = false,
		MoveTooltipsRight = false,
		ShowTitle = true,
		AutoHideTitle = false,
		MaxTasksEachAchievement = 0,
		GrowUpwards = false,
		UseStatusBars = true,
		AchievementContentIndent = 5,
		PaddingAfterAchievement = 3,
		Fonts = {
			MinionTitleFontSize = 11,
			MinionTitleFont = "framd",
			MinionTitleFontOutline = "",
			MinionTitleFontShadowed = true,
			
			AchievementTitleFontSize = 11,
			AchievementTitleFont = "framd",
			AchievementTitleFontOutline = "",
			AchievementTitleFontShadowed = true,
						
			AchievementObjectiveFontSize = 11,
			AchievementObjectiveFont = "framd",
			AchievementObjectiveFontOutline = "",
			AchievementObjectiveFontShadowed = true,			
		},
		Colours = {
			MinionTitleColour = {r = 0, g = 1, b = 0, a = 1},
			AchievementTitleColour = {r = 0, g = 1, b = 0, a = 1},
			AchievementDescriptionColour = {r = 0.8, g = 1, b = 0.6, a = 1},			
			AchievementObjectiveColour = {r = 1, g = 1, b = 1, a = 1},			
			AchievementObjectiveUndoneColour = {r = 0.8, g = 0.1, b = 0.1, a = 1},			
			StatusBarFillColour = {r = 0, g = 1, b = 0, a = 1},
			StatusBarBackColour = {r = 0, g = 0, b = 0, a = 1},
			MinionBackGroundColour = {r = 0.5, g = 0.5, b = 0.5, a = 0},
			MinionBorderColour = {r = 0.5, g = 0.5, b = 0.5, a = 0},
		}
	}
}

-- Options
local options
local function getOptions()
	if not options then
		options = {
			name = L["Achievement Settings"],
			type = "group",
			childGroups = "tab",
			order = 2,
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
								AchievementsTracker:MinionAnchorUpdate(false)
							end,
						},
						MinionLockedToggle = {
							name = L["Lock Minion"],
							type = "toggle",
							get = function() return db.MinionLocked end,
							set = function()
								db.MinionLocked = not db.MinionLocked
								AchievementsTracker:MinionAnchorUpdate(false)
							end,
							order = 2,
						},
						spacer1 = {
							name = "",
							type = "description",
							width = "half",
							order = 3,
						},
						ShowTitleToggle = {
							name = L["Show Minion Title"],
							type = "toggle",
							get = function() return db.ShowTitle end,
							set = function()
								db.ShowTitle = not db.ShowTitle
								AchievementsTracker:UpdateMinion()
							end,
							order = 4,
						},
						AutoHideTitleToggle = {
							name = L["Auto Hide Minion Title"],
							desc = L["Hide the title when there is nothing to display"],
							type = "toggle",
							disabled = function() return not(db.ShowTitle) end,
							get = function() return db.AutoHideTitle end,
							set = function()
								db.AutoHideTitle = not db.AutoHideTitle
								AchievementsTracker:UpdateMinion(false)
							end,
							order = 5,
						},
						spacer2 = {
							name = "",
							type = "description",
							width = "half",
							order = 6,
						},
						GrowUpwardsToggle = {
							name = L["Grow Upwards"],
							desc = L["Minions grows upwards from the anchor"],
							type = "toggle",
							get = function() return db.GrowUpwards end,
							set = function()
								db.GrowUpwards = not db.GrowUpwards
								AchievementsTracker:UpdateMinion()
							end,
							order = 7,
						},						
						CollapseToLeftToggle = {
							name = L["Autoshrink to left"],
							desc = L["Shrinks the width down when the length of current achievements is less then the max width\nNote: Doesn't work well with achievements that word wrap"],
							type = "toggle",
							get = function() return db.MinionCollapseToLeft end,
							set = function()
								db.MinionCollapseToLeft = not db.MinionCollapseToLeft
								AchievementsTracker:UpdateMinion()
							end,
							order = 8,
						},
						MoveTooltipsRightToggle = {
							name = L["Tooltips on right"],
							desc = L["Moves the tooltips to the right"],
							type = "toggle",
							get = function() return db.MoveTooltipsRight end,
							set = function()
								db.MoveTooltipsRight = not db.MoveTooltipsRight
								AchievementsTracker:UpdateMinion()
							end,
							order = 9,
						},
						MinionScaler = {
							order = 10,
							name = L["Minion Scale"],
							desc = L["Adjust the scale of the minion"],
							type = "range",
							min = 0.5, max = 2, step = 0.05,
							isPercent = false,
							get = function() return db.MinionScale end,
							set = function(info, value)
								db.MinionScale = value
								AchievementsTracker:MinionAnchorUpdate(true)
							end,
						},
						MinionWidth = {
							order = 11,
							name = L["Width"],
							desc = L["Adjust the width of the minion"],
							type = "range",
							min = 150, max = 600, step = 1,
							isPercent = false,
							get = function() return db.MinionWidth end,
							set = function(info, value)
								db.MinionWidth = value
								AchievementsTracker:UpdateMinion()
							end,
						},		
						MinionParent = {
							name = L["Minion Anchor Point"],
							desc = L["The minion to anchor this minion to"],
							type = "select",
							order = 12,
							values = function() return SorhaQuestLog:GetPossibleParents(fraMinionAnchor)end,
							get = function() return db.MinionParent  end,
							set = function(info, value)
								db.MinionParent = value
								AchievementsTracker:UpdateMinion()
							end,
						},
						AchievementMinionReset = {
							order = 14,
							type = "execute",
							name = L["Reset Minion Position"],
							desc = L["Resets Achievement Minions position"],
							func = function()
								db.MinionLocation.Point = "CENTER"
								db.MinionLocation.RelativePoint =  "CENTER"
								db.MinionLocation.X = 0
								db.MinionLocation.Y = 0
								AchievementsTracker:MinionAnchorUpdate(true)
							end,
						},
						AchivementsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 30,
						},
						AchivementsSpacerHeader = {
							name = L["Achievement Settings"],
							type = "header",
							order = 31,
						},
						UseStatusBarsToggle = {
							name = L["Use Bars"],
							desc = L["Uses status bars for achievements with a quantity"],
							type = "toggle",
							get = function() return db.UseStatusBars end,
							set = function()
								db.UseStatusBars = not db.UseStatusBars
								AchievementsTracker:UpdateMinion()
							end,
							order = 32,
						},		
						MaxNumTasks = {
							order = 34,
							name = L["Tasks # Cap (0 = All)"],
							desc = L["# Tasks shown per Achievement. Set to 0 to display all tasks"],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.MaxTasksEachAchievement end,
							set = function(info, value)
								db.MaxTasksEachAchievement = value
								if (blnMinionUpdating == false) then
									blnMinionUpdating = true
									AchievementsTracker:ScheduleTimer("UpdateMinion", 0.25)
								end
							end,
						},
						ContentIndent = {
							order = 35,
							name = L["Content Indent"],
							desc = L["Controls the level of indentation for the achievements content"],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.AchievementContentIndent end,
							set = function(info, value)
								db.AchievementContentIndent = value
								AchievementsTracker:UpdateMinion()
							end,
						},
						AchievementAfterPadding = {
							order = 36,
							name = L["Achievement Padding"],
							desc = L["The amount of extra padding after an Achievement before the next."],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.PaddingAfterAchievement end,
							set = function(info, value)
								db.PaddingAfterAchievement = value
								AchievementsTracker:UpdateMinion()
							end,
						}
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
								AchievementsTracker:UpdateMinion()
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
								AchievementsTracker:UpdateMinion()
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
								AchievementsTracker:UpdateMinion()
							end,
						},
						MinionTitleFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.MinionTitleFontShadowed end,
							set = function()
								db.Fonts.MinionTitleFontShadowed = not db.Fonts.MinionTitleFontShadowed
								AchievementsTracker:UpdateMinion()
							end,
							order = 45,
						},
						
						HeaderFontsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 50,
						},
						HeaderFonts = {
							name = L["Header Font Settings"],
							type = "header",
							order = 51,
						},
						AchievementTitleFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 52,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.AchievementTitleFont end,
							set = function(info, value)
								db.Fonts.AchievementTitleFont = value
								AchievementsTracker:UpdateMinion()
							end,
						},
						AchievementTitleFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 53,
							values = dicOutlines,
							get = function() return db.Fonts.AchievementTitleFontOutline end,
							set = function(info, value)
								db.Fonts.AchievementTitleFontOutline = value
								AchievementsTracker:UpdateMinion()
							end,
						},
						AchievementTitleFontSizeSize = {
							order = 54,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.AchievementTitleFontSize end,
							set = function(info, value)
								db.Fonts.AchievementTitleFontSize = value
								AchievementsTracker:UpdateMinion()
							end,
						},
						AchievementTitleFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.AchievementTitleFontShadowed end,
							set = function()
								db.Fonts.AchievementTitleFontShadowed = not db.Fonts.AchievementTitleFontShadowed
								AchievementsTracker:UpdateMinion()
							end,
							order = 55,
						},
						
						TaskFontsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 60,
						},
						TaskFonts = {
							name = L["Task Font Settings"],
							type = "header",
							order = 61,
						},
						AchievementObjectiveFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 62,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.AchievementObjectiveFont end,
							set = function(info, value)
								db.Fonts.AchievementObjectiveFont = value
								AchievementsTracker:UpdateMinion()
							end,
						},
						AchievementObjectiveFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 63,
							values = dicOutlines,
							get = function() return db.Fonts.AchievementObjectiveFontOutline end,
							set = function(info, value)
								db.Fonts.AchievementObjectiveFontOutline = value
								AchievementsTracker:UpdateMinion()
							end,
						},
						AchievementObjectiveFontSize = {
							order = 64,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.AchievementObjectiveFontSize end,
							set = function(info, value)
								db.Fonts.AchievementObjectiveFontSize = value
								AchievementsTracker:UpdateMinion()
							end,
						},
						AchievementObjectiveFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.AchievementObjectiveFontShadowed end,
							set = function()
								db.Fonts.AchievementObjectiveFontShadowed = not db.Fonts.AchievementObjectiveFontShadowed
								AchievementsTracker:UpdateMinion()
							end,
							order = 65,
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
									AchievementsTracker:HandleColourChanges()
								end,
							order = 81,
						},
						AchievementTitleColour = {
							name = L["Achievement Titles"],
							desc = L["Sets the color for Achievement Titles"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.AchievementTitleColour.r, db.Colours.AchievementTitleColour.g, db.Colours.AchievementTitleColour.b, db.Colours.AchievementTitleColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.AchievementTitleColour.r = r
									db.Colours.AchievementTitleColour.g = g
									db.Colours.AchievementTitleColour.b = b
									db.Colours.AchievementTitleColour.a = a
									AchievementsTracker:HandleColourChanges()
								end,
							order = 82,
						},
						AchievementDescriptionColour = {
							name = L["Achievement Description"],
							desc = L["Sets the color for Achievement Description"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.AchievementDescriptionColour.r, db.Colours.AchievementDescriptionColour.g, db.Colours.AchievementDescriptionColour.b, db.Colours.AchievementDescriptionColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.AchievementDescriptionColour.r = r
									db.Colours.AchievementDescriptionColour.g = g
									db.Colours.AchievementDescriptionColour.b = b
									db.Colours.AchievementDescriptionColour.a = a
									AchievementsTracker:HandleColourChanges()
								end,
							order = 83,
						},
						AchievementObjectiveColour = {
							name = L["Achievement Task"],
							desc = L["Sets the color for Achievement Objectives"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.AchievementObjectiveColour.r, db.Colours.AchievementObjectiveColour.g, db.Colours.AchievementObjectiveColour.b, db.Colours.AchievementObjectiveColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.AchievementObjectiveColour.r = r
									db.Colours.AchievementObjectiveColour.g = g
									db.Colours.AchievementObjectiveColour.b = b
									db.Colours.AchievementObjectiveColour.a = a
									AchievementsTracker:HandleColourChanges()
								end,
							order = 84,
						},
						AchievementObjectiveUndoneColourSelector = {
							name = L["Task In Progress"],
							desc = L["Sets the color for In Progress Achievement Objectives"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.AchievementObjectiveUndoneColour.r, db.Colours.AchievementObjectiveUndoneColour.g, db.Colours.AchievementObjectiveUndoneColour.b, db.Colours.AchievementObjectiveUndoneColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.AchievementObjectiveUndoneColour.r = r
									db.Colours.AchievementObjectiveUndoneColour.g = g
									db.Colours.AchievementObjectiveUndoneColour.b = b
									db.Colours.AchievementObjectiveUndoneColour.a = a
									AchievementsTracker:HandleColourChanges()
								end,
							order = 85,
						},

						StatusBarFillColour = {
							name = L["Bar Fill Colour"],
							desc = L["Sets the color for the completed part of the achievement status bars"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.StatusBarFillColour.r = r
									db.Colours.StatusBarFillColour.g = g
									db.Colours.StatusBarFillColour.b = b
									db.Colours.StatusBarFillColour.a = a
									AchievementsTracker:UpdateMinion()
								end,
							order = 87,
						},
						StatusBarBackColour = {
							name = L["Bar Back Colour"],
							desc = L["Sets the color for the un-completed part of the achievement status bars"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.StatusBarBackColour.r = r
									db.Colours.StatusBarBackColour.g = g
									db.Colours.StatusBarBackColour.b = b
									db.Colours.StatusBarBackColour.a = a
									AchievementsTracker:UpdateMinion()
								end,
							order = 88,
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
									AchievementsTracker:HandleColourChanges()
								end,
							order = 89,
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
									AchievementsTracker:HandleColourChanges()
								end,
							order = 90,
						},
					}
				},
			}
		}
	end

	return options
end


--Classes
local SQLAchievementTimer = {};
SQLAchievementTimer.__index = SQLAchievementTimer; 

function SQLAchievementTimer:new(duration, elasped) 
	local self = {};
	setmetatable(self, SQLAchievementTimer);

	self.Duration = duration;
	if (elasped == nil) then
		elasped = 0;
	end
	
	self.Elasped = elasped;
	self.TimeLeft = 0;
	self.Running = false;

	self:Start();
	return self;
end

function SQLAchievementTimer:Start()
	self.Running = false;
	self.TimeLeft = self.Duration;
	if (self.Duration > self.Elasped) then
		self.Running = true;
	end
end

function SQLAchievementTimer:Stop()
	self.Duration = 0;
	self.Elasped = 0;
	self.Running = false;
	self.TimeLeft = 0;
end

function SQLAchievementTimer:Refresh(elasped)
	if (elasped ~= nil) then
		self.Elasped = elasped;
	end
	
	self.TimeLeft = self.Duration - self.Elasped;

	if (self.TimeLeft > 0) then
		self.Running = true;
	else
		self.Duration = 0;
		self.Elasped = 0;
		self.Running = false;
		self.TimeLeft = 0;
	end
end

function SQLAchievementTimer:Update(elasped)
	if (elasped ~= nil) then
		self.Elasped = self.Elasped + elasped;
	end
	self.TimeLeft = self.Duration - self.Elasped;

	if (self.TimeLeft > 0) then
		self.Running = true;
	else
		self.Duration = 0;
		self.Elasped = 0;
		self.Running = false;
		self.TimeLeft = 0;
	end
end


local SQLAchievementCriteria = {};
SQLAchievementCriteria.__index = SQLAchievementCriteria; 

function SQLAchievementCriteria:new(criteriaIndex, achievementID) 
	local self = {};
	setmetatable(self, SQLAchievementCriteria);

	self.Index = criteriaIndex;
	self.AchievementID = achievementID
	self.Text = ""
	self.TextOnly = false;
	self.Have = 0;
	self.Need = 0;
	self.CompletionLevel = 0;
	self.Type = 0;
	self.IsEligable = false;
	self.IsComplete = false;

	self.HasProgressBar = false;
	self.ProgressBarText = "";
	self.Timer = nil;

	self:Update();

	return self;
end

function SQLAchievementCriteria:Update()
	local criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString, criteriaID, eligible, duration, elapsed = GetAchievementCriteriaInfo(self.AchievementID, self.Index)
	self.Type = criteriaType;
	self.Have = quantity;
	self.Need = reqQuantity;	
	self.Flags = flags;

	if (completed ~= true and (completed == nil or completed == false or quantity >= reqQuantity or criteriaType == 75 or criteriaType == 81 or criteriaType == 156 or criteriaType == 157 or criteriaType == 158 or criteriaType == 160)) then
		self.IsComplete = false;
	else 
		self.IsComplete = true;
	end

	if (eligible == nil or eligible == false) then
		self.IsEligable = false;
	else
		self.IsEligable = true;
	end

	self.HasProgressBar = false;
	if ( bit.band(self.Flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR ) then
		self.HasProgressBar = true
	end

	self.ProgressBarText = quantityString;

	if ( criteriaType == CRITERIA_TYPE_ACHIEVEMENT and assetID ) then
		local _, tmp = GetAchievementInfo(assetID);
		criteriaString = tmp;
	end
	
	if (criteriaString and criteriaString ~= "") then		
		if string.match(criteriaString, ".+/.+") then
			local _, _, criteriaText = string.match(criteriaString, "(.*)/(%S*)%s*(.*)")
			self.Text = criteriaText;
		else
			self.Text = criteriaString;
			self.TextOnly = true;
		end
	end

	if (self.Timer == nil) then
		if (duration ~= nil and duration > 0) then
			if (elapsed == nil) then
				elapsed = 0;
			end
			self.Timer =  SQLAchievementTimer:new(duration, elapsed);
		end
	else
		self.Timer:Refresh(elapsed);
	end
end

function SQLAchievementCriteria:Render(colourCompletion)
	local strOutput ="";

	if (self.IsEligable == false) then
		strOutput = strOutput .. strAchievementObjectiveUndoneColour;
	else
		if (colourCompletion == true and self.IsComplete == true) then
			strOutput = strOutput .. strAchievementObjectiveDoneColour;
		else
			strOutput = strOutput .. strAchievementObjectiveColour;
		end
	end

	if (self.TextOnly == true or self.Need < 1) then
		strOutput = strOutput .. "- " .. self.Text .. "|r";
	else
		strOutput = strOutput .. "- " .. self.Have .. "/" .. self.Need .. " " .. self.Text .. "|r";
	end
	
	return strOutput;
end



local SQLAchievement = {};
SQLAchievement.__index = SQLAchievement; 

function SQLAchievement:new(achivementID) 
	local self = {};
	setmetatable(self, SQLAchievement);

	self.ID = achivementID;
	self.Name = nil;
	self.Points = nil;
	self.IsComplete = false;

	self.Day = nil;
	self.Month = nil;
	self.Year = nil;
	self.Description = "";

	self.Flags = nil;
	self.Icon = nil;
	self.RewardText = "";
	self.IsGuild = false;
	self.EarnedByMe = false;
	self.EarnedBy = nil;

	self.Timer = nil;

	self.CriteriaList = {};
	self.CriteriaCount = 0;

	self.Changed = false;
	self.Keep = false;
	self:Update();


	return self;
end

function SQLAchievement:Update()
	self.Changed = false;
	self.Keep = true;

	local id, name, points, completed, month, day, year, description, flags, icon, rewardText, IsGuild, WasEarnedByMe, EarnedBy = GetAchievementInfo(self.ID)
	self.Name = name;
	self.Points = points;

	self.Day = day;
	self.Month = month;
	self.Year = year;
	self.Description = description;

	self.Flags = flags;
	self.Icon = icon;
	self.RewardText = rewardText;
	self.IsGuild = IsGuild;
	self.EarnedByMe = WasEarnedByMe;
	self.EarnedBy = EarnedBy;



	if (self.Timer ~= nil) then
		if (self.Timer.Running == false) then
			self.Timer = nil;
		end
	end

	if (completed == nil) then
		self.IsComplete = false;
	else
		self.IsComplete = true;
	end
		
	local numCriteria = GetAchievementNumCriteria(self.ID)	
	for i=1, numCriteria, 1 do		
		if (self.CriteriaList[i] == nil) then
			self.CriteriaList[i] = SQLAchievementCriteria:new(i, self.ID);
			self.CriteriaCount = self.CriteriaCount + 1;
		else
			self.CriteriaList[i]:Update();
		end
	end

	self._FirstUpdate = false;
	return self;
end

function SQLAchievement:Render()
	return strAchievementTitleColour .. self.Name .. "|r";
end

function SQLAchievement:RenderDescription()
	if(IsAchievementEligible(self.ID)) then
		return strAchievementDescriptionColour .. self.Description  .. "|r";
	else
		return strAchievementObjectiveUndoneColour .. self.Description  .. "|r";
	end
end

local SQLAchievementsData = {};
SQLAchievementsData.__index = SQLAchievementsData; 


function SQLAchievementsData:new() 
	local self = {};
	setmetatable(self, SQLAchievementsData);

	self.FirstUpdate = true;
	self.EntryCount = 0;

	self.AchievementCount = 0;
	self.AchievementList = {};

	self.Changed = false;
	self:Update();
	return self;
end


function SQLAchievementsData:Update()
	--self.Changed = false;

	for achievementKey, achievement in pairs(self.AchievementList) do
    	achievement.Keep = false;
	end

	local achievementIDs = {GetTrackedAchievements()};
	for _, achievementID in ipairs(achievementIDs) do		
		if (self.AchievementList[achievementID] == nil) then
			self.AchievementList[achievementID] = SQLAchievement:new(achievementID);
			self.AchievementCount = self.AchievementCount + 1;
		else
			self.AchievementList[achievementID]:Update();
		end
	end

	for achievementKey, achievement in pairs(self.AchievementList) do
    	if (achievement.Keep == false) then
    		self.AchievementList[achievement.ID] = nil;
    		self.AchievementCount = self.AchievementCount - 1;
    	end
	end
	self.FirstUpdate = false;
end

--Inits
function AchievementsTracker:OnInitialize()
	self.db = SorhaQuestLog.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	dbCore = SorhaQuestLog.db.profile
	self:SetEnabledState(SorhaQuestLog:GetModuleEnabled(MODNAME))
	SorhaQuestLog:RegisterModuleOptions(MODNAME, getOptions, L["Achievement Tracker"])
	
	self:UpdateColourStrings()
	self:MinionAnchorUpdate(true)
end

function AchievementsTracker:OnEnable()
	self:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
	self:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
	
	self:MinionAnchorUpdate(false)
	self:UpdateMinion()
end

function AchievementsTracker:OnDisable()
	self:UnregisterEvent("TRACKED_ACHIEVEMENT_UPDATE")	
	self:UnregisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")	
	self:MinionAnchorUpdate(true)
	self:UpdateMinion()
end

function AchievementsTracker:Refresh()
	db = self.db.profile
	dbCore = SorhaQuestLog.db.profile
	
	self:HandleColourChanges()
	self:MinionAnchorUpdate(true)
end

--Events/handlers
function AchievementsTracker:TRACKED_ACHIEVEMENT_UPDATE(...)	
	local achievementID = select(2, ...);
	local elapsed = select(4, ...);
	local duration = select(5, ...);

	if (elapsed == nil) then
		elapsed = 0;
	end

	if (duration ~= nil and duration > 0) then
		AchievementsTracker:UpdateData();

		local achievementInstance = achievementsData.AchievementList[achievementID];
		if (achievementInstance ~= nil) then
			if (achievementInstance.Timer == nil) then
				if (duration > elapsed) then
					achievementInstance.Timer = SQLAchievementTimer:new(duration, elapsed);
				end
			else
				elapsed = elapsed + achievementInstance.Timer.Elasped;
				achievementInstance.Timer:Update(elapsed);
			end
		end
	end

	--self = AchievementsTracker
	if (self:IsVisible() == true) then
		if (blnMinionUpdating == false) then 
			blnMinionUpdating = true
			self:ScheduleTimer("UpdateMinion", 0.1)
		end
	end
end

function AchievementsTracker:TRACKED_ACHIEVEMENT_LIST_CHANGED(...)
	if (self:IsVisible() == true) then
		if (blnMinionUpdating == false) then 
			blnMinionUpdating = true
			self:ScheduleTimer("UpdateMinion", 0.1)
		end
	end
end

--Buttons
function AchievementsTracker:GetMinionButton()
	local objButton = SorhaQuestLog:GetLogButton()
	objButton:SetParent(fraMinionAnchor)
	tinsert(tblUsingButtons, objButton);
	
	objButton.objFontString1:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, 0);

	return objButton
end


function AchievementsTracker:GetMinionAchievementButton(achievementInstance)
	local objButton = AchievementsTracker:GetMinionButton(achievementInstance)
	objButton.AchievementInstance = achievementInstance;

	-- Set buttons title text
	objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.AchievementTitleFont), db.Fonts.AchievementTitleFontSize, db.Fonts.AchievementTitleFontOutline)
	if (db.Fonts.AchievementTitleFontShadowed == true) then
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	objButton.objFontString1:SetText(objButton.AchievementInstance:Render())
	if (objButton.objFontString1:GetWidth() > db.MinionWidth) then
		objButton.objFontString1:SetWidth(db.MinionWidth)
	end

	
	local currentHeight = 0;
	local currentWidth = 0;

	currentWidth = objButton.objFontString1:GetWidth();

	if (db.Fonts.AchievementTitleFontOutline == "THICKOUTLINE") then
		currentHeight = objButton.objFontString1:GetHeight() + 2;
	elseif (db.Fonts.AchievementTitleFontOutline == "OUTLINE") then
		currentHeight = objButton.objFontString1:GetHeight() + 1;
	else
		currentHeight = objButton.objFontString1:GetHeight();
	end
	

	if (objButton.AchievementInstance.Timer ~= nil) then
		objButton.TimerBar = AchievementsTracker:GetTimerStatusBar(objButton.AchievementInstance.Timer);
		objButton.TimerBar:SetParent(objButton)
		objButton.TimerBar:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, -currentHeight-3);
		currentHeight = currentHeight + objButton.TimerBar:GetHeight() + 3;

		if (currentWidth < objButton.TimerBar.Width) then
			currentWidth = objButton.TimerBar.Width
		end
	end


	objButton:RegisterForClicks("AnyUp")
	objButton:SetScript("OnClick", function(self, button)
		if (button == "LeftButton") then
			if (IsShiftKeyDown()) then
				ChatEdit_InsertLink(GetAchievementLink(self.AchievementInstance.ID))
			else
				if not(AchievementFrame) then
					AchievementFrame_LoadUI();
				end

				if not(AchievementFrame:IsShown()) then
					AchievementFrame_ToggleAchievementFrame();
				end
				AchievementFrame_SelectAchievement(self.AchievementInstance.ID);
			end
		else
			RemoveTrackedAchievement(self.AchievementInstance.ID)
		end
	end)
	objButton:SetScript("OnEnter", function(self)
		if (db.MoveTooltipsRight == true) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -50);
		else 
			GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, -50);
		end

		GameTooltip:SetText(self.AchievementInstance:Render(), 0, 1, 0, 1);
		
		GameTooltip:AddLine(self.AchievementInstance:RenderDescription(), 0.5, 0.5, 0.5, 1);
		if (self.AchievementInstance.CriteriaCount > 0) then
			GameTooltip:AddLine(" ", 0.5, 0.5, 0.5, 1);
		end
		for i, criteria in ipairs(self.AchievementInstance.CriteriaList) do
			if (criteria.HasProgressBar == true) then
				GameTooltip:AddLine(criteria.ProgressBarText, 0.5, 0.5, 0.5, 1);
			else
				GameTooltip:AddLine(criteria:Render(true), 0.5, 0.5, 0.5, 1);
			end
		end
			
		GameTooltip:Show();
	end)

	objButton:SetScript("OnLeave", function(self) 
		GameTooltip:Hide() 
	end)

	objButton.Width = currentWidth;
	objButton.Height = currentHeight;
	objButton:SetWidth(db.MinionWidth);	
	return objButton
end

function AchievementsTracker:GetMinionAchievementDescriptionButton(achievementInstance)
	local objButton = AchievementsTracker:GetMinionButton(achievementInstance)
	objButton.AchievementInstance = achievementInstance;

	objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.AchievementObjectiveFont), db.Fonts.AchievementObjectiveFontSize, db.Fonts.AchievementObjectiveFontOutline)
	if (db.Fonts.AchievementObjectiveFontShadowed == true) then
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	objButton.objFontString1:SetText(objButton.AchievementInstance:RenderDescription());

	if (objButton.objFontString1:GetWidth() > (db.MinionWidth - db.AchievementContentIndent)) then
		objButton.objFontString1:SetWidth(db.MinionWidth - db.AchievementContentIndent)
	end

	objButton.Width = objButton.objFontString1:GetWidth();

	if (db.Fonts.AchievementObjectiveFontOutline == "THICKOUTLINE") then
		objButton.Height = objButton.objFontString1:GetHeight() + 1.5;
	elseif (db.Fonts.AchievementObjectiveFontOutline == "OUTLINE") then
		objButton.Height = objButton.objFontString1:GetHeight() + 0.5;
	else
		objButton.Height = objButton.objFontString1:GetHeight();
	end


	objButton:SetHeight(objButton.Height);
	objButton:SetWidth(db.MinionWidth - db.AchievementContentIndent);
	return objButton
end

function AchievementsTracker:GetMinionCriteriaButton(criteriaInstance)
	local objButton = AchievementsTracker:GetMinionButton(achievementInstance)
	objButton.CriteriaInstance = criteriaInstance;

	objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.AchievementObjectiveFont), db.Fonts.AchievementObjectiveFontSize, db.Fonts.AchievementObjectiveFontOutline)
	if (db.Fonts.AchievementObjectiveFontShadowed == true) then
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	local currentHeight = 0;
	local currentWidth = 0;

	if (objButton.CriteriaInstance.HasProgressBar == false or db.UseStatusBars == false) then
		
		if (objButton.CriteriaInstance.HasProgressBar == false) then
			objButton.objFontString1:SetText(objButton.CriteriaInstance:Render());
		else
			objButton.objFontString1:SetText("- " .. objButton.CriteriaInstance.ProgressBarText);
		end
		

		if (objButton.objFontString1:GetWidth() > (db.MinionWidth - db.AchievementContentIndent)) then
			objButton.objFontString1:SetWidth(db.MinionWidth - db.AchievementContentIndent)
		end

		currentWidth = objButton.objFontString1:GetWidth();

		if (db.Fonts.AchievementObjectiveFontOutline == "THICKOUTLINE") then
			currentHeight = objButton.objFontString1:GetHeight() + 1.5;
		elseif (db.Fonts.AchievementObjectiveFontOutline == "OUTLINE") then
			currentHeight = objButton.objFontString1:GetHeight() + 0.5;
		else
			currentHeight = objButton.objFontString1:GetHeight();
		end	

	else
		objButton.StatusBar = AchievementsTracker:GetProgressStatusBar(objButton.CriteriaInstance);
		objButton.StatusBar:SetParent(objButton)
		objButton.StatusBar:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, -3);
		currentHeight = objButton.StatusBar:GetHeight() + 3;
		
		if (currentWidth < objButton.StatusBar.Width) then
			currentWidth = objButton.StatusBar.Width
		end
	end		

	if (objButton.CriteriaInstance.Timer ~= nil) then
		objButton.TimerBar = AchievementsTracker:GetTimerStatusBar(objButton.CriteriaInstance.Timer);
		objButton.TimerBar:SetParent(objButton)
		objButton.TimerBar:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, -currentHeight-3);
		currentHeight = currentHeight + objButton.TimerBar:GetHeight() + 3;

		if (currentWidth < objButton.TimerBar.Width) then
			currentWidth = objButton.TimerBar.Width
		end
	end


	objButton.Width = currentWidth;
	objButton.Height = currentHeight;

	objButton:SetHeight(objButton.Height);
	objButton:SetWidth(db.MinionWidth);
	return objButton
end

function AchievementsTracker:GetMinionCriteriaCappedButton()
	local objButton = AchievementsTracker:GetMinionButton()

	
	objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.AchievementObjectiveFont), db.Fonts.AchievementObjectiveFontSize, db.Fonts.AchievementObjectiveFontOutline)
	if (db.Fonts.AchievementObjectiveFontShadowed == true) then
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	local currentHeight = 0;
	local currentWidth = 0;

	objButton.objFontString1:SetText("...");
	if (objButton.objFontString1:GetWidth() > (db.MinionWidth - db.AchievementContentIndent)) then
		objButton.objFontString1:SetWidth(db.MinionWidth - db.AchievementContentIndent)
	end

	currentWidth = objButton.objFontString1:GetWidth();

	if (db.Fonts.AchievementObjectiveFontOutline == "THICKOUTLINE") then
		currentHeight = objButton.objFontString1:GetHeight() + 1.5;
	elseif (db.Fonts.AchievementObjectiveFontOutline == "OUTLINE") then
		currentHeight = objButton.objFontString1:GetHeight() + 0.5;
	else
		currentHeight = objButton.objFontString1:GetHeight();
	end	
	
	objButton.Width = currentWidth;
	objButton.Height = currentHeight;

	objButton:SetHeight(objButton.Height);
	objButton:SetWidth(db.MinionWidth);
	return objButton
end

function AchievementsTracker:RecycleMinionButton(objButton)
	objButton.Height = 0;
	objButton.AchievementInstance = nil;
	objButton.CriteriaInstance = nil;

	if (objButton.StatusBar ~= nil) then
		self:RecycleStatusBar(objButton.StatusBar)
		objButton.StatusBar = nil
	end

	if (objButton.TimerBar ~= nil) then
		self:RecycleStatusBar(objButton.TimerBar)
		objButton.TimerBar = nil
	end
	SorhaQuestLog:RecycleLogButton(objButton);
end

function AchievementsTracker:GetProgressStatusBar(criteriaInstance)
	local objStatusBar = SorhaQuestLog:GetStatusBar();
	objStatusBar.CriteriaInstance = criteriaInstance

	-- Setup colours and texture
	objStatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))
	objStatusBar:SetStatusBarColor(db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a)
	
	objStatusBar.Background:SetTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))			
	objStatusBar.Background:SetVertexColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)
	
	objStatusBar:SetBackdropColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)

	
	objStatusBar.objFontString:SetFont(LSM:Fetch("font", db.Fonts.AchievementObjectiveFont), db.Fonts.AchievementObjectiveFontSize, db.Fonts.AchievementObjectiveFontOutline)
	if (db.Fonts.AchievementObjectiveFontShadowed == true) then
		objStatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objStatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	objStatusBar.objFontString:SetText(objStatusBar.CriteriaInstance.ProgressBarText)
	objStatusBar.Width = objStatusBar.objFontString:GetWidth();


	objStatusBar.objFontString:SetHeight(objStatusBar.objFontString:GetHeight() + 1.99);
	objStatusBar:SetHeight(objStatusBar.objFontString:GetHeight())	
	
	objStatusBar:SetMinMaxValues(0, objStatusBar.CriteriaInstance.Need);
	objStatusBar:SetValue(objStatusBar.CriteriaInstance.Have);
	objStatusBar:Show()

	objStatusBar:SetWidth(db.MinionWidth - db.AchievementContentIndent);
	objStatusBar.objFontString:SetWidth(db.MinionWidth - db.AchievementContentIndent)
	return objStatusBar;
end

function AchievementsTracker:GetTimerStatusBar(timerInstance)
	local objStatusBar = SorhaQuestLog:GetStatusBar();
	objStatusBar.TimerInstance = timerInstance

	-- Setup colours and texture
	objStatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))
	objStatusBar:SetStatusBarColor(db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a)
	
	objStatusBar.Background:SetTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))			
	objStatusBar.Background:SetVertexColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)
	
	objStatusBar:SetBackdropColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)

	
	objStatusBar.objFontString:SetFont(LSM:Fetch("font", db.Fonts.AchievementObjectiveFont), db.Fonts.AchievementObjectiveFontSize, db.Fonts.AchievementObjectiveFontOutline)
	if (db.Fonts.AchievementObjectiveFontShadowed == true) then
		objStatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objStatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end

	local r,g,b = SorhaQuestLog:GetTimerTextColor(objStatusBar.TimerInstance.Duration, objStatusBar.TimerInstance.Elasped);
	local colour = format("|c%02X%02X%02X%02X", 255, r * 255, g * 255, b * 255);

	objStatusBar.objFontString:SetText( colour .. SorhaQuestLog:SecondsToFormatedTime(objStatusBar.TimerInstance.TimeLeft) .. "|r")

	objStatusBar.Width = objStatusBar.objFontString:GetWidth();
	
	objStatusBar.objFontString:SetHeight(objStatusBar.objFontString:GetHeight() + 1.99);
	objStatusBar:SetHeight(objStatusBar.objFontString:GetHeight())	

	objStatusBar:SetMinMaxValues(0, objStatusBar.TimerInstance.Duration);
	objStatusBar:SetValue(objStatusBar.TimerInstance.TimeLeft);

	objStatusBar:Show()

	objStatusBar.updateTimer = 0;

	objStatusBar:SetScript('OnUpdate', function(self, elapsed)
		self.updateTimer = self.updateTimer + elapsed

		if(self.updateTimer > 0.05) then
			self.TimerInstance:Update(self.updateTimer);
			objStatusBar:SetValue(self.TimerInstance.TimeLeft);

			local r,g,b = SorhaQuestLog:GetTimerTextColor(self.TimerInstance.Duration, self.TimerInstance.Elasped);
			local colour = format("|c%02X%02X%02X%02X", 255, r * 255, g * 255, b * 255);

			objStatusBar.objFontString:SetText( colour .. SorhaQuestLog:SecondsToFormatedTime(self.TimerInstance.TimeLeft) .. "|r")
			self.updateTimer = 0;
		end
	end)

	objStatusBar:SetWidth(db.MinionWidth - db.AchievementContentIndent);
	objStatusBar.objFontString:SetWidth(db.MinionWidth - db.AchievementContentIndent)
	return objStatusBar;
end

function AchievementsTracker:RecycleStatusBar(objStatusBar)
	objStatusBar:SetScript("OnUpdate", nil);
	objStatusBar.TimerInstance = nil;
	objStatusBar.CriteriaInstance = nil;
	SorhaQuestLog:RecycleStatusBar(objStatusBar)
end

--Minion
function AchievementsTracker:CreateMinionLayout()
	fraMinionAnchor = SorhaQuestLog:doCreateFrame("FRAME","SQLAchievementMinionAnchor",UIParent,100,20,1,"BACKGROUND",1, db.MinionLocation.Point, UIParent, db.MinionLocation.RelativePoint, db.MinionLocation.X, db.MinionLocation.Y, 1)
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
			
			GameTooltip:SetText(L["Achievement Minion Anchor"], 0, 1, 0, 1);
			GameTooltip:AddLine(L["Drag this to move the Achievement minion when it is unlocked."], 1, 1, 1, 1);
			GameTooltip:AddLine(L["You can disable help tooltips in general settings"], 0.5, 0.5, 0.5, 1);
			
			GameTooltip:Show();
		end
	end)
	fraMinionAnchor:SetScript("OnLeave", function(self) 
		GameTooltip:Hide()
	end)
	
	
	fraMinionAnchor:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 5}})
	fraMinionAnchor:SetBackdropColor(0, 0, 1, 0)
	fraMinionAnchor:SetBackdropBorderColor(0, 0, 0, 0)

	
	-- Achievements Anchor
	fraMinionAnchor.fraAchievementAnchor = SorhaQuestLog:doCreateLooseFrame("FRAME","SQLQuestsAnchor",fraMinionAnchor, fraMinionAnchor:GetWidth(),1,1,"LOW",1,1)
	fraMinionAnchor.fraAchievementAnchor:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0);
	fraMinionAnchor.fraAchievementAnchor:SetBackdropColor(0, 0, 0, 0)
	fraMinionAnchor.fraAchievementAnchor:SetBackdropBorderColor(0,0,0,0)
	fraMinionAnchor.fraAchievementAnchor:SetAlpha(0)
	
	
	-- Title Fontstring
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
	
	fraMinionAnchor.BorderFrame = SorhaQuestLog:doCreateFrame("FRAME","SQLAchievementMinionBorder", fraMinionAnchor, 100,20,1,"BACKGROUND",1, "TOPLEFT", fraMinionAnchor, "TOPLEFT", -8, 6, 1)
	fraMinionAnchor.BorderFrame:SetBackdrop({bgFile = LSM:Fetch("background", dbCore.BackgroundTexture), tile = false, tileSize = 16,	edgeFile = LSM:Fetch("border", dbCore.BorderTexture), edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 3}})
	fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a)
	fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a)
	fraMinionAnchor.BorderFrame:Show()
	
	fraMinionAnchor.BottomFrame = SorhaQuestLog:doCreateFrame("FRAME","SQLAchievementMinionBottom", fraMinionAnchor, db.MinionWidth,20,1,"BACKGROUND",1, "TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0, 1)
	
	blnMinionInitialized = true
	self:MinionAnchorUpdate(false)
end

function AchievementsTracker:UpdateMinion()
	blnMinionUpdating = true
	
	if (blnMinionInitialized == false) then
		self:CreateMinionLayout()
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

	
	if (self:IsVisible() == false) then
		blnMinionUpdating = false
		return ""
	end
	
	-- Release all used buttons
	for k, objButton in pairs(tblUsingButtons) do
		self:RecycleMinionButton(objButton)
	end
	wipe(tblUsingButtons)

	self:UpdateData();


	local intYPosition = 4
	local intLargestWidth = 0
	local blnNothingShown = true
	
	-- Show title if enabled
	if (db.ShowTitle == true and (db.AutoHideTitle == false or (db.AutoHideTitle == true and achievementsData.AchievementCount > 0))) then
		blnNothingShown = false
		fraMinionAnchor.objFontString:SetFont(LSM:Fetch("font", db.Fonts.MinionTitleFont), db.Fonts.MinionTitleFontSize, db.Fonts.MinionTitleFontOutline)
		if (db.Fonts.MinionTitleFontShadowed == true) then
			fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
		else
			fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
		end
		
		fraMinionAnchor.objFontString:SetText(strMinionTitleColour .. L["Achievement Tracker Title"] .. "|r");
		intLargestWidth = fraMinionAnchor.objFontString:GetWidth()
		
		intYPosition = db.Fonts.MinionTitleFontSize
	else
		fraMinionAnchor.objFontString:SetText("")
		intLargestWidth = 100
	end			
	fraMinionAnchor:SetWidth(db.MinionWidth)

	if (achievementsData.AchievementCount > 0) then
		blnNothingShown = false
	end
		
	-- Create main minions buttons and set text etc	
	local intInitialYOffset = intYPosition
	
	for k, AchievementInstance in pairs(achievementsData.AchievementList) do
		local objButton = AchievementsTracker:GetMinionAchievementButton(AchievementInstance)
		objButton:SetPoint("TOPLEFT", fraMinionAnchor.fraAchievementAnchor, "TOPLEFT", 0, -intYPosition);
		if (objButton.Width > intLargestWidth) then
			intLargestWidth = objButton.Width
		end

		local totalHeight = objButton.Height;
		intYPosition = intYPosition + objButton.Height;

		local objButtonDescription = AchievementsTracker:GetMinionAchievementDescriptionButton(AchievementInstance)
		objButtonDescription:SetPoint("TOPLEFT", fraMinionAnchor.fraAchievementAnchor, "TOPLEFT", db.AchievementContentIndent, -intYPosition);
		if (objButtonDescription.Width > intLargestWidth) then
			intLargestWidth = objButtonDescription.Width
		end
		intYPosition = intYPosition + objButtonDescription.Height;	
		totalHeight = totalHeight + objButtonDescription.Height;

		local displayedCriteria = 0;
		for i, CriteriaInstance in pairs(AchievementInstance.CriteriaList) do
			if (CriteriaInstance.IsComplete == false) then
				
				--Max count
				if (db.MaxTasksEachAchievement > 0 and displayedCriteria >= db.MaxTasksEachAchievement) then
					local objButtonCriteria = AchievementsTracker:GetMinionCriteriaCappedButton(CriteriaInstance)
					objButtonCriteria:SetPoint("TOPLEFT", fraMinionAnchor.fraAchievementAnchor, "TOPLEFT", db.AchievementContentIndent, -intYPosition);
					if (objButtonCriteria.Width > intLargestWidth) then
						intLargestWidth = objButtonCriteria.Width
					end
					intYPosition = intYPosition + objButtonCriteria.Height;	
					totalHeight = totalHeight + objButtonCriteria.Height;
					break;
				end


				local objButtonCriteria = AchievementsTracker:GetMinionCriteriaButton(CriteriaInstance)
				objButtonCriteria:SetPoint("TOPLEFT", fraMinionAnchor.fraAchievementAnchor, "TOPLEFT", db.AchievementContentIndent, -intYPosition);
				if (objButtonCriteria.Width > intLargestWidth) then
					intLargestWidth = objButtonCriteria.Width
				end
				
				intYPosition = intYPosition + objButtonCriteria.Height;	
				totalHeight = totalHeight + objButtonCriteria.Height;
				displayedCriteria = displayedCriteria +1
			end
		end
		objButton:SetHeight(totalHeight);

		intYPosition = intYPosition + db.PaddingAfterAchievement;
	end

	local intBorderWidth = db.MinionWidth
	-- Auto collapse
	
	if (db.MinionCollapseToLeft == true) then
		if (intLargestWidth < db.MinionWidth) then
			fraMinionAnchor:SetWidth(intLargestWidth)
			intBorderWidth = intLargestWidth
			
			for k, objButton in pairs(tblUsingButtons) do
				if (objButton.CriteriaInstance ~= nil) then
					objButton.objFontString1:SetWidth(intLargestWidth - db.AchievementContentIndent)
					objButton:SetWidth(intLargestWidth - db.AchievementContentIndent)
				else
					objButton.objFontString1:SetWidth(intLargestWidth)
					objButton:SetWidth(intLargestWidth)
				end
				if (objButton.StatusBar ~= nil) then
					objButton.StatusBar.objFontString:SetWidth(intLargestWidth - db.AchievementContentIndent)
					objButton.StatusBar:SetWidth(intLargestWidth - db.AchievementContentIndent)
				end
				if (objButton.TimerBar ~= nil) then
					objButton.TimerBar.objFontString:SetWidth(intLargestWidth - db.AchievementContentIndent)
					objButton.TimerBar:SetWidth(intLargestWidth - db.AchievementContentIndent)
				end				
			end
		end
	end
	
	
	-- Show border if at least the title is shown
	if (blnNothingShown == true) then
		fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, 0)
		fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, 0)		
	else
		fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a)
		fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a)	
		fraMinionAnchor.BorderFrame:SetWidth(intBorderWidth + 16)
	end
	
	fraMinionAnchor.BorderFrame:ClearAllPoints()
	
	-- Reposition/Resize the border and the Achievements Anchor based on grow upwards option
	if (db.GrowUpwards == false) then
		fraMinionAnchor.BorderFrame:SetPoint("TOPLEFT", fraMinionAnchor.fraAchievementAnchor, "TOPLEFT", -8, 6);
		fraMinionAnchor.BorderFrame:SetHeight(intYPosition + 2 + fraMinionAnchor:GetHeight()/2)
		fraMinionAnchor.fraAchievementAnchor:ClearAllPoints()
		fraMinionAnchor.fraAchievementAnchor:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0);
	else
		fraMinionAnchor.BorderFrame:SetPoint("TOPLEFT", fraMinionAnchor.fraAchievementAnchor, "TOPLEFT", -8,  6 - intInitialYOffset);
		fraMinionAnchor.BorderFrame:SetHeight(intYPosition + 2 + fraMinionAnchor:GetHeight()/2)
		fraMinionAnchor.fraAchievementAnchor:ClearAllPoints()
		fraMinionAnchor.fraAchievementAnchor:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, intYPosition);
	end

	fraMinionAnchor.BottomFrame:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, -intYPosition);
	fraMinionAnchor.BottomFrame:SetWidth(fraMinionAnchor:GetWidth());
	
	blnMinionUpdating = false
end 

function AchievementsTracker:UpdateData()
	if (achievementsData == nil) then
		achievementsData = SQLAchievementsData:new();	
	else
		achievementsData:Update();
	end
end


--Uniform
function AchievementsTracker:MinionAnchorUpdate(blnMoveAnchors)
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
		
		-- Show/Hide Minion
		if (self:IsVisible() == true and dbCore.Main.HideAll == false) then
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

function AchievementsTracker:UpdateColourStrings()
	strMinionTitleColour = format("|c%02X%02X%02X%02X", 255, db.Colours.MinionTitleColour.r * 255, db.Colours.MinionTitleColour.g * 255, db.Colours.MinionTitleColour.b * 255);
	strAchievementTitleColour = format("|c%02X%02X%02X%02X", 255, db.Colours.AchievementTitleColour.r * 255, db.Colours.AchievementTitleColour.g * 255, db.Colours.AchievementTitleColour.b * 255);
	strAchievementDescriptionColour = format("|c%02X%02X%02X%02X", 255, db.Colours.AchievementDescriptionColour.r * 255, db.Colours.AchievementDescriptionColour.g * 255, db.Colours.AchievementDescriptionColour.b * 255);	
	strAchievementObjectiveColour = format("|c%02X%02X%02X%02X", 255, db.Colours.AchievementObjectiveColour.r * 255, db.Colours.AchievementObjectiveColour.g * 255, db.Colours.AchievementObjectiveColour.b * 255);
	strAchievementObjectiveUndoneColour = format("|c%02X%02X%02X%02X", 255, db.Colours.AchievementObjectiveUndoneColour.r * 255, db.Colours.AchievementObjectiveUndoneColour.g * 255, db.Colours.AchievementObjectiveUndoneColour.b * 255);
	
end

function AchievementsTracker:HandleColourChanges()
	self:UpdateColourStrings()
	if (self:IsVisible() == true) then
		if (blnMinionUpdating == false) then
			blnMinionUpdating = true
			self:ScheduleTimer("UpdateMinion", 0.1)
		end
	end
end

function AchievementsTracker:ToggleLockState()
	db.MinionLocked = not db.MinionLocked
end

function AchievementsTracker:IsVisible()
	if (self:IsEnabled() == true and dbCore.Main.HideAll == false) then
		return true
	end
	return false	
end

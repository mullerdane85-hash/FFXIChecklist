texts = require('util/texts')
-- UI CONSTANTS
UI_SCALE				= tonumber(trackermenusettings.ui_scale) or 1
FONT_SIZE				= function() return 12 * UI_SCALE end
SUBTAB_FONT_SIZE 		= function() return 0.8 * FONT_SIZE() end
LINE_HEIGHT				= function() return 16 * UI_SCALE end
PADDING					= function() return 8 * UI_SCALE end
SUBTAB_PADDING			= function() return 0.8 * PADDING() end
CHAR_WIDTH				= function() return (FONT_SIZE()/(2*UI_SCALE)) * UI_SCALE end
VISIBLE_ROWS			= 15
-- UI COLORS
-- All panel-style alphas bumped to 250 (FFXIChecklist GUI fork). The
-- original XIchecklist used 200-240 which let the game world bleed
-- through the overlay; bumping makes it read as a solid window like
-- the rest of the GSUI-family addons (GSUI, FFXIJSE, FFXITrusts,
-- FFXIMissingSpells, FFXI-FFXIVHotbar).
UI_BG					= {red = 12, green = 12,  blue = 32,  alpha = 250}
UI_TABBG				= {red = 30, green = 60,  blue = 120, alpha = 250}
UI_TABBG_SELECTED		= {red = 70, green = 130, blue = 200, alpha = 250}
UI_SUBTABBG				= {red = 75, green = 75,  blue = 100, alpha = 250}
UI_SUBTABBG_SELECTED	= {red = 70, green = 130, blue = 200, alpha = 250}
UI_SUBTABBG_COMPLETED	= {red = 35, green = 110, blue = 35,  alpha = 250}
-- UI WINDOW STATE
active_tab				= 1
active_subtab			= 0
scroll					= 0
selected				= 1
maintabs_height			= 0
subtabs_height			= 0
subtabs_initiated 		= false
subtabs_drawn 			= false
-- UI DATA
tabs = {
    {
        name = 'Main',
        items = L{},
		button = {},
    },
    {
        name = 'Story',
        items = L{},
		button = {},
		tabs = {'sandoriamissions', 'bastokmissions', 'windurstmissions', 'zilartmissions', 'copmissions', 'assaults', 'ahturhganmissions', 'campaign', 'wotgmissions', 'acpmissions', 'mkdmissions', 'asamissions', 'soamissions', 'rovmissions', 'tvrmissions', 'sandoria', 'bastok', 'windurst', 'jeuno', 'ahturhgan', 'crystalwar', 'outlands', 'other', 'abyssea', 'adoulin', 'coalition'},
    },
	{
        name = 'Other Content',
        items = L{},
		button = {},
		tabs = {'fishes', 'ergonlocus'},
    },
	{
        name = 'Key Items',
        items = L{},
		button = {},
		tabs = {'Permanent_Key_Items', 'Magical_Maps', 'Mounts', 'Active_Effects', 'Abyssea', 'Voidwatch', 'Mog_Garden', 'Claim_Slips', 'atmacite'},
    },
	{
        name = 'Magic',
        items = L{},
		button = {},
		tabs = {'WhiteMagic', 'BlackMagic', 'SummonerPact', 'Ninjutsu', 'BardSong', 'BlueMagic', 'Geomancy', 'Trust'}
    },
	{
        name = 'Warps',
        items = L{},
		button = {},
		tabs = {'homepoints', 'survivalguides', 'waypoints', 'telepoints', 'cavernousmaws', 'lycopodium', 'eschanportals', 'outposts', 'protowaypoints', 'zones'},
    },
	{
        name = 'Monstrosity',
        items = L{},
		button = {},
		tabs = {'monsterlevels', 'monstervariants', 'racejobinstincts', 'monsterinstincts'},
    },
	{
        name = 'Titles',
        items = L{},
		button = {},
		tabs = {'titles', 'titles_by_content'},
    },
	{
        name = 'RoE',
        items = L{},
		button = {},
		tabs = {'roe'},
    },
	{
        name = 'Battle Content',
        items = L{},
		button = {},
		tabs = {'mmm_mazecount', 'mmmvouchers','mmmrunes','meebleburrows','sheola','sheolb','sheolc','sheolgaol','vorseals', 'emporox'},
    },
}

subtabs = T{}

-- UI TEXT OBJECT
ui = {}
ui.menu = texts.new('', {
    pos = { x = trackermenusettings.pos.x, y = trackermenusettings.pos.y },
    text = {
        font = 'Arial',
        size = FONT_SIZE(),
        red = 255, green = 255, blue = 255,
    },
    bg = {
        red = UI_BG.red, green = UI_BG.green, blue = UI_BG.blue,
        alpha = UI_BG.alpha,
    },
    padding = PADDING(),
})

initiate_tabs = function()
	for i, tab in ipairs(tabs) do
		tabs[i].button = texts.new('', {
			pos = { x = ui.menu:pos_x(), y = ui.menu:pos_y()},
			text = {
				font = 'Arial',
				size = FONT_SIZE(),
				red = 255, green = 255, blue = 255,
			},
			bg = {
				red = UI_TABBG.red, green = UI_TABBG.green, blue = UI_TABBG.blue,
				alpha = UI_TABBG.alpha,
			},
			padding = PADDING(),
			flags = {
				draggable = false,
			},
		})
		tabs[i].button:text(tab.name)
		tabs[i].button:register_event('left_click', function()
			if tabs[i].tabs then
				tabs[i].items = L{}
				for idx, tab in ipairs(tabs[i].tabs) do
					append_header(i, tab_logs[tab].name..' (%d/%d)', tab_logs[tab].completed, tab_logs[tab].total)
					if (addonhelptext[tab]) then
						for hi, helptext in pairs(addonhelptext[tab]) do
							append_addonhelp(i, addonhelptext[tab][hi][1], playertracker.talk_to_npc[addonhelptext[tab][hi][2]])
						end
					end
					append_items(tabs[i].items, tab_logs[tab].items)
				end
			end
			active_tab = i
			active_subtab = 0
			selected = 1
			scroll = 0
			subtabs_drawn = false
			draw()
		end)
		if tabs[i].tabs then
			initiate_subtabs(i, tabs[i].tabs)
		end
	end
	subtabs_initiated = true
end

initiate_subtabs = function(activetab, subtabslist)
	tabs[activetab].subtabs = {}
	for i, tab in ipairs(subtabslist) do
		tabs[activetab].subtabs[i] = {}
		tabs[activetab].subtabs[i].active_tab = activetab
		tabs[activetab].subtabs[i].button = texts.new('', {
			pos = {x = 0, y = 0},
			text = {
				font = 'Arial',
				size = FONT_SIZE(),
				red = 255, green = 255, blue = 255,
			},
			bg = {
				red = UI_SUBTABBG.red, green = UI_SUBTABBG.green, blue = UI_SUBTABBG.blue,
				alpha = UI_SUBTABBG.alpha,
			},
			padding = PADDING(),
			flags = {
				draggable = false,
			},
		})
		tabs[activetab].subtabs[i].button:text(defaulttab_logs[tab].name)
		tabs[activetab].subtabs[i].tab = tab
		tabs[activetab].subtabs[i].button:register_event('left_click', function()
			tabs[activetab].items = L{}
			append_header(activetab, tab_logs[tab].name..' (%d/%d)', tab_logs[tab].completed, tab_logs[tab].total)
			if (addonhelptext[tab]) then
				for i, helptext in pairs(addonhelptext[tab]) do
					append_addonhelp(activetab, addonhelptext[tab][i][1], playertracker.talk_to_npc[addonhelptext[tab][i][2]])
				end
			end
			append_items(tabs[activetab].items, tab_logs[tab].items)
			active_subtab = i
			selected = 1
			scroll = 0
			subtabs_drawn = false
			draw()
		end)
	end
end

-- =============================================================================
-- FFXIChecklist v1.1 layout: VERTICAL SIDEBAR on the left, items on the right
-- (FFXITrusts-style). The original XIchecklist used a horizontal tab strip
-- across the top with subtabs wrapping below; this stacks them vertically so
-- the right pane gets the full width for item text.
--
-- Per-tab vertical position:
--   main tab i lands at  base_y + maintabs_y_offset[i]
-- where maintabs_y_offset is recomputed each frame, allowing the active
-- tab's subtabs to push subsequent main tabs further down.
-- =============================================================================
maintabs_y_offset = {}    -- [i] = pixel y-offset of tab i from base_y
sidebar_width     = 0     -- widest main / subtab button this frame

draw_tabs = function()
	-- Anchor: trackermenusettings.pos is the SIDEBAR's top-left (the
	-- whole UI's anchor). ui.menu (the items pane) is positioned by
	-- draw() to sit just to the right of the sidebar. Both panes share
	-- the same anchor so dragging the items pane moves everything.
	local base_x = trackermenusettings.pos.x
	local base_y = trackermenusettings.pos.y
	local row_h  = LINE_HEIGHT()
	local sub_h  = math.floor(LINE_HEIGHT() * 0.9)
	local total_yextent = 0
	local widest = 0

	for i, tab in ipairs(tabs) do
		maintabs_y_offset[i] = total_yextent
		tabs[i].button:pos(base_x, base_y + total_yextent)
		tabs[i].button:visible(ui.menu:visible())
		tabs[i].button:size(FONT_SIZE())
		tabs[i].button:pad(PADDING())
		if active_tab == i then
			tabs[i].button:bg_color(UI_TABBG_SELECTED.red, UI_TABBG_SELECTED.green, UI_TABBG_SELECTED.blue)
			tabs[i].button:bg_alpha(UI_TABBG_SELECTED.alpha)
		else
			tabs[i].button:bg_color(UI_TABBG.red, UI_TABBG.green, UI_TABBG.blue)
			tabs[i].button:bg_alpha(UI_TABBG.alpha)
		end
		local xextent, yextent = tabs[i].button:extents()
		if xextent > widest then widest = xextent end
		total_yextent = total_yextent + yextent + 2

		-- If this is the active tab AND it has subtabs, reserve vertical
		-- space for them so the NEXT main tab gets pushed down. The actual
		-- subtab positioning happens in draw_subtabs() — we just account
		-- for the room they'll take.
		if active_tab == i and tabs[i].subtabs then
			for _ in pairs(tabs[i].subtabs) do
				total_yextent = total_yextent + sub_h + 1
			end
		end
	end

	sidebar_width  = widest
	maintabs_height = total_yextent
	ui.width        = widest
end

draw_subtabs = function()
	-- New layout: subtabs of the active main tab stack VERTICALLY directly
	-- below their parent in the sidebar (indented). Subtabs of non-active
	-- main tabs are hidden.
	if not subtabs_initiated then return end
	hide_subtabs()
	if not tabs[active_tab] or not tabs[active_tab].subtabs then
		subtabs_height = 0
		return
	end

	-- Sidebar anchor — match draw_tabs (relative to trackermenusettings.pos).
	local base_x = trackermenusettings.pos.x
	local base_y = trackermenusettings.pos.y
	-- Find the y position just below the active main tab button
	local parent_y = maintabs_y_offset[active_tab] or 0
	local main_xextent, main_yextent = tabs[active_tab].button:extents()
	local cursor_y = parent_y + main_yextent + 1
	local indent_x = math.floor(PADDING() * 0.6)

	for i, _ in pairs(tabs[active_tab].subtabs) do
		local sub = tabs[active_tab].subtabs[i]
		local tabname = sub.tab
		sub.button:pos(base_x + indent_x, base_y + cursor_y)
		sub.button:text(defaulttab_logs[tabname].name .. ' (%d/%d)':format(tab_logs[tabname].completed, tab_logs[tabname].total))
		sub.button:visible(ui.menu:visible())
		sub.button:size(SUBTAB_FONT_SIZE())
		sub.button:pad(SUBTAB_PADDING())
		if active_subtab == i then
			sub.button:bg_color(UI_SUBTABBG_SELECTED.red, UI_SUBTABBG_SELECTED.green, UI_SUBTABBG_SELECTED.blue)
			sub.button:bg_alpha(UI_SUBTABBG_SELECTED.alpha)
		else
			if (tab_logs[tabname].completed >= tab_logs[tabname].total) and (tab_logs[tabname].total > 0) then
				sub.button:bg_color(UI_SUBTABBG_COMPLETED.red, UI_SUBTABBG_COMPLETED.green, UI_SUBTABBG_COMPLETED.blue)
				sub.button:bg_alpha(UI_SUBTABBG_COMPLETED.alpha)
			else
				sub.button:bg_color(UI_SUBTABBG.red, UI_SUBTABBG.green, UI_SUBTABBG.blue)
				sub.button:bg_alpha(UI_SUBTABBG.alpha)
			end
		end
		local sub_xextent, sub_yextent = sub.button:extents()
		-- Track widest subtab against the sidebar width
		if (sub_xextent + indent_x) > sidebar_width then
			sidebar_width = sub_xextent + indent_x
			ui.width = sidebar_width
		end
		cursor_y = cursor_y + sub_yextent + 1
	end
	subtabs_height = cursor_y - (parent_y + main_yextent + 1)
end

hide_subtabs = function()
	for i, tab in ipairs(tabs) do
		if tabs[i].subtabs then
			for ti, tab in pairs(tabs[i].subtabs) do
				tabs[i].subtabs[ti].button:hide()
			end
		end
	end
	subtabs_height = 0
end

append_items = function(dst, src)
    if type(dst) ~= 'table' or type(src) ~= 'table' then
        return
    end
    for _, item in ipairs(src) do
		dst:append(item)
    end
end

format_item = function(item)
	local text = item.text
	local menucolor = item.completed and '(0,255,0)' or '(255,255,0)'
	if item.obtainmethod ~= nil then
		local obtainmethod = '\\cs(255,255,255)[' .. item.obtainmethod .. ']\\cr\\cs'..menucolor
		if item.category == 'Titles' then
			text = obtainmethod..' '..text
		else
			text = text..' '..obtainmethod
		end
	end
	text = '\\cs'..menucolor..text..'\\cr'
	
	return text
end

append_maintab = function(text, ...)
	local args = {...}
	local menulinecolor = (args[1]==args[2]) and '(0,255,0)' or '(255,255,0)'
	tabs[1].items:append(util.list_item(nil, '\\cs'..menulinecolor..'-'..text:format(...)..'\\cr'))
end

append_header = function(tab, text, ...)
	args = {...}
	local menulinecolor = (args[1]==args[2]) and '(0,255,0)' or '(255,255,255)'
	text = '==== '..text..' ===='
	tabs[tab].items:append(util.list_item(nil, '\\cs'..menulinecolor..text:format(...)..'\\cr'))
	if args[2] == 0 then
		tabs[tab].items:append(util.list_item(nil, '\\cs(235,0,0)You must zone to update.\\cr'))
	end
end

append_addonhelp = function(tab, text, condition)
	if not (condition and trackermenusettings.showcompleted) then
		append_items(tabs[tab].items, {util.list_item('Addon Help', '\\cs(235,0,0)'..text..'\\cr', condition)})
	end
end

-- UI HELPERS
inside = function(mx, my, x, y, width, h)
	return mx >= x and mx <= x + width
		and my >= y and my <= y + h
end

clamp_scroll = function(count)
	if selected < scroll + 1 then
		scroll = selected - 1
	elseif selected > scroll + VISIBLE_ROWS then
		scroll = selected - VISIBLE_ROWS
	end
	scroll = math.max(0, math.min(scroll, count - VISIBLE_ROWS))
end

draw = function()
	-- In the new vertical-sidebar layout, ui.menu is the RIGHT pane (the
	-- items list). It sits next to the sidebar buttons rather than below
	-- them. The sidebar buttons are positioned by draw_tabs / draw_subtabs
	-- using their own coordinates; ui.menu just needs to shift right by
	-- the sidebar width so the two don't overlap.
	local saved_x = trackermenusettings.pos.x
	local saved_y = trackermenusettings.pos.y
	local gap = math.floor(PADDING() * 0.8)
	local items_x = saved_x + (sidebar_width or 0) + gap
	ui.menu:pos(items_x, saved_y)

	local text = ''
	-- Right-pane header: which category/subcategory is being shown
	local heading = (tabs[active_tab] and tabs[active_tab].name) or ''
	if tabs[active_tab] and tabs[active_tab].subtabs
	   and active_subtab and active_subtab > 0
	   and tabs[active_tab].subtabs[active_subtab] then
		local sn = tabs[active_tab].subtabs[active_subtab].tab
		if defaulttab_logs[sn] then
			heading = heading .. ' / ' .. defaulttab_logs[sn].name
		end
	end
	text = text .. '\\cs(150,210,255)── '..heading..' ──\\cr\n'

	-- List
	local items = tabs[active_tab].items
	if (trackermenusettings.showcompleted == false) then
		items = items:filter(function(item)
			return item.completed == false
		end)
	end
	local count = items:length()
	if count == 0 then
		items = {util.list_item(nil, '\\cs(128,128,128)Change zones to update Quests / Campaigns / Warps / Monstrosity \\cr \n \\cs(128,128,128)Check the README or "//ffxic help" to register NPC-related data \\cr')}
		count = 1
	end
	clamp_scroll(count)
	for i = 1, VISIBLE_ROWS do
		local idx = i + scroll
		if items[idx] then
			text = text .. (idx == selected and '\\cs(255,0,0)> ' or '  ') .. format_item(items[idx]) .. '\\cr\n'
		end
	end
	ui.menu:text(text)
end

initiate_tabs()

-------------------------------------------------
windower.register_event('prerender', function()
	draw_tabs()
	draw_subtabs()
	draw()
	if not subtabs_drawn then
		coroutine.sleep(0.1)
		subtabs_drawn = true
	end
end)

ui.menu:register_event('drag', function()
	subtabs_drawn = false
	draw_tabs()
	draw_subtabs()
end)

windower.register_event('mouse', function(type, x, y, delta, blocked)
	if (ui.menu:visible() == false) then return end
    local px, py = ui.menu:pos()
    local items = tabs[active_tab].items
    local count = #items
	-- Translate items-pane position back to sidebar anchor before saving:
	-- ui.menu sits at (anchor.x + sidebar_width + gap, anchor.y). When the
	-- user drags ui.menu we need to recover anchor.x by subtracting the
	-- sidebar offset, otherwise the sidebar buttons drift further right
	-- every drag.
	local gap = math.floor(PADDING() * 0.8)
	local anchor_x = px - ((sidebar_width or 0) + gap)
	local anchor_y = py
	if (anchor_x ~= trackermenusettings.pos.x) or (anchor_y ~= trackermenusettings.pos.y) then
		trackermenusettings.pos.x = anchor_x
		trackermenusettings.pos.y = anchor_y
		trackermenusettings:save()
	end
	-- mouse scroll up down
	if delta and delta ~= 0 then
		if ui.menu:hover(x, y) then
			if delta > 0 then
				selected = math.max(1, selected - 1)
				clamp_scroll(count)
			else
				selected = math.min(count, selected - delta)
				clamp_scroll(count)
			end
			draw()
			return true
		end
	end
end)
-- =============================================================================
-- FFXIChecklist UI (GSUI-family / FFXITrusts-style window)
--
-- The original XIchecklist rendered each tab and subtab as its own loose
-- `texts.new` object floating on screen with no enclosing background.
-- This file replaces that with a self-contained window:
--
--   * Solid border + dark navy body (fully opaque)
--   * Header bar with title + close X
--   * Vertical sidebar on the left with main tabs; active main tab's
--     subtabs appear indented directly underneath it
--   * Items pane on the right (scrollable with mouse wheel)
--   * Drag the title bar to move the whole window
--
-- Public API preserved so menus.lua + the main lua keep working:
--   tabs, subtabs, ui, active_tab, active_subtab, scroll, selected (globals)
--   initiate_tabs(), initiate_subtabs(), draw_tabs(), draw_subtabs(),
--   hide_subtabs(), draw(), append_items(), format_item(),
--   append_maintab(), append_header(), append_addonhelp(),
--   inside(), clamp_scroll()
-- =============================================================================

texts = require('util/texts')
images = require('images')

-- =============================================================================
-- Constants
-- =============================================================================
UI_SCALE         = tonumber(trackermenusettings.ui_scale) or 1
FONT_SIZE        = function() return 11 * UI_SCALE end
SUBTAB_FONT_SIZE = function() return 9 * UI_SCALE end
TITLE_FONT_SIZE  = function() return 13 * UI_SCALE end
LINE_HEIGHT      = function() return 18 * UI_SCALE end
SUBTAB_HEIGHT    = function() return 16 * UI_SCALE end
PADDING          = function() return 8 * UI_SCALE end
SUBTAB_PADDING   = function() return 6 * UI_SCALE end
CHAR_WIDTH       = function() return 6 * UI_SCALE end
VISIBLE_ROWS     = 18

PANEL_W       = 720 * UI_SCALE       -- total window width
SIDEBAR_W     = 200 * UI_SCALE       -- left column width
HEADER_H      = 30 * UI_SCALE        -- title bar height
BORDER        = 3 * UI_SCALE
CLOSE_HIT_W   = 24 * UI_SCALE

-- =============================================================================
-- Colors (alpha, red, green, blue). Match the GSUI-family palette.
-- =============================================================================
UI_BORDER     = {red = 70,  green = 130, blue = 200, alpha = 230}
UI_BG         = {red = 12,  green = 12,  blue = 32,  alpha = 250}
UI_HEADER_BG  = {red = 22,  green = 36,  blue = 70,  alpha = 250}
UI_HEADER_LINE= {red = 60,  green = 110, blue = 160, alpha = 220}
UI_DIVIDER    = {red = 40,  green = 70,  blue = 110, alpha = 200}
UI_TABBG               = {red = 30, green = 60,  blue = 120, alpha = 250}
UI_TABBG_SELECTED      = {red = 70, green = 130, blue = 200, alpha = 250}
UI_SUBTABBG            = {red = 60, green = 65,  blue = 90,  alpha = 250}
UI_SUBTABBG_SELECTED   = {red = 70, green = 130, blue = 200, alpha = 250}
UI_SUBTABBG_COMPLETED  = {red = 35, green = 110, blue = 35,  alpha = 250}

-- =============================================================================
-- Window / runtime state
-- =============================================================================
active_tab        = 1
active_subtab     = 0
scroll            = 0
selected          = 1
subtabs_initiated = false
subtabs_drawn     = false

-- internal: vertical pixel-offset for each main tab (updated each frame so the
-- active tab's subtabs can push the next main tab down).
maintabs_y_offset = {}

-- =============================================================================
-- Tab data (categories rendered in the sidebar from top to bottom).
-- =============================================================================
tabs = {
    { name = 'Main', items = L{}, button = {} },
    { name = 'Story', items = L{}, button = {},
        tabs = {'sandoriamissions','bastokmissions','windurstmissions','zilartmissions','copmissions','assaults','ahturhganmissions','campaign','wotgmissions','acpmissions','mkdmissions','asamissions','soamissions','rovmissions','tvrmissions','sandoria','bastok','windurst','jeuno','ahturhgan','crystalwar','outlands','other','abyssea','adoulin','coalition'} },
    { name = 'Other Content', items = L{}, button = {}, tabs = {'fishes','ergonlocus'} },
    { name = 'Key Items', items = L{}, button = {},
        tabs = {'Permanent_Key_Items','Magical_Maps','Mounts','Active_Effects','Abyssea','Voidwatch','Mog_Garden','Claim_Slips','atmacite'} },
    { name = 'Magic', items = L{}, button = {},
        tabs = {'WhiteMagic','BlackMagic','SummonerPact','Ninjutsu','BardSong','BlueMagic','Geomancy','Trust'} },
    { name = 'Warps', items = L{}, button = {},
        tabs = {'homepoints','survivalguides','waypoints','telepoints','cavernousmaws','lycopodium','eschanportals','outposts','protowaypoints','zones'} },
    { name = 'Monstrosity', items = L{}, button = {},
        tabs = {'monsterlevels','monstervariants','racejobinstincts','monsterinstincts'} },
    { name = 'Titles', items = L{}, button = {}, tabs = {'titles','titles_by_content'} },
    { name = 'RoE', items = L{}, button = {}, tabs = {'roe'} },
    { name = 'Battle Content', items = L{}, button = {},
        tabs = {'mmm_mazecount','mmmvouchers','mmmrunes','meebleburrows','sheola','sheolb','sheolc','sheolgaol','vorseals','emporox'} },
}

subtabs = T{}

-- =============================================================================
-- UI elements
-- =============================================================================
ui = {}
ui.panel_h = 0      -- recomputed each frame so the panel tall enough for sidebar
ui.last_h  = 0      -- previous frame's height (used to detect resize)

-- A `texts.new` factory for buttons (clickable; bg color toggleable).
local function make_button(label, font_size)
    return texts.new('', {
        pos = {x = 0, y = 0},
        text = { font = 'Arial', size = font_size, red = 255, green = 255, blue = 255,
                 stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0} },
        bg = { red = UI_TABBG.red, green = UI_TABBG.green, blue = UI_TABBG.blue,
               alpha = UI_TABBG.alpha },
        padding = PADDING(),
        flags = { draggable = false },
    })
end

-- Background image factory
local function make_bg(c)
    return images.new({
        color = { alpha = c.alpha, red = c.red, green = c.green, blue = c.blue },
        pos   = { x = 0, y = 0 },
        size  = { width = 1, height = 1 },
        draggable = false,
        visible = false,
    })
end

-- Main panel pieces
ui.main_bg     = make_bg(UI_BG)
ui.border_top  = make_bg(UI_BORDER)
ui.border_bot  = make_bg(UI_BORDER)
ui.border_left = make_bg(UI_BORDER)
ui.border_rite = make_bg(UI_BORDER)
ui.header_bg   = make_bg(UI_HEADER_BG)
ui.header_line = make_bg(UI_HEADER_LINE)
ui.divider     = make_bg(UI_DIVIDER)

-- Title + close X (texts so they sit above the bg images and can take clicks)
ui.title_text = texts.new('', {
    pos = {x = 0, y = 0},
    text = { font = 'Arial', size = TITLE_FONT_SIZE(), red = 130, green = 210, blue = 240,
             stroke = {width = 1, alpha = 200, red = 0, green = 0, blue = 0} },
    bg = { alpha = 0 },
    padding = 0,
    flags = { draggable = true, bold = true },
})
ui.title_text:text('FFXIChecklist')

ui.close_text = texts.new('', {
    pos = {x = 0, y = 0},
    text = { font = 'Arial', size = TITLE_FONT_SIZE(), red = 230, green = 170, blue = 170,
             stroke = {width = 1, alpha = 200, red = 0, green = 0, blue = 0} },
    bg = { alpha = 0 },
    padding = 0,
    flags = { draggable = false, bold = true },
})
ui.close_text:text('X')
ui.close_text:register_event('left_click', function()
    trackermenusettings.visibility = false
    trackermenusettings:save()
    ui_hide_all()
end)

-- Items pane (the content on the right). Transparent bg so the panel
-- background shows through.
ui.menu = texts.new('', {
    pos = { x = trackermenusettings.pos.x or 200, y = trackermenusettings.pos.y or 200 },
    text = { font = 'Arial', size = FONT_SIZE(), red = 255, green = 255, blue = 255,
             stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0} },
    bg = { alpha = 0 },
    padding = PADDING(),
    flags = { draggable = false },
})

-- =============================================================================
-- show / hide helpers — driven by trackermenusettings.visibility
-- =============================================================================
ui_show_all = function()
    ui.main_bg:show(); ui.header_bg:show(); ui.header_line:show()
    ui.border_top:show(); ui.border_bot:show()
    ui.border_left:show(); ui.border_rite:show()
    ui.divider:show()
    ui.title_text:show(); ui.close_text:show()
    ui.menu:show()
    for _, tab in ipairs(tabs) do
        if tab.button and tab.button.show then tab.button:show() end
    end
    -- subtabs of the active tab handled by draw_subtabs / hide_subtabs
end

ui_hide_all = function()
    ui.main_bg:hide(); ui.header_bg:hide(); ui.header_line:hide()
    ui.border_top:hide(); ui.border_bot:hide()
    ui.border_left:hide(); ui.border_rite:hide()
    ui.divider:hide()
    ui.title_text:hide(); ui.close_text:hide()
    ui.menu:hide()
    for _, tab in ipairs(tabs) do
        if tab.button and tab.button.hide then tab.button:hide() end
    end
    for _, tab in ipairs(tabs) do
        if tab.subtabs then
            for _, s in pairs(tab.subtabs) do
                if s.button then s.button:hide() end
            end
        end
    end
end

-- Compatibility: existing code calls ui.menu:show()/hide() directly.
-- Wrap those into show/hide-all so the whole panel toggles together.
do
    local _orig_show = ui.menu.show
    local _orig_hide = ui.menu.hide
    function ui.menu:show()
        _orig_show(self)
        ui_show_all()
    end
    function ui.menu:hide()
        _orig_hide(self)
        ui_hide_all()
    end
end

-- =============================================================================
-- Tab + subtab button creation (click handlers preserved from the original).
-- =============================================================================
initiate_tabs = function()
    for i, tab in ipairs(tabs) do
        tabs[i].button = make_button(tab.name, FONT_SIZE())
        tabs[i].button:text(tab.name)
        tabs[i].button:register_event('left_click', function()
            if tabs[i].tabs then
                tabs[i].items = L{}
                for _, sn in ipairs(tabs[i].tabs) do
                    append_header(i, tab_logs[sn].name..' (%d/%d)', tab_logs[sn].completed, tab_logs[sn].total)
                    if addonhelptext[sn] then
                        for hi, _ in pairs(addonhelptext[sn]) do
                            append_addonhelp(i, addonhelptext[sn][hi][1], playertracker.talk_to_npc[addonhelptext[sn][hi][2]])
                        end
                    end
                    append_items(tabs[i].items, tab_logs[sn].items)
                end
            end
            active_tab    = i
            active_subtab = 0
            selected      = 1
            scroll        = 0
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
        tabs[activetab].subtabs[i] = {
            active_tab = activetab,
            tab        = tab,
            button     = make_button(defaulttab_logs[tab].name, SUBTAB_FONT_SIZE()),
        }
        tabs[activetab].subtabs[i].button:text(defaulttab_logs[tab].name)
        tabs[activetab].subtabs[i].button:register_event('left_click', function()
            tabs[activetab].items = L{}
            append_header(activetab, tab_logs[tab].name..' (%d/%d)', tab_logs[tab].completed, tab_logs[tab].total)
            if addonhelptext[tab] then
                for j, _ in pairs(addonhelptext[tab]) do
                    append_addonhelp(activetab, addonhelptext[tab][j][1], playertracker.talk_to_npc[addonhelptext[tab][j][2]])
                end
            end
            append_items(tabs[activetab].items, tab_logs[tab].items)
            active_subtab = i
            selected      = 1
            scroll        = 0
            subtabs_drawn = false
            draw()
        end)
    end
end

-- =============================================================================
-- Frame layout
-- =============================================================================
local function compute_panel_height()
    -- Sidebar height = vertical sum of all main tabs + active tab's subtabs
    local h = 0
    for i, tab in ipairs(tabs) do
        h = h + LINE_HEIGHT() + 2
        if active_tab == i and tab.subtabs then
            for _ in pairs(tab.subtabs) do
                h = h + SUBTAB_HEIGHT() + 1
            end
        end
    end
    -- Items pane height = VISIBLE_ROWS * line + heading
    local items_h = (VISIBLE_ROWS + 2) * LINE_HEIGHT()
    return math.max(h, items_h) + PADDING() * 2
end

draw_tabs = function()
    if not trackermenusettings.visibility then return end
    local px = trackermenusettings.pos.x
    local py = trackermenusettings.pos.y
    -- Sidebar starts inside the panel under the header
    local sx = px + BORDER + PADDING()
    local sy = py + BORDER + HEADER_H + PADDING()
    local cursor_y = 0

    for i, tab in ipairs(tabs) do
        maintabs_y_offset[i] = cursor_y
        tabs[i].button:pos(sx, sy + cursor_y)
        tabs[i].button:visible(true)
        tabs[i].button:size(FONT_SIZE())
        tabs[i].button:pad(PADDING())
        tabs[i].button:text(tab.name)
        if active_tab == i then
            tabs[i].button:bg_color(UI_TABBG_SELECTED.red, UI_TABBG_SELECTED.green, UI_TABBG_SELECTED.blue)
            tabs[i].button:bg_alpha(UI_TABBG_SELECTED.alpha)
        else
            tabs[i].button:bg_color(UI_TABBG.red, UI_TABBG.green, UI_TABBG.blue)
            tabs[i].button:bg_alpha(UI_TABBG.alpha)
        end
        local _, yextent = tabs[i].button:extents()
        cursor_y = cursor_y + (yextent or LINE_HEIGHT()) + 2

        -- Reserve room for the active tab's subtabs
        if active_tab == i and tabs[i].subtabs then
            for _ in pairs(tabs[i].subtabs) do
                cursor_y = cursor_y + SUBTAB_HEIGHT() + 1
            end
        end
    end
end

draw_subtabs = function()
    if not trackermenusettings.visibility then return end
    if not subtabs_initiated then return end
    hide_subtabs()
    if not tabs[active_tab] or not tabs[active_tab].subtabs then return end

    local px = trackermenusettings.pos.x
    local py = trackermenusettings.pos.y
    local sx = px + BORDER + PADDING()
    local sy = py + BORDER + HEADER_H + PADDING()
    local parent_y = maintabs_y_offset[active_tab] or 0
    local _, parent_h = tabs[active_tab].button:extents()
    local cursor_y = parent_y + (parent_h or LINE_HEIGHT()) + 1
    local indent = math.floor(PADDING() * 0.6)

    for i, _ in pairs(tabs[active_tab].subtabs) do
        local sub = tabs[active_tab].subtabs[i]
        local tabname = sub.tab
        sub.button:pos(sx + indent, sy + cursor_y)
        sub.button:visible(true)
        sub.button:size(SUBTAB_FONT_SIZE())
        sub.button:pad(SUBTAB_PADDING())
        sub.button:text(defaulttab_logs[tabname].name .. ' (%d/%d)':format(tab_logs[tabname].completed, tab_logs[tabname].total))
        if active_subtab == i then
            sub.button:bg_color(UI_SUBTABBG_SELECTED.red, UI_SUBTABBG_SELECTED.green, UI_SUBTABBG_SELECTED.blue)
            sub.button:bg_alpha(UI_SUBTABBG_SELECTED.alpha)
        elseif (tab_logs[tabname].completed >= tab_logs[tabname].total) and (tab_logs[tabname].total > 0) then
            sub.button:bg_color(UI_SUBTABBG_COMPLETED.red, UI_SUBTABBG_COMPLETED.green, UI_SUBTABBG_COMPLETED.blue)
            sub.button:bg_alpha(UI_SUBTABBG_COMPLETED.alpha)
        else
            sub.button:bg_color(UI_SUBTABBG.red, UI_SUBTABBG.green, UI_SUBTABBG.blue)
            sub.button:bg_alpha(UI_SUBTABBG.alpha)
        end
        cursor_y = cursor_y + SUBTAB_HEIGHT() + 1
    end
end

hide_subtabs = function()
    for _, tab in ipairs(tabs) do
        if tab.subtabs then
            for _, s in pairs(tab.subtabs) do
                if s.button then s.button:hide() end
            end
        end
    end
end

-- =============================================================================
-- Data API (preserved verbatim for menus.lua compatibility)
-- =============================================================================
append_items = function(dst, src)
    if type(dst) ~= 'table' or type(src) ~= 'table' then return end
    for _, item in ipairs(src) do dst:append(item) end
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

inside = function(mx, my, x, y, width, h)
    return mx >= x and mx <= x + width and my >= y and my <= y + h
end

clamp_scroll = function(count)
    if selected < scroll + 1 then
        scroll = selected - 1
    elseif selected > scroll + VISIBLE_ROWS then
        scroll = selected - VISIBLE_ROWS
    end
    scroll = math.max(0, math.min(scroll, count - VISIBLE_ROWS))
end

-- =============================================================================
-- Main draw — positions every panel piece and renders the items pane
-- =============================================================================
draw = function()
    if not trackermenusettings.visibility then return end

    local px = trackermenusettings.pos.x
    local py = trackermenusettings.pos.y

    -- Panel height adapts to content
    local body_h  = compute_panel_height()
    local total_h = HEADER_H + body_h + BORDER * 2
    ui.panel_h = total_h

    -- Main panel + borders
    ui.main_bg:pos(px, py)
    ui.main_bg:size(PANEL_W, total_h)
    ui.border_top:pos(px, py)
    ui.border_top:size(PANEL_W, BORDER)
    ui.border_bot:pos(px, py + total_h - BORDER)
    ui.border_bot:size(PANEL_W, BORDER)
    ui.border_left:pos(px, py)
    ui.border_left:size(BORDER, total_h)
    ui.border_rite:pos(px + PANEL_W - BORDER, py)
    ui.border_rite:size(BORDER, total_h)

    -- Header strip
    ui.header_bg:pos(px + BORDER, py + BORDER)
    ui.header_bg:size(PANEL_W - BORDER * 2, HEADER_H)
    ui.header_line:pos(px + BORDER, py + BORDER + HEADER_H)
    ui.header_line:size(PANEL_W - BORDER * 2, 1)
    ui.title_text:pos(px + BORDER + PADDING(), py + BORDER + math.floor((HEADER_H - TITLE_FONT_SIZE()) / 2))
    ui.close_text:pos(px + PANEL_W - BORDER - PADDING() - 8, py + BORDER + math.floor((HEADER_H - TITLE_FONT_SIZE()) / 2))

    -- Divider between sidebar and items pane
    local divider_x = px + BORDER + SIDEBAR_W
    ui.divider:pos(divider_x, py + BORDER + HEADER_H + 2)
    ui.divider:size(1, total_h - BORDER * 2 - HEADER_H - 4)

    -- Items pane to the right of the divider
    local items_x = divider_x + PADDING()
    local items_y = py + BORDER + HEADER_H + PADDING()
    ui.menu:pos(items_x, items_y)

    -- Build the items text
    local text = ''
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

    local items = tabs[active_tab].items
    if (trackermenusettings.showcompleted == false) then
        items = items:filter(function(item) return item.completed == false end)
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

-- =============================================================================
-- Wire up
-- =============================================================================
initiate_tabs()

windower.register_event('prerender', function()
    if not trackermenusettings.visibility then return end
    draw_tabs()
    draw_subtabs()
    draw()
    if not subtabs_drawn then
        coroutine.sleep(0.1)
        subtabs_drawn = true
    end
end)

-- Drag the title bar to move the whole window.
ui.title_text:register_event('drag', function()
    local tx, ty = ui.title_text:pos()
    -- title_text sits at (px + BORDER + PADDING(), py + BORDER + ...)
    -- so subtract the offsets to recover the anchor
    local anchor_x = tx - BORDER - PADDING()
    local anchor_y = ty - BORDER - math.floor((HEADER_H - TITLE_FONT_SIZE()) / 2)
    trackermenusettings.pos.x = anchor_x
    trackermenusettings.pos.y = anchor_y
    trackermenusettings:save()
    subtabs_drawn = false
end)

windower.register_event('mouse', function(type, x, y, delta, blocked)
    if not trackermenusettings.visibility then return end
    -- Scroll wheel: only when hovering anywhere over the panel
    if delta and delta ~= 0 then
        local px = trackermenusettings.pos.x
        local py = trackermenusettings.pos.y
        if inside(x, y, px, py, PANEL_W, ui.panel_h) then
            local items = tabs[active_tab].items
            local count = #items
            if delta > 0 then
                selected = math.max(1, selected - 1)
            else
                selected = math.min(count, selected - delta)
            end
            clamp_scroll(count)
            draw()
            return true
        end
    end
end)

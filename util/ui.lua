-- =============================================================================
-- FFXIChecklist UI — 3-pane window
--
--   ┌──────────────────────────────────────────────────────────────────┐
--   │ FFXIChecklist                                                  X │
--   ├──────────────────────────────────────────────────────────────────┤
--   │ [Main] [Story] [Other] [KI] [Magic] [Warps] [Monstr] [Titles]…   │  ← horizontal main tabs (wraps)
--   ├──────────────────┬───────────────────────────────────────────────┤
--   │ Subtab 1         │ ── Story / Sandoria Missions ──               │
--   │ Subtab 2  ◄      │                                               │
--   │ Subtab 3         │ > - Mission 1                                 │
--   │ Subtab 4         │   - Mission 2                                 │
--   │ ▲                │   ...                                         │
--   │ ▼                │                                               │
--   └──────────────────┴───────────────────────────────────────────────┘
--
-- Everything is enclosed in one bordered panel (FFXITrusts-family).
-- M toggles the window via trackermenusettings.visibility — the prerender
-- state machine at the bottom of this file shows/hides every panel piece
-- on transitions so nothing leaks visible after the window is closed.
-- =============================================================================

texts  = require('util/texts')
images = require('images')

-- Optional BG-Wiki quest info side-panel. Loaded lazily so the addon
-- still functions if the data file is missing.
quest_panel = nil
do
    local ok, mod = pcall(require, 'util/quest_panel')
    if ok and type(mod) == 'table' then quest_panel = mod end
end

-- =============================================================================
-- Constants
-- =============================================================================
UI_SCALE         = tonumber(trackermenusettings.ui_scale) or 1
FONT_SIZE        = function() return 11 * UI_SCALE end
SUBTAB_FONT_SIZE = function() return 10 * UI_SCALE end
TITLE_FONT_SIZE  = function() return 13 * UI_SCALE end
LINE_HEIGHT      = function() return 18 * UI_SCALE end
SUBTAB_HEIGHT    = function() return 18 * UI_SCALE end
MAINTAB_HEIGHT   = function() return 22 * UI_SCALE end
PADDING          = function() return 8 * UI_SCALE end
SUBTAB_PADDING   = function() return 5 * UI_SCALE end
CHAR_WIDTH       = function() return 6 * UI_SCALE end

VISIBLE_ROWS          = 16        -- items pane: rows shown at once
SIDEBAR_VISIBLE_ROWS  = 14        -- left sidebar: subtab rows shown at once

PANEL_W       = 900 * UI_SCALE
SIDEBAR_W     = 240 * UI_SCALE       -- bumped from 200 -- the longest subtab labels
                                     -- ("San d'Oria Missions (0/0)" etc.) were spilling
                                     -- past the column's right edge into the divider line.
HEADER_H      = 30 * UI_SCALE
BORDER        = 3 * UI_SCALE
MAINTAB_GAP   = 4 * UI_SCALE
SCROLL_BTN_H  = 18 * UI_SCALE

-- =============================================================================
-- Colors (alpha, red, green, blue) — GSUI-family palette
-- =============================================================================
UI_BORDER     = {red = 70,  green = 130, blue = 200, alpha = 230}
UI_BG         = {red = 12,  green = 12,  blue = 32,  alpha = 250}
UI_HEADER_BG  = {red = 22,  green = 36,  blue = 70,  alpha = 250}
UI_HEADER_LINE= {red = 60,  green = 110, blue = 160, alpha = 220}
UI_DIVIDER    = {red = 40,  green = 70,  blue = 110, alpha = 220}
UI_TABBG               = {red = 30, green = 60,  blue = 120, alpha = 250}
UI_TABBG_SELECTED      = {red = 70, green = 130, blue = 200, alpha = 250}
UI_SUBTABBG            = {red = 60, green = 65,  blue = 90,  alpha = 250}
UI_SUBTABBG_SELECTED   = {red = 70, green = 130, blue = 200, alpha = 250}
UI_SUBTABBG_COMPLETED  = {red = 35, green = 110, blue = 35,  alpha = 250}
UI_SCROLL_BG  = {red = 40, green = 50, blue = 90, alpha = 230}
UI_SCROLL_OFF = {red = 25, green = 30, blue = 55, alpha = 180}

-- =============================================================================
-- Window state
-- =============================================================================
active_tab        = 1
active_subtab     = 0
scroll            = 0       -- items pane scroll
sidebar_scroll    = 0       -- subtab sidebar scroll

-- Search state. Empty string = no filter (full list shown). Set by the
-- //xic search and //xic findall slash commands; consumed in draw()
-- below. search_scope = 'current' searches only the active subtab's
-- items; 'all' aggregates matches from every subtab in every tab and
-- prefixes each hit with its source [Subtab Name] so the user can
-- find a quest without knowing which tab it lives under.
search_query  = ''
search_scope  = 'current'
selected          = 1
subtabs_initiated = false
subtabs_drawn     = false

-- Layout-computed each frame
maintab_strip_h   = 0     -- pixel height occupied by the wrapped main tab strip
panel_h           = 0     -- total panel height (border to border)
sidebar_end_y     = 0     -- absolute y of the last sidebar element this frame

-- Drag state — owned by the global mouse handler (not the texts library)
-- so it works reliably even when we consume all mouse events over the
-- panel. drag.off_x/off_y is the cursor's offset from the panel anchor
-- at drag-start; updating the anchor by (cursor - offset) on every move
-- keeps the panel attached to the cursor.
local drag = { active = false, off_x = 0, off_y = 0 }

-- =============================================================================
-- Tab data — categories in the horizontal main-tab strip
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
-- UI elements (images = bg pieces, texts = clickable buttons / labels)
-- =============================================================================
ui = {}

local function make_button(font_size)
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

local function make_bg(c)
    return images.new({
        color = { alpha = c.alpha, red = c.red, green = c.green, blue = c.blue },
        pos   = { x = 0, y = 0 },
        size  = { width = 1, height = 1 },
        draggable = false,
        visible = false,
    })
end

-- Panel pieces
ui.main_bg     = make_bg(UI_BG)
ui.border_top  = make_bg(UI_BORDER)
ui.border_bot  = make_bg(UI_BORDER)
ui.border_left = make_bg(UI_BORDER)
ui.border_rite = make_bg(UI_BORDER)
ui.header_bg   = make_bg(UI_HEADER_BG)
ui.header_line = make_bg(UI_HEADER_LINE)
ui.divider     = make_bg(UI_DIVIDER)         -- vertical line between sidebar + items
ui.tabstrip_line = make_bg(UI_HEADER_LINE)   -- horizontal line below main tab strip

-- Title + close X. draggable=false: drag is handled by the global mouse
-- handler so it works reliably when we consume mouse events over the
-- panel (the texts library's own drag mechanism couldn't fire reliably
-- in that case).
ui.title_text = texts.new('', {
    pos = {x = 0, y = 0},
    text = { font = 'Arial', size = TITLE_FONT_SIZE(), red = 130, green = 210, blue = 240,
             stroke = {width = 1, alpha = 200, red = 0, green = 0, blue = 0} },
    bg = { alpha = 0 },
    padding = 0,
    flags = { draggable = false, bold = true },
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
end)

-- Sidebar scroll arrows (texts so they can take clicks)
ui.sidebar_up = texts.new('', {
    pos = {x = 0, y = 0},
    text = { font = 'Arial', size = SUBTAB_FONT_SIZE(), red = 255, green = 255, blue = 255,
             stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0} },
    bg = { red = UI_SCROLL_BG.red, green = UI_SCROLL_BG.green, blue = UI_SCROLL_BG.blue,
           alpha = UI_SCROLL_BG.alpha },
    padding = SUBTAB_PADDING(),
    flags = { draggable = false, bold = true },
})
ui.sidebar_up:text('▲  Scroll Up  ▲')
ui.sidebar_up:register_event('left_click', function()
    sidebar_scroll = math.max(0, sidebar_scroll - math.floor(SIDEBAR_VISIBLE_ROWS / 2))
end)

ui.sidebar_dn = texts.new('', {
    pos = {x = 0, y = 0},
    text = { font = 'Arial', size = SUBTAB_FONT_SIZE(), red = 255, green = 255, blue = 255,
             stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0} },
    bg = { red = UI_SCROLL_BG.red, green = UI_SCROLL_BG.green, blue = UI_SCROLL_BG.blue,
           alpha = UI_SCROLL_BG.alpha },
    padding = SUBTAB_PADDING(),
    flags = { draggable = false, bold = true },
})
ui.sidebar_dn:text('▼  Scroll Down  ▼')
ui.sidebar_dn:register_event('left_click', function()
    if tabs[active_tab] and tabs[active_tab].subtabs then
        local count = 0
        for _ in pairs(tabs[active_tab].subtabs) do count = count + 1 end
        sidebar_scroll = math.min(math.max(0, count - SIDEBAR_VISIBLE_ROWS),
                                  sidebar_scroll + math.floor(SIDEBAR_VISIBLE_ROWS / 2))
    end
end)

-- Items text (right pane). Transparent bg so the panel bg shows through.
ui.menu = texts.new('', {
    pos = { x = trackermenusettings.pos.x or 200, y = trackermenusettings.pos.y or 200 },
    text = { font = 'Arial', size = FONT_SIZE(), red = 255, green = 255, blue = 255,
             stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0} },
    bg = { alpha = 0 },
    padding = PADDING(),
    flags = { draggable = false },
})

-- =============================================================================
-- Show / hide every piece. ui_hide_all() is exhaustive — every texts.new
-- and images.new object created above gets hidden so the M key truly
-- closes the entire window with no leftover floaters.
-- =============================================================================
ui_show_all = function()
    ui.main_bg:show(); ui.header_bg:show(); ui.header_line:show()
    ui.border_top:show(); ui.border_bot:show()
    ui.border_left:show(); ui.border_rite:show()
    ui.divider:show()
    ui.tabstrip_line:show()
    ui.title_text:show(); ui.close_text:show()
    ui.menu:show()
    for _, tab in ipairs(tabs) do
        if tab.button and tab.button.show then tab.button:show() end
    end
    -- Subtabs: the prerender draw_subtabs() will (re)show only the
    -- visible ones for the active tab. Make sure inactive tabs'
    -- subtabs stay hidden.
    for i, tab in ipairs(tabs) do
        if tab.subtabs then
            for _, s in pairs(tab.subtabs) do
                if i ~= active_tab then
                    if s.bg then s.bg:hide() end
                    if s.label then s.label:hide() end
                end
            end
        end
    end
end

ui_hide_all = function()
    ui.main_bg:hide(); ui.header_bg:hide(); ui.header_line:hide()
    ui.border_top:hide(); ui.border_bot:hide()
    ui.border_left:hide(); ui.border_rite:hide()
    ui.divider:hide()
    ui.tabstrip_line:hide()
    ui.title_text:hide(); ui.close_text:hide()
    ui.menu:hide()
    ui.sidebar_up:hide(); ui.sidebar_dn:hide()
    -- EVERY main tab + EVERY subtab (bg + label) -- no floating leftovers
    for _, tab in ipairs(tabs) do
        if tab.button and tab.button.hide then tab.button:hide() end
        if tab.subtabs then
            for _, s in pairs(tab.subtabs) do
                if s.bg then s.bg:hide() end
                if s.label then s.label:hide() end
                s.rect = {x = 0, y = 0, w = 0, h = 0}
            end
        end
    end
end

-- =============================================================================
-- Tab / subtab button creation — click handlers populate items list
-- =============================================================================
initiate_tabs = function()
    for i, tab in ipairs(tabs) do
        tabs[i].button = make_button(FONT_SIZE())
        tabs[i].button:text(tab.name)
        tabs[i].button:register_event('left_click', function()
            -- Switching main tab: rebuild items, reset scroll, reset selection
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
            active_tab     = i
            active_subtab  = 0
            selected       = 1
            scroll         = 0
            sidebar_scroll = 0
            subtabs_drawn  = false
            -- Hide subtabs of every OTHER main tab so their bgs/labels
            -- don't render underneath the new active tab's subtabs.
            -- (Previously this called s.button:hide(), but after the
            -- refactor to images.new bg + transparent label that field
            -- no longer exists — the old subtabs were stuck visible.)
            for j, t in ipairs(tabs) do
                if t.subtabs and j ~= i then
                    for _, s in pairs(t.subtabs) do
                        if s.bg then s.bg:hide() end
                        if s.label then s.label:hide() end
                        s.rect = {x = 0, y = 0, w = 0, h = 0}
                    end
                end
            end
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
        -- Each subtab is now a fixed-width images.new background + a
        -- transparent texts.new label on top + a click handler closure.
        -- Clicks are hit-tested against `rect` in the global mouse
        -- handler, so the whole bg rectangle is clickable (not just
        -- the text). This gives a uniform-column-width sidebar without
        -- relying on monospaced-style space padding.
        local bg = images.new({
            color = { alpha = UI_SUBTABBG.alpha, red = UI_SUBTABBG.red,
                      green = UI_SUBTABBG.green, blue = UI_SUBTABBG.blue },
            pos   = { x = 0, y = 0 },
            size  = { width = 1, height = 1 },
            draggable = false,
            visible = false,
        })
        local label = texts.new('', {
            pos = {x = 0, y = 0},
            text = { font = 'Arial', size = SUBTAB_FONT_SIZE(),
                     red = 255, green = 255, blue = 255,
                     stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0} },
            bg = { alpha = 0 },
            padding = 0,
            flags = { draggable = false },
        })
        label:text(defaulttab_logs[tab].name)
        tabs[activetab].subtabs[i] = {
            active_tab = activetab,
            tab        = tab,
            bg         = bg,
            label      = label,
            rect       = {x = 0, y = 0, w = 0, h = 0},
            on_click   = function()
                tabs[activetab].items = L{}
                append_header(activetab, tab_logs[tab].name..' (%d/%d)',
                              tab_logs[tab].completed, tab_logs[tab].total)
                if addonhelptext[tab] then
                    for j, _ in pairs(addonhelptext[tab]) do
                        append_addonhelp(activetab, addonhelptext[tab][j][1],
                                         playertracker.talk_to_npc[addonhelptext[tab][j][2]])
                    end
                end
                append_items(tabs[activetab].items, tab_logs[tab].items)
                active_subtab = i
                selected      = 1
                scroll        = 0
                subtabs_drawn = false
                draw()
            end,
        }
    end
end

-- =============================================================================
-- Layout: horizontal main tab strip (wraps to multiple rows if needed)
-- =============================================================================
draw_tabs = function()
    if not trackermenusettings.visibility then return end
    local px = trackermenusettings.pos.x
    local py = trackermenusettings.pos.y
    local tx_start = px + BORDER + PADDING()
    local tx_max   = px + PANEL_W - BORDER - PADDING()
    local ty_start = py + BORDER + HEADER_H + PADDING() / 2

    local cur_x = tx_start
    local cur_y = ty_start
    local row_h = 0

    for i, tab in ipairs(tabs) do
        tabs[i].button:visible(true)
        tabs[i].button:size(FONT_SIZE())
        tabs[i].button:pad(PADDING())
        tabs[i].button:text(tab.name)
        local w, h = tabs[i].button:extents()
        w = w or MAINTAB_HEIGHT()
        h = h or MAINTAB_HEIGHT()
        -- Wrap to next row if we'd overflow the right edge
        if cur_x + w > tx_max and cur_x > tx_start then
            cur_x = tx_start
            cur_y = cur_y + h + MAINTAB_GAP
        end
        tabs[i].button:pos(cur_x, cur_y)
        if active_tab == i then
            tabs[i].button:bg_color(UI_TABBG_SELECTED.red, UI_TABBG_SELECTED.green, UI_TABBG_SELECTED.blue)
            tabs[i].button:bg_alpha(UI_TABBG_SELECTED.alpha)
        else
            tabs[i].button:bg_color(UI_TABBG.red, UI_TABBG.green, UI_TABBG.blue)
            tabs[i].button:bg_alpha(UI_TABBG.alpha)
        end
        row_h = math.max(row_h, h)
        cur_x = cur_x + w + MAINTAB_GAP
    end
    -- Total strip height = (cur_y - ty_start) + row_h
    maintab_strip_h = (cur_y - ty_start) + row_h + PADDING() / 2
end

-- =============================================================================
-- Layout: left sidebar (subtabs of the active tab, scrollable)
-- =============================================================================
draw_subtabs = function()
    if not trackermenusettings.visibility then return end
    if not subtabs_initiated then return end

    -- Defensive frame-by-frame cleanup: hide every NON-active main tab's
    -- subtab bg + label, and zero their rects. This is a safety net so
    -- even if some other code path mishandles tab-switching, ghost
    -- subtabs can't leak through into the visible UI (which is exactly
    -- what was causing the runtime errors + visible overlap before).
    for i, t in ipairs(tabs) do
        if t.subtabs and i ~= active_tab then
            for _, s in pairs(t.subtabs) do
                if s.bg then s.bg:hide() end
                if s.label then s.label:hide() end
                s.rect = {x = 0, y = 0, w = 0, h = 0}
            end
        end
    end

    local px = trackermenusettings.pos.x
    local py = trackermenusettings.pos.y
    local sx = px + BORDER + PADDING() / 2
    local sy = py + BORDER + HEADER_H + maintab_strip_h + PADDING() / 2

    if not tabs[active_tab] or not tabs[active_tab].subtabs then
        ui.sidebar_up:hide()
        ui.sidebar_dn:hide()
        return
    end

    -- Build a positional list so we can scroll by index
    local sub_list = {}
    for i, _ in pairs(tabs[active_tab].subtabs) do sub_list[#sub_list+1] = i end
    table.sort(sub_list)

    local total = #sub_list

    -- Pre-pass: find the longest subtab display string across the WHOLE
    -- active-tab subtab list (not just the visible window). Padding all
    -- buttons to that length keeps the sidebar a uniform width even as
    -- we scroll through entries with varying name lengths.
    local max_len = 0
    for _, i in ipairs(sub_list) do
        local tabname = tabs[active_tab].subtabs[i].tab
        local display = defaulttab_logs[tabname].name
                     .. ' (%d/%d)':format(tab_logs[tabname].completed, tab_logs[tabname].total)
        if #display > max_len then max_len = #display end
    end
    if sidebar_scroll < 0 then sidebar_scroll = 0 end
    if sidebar_scroll > math.max(0, total - SIDEBAR_VISIBLE_ROWS) then
        sidebar_scroll = math.max(0, total - SIDEBAR_VISIBLE_ROWS)
    end

    -- Hide every subtab first; only the visible window gets shown.
    -- Also zero each rect so the mouse handler doesn't match against
    -- stale geometry for hidden subtabs.
    for _, s in pairs(tabs[active_tab].subtabs) do
        if s.bg then s.bg:hide() end
        if s.label then s.label:hide() end
        s.rect = {x = 0, y = 0, w = 0, h = 0}
    end

    -- Fixed dimensions for each row. Every subtab gets the SAME width
    -- (computed from SIDEBAR_W minus margins) so the column reads as
    -- evenly stacked rectangles regardless of label length.
    local row_w = SIDEBAR_W - PADDING()
    local row_h = SUBTAB_HEIGHT() + (SUBTAB_PADDING() * 2)
    local row_gap = 2

    local need_scroll = total > SIDEBAR_VISIBLE_ROWS
    local cur_y = sy
    if need_scroll and sidebar_scroll > 0 then
        ui.sidebar_up:pos(sx, cur_y)
        ui.sidebar_up:visible(true)
        ui.sidebar_up:size(SUBTAB_FONT_SIZE())
        ui.sidebar_up:pad(SUBTAB_PADDING())
        local _, h = ui.sidebar_up:extents()
        cur_y = cur_y + (h or SCROLL_BTN_H) + row_gap
    else
        ui.sidebar_up:hide()
    end

    for vi = 1, SIDEBAR_VISIBLE_ROWS do
        local idx = sidebar_scroll + vi
        local i = sub_list[idx]
        if not i then break end
        local sub = tabs[active_tab].subtabs[i]
        local tabname = sub.tab

        -- Pick bg color by state
        local c
        if active_subtab == i then
            c = UI_SUBTABBG_SELECTED
        elseif (tab_logs[tabname].completed >= tab_logs[tabname].total) and (tab_logs[tabname].total > 0) then
            c = UI_SUBTABBG_COMPLETED
        else
            c = UI_SUBTABBG
        end

        -- Position + size the fixed-width background rectangle
        sub.bg:pos(sx, cur_y)
        sub.bg:size(row_w, row_h)
        sub.bg:color(c.red, c.green, c.blue)
        sub.bg:alpha(c.alpha)
        sub.bg:show()

        -- Label sits on top of the bg, left-padded inside it
        local display = defaulttab_logs[tabname].name
                     .. ' (%d/%d)':format(tab_logs[tabname].completed, tab_logs[tabname].total)
        sub.label:text(display)
        sub.label:size(SUBTAB_FONT_SIZE())
        sub.label:pos(sx + SUBTAB_PADDING(),
                      cur_y + math.floor((row_h - SUBTAB_FONT_SIZE()) / 2))
        sub.label:show()

        -- Hit-test rect for the global mouse handler. Click anywhere
        -- on the row (not just on the text) fires the on_click handler.
        sub.rect = {x = sx, y = cur_y, w = row_w, h = row_h}

        cur_y = cur_y + row_h + row_gap
    end

    if need_scroll and sidebar_scroll + SIDEBAR_VISIBLE_ROWS < total then
        ui.sidebar_dn:pos(sx, cur_y)
        ui.sidebar_dn:visible(true)
        ui.sidebar_dn:size(SUBTAB_FONT_SIZE())
        ui.sidebar_dn:pad(SUBTAB_PADDING())
        local _, h = ui.sidebar_dn:extents()
        cur_y = cur_y + (h or SCROLL_BTN_H)
    else
        ui.sidebar_dn:hide()
    end

    -- Record where the sidebar actually ended so draw() can grow the
    -- panel to enclose it. Without this the body_h estimate was too
    -- small and subtabs spilled past the bottom of the panel.
    sidebar_end_y = cur_y
end

hide_subtabs = function()
    for _, tab in ipairs(tabs) do
        if tab.subtabs then
            for _, s in pairs(tab.subtabs) do
                if s.bg then s.bg:hide() end
                if s.label then s.label:hide() end
                s.rect = {x = 0, y = 0, w = 0, h = 0}
            end
        end
    end
end

-- =============================================================================
-- Data API — preserved verbatim for menus.lua and the main lua
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
-- Main draw — panel pieces + items pane
-- =============================================================================
draw = function()
    if not trackermenusettings.visibility then return end

    local px = trackermenusettings.pos.x
    local py = trackermenusettings.pos.y

    -- Panel height = max(items pane needs, sidebar actual end) plus chrome.
    --
    -- The sidebar's actual rendered height comes from draw_subtabs() which
    -- records sidebar_end_y. The items pane needs ~VISIBLE_ROWS lines.
    -- Pick the larger so the panel encloses both contents without spill.
    local items_body_h = (VISIBLE_ROWS + 2) * LINE_HEIGHT() + PADDING()
    local sidebar_body_h = math.max(0, sidebar_end_y - (py + BORDER + HEADER_H + maintab_strip_h))
    local body_h = math.max(items_body_h, sidebar_body_h + PADDING())
    local total_h = HEADER_H + maintab_strip_h + body_h + BORDER * 2 + PADDING()
    panel_h = total_h

    -- Panel + borders
    ui.main_bg:pos(px, py); ui.main_bg:size(PANEL_W, total_h)
    ui.border_top:pos(px, py); ui.border_top:size(PANEL_W, BORDER)
    ui.border_bot:pos(px, py + total_h - BORDER); ui.border_bot:size(PANEL_W, BORDER)
    ui.border_left:pos(px, py); ui.border_left:size(BORDER, total_h)
    ui.border_rite:pos(px + PANEL_W - BORDER, py); ui.border_rite:size(BORDER, total_h)

    -- Header strip
    ui.header_bg:pos(px + BORDER, py + BORDER)
    ui.header_bg:size(PANEL_W - BORDER * 2, HEADER_H)
    ui.header_line:pos(px + BORDER, py + BORDER + HEADER_H)
    ui.header_line:size(PANEL_W - BORDER * 2, 1)
    ui.title_text:pos(px + BORDER + PADDING(), py + BORDER + math.floor((HEADER_H - TITLE_FONT_SIZE()) / 2))
    ui.close_text:pos(px + PANEL_W - BORDER - PADDING() - 8, py + BORDER + math.floor((HEADER_H - TITLE_FONT_SIZE()) / 2))

    -- Horizontal line below the main tab strip
    local tabstrip_bottom_y = py + BORDER + HEADER_H + maintab_strip_h
    ui.tabstrip_line:pos(px + BORDER, tabstrip_bottom_y)
    ui.tabstrip_line:size(PANEL_W - BORDER * 2, 1)

    -- Vertical divider between sidebar and items pane
    local divider_x = px + BORDER + SIDEBAR_W
    ui.divider:pos(divider_x, tabstrip_bottom_y + 1)
    ui.divider:size(1, total_h - (tabstrip_bottom_y + 1 - py) - BORDER)

    -- Items pane
    local items_x = divider_x + PADDING()
    local items_y = tabstrip_bottom_y + PADDING()
    ui.menu:pos(items_x, items_y)

    -- Items text content
    local text = ''
    local heading = (tabs[active_tab] and tabs[active_tab].name) or ''
    local active_subtab_name = nil
    if tabs[active_tab] and tabs[active_tab].subtabs
       and active_subtab and active_subtab > 0
       and tabs[active_tab].subtabs[active_subtab] then
        local sn = tabs[active_tab].subtabs[active_subtab].tab
        active_subtab_name = sn
        if defaulttab_logs[sn] then
            heading = heading .. ' / ' .. defaulttab_logs[sn].name
        end
    end

    -- ----- Completion summary -----
    -- This is the line under the heading that tells the user:
    --   * How many entries are in this category total
    --   * How many they've completed
    --   * How many are currently HIDDEN by the showcompleted=false filter
    -- The user reported "everything is mismatched" because completed
    -- items disappear from the items pane while the sidebar still
    -- counts them. Spelling out the hidden count here, plus the
    -- toggle hint, fixes that "wait why is this list so short" feeling.
    local completed_count, total_count = 0, 0
    if active_subtab_name and tab_logs[active_subtab_name] then
        completed_count = tab_logs[active_subtab_name].completed or 0
        total_count     = tab_logs[active_subtab_name].total or 0
    end

    text = text .. '\\cs(150,210,255)── '..heading..' ──\\cr\n'

    if active_subtab_name and total_count > 0 then
        local hidden_part = ''
        if not trackermenusettings.showcompleted and completed_count > 0 then
            hidden_part = '  \\cs(255,200,120)('..completed_count
                          ..' completed hidden -- //xic showcompleted to show)\\cr'
        end
        text = text .. '\\cs(170,190,210)'..completed_count..' / '..total_count
                    ..' complete\\cr'..hidden_part..'\n'
    end

    if search_query ~= '' then
        text = text .. '\\cs(255,220,140)Search: "'..search_query..'"'
            ..(search_scope == 'all' and ' (all tabs)' or '')
            ..'  \\cs(170,170,170)[//xic search clear]\\cr\n'
    end

    -- ---- Item list assembly ----
    -- Strips color escapes from item text so search matches against the
    -- raw quest name, not the markup wrapping it.
    local function _strip_cs(s)
        if not s then return '' end
        return (s:gsub('\\cs%([%d,]+%)', ''):gsub('\\cr', ''))
    end
    local _query_lc = search_query:lower()
    local function _matches_search(item_text)
        if _query_lc == '' then return true end
        return _strip_cs(item_text):lower():find(_query_lc, 1, true) ~= nil
    end

    local items
    if search_query ~= '' and search_scope == 'all' then
        -- Global search: walk every subtab in every tab and collect
        -- matches. Each match gets prefixed with [Subtab Name] so the
        -- user can see which list it came from.
        items = L{}
        local seen = {}
        for _, tab in ipairs(tabs) do
            if tab.tabs then
                for _, sn in ipairs(tab.tabs) do
                    local log = tab_logs[sn]
                    if log and log.items then
                        for _, item in ipairs(log.items) do
                            if item.text and _matches_search(item.text) then
                                local key = sn..'|'..item.text
                                if not seen[key] then
                                    seen[key] = true
                                    local label = defaulttab_logs[sn]
                                                  and defaulttab_logs[sn].name
                                                  or sn
                                    items:append(util.list_item(
                                        item.category,
                                        '\\cs(150,210,255)['..label..']\\cr '
                                            .. item.text,
                                        item.completed,
                                        item.obtainmethod))
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        items = tabs[active_tab].items
        if search_query ~= '' then
            items = items:filter(function(item)
                return item.text and _matches_search(item.text)
            end)
        end
    end

    if (trackermenusettings.showcompleted == false) then
        items = items:filter(function(item) return item.completed == false end)
    end
    local count = items:length()
    if count == 0 then
        if search_query ~= '' then
            items = {util.list_item(nil, '\\cs(170,170,170)No matches for "'..search_query..'". \\cr\n \\cs(170,170,170)Try //xic findall '..search_query..' for a global search, or //xic search clear to reset.\\cr')}
        else
            items = {util.list_item(nil, '\\cs(128,128,128)Change zones to update Quests / Campaigns / Warps / Monstrosity \\cr \n \\cs(128,128,128)Check the README or "//ffxic help" to register NPC-related data \\cr')}
        end
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
    -- Expose the post-filter items list so the quest-info side panel
    -- (and any other prerender consumer) sees the same list the user
    -- is actually looking at. Without this, search filtering and the
    -- showcompleted filter would silently desync the wiki panel from
    -- the highlighted row.
    displayed_items = items
end

-- =============================================================================
-- Wire-up
-- =============================================================================
initiate_tabs()

-- Visibility state machine: explicit show/hide on transition.
local _was_visible = false

-- Login-screen guard. windower.ffxi.get_info().logged_in is true only when the
-- character is actually in the game world; while sitting at character-select
-- or the launcher we suppress the panel entirely so it doesn't render on top
-- of the login UI. The user's saved visibility preference
-- (trackermenusettings.visibility) is preserved -- this just temporarily
-- overrides it whenever there's no logged-in character.
local function _player_in_game()
    local info = windower.ffxi.get_info()
    return info and info.logged_in == true
end

windower.register_event('prerender', function()
    local is_visible = (trackermenusettings.visibility == true)
                      and _player_in_game()
    if is_visible and not _was_visible then
        ui_show_all()
        _was_visible = true
    elseif (not is_visible) and _was_visible then
        ui_hide_all()
        _was_visible = false
        if quest_panel then quest_panel.hide() end
    end
    if not is_visible then
        if quest_panel then quest_panel.hide() end
        return
    end
    draw_tabs()
    draw_subtabs()
    draw()

    -- BG-Wiki quest info side-panel. Renders only when:
    --   * the user-level toggle is on
    --   * the active subtab is a starter-city mission tab
    --   * the currently-selected item maps to a known mission page
    if quest_panel then
        local subtab_name, sel_text = nil, nil
        if tabs[active_tab] and tabs[active_tab].subtabs
           and active_subtab and active_subtab > 0
           and tabs[active_tab].subtabs[active_subtab] then
            subtab_name = tabs[active_tab].subtabs[active_subtab].tab
        end
        -- Use the post-filter list draw() exposes so search / show-
        -- completed filtering keeps the wiki panel aligned with the
        -- highlighted row.
        local items = displayed_items or tabs[active_tab].items
        if items and items[selected] then
            sel_text = items[selected].text
        end
        -- If we're in global findall mode, the matched item text is
        -- prefixed with "[Subtab Name] " -- strip that so the wiki
        -- lookup matches the real quest name.
        if sel_text and search_query ~= '' and search_scope == 'all' then
            sel_text = sel_text:gsub('^%[[^%]]+%]%s*', '')
        end
        -- If the currently-selected row is a header / non-quest row
        -- (very common right after switching subtabs, since selected
        -- defaults to 1 which is the "==== Bastok Missions ====" header),
        -- fall back to the first item that does map to a known mission so
        -- the wiki panel still has something useful to show.
        if quest_panel and quest_panel.is_starter(subtab_name)
           and items and not (quest_panel.lookup(sel_text)) then
            for idx = 1, #items do
                local t = items[idx] and items[idx].text
                if search_query ~= '' and search_scope == 'all' and t then
                    t = t:gsub('^%[[^%]]+%]%s*', '')
                end
                if quest_panel.lookup(t) then
                    sel_text = t
                    break
                end
            end
        end
        quest_panel.tick({
            visible       = true,
            show_wiki     = (trackermenusettings.showwikiinfo == true),
            subtab_name   = subtab_name,
            selected_text = sel_text,
            anchor_x      = trackermenusettings.pos.x,
            anchor_y      = trackermenusettings.pos.y,
            panel_w       = PANEL_W,
            panel_h       = panel_h,
        })
    end
end)

-- (Drag is handled inside the global mouse handler below — it picks up
-- LMB-down on the title bar, tracks moves, and ends on LMB-up. The
-- texts-library drag event isn't used here because consuming mouse
-- events globally blocks the library's internal drag dispatch.)

-- Mouse handler — handles wheel scroll + blocks right-click camera grab
-- when the cursor is over the panel. Left-click events pass through
-- (return false) so the individual texts.new buttons' click handlers
-- still fire.
--
-- Windower mouse types:
--   0  move    1 LMB down   2 LMB up   3 RMB down   4 RMB up
--   5  MMB d.  6 MMB up    10 wheel
windower.register_event('mouse', function(type, x, y, delta, blocked)
    if not trackermenusettings.visibility then return false end
    if blocked then return false end
    local px = trackermenusettings.pos.x
    local py = trackermenusettings.pos.y

    -- Active-drag updates run BEFORE the over-panel check because a
    -- fast drag can put the cursor outside the panel for a frame and
    -- we still want to follow it.
    if drag.active then
        if type == 0 then          -- mouse move
            trackermenusettings.pos.x = x - drag.off_x
            trackermenusettings.pos.y = y - drag.off_y
            trackermenusettings:save()
            return true
        elseif type == 2 then      -- LMB up — end drag
            drag.active = false
            return true
        end
    end

    local over = inside(x, y, px, py, PANEL_W, panel_h)
    if not over then return false end

    -- Title-bar hit area = full header strip minus the close-X right edge
    local title_y_top = py + BORDER
    local title_y_bot = py + BORDER + HEADER_H
    local close_x_left = px + PANEL_W - BORDER - PADDING() - 18
    if type == 1
       and y >= title_y_top and y <= title_y_bot
       and x < close_x_left then
        drag.active = true
        drag.off_x  = x - px
        drag.off_y  = y - py
        return true
    end

    -- Mouse wheel: scroll the pane the cursor is over.
    --   Sidebar zone   → moves sidebar_scroll (the subtab list)
    --   Items zone     → moves selected/scroll (the items list)
    if type == 10 and delta and delta ~= 0 then
        local body_top = py + BORDER + HEADER_H + maintab_strip_h
        local body_bot = py + panel_h - BORDER
        local sidebar_left = px + BORDER
        local sidebar_right = px + BORDER + SIDEBAR_W
        local items_left = sidebar_right + 1
        local items_right = px + PANEL_W - BORDER

        local in_sidebar = (x >= sidebar_left and x <= sidebar_right
                            and y >= body_top and y <= body_bot)
        local in_items   = (x >= items_left and x <= items_right
                            and y >= body_top and y <= body_bot)

        if in_sidebar and tabs[active_tab] and tabs[active_tab].subtabs then
            -- Scroll the subtab list. Count the entries first so we
            -- don't scroll past the end.
            local total = 0
            for _ in pairs(tabs[active_tab].subtabs) do total = total + 1 end
            local max_scroll = math.max(0, total - SIDEBAR_VISIBLE_ROWS)
            if delta > 0 then
                sidebar_scroll = math.max(0, sidebar_scroll - 1)
            else
                sidebar_scroll = math.min(max_scroll, sidebar_scroll + 1)
            end
            return true
        elseif in_items then
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
        else
            -- Hover is over the header / main tab strip — fall back to
            -- items scroll so the wheel still does something useful.
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

    -- Left-button DOWN: hit-test against subtab rects so a click
    -- anywhere on a subtab's row (not just on the text) fires its
    -- on_click. We always return true at the end of the handler so
    -- the click doesn't fall through to the game world.
    if type == 1 then
        if tabs[active_tab] and tabs[active_tab].subtabs then
            for i, s in pairs(tabs[active_tab].subtabs) do
                local r = s.rect
                if r and r.w > 0 and r.h > 0
                   and x >= r.x and x <= r.x + r.w
                   and y >= r.y and y <= r.y + r.h then
                    if s.on_click then s.on_click() end
                    break
                end
            end
        end
    end

    -- Consume EVERY mouse event the cursor is over the panel for.
    -- Returning true here only controls game-engine propagation, not
    -- the texts.new register_event('left_click') / drag handlers,
    -- which fire from their own internal mouse listener — so main
    -- tab buttons, close X, scroll arrows, and title-bar drag all
    -- still work correctly while:
    --   - right-clicks no longer grab the FFXI camera
    --   - left-clicks on dead space don't trigger the "invalid
    --     action" beep
    --   - middle-clicks don't trigger camera-recenter
    --   - wheel events (handled above) don't scroll the game world
    return true
end)

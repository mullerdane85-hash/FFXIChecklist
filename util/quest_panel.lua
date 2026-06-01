-- =============================================================================
-- FFXIChecklist Quest Info Panel
--
-- A floating BG-Wiki info panel that auto-renders next to the main panel
-- when the user is browsing a starter-city mission subtab
-- (sandoriamissions / bastokmissions / windurstmissions) and the
-- currently-selected list item maps to a known mission page.
--
-- Field order (matches user request, top-down):
--      Starting NPC
--      Title
--      Repeatable
--      Description
--      Walkthrough (nested bullets)
--
-- Lookup: build a reverse map at load time keyed by mission TITLE
-- (e.g. "The Zeruhn Report" -> Bastok 1-1 record). The list items in
-- FFXIChecklist already show the title verbatim, so that gives us a
-- clean key without depending on slot index alignment.
-- =============================================================================

local quest_panel = {}

texts  = texts  or require('texts')
images = images or require('images')

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------
local quest_info
local title_index   = {}   -- clean title/key -> { subtab, key, data }
local subtab_known  = {}   -- subtab name -> true if we have data for it

local function _norm(s)
    if not s then return '' end
    s = s:gsub('\\cs%([%d,]+%)', ''):gsub('\\cr', '')
    -- Strip leading list-marker noise: dashes, bullets, '>' marker,
    -- AND the leading underscores that FFXIChecklist's story.lua uses to
    -- indent mission entries (e.g. '__Resonance' -> 'Resonance').
    -- Also drop leading apostrophes used for chapter headers
    -- (e.g. "'Chapter One: Creation and Rebirth'").
    s = s:gsub("^['\"_]+", '')
    s = s:gsub('^[%-%*%>%s]+', ''):gsub('%s+$','')
    s = s:gsub("['\"]+$", '')
    -- Lowercase + collapse spaces so curly-quote / apostrophe noise
    -- between FFXIChecklist's stored mission names and BG-Wiki's titles
    -- can't keep matches from landing.
    s = s:lower():gsub("['`']", "'"):gsub('%s+', ' ')
    return s
end

local function _load()
    local ok, data = pcall(dofile, windower.addon_path .. 'libs/quest_info.lua')
    if not ok or type(data) ~= 'table' then
        quest_info = {}
        return
    end
    quest_info = data
    -- Build reverse lookup. The data file is keyed by FFXIChecklist subtab
    -- name (e.g. 'bastokmissions', 'soamissions') and inside each, by the
    -- BG-Wiki page name (e.g. 'Bastok Mission 1-1', 'A Mythril Bullet for
    -- the General'). We index by:
    --   * the BG-Wiki page-name key   ("Bastok Mission 1-1")
    --   * the mission TITLE           ("The Zeruhn Report")
    --   * normalized variants of both ("the zeruhn report")
    -- so a click from FFXIChecklist's list (which shows the title) lands.
    for subtab, missions in pairs(quest_info) do
        subtab_known[subtab] = true
        for key, m in pairs(missions) do
            local rec = { subtab = subtab, key = key, data = m }
            title_index[key]         = rec
            title_index[_norm(key)]  = rec
            if m.title and m.title ~= '' then
                title_index[m.title]         = rec
                title_index[_norm(m.title)]  = rec
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Theme (matches FFXIChecklist's existing palette)
-- ---------------------------------------------------------------------------
local PANEL_W = 460
local FONT    = 'Arial'
local FONT_SZ = 11
local TITLE_SZ= 13
local BORDER  = 3
local PADDING = 8
local HEADER_H= 28

local C_BORDER     = {alpha = 230, red = 70,  green = 130, blue = 200}
local C_BG         = {alpha = 250, red = 12,  green = 12,  blue = 32}
local C_HEADER_BG  = {alpha = 250, red = 22,  green = 36,  blue = 70}
local C_HEADER_LINE= {alpha = 220, red = 60,  green = 110, blue = 160}

-- Wiki info text colors (match FFXIMissingSpells styling)
local CS_LABEL     = '\\cs(150,220,255)'   -- cyan field labels
local CS_VALUE     = '\\cs(230,230,230)'   -- white-ish values
local CS_HEADER    = '\\cs(255,220,140)'   -- yellow section header
local CS_BULLET    = '\\cs(180,200,230)'   -- soft blue bullets
local CS_MUTED     = '\\cs(170,170,170)'   -- muted gray
local CS_END       = '\\cr'

local TOOLTIP_WIDTH_CHARS = 60

-- ---------------------------------------------------------------------------
-- UI objects
-- ---------------------------------------------------------------------------
local ui = {}
local _visible = false
local _last_title = nil  -- so we only rebuild text when the selection changes

local function _mk_bg(c)
    return images.new({
        color = { alpha = c.alpha, red = c.red, green = c.green, blue = c.blue },
        pos = {x = 0, y = 0}, size = {width = 1, height = 1},
        draggable = false, visible = false,
    })
end

local function _init_ui()
    if ui.bg then return end
    ui.bg          = _mk_bg(C_BG)
    ui.border_top  = _mk_bg(C_BORDER)
    ui.border_bot  = _mk_bg(C_BORDER)
    ui.border_left = _mk_bg(C_BORDER)
    ui.border_rite = _mk_bg(C_BORDER)
    ui.header_bg   = _mk_bg(C_HEADER_BG)
    ui.header_line = _mk_bg(C_HEADER_LINE)

    ui.title = texts.new('', {
        pos = {x = 0, y = 0},
        text = {font = FONT, size = TITLE_SZ, red = 130, green = 210, blue = 240,
                stroke = {width = 1, alpha = 200, red = 0, green = 0, blue = 0}},
        bg = {alpha = 0}, padding = 0,
        flags = {draggable = false, bold = true},
    })
    ui.body = texts.new('', {
        pos = {x = 0, y = 0},
        text = {font = FONT, size = FONT_SZ, red = 255, green = 255, blue = 255,
                stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
        bg = {alpha = 0}, padding = PADDING,
        flags = {draggable = false},
    })
end

local function _show()
    if not ui.bg then return end
    ui.bg:show(); ui.border_top:show(); ui.border_bot:show()
    ui.border_left:show(); ui.border_rite:show()
    ui.header_bg:show(); ui.header_line:show()
    ui.title:show(); ui.body:show()
    _visible = true
end

local function _hide()
    if not ui.bg then return end
    ui.bg:hide(); ui.border_top:hide(); ui.border_bot:hide()
    ui.border_left:hide(); ui.border_rite:hide()
    ui.header_bg:hide(); ui.header_line:hide()
    ui.title:hide(); ui.body:hide()
    _visible = false
end

-- ---------------------------------------------------------------------------
-- Text wrapping helper. Word-wraps a long paragraph into multiple lines
-- of <= width chars, prefixed with `prefix` on the first line and
-- `cont` on continuation lines.
-- ---------------------------------------------------------------------------
local function _wrap_line(text, width, prefix, cont)
    prefix = prefix or ''
    cont   = cont or string.rep(' ', #prefix)
    local out = {}
    if not text or text == '' then return out end
    local rest = text
    local first = true
    while #rest > width do
        local cut = width
        local spc = rest:sub(1, width):find(' [^%s]*$')
        if spc then cut = spc - 1 end
        if cut <= 0 then cut = width end
        out[#out+1] = (first and prefix or cont) .. rest:sub(1, cut)
        rest = rest:sub(cut + 1):gsub('^%s+', '')
        first = false
    end
    if #rest > 0 then
        out[#out+1] = (first and prefix or cont) .. rest
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Render a quest_info record into text. Returns the formatted string.
-- ---------------------------------------------------------------------------
local function _emit_field(lines, label, value)
    if not value or value == '' then return end
    local prefix = CS_LABEL .. label .. ': ' .. CS_END .. CS_VALUE
    local wrapped = _wrap_line(value, TOOLTIP_WIDTH_CHARS,
                               prefix, CS_VALUE .. string.rep(' ', #label + 2))
    for _, l in ipairs(wrapped) do
        lines[#lines+1] = l .. CS_END
    end
end

local function _emit_walk(lines, items, depth)
    depth = depth or 0
    local indent = string.rep('   ', depth)
    local bullet = (depth == 0) and '* ' or '- '
    for _, entry in ipairs(items) do
        local text = entry[1] or ''
        local prefix = CS_BULLET .. indent .. bullet .. CS_END .. CS_VALUE
        local cont   = CS_VALUE .. indent .. string.rep(' ', #bullet)
        local wrapped = _wrap_line(text, TOOLTIP_WIDTH_CHARS - (#indent + #bullet),
                                   prefix, cont)
        for _, l in ipairs(wrapped) do
            lines[#lines+1] = l .. CS_END
        end
        if entry.sub then
            _emit_walk(lines, entry.sub, depth + 1)
        end
    end
end

local function _format(rec)
    local d = rec.data
    local lines = {}

    -- Header: "Bastok Mission 1-1 - The Zeruhn Report"
    local hdr = (d.title and d.title ~= '' and d.title) or rec.key
    lines[#lines+1] = CS_HEADER .. rec.key .. CS_END
    if d.title and d.title ~= rec.key then
        lines[#lines+1] = CS_HEADER .. '   "' .. d.title .. '"' .. CS_END
    end
    lines[#lines+1] = ''

    -- Top-of-card fields (user-specified order: Starting NPC first).
    _emit_field(lines, 'Starting NPC', d.starting_npc)
    if d.subtitle and d.subtitle ~= '' and d.subtitle ~= 'None' then
        _emit_field(lines, 'Title', d.subtitle)
    else
        _emit_field(lines, 'Title', d.subtitle == '' and nil or d.subtitle)
    end
    _emit_field(lines, 'Repeatable', d.repeatable)
    -- Assault-specific fields (present only on Category:Assault pages,
    -- absent on regular mission pages so they just skip).
    _emit_field(lines, 'Assault Rank',   d.assault_rank)
    _emit_field(lines, 'Time Limit',     d.time_limit)
    _emit_field(lines, 'Recommended Lv', d.recommended_lv)
    _emit_field(lines, 'Mission Orders', d.mission_orders)
    lines[#lines+1] = ''
    _emit_field(lines, 'Description', d.description)
    lines[#lines+1] = ''

    -- Walkthrough
    if d.walkthrough and #d.walkthrough > 0 then
        lines[#lines+1] = CS_HEADER .. 'Walkthrough' .. CS_END
        _emit_walk(lines, d.walkthrough, 0)
    end

    -- Footer: series + prev/next (faded)
    if d.series and d.series ~= '' then
        lines[#lines+1] = ''
        lines[#lines+1] = CS_MUTED .. 'Series: ' .. d.series .. CS_END
    end

    return table.concat(lines, '\n')
end

-- ---------------------------------------------------------------------------
-- Public: lookup record by mission title (or page key).
-- ---------------------------------------------------------------------------
function quest_panel.lookup(title)
    if not title or title == '' then return nil end
    -- Strip color escapes that may surround the item text.
    local clean = title:gsub('\\cs%([%d,]+%)', ''):gsub('\\cr', ''):gsub('^%s+',''):gsub('%s+$','')
    -- Strip a leading "- " or "* " or "> " that the items pane may have added.
    clean = clean:gsub('^[%-%*%>%s]+', '')
    -- Try exact match first, then normalized fallback.
    return title_index[clean] or title_index[_norm(clean)]
end

-- ---------------------------------------------------------------------------
-- Public: render the panel for the given record next to the main panel.
-- Pass nil to hide.
-- ---------------------------------------------------------------------------
function quest_panel.render(rec, anchor_x, anchor_y, main_panel_w, main_panel_h)
    _init_ui()
    if not rec then
        _hide()
        _last_title = nil
        return
    end

    -- Position next to the main panel, clamped to the screen.
    --
    -- Preferred: right of the main panel. If the panel would overflow
    -- the right edge of the screen, fall back to the LEFT side. If even
    -- that won't fit (tiny resolution), clamp to whichever edge has more
    -- room. Then clamp Y so the panel doesn't slide off the bottom.
    local res = windower.get_windower_settings()
    local screen_w = (res and res.ui_x_res) or 1920
    local screen_h = (res and res.ui_y_res) or 1080

    -- Estimate panel height from the body text line count, so a long
    -- walkthrough doesn't spill past the bottom border. We rebuild the
    -- text up-front (cheap; only done when selection changes anyway)
    -- and count newlines to size the chrome.
    local body_text = _format(rec)
    local n_lines = 1
    for _ in body_text:gmatch('\n') do n_lines = n_lines + 1 end
    local line_h = FONT_SZ + 6                            -- approx line height
    local content_h = HEADER_H + PADDING * 2 + (n_lines * line_h)
    local height = math.max(main_panel_h, content_h, 280)
    -- Cap to screen height so we never exceed the display.
    if height > screen_h - 20 then height = screen_h - 20 end
    local gap = 6

    local right_px = anchor_x + main_panel_w + gap
    local left_px  = anchor_x - PANEL_W - gap
    local px
    if right_px + PANEL_W <= screen_w then
        px = right_px                                       -- prefer right side
    elseif left_px >= 0 then
        px = left_px                                        -- fall back to left
    else
        -- Tiny screen: pin to whichever side has more room.
        local space_right = screen_w - (anchor_x + main_panel_w + gap)
        local space_left  = anchor_x - gap
        if space_right >= space_left then
            px = math.max(0, screen_w - PANEL_W)
        else
            px = 0
        end
    end

    -- Clamp Y so the panel stays on-screen vertically.
    local py = anchor_y
    if py + height > screen_h then py = math.max(0, screen_h - height) end
    if py < 0 then py = 0 end

    -- Background
    ui.bg:pos(px, py); ui.bg:size(PANEL_W, height)
    ui.border_top:pos(px, py); ui.border_top:size(PANEL_W, BORDER)
    ui.border_bot:pos(px, py + height - BORDER); ui.border_bot:size(PANEL_W, BORDER)
    ui.border_left:pos(px, py); ui.border_left:size(BORDER, height)
    ui.border_rite:pos(px + PANEL_W - BORDER, py); ui.border_rite:size(BORDER, height)
    ui.header_bg:pos(px + BORDER, py + BORDER)
    ui.header_bg:size(PANEL_W - BORDER * 2, HEADER_H)
    ui.header_line:pos(px + BORDER, py + BORDER + HEADER_H)
    ui.header_line:size(PANEL_W - BORDER * 2, 1)

    ui.title:pos(px + BORDER + PADDING,
                 py + BORDER + math.floor((HEADER_H - TITLE_SZ) / 2))
    ui.title:text('Quest Info - ' .. rec.key)

    ui.body:pos(px + BORDER + 2, py + BORDER + HEADER_H + 4)

    -- Body text was already built up-front (so we could measure its
    -- height). Push it into the texts object only when the selection
    -- actually changes to avoid re-rendering identical text every frame.
    if rec.key ~= _last_title then
        ui.body:text(body_text)
        _last_title = rec.key
    end

    _show()
end

function quest_panel.hide()
    _hide()
    _last_title = nil
end

-- ---------------------------------------------------------------------------
-- Public: integration hook called every prerender by ui.lua.
-- Decides whether to show/hide based on active subtab + selected item.
-- ---------------------------------------------------------------------------
function quest_panel.tick(opts)
    -- opts:
    --   visible        bool   panel visibility (from main visibility check)
    --   subtab_name    string current active subtab name (e.g. 'bastokmissions')
    --   selected_text  string text of the currently-selected items row
    --   anchor_x/y     int    main panel top-left
    --   panel_w/h      int    main panel size
    --   show_wiki      bool   user toggle (sidebar checkbox / setting)
    if not opts or not opts.visible or not opts.show_wiki then
        _hide(); return
    end
    if not opts.subtab_name or not subtab_known[opts.subtab_name] then
        _hide(); return
    end
    local rec = quest_panel.lookup(opts.selected_text)
    if not rec then
        _hide(); return
    end
    quest_panel.render(rec, opts.anchor_x, opts.anchor_y, opts.panel_w, opts.panel_h)
end

-- ---------------------------------------------------------------------------
-- Load on require()
-- ---------------------------------------------------------------------------
_load()

function quest_panel.is_starter(subtab_name)
    -- Retained for back-compat. Returns true if we have wiki data for
    -- this subtab regardless of whether it's a "starter city" mission.
    return subtab_known[subtab_name] == true
end

function quest_panel.has_data(subtab_name)
    return subtab_known[subtab_name] == true
end

function quest_panel.reload()
    title_index  = {}
    subtab_known = {}
    _load()
    _last_title = nil
end

return quest_panel

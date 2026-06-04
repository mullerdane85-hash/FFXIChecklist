-- =============================================================================
-- FFXIChecklist Quest Info Panel
--
-- A floating BG-Wiki info panel that auto-renders next to the main panel
-- whenever the user is browsing one of the 14 mission subtabs FFXIChecklist
-- tracks (sandoriamissions / bastokmissions / windurstmissions /
-- zilartmissions / copmissions / ahturhganmissions / wotgmissions /
-- acpmissions / mkdmissions / asamissions / soamissions / rovmissions /
-- tvrmissions / assaults).
--
-- Field order (matches user request, top-down):
--      Starting NPC
--      Title
--      Repeatable
--      Description
--      Walkthrough (nested bullets)
--
-- Layout: the panel is a FIXED size locked to the height of the main
-- FFXIChecklist window. Content that doesn't fit scrolls via the mouse
-- wheel or the on-panel ▲/▼ arrows. It NEVER grows to fit content -- the
-- panel chrome stays put, the lines slide.
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
    -- Strip leading list-marker noise FFXIChecklist's story.lua uses for
    -- visual grouping: underscores (RoV indent), apostrophes (chapter
    -- header), plus-prefix (quest groups), regular dashes/bullets.
    s = s:gsub("^[%+'\"_]+", '')
    s = s:gsub('^[%-%*%>%s]+', ''):gsub('%s+$','')
    s = s:gsub("['\"]+$", '')
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
local SCROLL_BTN_H = 18

-- Vertical distance Arial advances per rendered line at FONT_SZ. Empirically
-- the texts library renders Arial 11 with stroke at ~18px line pitch (was
-- 16 originally -- the user reported lines bleeding past the bottom of the
-- panel because rows-per-height was overestimated). The measure-and-trim
-- pass in render() catches any remaining slack.
local LINE_H = 18

-- Word-wrap width. Arial 11 in a 460px panel (minus borders + the 4px gutter
-- on the body) gives ~440px of usable width. Conservative average char width
-- of 5.5px yields ~75 chars, but Arial's wide caps + punctuation push that
-- below in practice -- we cap at 52 chars so text always stays inside the
-- right border, matching the user's bug report about glyphs spilling out.
local TOOLTIP_WIDTH_CHARS = 52

local C_BORDER     = {alpha = 230, red = 70,  green = 130, blue = 200}
local C_BG         = {alpha = 250, red = 12,  green = 12,  blue = 32}
local C_HEADER_BG  = {alpha = 250, red = 22,  green = 36,  blue = 70}
local C_HEADER_LINE= {alpha = 220, red = 60,  green = 110, blue = 160}
local C_SCROLL_BG  = {alpha = 230, red = 40,  green = 50,  blue = 90}
local C_SCROLL_OFF = {alpha = 130, red = 25,  green = 30,  blue = 55}

local CS_LABEL     = '\\cs(150,220,255)'
local CS_VALUE     = '\\cs(230,230,230)'
local CS_HEADER    = '\\cs(255,220,140)'
local CS_BULLET    = '\\cs(180,200,230)'
local CS_MUTED     = '\\cs(170,170,170)'
local CS_SECTION   = '\\cs(255,200,100)'   -- ── X ── section dividers from BG-Wiki H3s
local CS_END       = '\\cr'

-- ---------------------------------------------------------------------------
-- UI objects + state
-- ---------------------------------------------------------------------------
local ui = {}
local _visible      = false
local _last_key     = nil    -- the rec.key whose lines are currently cached
local _lines        = {}     -- cached formatted line array for _last_key
local _scroll       = 0      -- top-of-window line index (0 = first line)
local _visible_rows = 1      -- how many lines fit per panel height
local _panel_rect   = {x = 0, y = 0, w = 0, h = 0}   -- screen-space hit rect
local _up_rect      = {x = 0, y = 0, w = 0, h = 0}
local _dn_rect      = {x = 0, y = 0, w = 0, h = 0}

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

    ui.scroll_up = texts.new('', {
        pos = {x = 0, y = 0},
        text = {font = FONT, size = FONT_SZ, red = 255, green = 255, blue = 255,
                stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
        bg = {red = C_SCROLL_BG.red, green = C_SCROLL_BG.green,
              blue = C_SCROLL_BG.blue, alpha = C_SCROLL_BG.alpha},
        padding = 4, flags = {draggable = false, bold = true},
    })
    ui.scroll_up:text('  \\cs(200,220,255)▲  Scroll Up  ▲\\cr  ')

    ui.scroll_dn = texts.new('', {
        pos = {x = 0, y = 0},
        text = {font = FONT, size = FONT_SZ, red = 255, green = 255, blue = 255,
                stroke = {width = 1, alpha = 180, red = 0, green = 0, blue = 0}},
        bg = {red = C_SCROLL_BG.red, green = C_SCROLL_BG.green,
              blue = C_SCROLL_BG.blue, alpha = C_SCROLL_BG.alpha},
        padding = 4, flags = {draggable = false, bold = true},
    })
    ui.scroll_dn:text('  \\cs(200,220,255)▼  Scroll Down  ▼\\cr  ')
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
    if ui.scroll_up then ui.scroll_up:hide() end
    if ui.scroll_dn then ui.scroll_dn:hide() end
    _visible = false
    _panel_rect = {x = 0, y = 0, w = 0, h = 0}
    _up_rect    = {x = 0, y = 0, w = 0, h = 0}
    _dn_rect    = {x = 0, y = 0, w = 0, h = 0}
end

-- ---------------------------------------------------------------------------
-- Text wrapping helper. Word-wraps a long paragraph into multiple lines
-- of <= width chars (excluding color escapes), prefixed with `prefix` on
-- the first line and `cont` on continuation lines.
-- ---------------------------------------------------------------------------
local function _wrap_line(text, width, prefix, cont)
    prefix = prefix or ''
    cont   = cont or ''
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

local function _emit_field(lines, label, value)
    if not value or value == '' then return end
    local lead   = label .. ': '
    local prefix = CS_LABEL .. lead .. CS_END .. CS_VALUE
    local cont   = CS_VALUE .. string.rep(' ', #lead)
    local body_w = TOOLTIP_WIDTH_CHARS - #lead
    if body_w < 16 then body_w = 16 end
    local first_chunk = value:sub(1, body_w)
    local rest        = value:sub(#first_chunk + 1):gsub('^%s+','')
    local wrapped = {}
    -- First line keeps prefix; subsequent lines align under the value.
    wrapped[1] = prefix .. first_chunk
    if #rest > 0 then
        local cont_wrap = _wrap_line(rest, body_w, cont, cont)
        for _, l in ipairs(cont_wrap) do wrapped[#wrapped+1] = l end
    end
    for _, l in ipairs(wrapped) do lines[#lines+1] = l .. CS_END end
end

-- Detect a `── Title ──` divider produced by the scraper from a BG-Wiki H3.
-- Returns the inner title string on match, otherwise nil.
local function _section_title(text)
    return text and text:match('^──%s+(.-)%s+──$')
end

-- After a section divider, sibling items render indented as if they were the
-- divider's children. BG-Wiki's source has no explicit end-of-section marker,
-- so we use a heuristic to detect when the walkthrough resumes the main flow.
-- These phrases match the common "back to the main steps" wording across pages.
local _RETURN_PATTERNS = {
    '^Once you',
    '^Once the',
    '^After the cutscene',
    '^After you',
    '^After completing',
    '^After defeating',
    '^Finally',
    '^Return to ',
    '^Head back',
    '^Head to ',
    '^Travel to ',
    '^Speak to .- to receive',
    '^Trade .- to receive',
    '^Examine ',
    '^Report to ',
    '^Talk to .- for your reward',
}
local function _is_return_to_flow(text)
    if not text then return false end
    for _, pat in ipairs(_RETURN_PATTERNS) do
        if text:match(pat) then return true end
    end
    return false
end

local function _emit_walk(lines, items, depth, section_depth)
    depth = depth or 0
    section_depth = section_depth or 0   -- extra indent applied while inside a section
    local effective = depth + section_depth
    local indent = string.rep('   ', effective)
    local bullet = (effective == 0) and '* ' or '- '
    local lead   = indent .. bullet
    -- Sticky-section tracking: once a divider appears at this level, every
    -- sibling item until either the next divider OR a return-to-flow phrase
    -- (e.g. "Once you have...", "After the cutscene...") is rendered indented
    -- one level deeper, as if it were the divider's child.
    local local_section_depth = section_depth
    for _, entry in ipairs(items) do
        local text = entry[1] or ''
        local sect = _section_title(text)
        if sect then
            local hdr_indent = string.rep('   ', depth)
            if #lines > 0 and lines[#lines] ~= '' then
                lines[#lines+1] = ''
            end
            lines[#lines+1] = CS_SECTION .. hdr_indent .. '═══ ' .. sect .. ' ═══' .. CS_END
            local_section_depth = section_depth + 1
            if entry.sub then
                _emit_walk(lines, entry.sub, depth + 1, section_depth)
            end
        else
            -- If we're currently inside a section and this item reads like a
            -- return to the main walkthrough flow, pop back to base depth and
            -- insert a blank line so the visual hierarchy reads clearly.
            if local_section_depth > section_depth and _is_return_to_flow(text) then
                local_section_depth = section_depth
                if #lines > 0 and lines[#lines] ~= '' then
                    lines[#lines+1] = ''
                end
            end
            local eff = depth + local_section_depth
            local ind = string.rep('   ', eff)
            local b   = (eff == 0) and '* ' or '- '
            local ld  = ind .. b
            local body_w = TOOLTIP_WIDTH_CHARS - #ld
            if body_w < 16 then body_w = 16 end
            local prefix = CS_BULLET .. ld .. CS_END .. CS_VALUE
            local cont   = CS_VALUE .. string.rep(' ', #ld)
            local wrapped = _wrap_line(text, body_w, prefix, cont)
            for _, l in ipairs(wrapped) do
                lines[#lines+1] = l .. CS_END
            end
            if entry.sub then
                _emit_walk(lines, entry.sub, depth + 1, local_section_depth)
            end
        end
    end
end

-- Build the formatted line array for a record.
-- Renders both mission AND quest schemas; absent fields just skip.
local function _build_lines(rec)
    local d = rec.data
    local L = {}

    -- Header: page key + mission/quest title in quotes if distinct.
    L[#L+1] = CS_HEADER .. rec.key .. CS_END
    if d.title and d.title ~= rec.key and d.title ~= '' then
        L[#L+1] = CS_HEADER .. '   "' .. d.title .. '"' .. CS_END
    end
    L[#L+1] = ''

    -- Field order locked to the user's spec:
    --   Starting NPC -> Title -> Repeatable -> (quest extras)
    --   -> Description -> Note -> Walkthrough -> footer
    _emit_field(L, 'Starting NPC', d.starting_npc)
    if d.subtitle and d.subtitle ~= '' and d.subtitle ~= 'None' then
        _emit_field(L, 'Title', d.subtitle)
    else
        _emit_field(L, 'Title', d.subtitle == '' and nil or d.subtitle)
    end
    _emit_field(L, 'Repeatable',        d.repeatable)
    -- Quest-specific fields (from Category:Quests pages).
    _emit_field(L, 'Required Fame',     d.required_fame)
    _emit_field(L, 'Level Restriction', d.level_restriction)
    _emit_field(L, 'Pack',              d.pack)
    _emit_field(L, 'Requirements',      d.requirements)
    _emit_field(L, 'Rewards',           d.rewards)
    -- Assault-specific fields (from Category:Assault pages).
    _emit_field(L, 'Assault Rank',      d.assault_rank)
    _emit_field(L, 'Time Limit',        d.time_limit)
    _emit_field(L, 'Recommended Lv',    d.recommended_lv)
    _emit_field(L, 'Mission Orders',    d.mission_orders)
    L[#L+1] = ''
    _emit_field(L, 'Description', d.description)

    if d.note and d.note ~= '' then
        L[#L+1] = ''
        -- Highlight the note label in red to match BG-Wiki's styling.
        local lead   = 'Note: '
        local prefix = '\\cs(255,90,90)' .. lead .. CS_END .. CS_VALUE
        local cont   = CS_VALUE .. string.rep(' ', #lead)
        local body_w = TOOLTIP_WIDTH_CHARS - #lead
        if body_w < 16 then body_w = 16 end
        local first_chunk = d.note:sub(1, body_w)
        local rest        = d.note:sub(#first_chunk + 1):gsub('^%s+','')
        L[#L+1] = prefix .. first_chunk .. CS_END
        if #rest > 0 then
            for _, l in ipairs(_wrap_line(rest, body_w, cont, cont)) do
                L[#L+1] = l .. CS_END
            end
        end
    end
    L[#L+1] = ''

    if d.walkthrough and #d.walkthrough > 0 then
        L[#L+1] = CS_HEADER .. 'Walkthrough' .. CS_END
        _emit_walk(L, d.walkthrough, 0)
    end

    -- The H2 "Notes" section from BG-Wiki, when present, lands here.
    if d.notes and #d.notes > 0 then
        L[#L+1] = ''
        L[#L+1] = CS_HEADER .. 'Notes' .. CS_END
        _emit_walk(L, d.notes, 0)
    end

    -- Footer.
    if d.series and d.series ~= '' then
        L[#L+1] = ''
        L[#L+1] = CS_MUTED .. 'Series: ' .. d.series .. CS_END
    end
    if d.previous_quest and d.previous_quest ~= '' and d.previous_quest ~= 'None' then
        L[#L+1] = CS_MUTED .. 'Previous Quest: ' .. d.previous_quest .. CS_END
    end
    if d.next_quest and d.next_quest ~= '' and d.next_quest ~= 'None' then
        L[#L+1] = CS_MUTED .. 'Next Quest: ' .. d.next_quest .. CS_END
    end

    return L
end

-- ---------------------------------------------------------------------------
-- Public: lookup record by mission title or page key.
-- ---------------------------------------------------------------------------
function quest_panel.lookup(title)
    if not title or title == '' then return nil end
    local clean = title:gsub('\\cs%([%d,]+%)', ''):gsub('\\cr', '')
                        :gsub('^%s+',''):gsub('%s+$','')
    -- Also drop leading + that FFXIChecklist uses on some quest groupings.
    clean = clean:gsub('^[%-%*%>%+%s]+', '')
    return title_index[clean] or title_index[_norm(clean)]
end

-- ---------------------------------------------------------------------------
-- Render the panel at fixed size next to the main window.
-- ---------------------------------------------------------------------------
function quest_panel.render(rec, anchor_x, anchor_y, main_panel_w, main_panel_h)
    _init_ui()
    if not rec then
        _hide(); _last_key = nil; _lines = {}; _scroll = 0
        return
    end

    -- ----- Fixed panel size: locks to the main window's current height.
    --       Never grows or shrinks to content; we scroll instead. --------
    local res = windower.get_windower_settings()
    local screen_w = (res and res.ui_x_res) or 1920
    local screen_h = (res and res.ui_y_res) or 1080

    local height = main_panel_h or 400
    if height > screen_h - 20 then height = screen_h - 20 end
    if height < 200 then height = 200 end

    -- ----- Horizontal placement: prefer right, fall back to left,
    --       clamp to edge on tiny screens. ------------------------------
    local gap = 6
    local right_px = anchor_x + main_panel_w + gap
    local left_px  = anchor_x - PANEL_W - gap
    local px
    if right_px + PANEL_W <= screen_w then
        px = right_px
    elseif left_px >= 0 then
        px = left_px
    else
        local space_right = screen_w - (anchor_x + main_panel_w + gap)
        local space_left  = anchor_x - gap
        if space_right >= space_left then
            px = math.max(0, screen_w - PANEL_W)
        else
            px = 0
        end
    end

    local py = anchor_y
    if py + height > screen_h then py = math.max(0, screen_h - height) end
    if py < 0 then py = 0 end

    -- ----- Chrome ------------------------------------------------------
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

    -- ----- Body region geometry ---------------------------------------
    local body_x = px + BORDER + 2
    local body_y = py + BORDER + HEADER_H + 4
    local body_h_avail = height - HEADER_H - BORDER * 2 - 8

    -- Rebuild lines only when selection changes; reset scroll too.
    if rec.key ~= _last_key then
        _lines    = _build_lines(rec)
        _last_key = rec.key
        _scroll   = 0
    end

    local total = #_lines
    -- Compute how many lines fit, leaving room for the scroll buttons
    -- when scrolling is actually needed.
    local rows_no_scroll = math.max(1, math.floor(body_h_avail / LINE_H))
    local need_scroll    = total > rows_no_scroll
    local rows
    if need_scroll then
        local room = body_h_avail - (SCROLL_BTN_H + 4) * 2
        rows = math.max(1, math.floor(room / LINE_H))
    else
        rows = rows_no_scroll
    end
    _visible_rows = rows

    -- Clamp scroll to valid range.
    local max_scroll = math.max(0, total - rows)
    if _scroll > max_scroll then _scroll = max_scroll end
    if _scroll < 0 then _scroll = 0 end

    -- ----- Scroll arrows ----------------------------------------------
    if need_scroll then
        ui.scroll_up:pos(body_x, body_y)
        ui.scroll_up:visible(true)
        local uw, uh = ui.scroll_up:extents()
        uw = uw or 140; uh = uh or SCROLL_BTN_H
        _up_rect = {x = body_x, y = body_y, w = uw, h = uh}
        body_y = body_y + uh + 4

        ui.scroll_dn:visible(true)
        local dw, dh = ui.scroll_dn:extents()
        dw = dw or 140; dh = dh or SCROLL_BTN_H
        local dn_y = py + height - BORDER - dh - 4
        ui.scroll_dn:pos(body_x, dn_y)
        _dn_rect = {x = body_x, y = dn_y, w = dw, h = dh}

        -- Fade the inactive arrow.
        if _scroll <= 0 then
            ui.scroll_up:bg_alpha(C_SCROLL_OFF.alpha)
        else
            ui.scroll_up:bg_alpha(C_SCROLL_BG.alpha)
        end
        if _scroll >= max_scroll then
            ui.scroll_dn:bg_alpha(C_SCROLL_OFF.alpha)
        else
            ui.scroll_dn:bg_alpha(C_SCROLL_BG.alpha)
        end
    else
        ui.scroll_up:hide()
        ui.scroll_dn:hide()
        _up_rect = {x = 0, y = 0, w = 0, h = 0}
        _dn_rect = {x = 0, y = 0, w = 0, h = 0}
    end

    -- ----- Visible slice of body text --------------------------------
    --
    -- The math above gives a starting `rows` count, but Arial line pitch
    -- varies a hair between renders and stroke padding eats a few pixels,
    -- so a row or two would leak past the bottom border (the user's
    -- screenshot showed "Home Point #1..." rendering below the chrome).
    -- After we set the slice, we measure the texts object's actual
    -- rendered height with extents() and pop one row at a time until it
    -- fits. We then memoize the trimmed row count so subsequent scroll
    -- frames don't pay the measure cost.
    ui.body:pos(body_x, body_y)
    local body_bottom_y = need_scroll
        and (py + height - BORDER - 4 - SCROLL_BTN_H - 4)
        or  (py + height - BORDER - 4)
    local body_h_target = body_bottom_y - body_y

    local function _build_slice(n)
        local s = {}
        for i = 1, n do
            local idx = i + _scroll
            s[#s+1] = _lines[idx] or ''
        end
        return s
    end

    ui.body:text(table.concat(_build_slice(rows), '\n'))
    local _w, mh = ui.body:extents()
    local guard = 0
    while mh and mh > body_h_target and rows > 1 and guard < 60 do
        rows = rows - 1
        ui.body:text(table.concat(_build_slice(rows), '\n'))
        _w, mh = ui.body:extents()
        guard = guard + 1
    end
    _visible_rows = rows

    -- Re-clamp scroll now that we know the true visible-row count
    -- (max_scroll may have decreased).
    local new_max_scroll = math.max(0, total - rows)
    if _scroll > new_max_scroll then
        _scroll = new_max_scroll
        ui.body:text(table.concat(_build_slice(rows), '\n'))
    end

    -- ----- Hit rect for the mouse wheel handler ----------------------
    _panel_rect = {x = px, y = py, w = PANEL_W, h = height}

    _show()
end

function quest_panel.hide()
    _hide()
    _last_key = nil; _lines = {}; _scroll = 0
end

-- ---------------------------------------------------------------------------
-- Public hook called every prerender by ui.lua.
-- ---------------------------------------------------------------------------
function quest_panel.tick(opts)
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
-- Mouse handler. Consumes wheel events over the panel + click-to-scroll
-- on the ▲/▼ buttons. ui.lua already owns the main panel's mouse handler;
-- ours is independent and only acts when the cursor is over OUR rect.
--   type:   0 move | 1 LMB down | 2 LMB up | 10 wheel
--   delta:  +1 wheel up | -1 wheel down (Windower convention)
-- ---------------------------------------------------------------------------
windower.register_event('mouse', function(type, x, y, delta, blocked)
    if blocked then return false end
    if not _visible then return false end
    local r = _panel_rect
    local over_panel = (x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h)
    if not over_panel then return false end

    if type == 10 and delta and delta ~= 0 then
        local total = #_lines
        local max_scroll = math.max(0, total - _visible_rows)
        if delta > 0 then
            _scroll = math.max(0, _scroll - 2)
        else
            _scroll = math.min(max_scroll, _scroll + 2)
        end
        return true
    end

    if type == 1 then
        local u = _up_rect
        if u.w > 0 and x >= u.x and x <= u.x + u.w
                  and y >= u.y and y <= u.y + u.h then
            _scroll = math.max(0, _scroll - math.max(1, math.floor(_visible_rows / 2)))
            return true
        end
        local d = _dn_rect
        if d.w > 0 and x >= d.x and x <= d.x + d.w
                  and y >= d.y and y <= d.y + d.h then
            local total = #_lines
            local max_scroll = math.max(0, total - _visible_rows)
            _scroll = math.min(max_scroll, _scroll + math.max(1, math.floor(_visible_rows / 2)))
            return true
        end
    end

    -- Consume the click anywhere over the panel so it doesn't fall
    -- through to the game world (matches ui.lua's main-panel behavior).
    if type == 1 or type == 3 or type == 5 then return true end
    return false
end)

-- ---------------------------------------------------------------------------
-- Load on require()
-- ---------------------------------------------------------------------------
_load()

function quest_panel.is_starter(subtab_name)
    return subtab_known[subtab_name] == true
end

function quest_panel.has_data(subtab_name)
    return subtab_known[subtab_name] == true
end

function quest_panel.reload()
    title_index  = {}
    subtab_known = {}
    _load()
    _last_key = nil; _lines = {}; _scroll = 0
end

return quest_panel

#!/usr/bin/env python3
# Scrape BG-Wiki Category:Quests subcategories for FFXIChecklist's quest subtabs.
# Output goes into the SAME quest_info.lua file the mission scraper writes to,
# under additional top-level keys matching FFXIChecklist subtab names
# (sandoria, bastok, windurst, jeuno, ahturhgan, crystalwar, outlands, other,
#  abyssea, adoulin, coalition).
#
# Quest info-box schema (different from missions):
#   <td style="background:#E2EDF7;...">Label</td><td>value</td>
# plus a side table for Previous Quest / Next Quest / Requirements / Rewards
# and an optional <font style="color:red"><b>Note:</b></font>... block.

import re, sys, os, html as htmllib, urllib.request, time, json
from scrape_missions import (
    fetch, fetch_category_pages, strip_tags, parse_walkthrough, parse_notes,
    lua_str, emit_walkthrough,
)

sys.stdout.reconfigure(encoding='utf-8')

# (BG-Wiki category slug, FFXIChecklist subtab name)
QUEST_CATEGORIES = [
    ('Category:Bastok_Quests',         'bastok'),
    ('Category:San_d%27Oria_Quests',   'sandoria'),
    ('Category:Windurst_Quests',       'windurst'),
    ('Category:Jeuno_Quests',          'jeuno'),
    ('Category:Aht_Urhgan_Quests',     'ahturhgan'),
    ('Category:Crystal_War_Quests',    'crystalwar'),
    ('Category:Outlands_Quests',       'outlands'),
    ('Category:Other_Quests',          'other'),
    ('Category:Abyssea_Quests',        'abyssea'),
    ('Category:Adoulin_Quests',        'adoulin'),
    ('Category:Coalition_Assignments', 'coalition'),
    # Categories that don't map to a dedicated FFXIChecklist subtab get
    # filed under 'other' so lookups still find them by title.
    ('Category:Additional_Job_Quests', 'other'),
    ('Category:Avatar_Quests',         'other'),
    ('Category:Promotion_Quests',      'other'),
    ('Category:Map_Quests',            'other'),
    ('Category:Escort_Quests',         'other'),
    ('Category:Voidwatch_Quests',      'other'),
    ('Category:Fellowship_Quests',     'other'),
    ('Category:WSNM',                  'other'),
]

# --- Recognized info-table label set for scoring -----------------
_INFO_KEYS = {
    'required fame','level restriction','starting npc','pack','title',
    'repeatable','description','previous quest','next quest',
    'requirements','reward','rewards','items needed','items granted',
    'aliases','mission orders','series','time limit','assault rank',
    'recommended lv','recommended lv.',
}

def parse_quest_info_table(html):
    """Quest info-box parser. Handles three row schemas:
       <th>Label</th><td>value</td>
       <td><b>Label:</b></td><td>value</td>            (assault / older)
       <td style="background:...">Label</td><td>value</td>  (modern quest)
    Picks the table that scores highest on recognized labels.
    """
    tables = re.findall(r'<table[^>]*>(.*?)</table>', html, re.DOTALL)
    merged = {}
    any_hit = False
    for t in tables:
        local = {}
        # Title in colspan top row
        mtitle = re.search(r'<th[^>]*colspan="?\d+%?"?[^>]*>(.*?)</th>', t, re.DOTALL)
        if not mtitle:
            mtitle = re.search(r'<td[^>]*colspan="?\d+"?[^>]*>\s*<b[^>]*>(.*?)</b>', t, re.DOTALL)
        if mtitle:
            local['_title'] = strip_tags(mtitle.group(1))
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', t, re.DOTALL)
        for row in rows:
            # Schema A: <th>label</th><td>value</td>
            m = re.search(r'<th[^>]*>(.*?)</th>\s*<td[^>]*>(.*?)</td>', row, re.DOTALL)
            if m:
                k = strip_tags(m.group(1)).rstrip(':')
                v = strip_tags(m.group(2))
                if k: local[k] = v
                continue
            # Schema B: <td>...<b>label:</b></td><td>value</td>
            m = re.search(r'<td[^>]*>\s*(?:&#160;)?\s*<b[^>]*>(.*?)</b>\s*</td>\s*<td[^>]*>(.*?)</td>', row, re.DOTALL)
            if m:
                k = strip_tags(m.group(1)).rstrip(':')
                v = strip_tags(m.group(2))
                if k: local[k] = v
                continue
            # Schema C: <td bg-colored>label</td><td>value</td>
            m = re.search(r'<td[^>]*style="[^"]*background[^"]*"[^>]*>([^<]+?)</td>\s*<td[^>]*>(.*?)</td>', row, re.DOTALL)
            if m:
                k = strip_tags(m.group(1)).rstrip(':')
                v = strip_tags(m.group(2))
                if k: local[k] = v
                continue
            # Side table: two-column header pairs (Previous Quest / Next
            # Quest) then a matching <td>value1</td><td>value2</td> row.
            # The value cells contain links/markup so we use (.*?) not
            # [^<]*.
            if local.get('_pending_pair_labels'):
                m = re.search(r'<td[^>]*>(.*?)</td>\s*<td[^>]*>(.*?)</td>', row, re.DOTALL)
                if m:
                    lbl_a, lbl_b = local.pop('_pending_pair_labels')
                    v_a = strip_tags(m.group(1)); v_b = strip_tags(m.group(2))
                    if lbl_a: local[lbl_a] = v_a
                    if lbl_b: local[lbl_b] = v_b
                    continue
            # Single-label colspan rows: <th colspan="2">Requirements</th>
            # then <td colspan="2">value</td>.
            if local.get('_pending_solo_label'):
                m = re.search(r'<td[^>]*colspan="?\d+"?[^>]*>(.*?)</td>', row, re.DOTALL)
                if m:
                    lbl = local.pop('_pending_solo_label')
                    v   = strip_tags(m.group(1))
                    if lbl: local[lbl] = v
                    continue
            # Paired-header row: <th>A</th><th>B</th>
            mp = re.search(r'<th[^>]*>([^<]+?)</th>\s*<th[^>]*>([^<]+?)</th>', row, re.DOTALL)
            if mp:
                local['_pending_pair_labels'] = (
                    strip_tags(mp.group(1)).rstrip(':'),
                    strip_tags(mp.group(2)).rstrip(':'),
                )
                continue
            # Solo-label header row: <th colspan="2">Requirements</th>
            ms = re.search(r'<th[^>]*colspan="?\d+"?[^>]*>([^<]+?)</th>', row, re.DOTALL)
            if ms:
                lbl = strip_tags(ms.group(1)).rstrip(':')
                # If this is the title (single header at top), skip --
                # we already captured it via mtitle. Detect by checking
                # whether we've seen any data rows yet.
                if lbl and not local.get('_title'):
                    # No title yet: this IS the title row.
                    local['_title'] = lbl
                elif lbl:
                    local['_pending_solo_label'] = lbl
                continue
        local.pop('_pending_pair_labels', None)
        local.pop('_pending_solo_label', None)
        score = sum(1 for k in local if k.lower() in _INFO_KEYS)
        if local.get('_title'): score += 1
        if score >= 1:
            any_hit = True
            # Merge: later tables don't overwrite a value the left/main
            # table already set unless the field is currently empty.
            for k, v in local.items():
                if k == '_title':
                    if not merged.get('_title'): merged['_title'] = v
                    continue
                if k not in merged or not merged[k]:
                    merged[k] = v
    return merged if any_hit else {}

def parse_note(html):
    """Optional red-text Note block above the Walkthrough section."""
    m = re.search(r'<font[^>]*color\s*:\s*red[^>]*>\s*<b[^>]*>Note:?</b>\s*</font>(.*?)(?=<h2>|<p><br|</p>)', html, re.DOTALL | re.IGNORECASE)
    if not m:
        m = re.search(r'<b[^>]*>Note:?</b>(.*?)(?=<h2>)', html, re.DOTALL)
    if not m: return ''
    return strip_tags(m.group(1))

def scrape_quest(slug, display_title):
    html = fetch(slug)
    info = parse_quest_info_table(html)
    walk = parse_walkthrough(html)
    notes = parse_notes(html)
    note = parse_note(html)
    rec = {
        'page'            : display_title,
        'title'           : info.get('_title') or info.get('Title') or display_title,
        'starting_npc'    : info.get('Starting NPC',''),
        'subtitle'        : info.get('Title',''),
        'repeatable'      : info.get('Repeatable',''),
        'description'     : info.get('Description',''),
        'required_fame'   : info.get('Required Fame',''),
        'level_restriction': info.get('Level Restriction',''),
        'pack'            : info.get('Pack',''),
        'previous_quest'  : info.get('Previous Quest',''),
        'next_quest'      : info.get('Next Quest',''),
        'requirements'    : info.get('Requirements',''),
        'rewards'         : info.get('Rewards','') or info.get('Reward',''),
        'note'            : note,
        'walkthrough'     : walk,
        'notes'           : notes,
    }
    # Junk filter: skip pages with neither title nor any quest-shaped fields.
    if not (rec['title'] and (rec['description'] or rec['starting_npc']
                              or rec['walkthrough'] or rec['notes']
                              or rec['required_fame'] or rec['rewards'])):
        return None
    return rec

def emit_quest_block(L, subtab, missions):
    """Emit one quest_info['<subtab>'] = { ... } block. Skips duplicate
    page keys, since the same quest can appear under multiple BG-Wiki
    subcategories (Repeatable + Bastok, Map + Bastok, etc.)."""
    seen = set()
    L.append(f"quest_info['{subtab}'] = {{")
    for m in missions:
        key = m['page']
        if key in seen: continue
        seen.add(key)
        L.append(f"    [{lua_str(key)}] = {{")
        L.append(f"        title             = {lua_str(m['title'])},")
        L.append(f"        starting_npc      = {lua_str(m['starting_npc'])},")
        L.append(f"        subtitle          = {lua_str(m['subtitle'])},")
        L.append(f"        repeatable        = {lua_str(m['repeatable'])},")
        L.append(f"        description       = {lua_str(m['description'])},")
        if m.get('required_fame'):
            L.append(f"        required_fame     = {lua_str(m['required_fame'])},")
        if m.get('level_restriction'):
            L.append(f"        level_restriction = {lua_str(m['level_restriction'])},")
        if m.get('pack'):
            L.append(f"        pack              = {lua_str(m['pack'])},")
        if m.get('requirements'):
            L.append(f"        requirements      = {lua_str(m['requirements'])},")
        if m.get('rewards'):
            L.append(f"        rewards           = {lua_str(m['rewards'])},")
        if m.get('previous_quest'):
            L.append(f"        previous_quest    = {lua_str(m['previous_quest'])},")
        if m.get('next_quest'):
            L.append(f"        next_quest        = {lua_str(m['next_quest'])},")
        if m.get('note'):
            L.append(f"        note              = {lua_str(m['note'])},")
        if m['walkthrough']:
            L.append('        walkthrough       = {')
            L.extend(emit_walkthrough(m['walkthrough'], 12))
            L.append('        },')
        else:
            L.append('        walkthrough       = {},')
        if m.get('notes'):
            L.append('        notes             = {')
            L.extend(emit_walkthrough(m['notes'], 12))
            L.append('        },')
        L.append('    },')
    L.append('}')
    L.append('')

def main():
    # Group results by FFXIChecklist subtab (multiple BG-Wiki cats can map
    # to the same FFXIChecklist subtab, e.g. Promotion → other).
    by_subtab = {}
    for cat_slug, subtab in QUEST_CATEGORIES:
        print(f'=== {subtab} <- {cat_slug} ===', flush=True)
        try:
            pages = fetch_category_pages(cat_slug)
        except Exception as e:
            print('  ERROR fetching category:', e); continue
        print(f'  {len(pages)} pages')
        skipped = 0
        for i, (slug, title) in enumerate(pages):
            try:
                m = scrape_quest(slug, title)
                if m is None:
                    skipped += 1; continue
                by_subtab.setdefault(subtab, []).append(m)
                if (i+1) % 50 == 0:
                    print(f'    [{i+1}/{len(pages)}] {title}', flush=True)
            except Exception as e:
                print('    ERROR', slug, ':', e)
        if skipped:
            print(f'  (skipped {skipped} non-quest pages)')

    # Merge into existing mission quest_info.lua so the addon only has to
    # require() one file.
    target = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'quest_info.lua')
    if os.path.exists(target):
        with open(target,'r',encoding='utf-8') as f: existing = f.read()
    else:
        existing = "local quest_info = {}\n\nreturn quest_info\n"

    # Insert quest blocks BEFORE the final `return quest_info`.
    new_lines = []
    for subtab, missions in by_subtab.items():
        # Sort missions alphabetically by page name within each subtab so
        # the file diff stays stable run-to-run.
        missions.sort(key=lambda m: m['page'].lower())
        emit_quest_block(new_lines, subtab, missions)

    # Splice: drop any prior quest_info['<subtab>'] = {...} blocks for
    # the same subtabs (so re-running doesn't duplicate them).
    out = existing
    for subtab in by_subtab:
        # Remove any prior block for this subtab
        pat = re.compile(r"\nquest_info\['" + re.escape(subtab) + r"'\] = \{.*?\n\}\n", re.DOTALL)
        out = pat.sub('\n', out)
    # Now insert new blocks before `return quest_info`.
    ins = '\n'.join(new_lines)
    if 'return quest_info' in out:
        out = out.replace('return quest_info', ins + '\nreturn quest_info')
    else:
        out = out + '\n' + ins
    with open(target,'w',encoding='utf-8') as f: f.write(out)
    print('Wrote', target)
    for subtab, arr in by_subtab.items():
        print(f'  {subtab}: {len(arr)}')

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
# Scrape BG-Wiki for ALL mission categories. Maps to FFXIChecklist subtab names.
import re, sys, os, html as htmllib, urllib.request, time, json

sys.stdout.reconfigure(encoding='utf-8')

# (BG-Wiki category slug, FFXIChecklist subtab name, friendly nation key)
CATEGORIES = [
    ('Category:Bastok_Missions',                       'bastokmissions',   'Bastok'),
    ('Category:Windurst_Missions',                     'windurstmissions', 'Windurst'),
    ('Category:San_d%27Oria_Missions',                 'sandoriamissions', 'SanDoria'),
    ('Category:Zilart_Missions',                       'zilartmissions',   'Zilart'),
    ('Category:Promathia_Missions',                    'copmissions',      'CoP'),
    ('Category:Aht_Urhgan_Missions',                   'ahturhganmissions','AhtUrhgan'),
    ('Category:Wings_of_the_Goddess_Missions',         'wotgmissions',     'WotG'),
    ('Category:Crystalline_Missions',                  'acpmissions',      'ACP'),
    ('Category:A_Moogle_Kupo_d%27Etat_Missions',       'mkdmissions',      'MKD'),
    ('Category:A_Shantotto_Ascension_Missions',        'asamissions',      'ASA'),
    ('Category:Seekers_of_Adoulin_Missions',           'soamissions',      'SoA'),
    ('Category:Rhapsodies_of_Vanadiel_Missions',       'rovmissions',      'RoV'),
    ('Category:The_Voracious_Resurgence_Missions',     'tvrmissions',      'TVR'),
    ('Category:Assault',                               'assaults',         'Assault'),
]

UA = {'User-Agent': 'Mozilla/5.0 (FFXIChecklist QuestScraper)'}

def fetch(slug, force=False):
    fname = re.sub(r'[^A-Za-z0-9._-]', '_', slug) + '.html'
    if not force and os.path.exists(fname) and os.path.getsize(fname) > 4000:
        with open(fname, 'r', encoding='utf-8') as f: return f.read()
    url = f'https://www.bg-wiki.com/ffxi/{slug}'
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read().decode('utf-8','replace')
    with open(fname, 'w', encoding='utf-8') as f: f.write(data)
    time.sleep(0.25)
    return data

def fetch_category_pages(cat_slug):
    """Walk all paginated pages of a category. Returns list of (slug, title)."""
    out = []
    next_slug = cat_slug
    seen_titles = set()
    page_count = 0
    while next_slug and page_count < 40:
        page_count += 1
        html = fetch(next_slug)
        # Extract from mw-pages section
        m = re.search(r'<div id="mw-pages">(.*?)<div class="printfooter"', html, re.DOTALL)
        section = m.group(1) if m else html
        # Find page links
        links = re.findall(r'<a href="/ffxi/([^"#]+)" title="([^"]+)">', section)
        for slug, title in links:
            if 'Category:' in slug: continue
            if 'Special:' in slug: continue
            title = htmllib.unescape(title)
            if title in seen_titles: continue
            seen_titles.add(title)
            out.append((slug, title))
        # Find 'next page' link
        nxt = re.search(r'<a href="[^"]*\?title=([^&"]+)&amp;pagefrom=([^"&]+)[^"]*"[^>]*>next page</a>', html)
        if nxt:
            # Reconstruct slug with pagefrom param
            next_slug = f'{nxt.group(1)}&pagefrom={nxt.group(2)}'
        else:
            break
    return out

def strip_tags(s):
    s = re.sub(r'<img[^>]*alt="([^"]*)"[^>]*/?>', r'\1', s)
    s = re.sub(r'<br\s*/?>', '\n', s)
    s = re.sub(r'<[^>]+>', '', s)
    s = htmllib.unescape(s).strip()
    s = re.sub(r'[ \t]+', ' ', s)
    s = re.sub(r'\n[ \t]+', '\n', s)
    s = re.sub(r'\n+', ' ', s)
    return s.strip()

_INFO_KEYS = {
    'series','starting npc','title','repeatable','description',
    'previous mission','next mission','reward','level cap','members',
    'assault rank','objective','mission orders','time limit',
    'recommended lv.','recommended lv','assault points',
    'tag','tag npc','issuing officer','required rank','required mission',
    'previous assault','next assault',
}

def parse_info_table(html):
    """Parse mission/assault info-box, handling both row schemas:
       <th>label</th><td>value</td>     (standard mission template)
       <td><b>label:</b></td><td>value</td> (assault / older quest templates)
    Returns a dict; empty if nothing matched."""
    tables = re.findall(r'<table[^>]*>(.*?)</table>', html, re.DOTALL)
    info = {}
    best_score = -1
    for t in tables:
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', t, re.DOTALL)
        local = {}
        # Title in top colspan row
        mtitle = re.search(r'<th[^>]*colspan="?100%"?[^>]*>(.*?)</th>', t, re.DOTALL)
        if not mtitle:
            mtitle = re.search(r'<td[^>]*colspan="?\d+"?[^>]*>\s*<b[^>]*>(.*?)</b>', t, re.DOTALL)
        if mtitle:
            local['_title'] = strip_tags(mtitle.group(1))
        for row in rows:
            # Standard schema: <th>label</th><td>value</td>
            m = re.search(r'<th[^>]*>(.*?)</th>\s*<td[^>]*>(.*?)</td>', row, re.DOTALL)
            if m:
                k = strip_tags(m.group(1)); v = strip_tags(m.group(2))
                if k: local[k] = v
                continue
            # Assault schema: <td>...<b>label:</b></td><td>value</td>...
            m = re.search(r'<td[^>]*>\s*(?:&#160;)?\s*<b[^>]*>(.*?)</b>\s*</td>\s*(?:<td[^>]*colspan="?\d+"?[^>]*>|<td[^>]*>)(.*?)</td>', row, re.DOTALL)
            if m:
                k = strip_tags(m.group(1)).rstrip(':')
                v = strip_tags(m.group(2))
                if k: local[k] = v
                # An assault row can carry a SECOND label/value pair in the
                # remaining tds (e.g. Time Limit + Recommended Lv).
                tail = row[m.end():]
                m2 = re.search(r'<td[^>]*>\s*(?:&#160;)?\s*<b[^>]*>(.*?)</b>\s*</td>\s*<td[^>]*>(.*?)</td>', tail, re.DOTALL)
                if m2:
                    k2 = strip_tags(m2.group(1)).rstrip(':')
                    v2 = strip_tags(m2.group(2))
                    if k2: local[k2] = v2
        # Score the table by how many recognized keys it contains
        score = sum(1 for k in local if k.lower() in _INFO_KEYS)
        if local.get('_title'): score += 1
        if score > best_score:
            best_score = score
            info = local
    return info if best_score >= 1 else {}

def _consume_ul(chunk, pos):
    """At chunk[pos]=='<ul>', walk balanced ul..</ul>; return (parsed_items, end_pos)."""
    depth = 0; i = pos
    while i < len(chunk):
        if chunk[i:i+4] == '<ul>':
            depth += 1; i += 4
        elif chunk[i:i+5] == '</ul>':
            depth -= 1; i += 5
            if depth == 0: break
        else:
            i += 1
    body = chunk[pos+4 : i-5]
    return parse_li_list(body), i

def _find_section(html, section_id):
    """Capture body of an <h2 id=section_id> up to the next <h2> or printfooter."""
    m = re.search(
        r'<h2><span[^>]*id="' + re.escape(section_id) +
        r'"[^>]*>.*?</span>\s*</h2>(.*?)(?=<h2>|<!--|</div></div><div class="printfooter")',
        html, re.DOTALL)
    if not m: return None
    chunk = m.group(1)
    chunk = re.sub(r'<figure[^>]*>.*?</figure>', '', chunk, flags=re.DOTALL)
    chunk = re.sub(r'<style[^>]*>.*?</style>', '', chunk, flags=re.DOTALL)
    return chunk

def parse_walkthrough(html):
    """Walk every top-level <ul>, <h3>, and narrator <p> under the Walkthrough h2.
    Earlier versions only grabbed the first <ul> and dropped everything after the
    first H3 sub-section (e.g. 'NPC Outfits' on TVR 1-3), and never captured the
    Notes h2 at all. This version preserves the full BG-Wiki content."""
    chunk = _find_section(html, 'Walkthrough')
    if chunk is None: return []
    out = []
    pos = 0
    n = len(chunk)
    while pos < n:
        # Find next top-level block of interest
        nxt = None
        for tag in ('<ul>', '<h3', '<p>', '<p '):
            i = chunk.find(tag, pos)
            if i < 0: continue
            if nxt is None or i < nxt[0]: nxt = (i, tag)
        if nxt is None: break
        i, tag = nxt
        if tag == '<ul>':
            items, end = _consume_ul(chunk, i)
            out.extend(items)
            pos = end
        elif tag == '<h3':
            close = chunk.find('</h3>', i)
            if close < 0: break
            title = strip_tags(chunk[i:close])
            if title:
                # Visual divider in the rendered panel: `── NPC Outfits ──`.
                out.append((f'── {title} ──', []))
            pos = close + 5
        else:  # <p> / <p ...>
            close = chunk.find('</p>', i)
            if close < 0: break
            text = strip_tags(chunk[i:close])
            # Skip empty paragraph dividers but keep meaningful intro lines.
            if text and len(text) > 4:
                out.append((text, []))
            pos = close + 4
    return out

def parse_notes(html):
    """Capture the Notes h2 section as a flat list of bullets."""
    chunk = _find_section(html, 'Notes')
    if chunk is None: return []
    out = []
    pos = 0
    n = len(chunk)
    while pos < n:
        i = chunk.find('<ul>', pos)
        if i < 0: break
        items, end = _consume_ul(chunk, i)
        out.extend(items)
        pos = end
    return out

def parse_section_body(chunk):
    """Generic walker for any H2 section body. Returns a list of bullet items
    interleaved with `── H3 Title ──` dividers and meaningful paragraphs —
    the same shape as parse_walkthrough(), so the existing renderer handles
    Plot_Details / Reward / Trivia / etc. with zero extra UI work."""
    if chunk is None: return []
    out = []
    pos = 0
    n = len(chunk)
    while pos < n:
        nxt = None
        for tag in ('<ul>', '<h3', '<p>', '<p '):
            i = chunk.find(tag, pos)
            if i < 0: continue
            if nxt is None or i < nxt[0]: nxt = (i, tag)
        if nxt is None: break
        i, tag = nxt
        if tag == '<ul>':
            items, end = _consume_ul(chunk, i)
            out.extend(items)
            pos = end
        elif tag == '<h3':
            close = chunk.find('</h3>', i)
            if close < 0: break
            title = strip_tags(chunk[i:close])
            if title:
                out.append((f'── {title} ──', []))
            pos = close + 5
        else:
            close = chunk.find('</p>', i)
            if close < 0: break
            text = strip_tags(chunk[i:close])
            if text and len(text) > 4:
                out.append((text, []))
            pos = close + 4
    return out

# H2 sections we DO NOT capture as standalone fields because they're either
# already pulled by dedicated parsers (Walkthrough / Notes), purely
# navigational (See_Also), or low-value boilerplate.
_SKIP_SECTIONS = {'walkthrough', 'notes', 'see_also', 'external_links', 'references'}

def parse_all_other_sections(html):
    """Find every H2 section that ISN'T Walkthrough / Notes and capture its
    body. Returns dict mapping section title (display name, NOT id) -> list
    of bullet items. The user reported that previous scrapes silently
    dropped Plot_Details, Related_Links, Trust:_Gessho, Reward, Boss_Fight,
    Reacquisition, Enemies, Drops, Map etc. — this catches them all."""
    out = {}
    for m in re.finditer(
            r'<h2><span[^>]*id="([^"]+)"[^>]*>(.*?)</span>\s*</h2>(.*?)(?=<h2>|<!--|</div></div><div class="printfooter")',
            html, re.DOTALL):
        sec_id = m.group(1)
        sec_title = strip_tags(m.group(2))
        if sec_id.lower() in _SKIP_SECTIONS: continue
        if sec_title.lower() in _SKIP_SECTIONS: continue
        body = m.group(3)
        body = re.sub(r'<figure[^>]*>.*?</figure>', '', body, flags=re.DOTALL)
        body = re.sub(r'<style[^>]*>.*?</style>', '', body, flags=re.DOTALL)
        items = parse_section_body(body)
        if items:
            out[sec_title] = items
    return out

def parse_ul(chunk):
    """Legacy helper kept for callers that explicitly want the first <ul> only."""
    start = chunk.find('<ul>')
    if start < 0: return []
    items, _ = _consume_ul(chunk, start)
    return items

def parse_li_list(body):
    out = []
    i = 0
    while i < len(body):
        if body[i:i+4] != '<li>':
            i += 1; continue
        depth = 1; j = i + 4
        while j < len(body) and depth > 0:
            if body[j:j+4] == '<li>':
                depth += 1; j += 4
            elif body[j:j+5] == '</li>':
                depth -= 1; j += 5
            else:
                j += 1
        item = body[i+4 : j-5]
        sub = []
        sstart = item.find('<ul>')
        if sstart >= 0:
            depth2 = 0; k = sstart
            while k < len(item):
                if item[k:k+4] == '<ul>':
                    depth2 += 1; k += 4
                elif item[k:k+5] == '</ul>':
                    depth2 -= 1; k += 5
                    if depth2 == 0: break
                else:
                    k += 1
            pre = item[:sstart]
            sub_body = item[sstart+4 : k-5]
            post = item[k:]
            sub = parse_li_list(sub_body)
            item = pre + post
        text = strip_tags(item)
        if text or sub:
            out.append((text, sub))
        i = j
    return out

def scrape_mission(slug, display_title):
    html = fetch(slug)
    info = parse_info_table(html)
    walk = parse_walkthrough(html)
    notes = parse_notes(html)
    sections = parse_all_other_sections(html)
    # Pull description from any of several possible label variants.
    desc = (info.get('Description') or info.get('Objective')
            or info.get('Mission Orders') or '')
    npc  = (info.get('Starting NPC') or info.get('Tag NPC')
            or info.get('Tag') or info.get('Issuing Officer') or '')
    rec = {
        'page'         : display_title,
        'title'        : info.get('_title') or info.get('Title') or display_title,
        'series'       : info.get('Series',''),
        'starting_npc' : npc,
        'subtitle'     : info.get('Title',''),
        'repeatable'   : info.get('Repeatable',''),
        'description'  : desc,
        'walkthrough'  : walk,
        'notes'        : notes,
        'sections'     : sections,
        'previous'     : info.get('Previous Mission','') or info.get('Previous Assault',''),
        'next'         : info.get('Next Mission','')     or info.get('Next Assault',''),
        # Assault-specific (empty for regular missions)
        'assault_rank' : info.get('Assault Rank',''),
        'time_limit'   : info.get('Time Limit',''),
        'mission_orders': info.get('Mission Orders',''),
        'recommended_lv': info.get('Recommended Lv.','') or info.get('Recommended Lv',''),
    }
    # Filter: skip pages with no useful info at all (NPC/gear/category-list
    # noise pulled in from the category pages).
    if not (rec['title'] and (rec['description'] or rec['starting_npc']
                              or rec['walkthrough'] or rec['notes']
                              or rec['series'] or rec['assault_rank'])):
        return None
    return rec

def lua_str(s):
    if s is None: return "''"
    s = s.replace('\\','\\\\').replace("'", "\\'")
    s = s.replace('\r','').replace('\n','\\n')
    return "'" + s + "'"

def emit_walkthrough(items, indent):
    pad = ' ' * indent
    lines = []
    for txt, sub in items:
        if sub:
            lines.append(f"{pad}{{ {lua_str(txt)}, sub = {{")
            lines.extend(emit_walkthrough(sub, indent + 4))
            lines.append(f"{pad}}} }},")
        else:
            lines.append(f"{pad}{{ {lua_str(txt)} }},")
    return lines

def emit_lua(missions_by_subtab, outpath):
    L = []
    L.append('-- Auto-generated by FFXIChecklist quest scraper.')
    L.append('-- Source: BG-Wiki (https://www.bg-wiki.com/ffxi/Category:Missions)')
    L.append('-- Do not edit by hand - re-run scrape_all_missions.py to regenerate.')
    L.append('')
    L.append('local quest_info = {}')
    L.append('')
    for subtab, missions in missions_by_subtab.items():
        L.append(f"quest_info['{subtab}'] = {{")
        for m in missions:
            key = m['page']
            L.append(f"    [{lua_str(key)}] = {{")
            L.append(f"        title        = {lua_str(m['title'])},")
            L.append(f"        starting_npc = {lua_str(m['starting_npc'])},")
            L.append(f"        subtitle     = {lua_str(m['subtitle'])},")
            L.append(f"        repeatable   = {lua_str(m['repeatable'])},")
            L.append(f"        description  = {lua_str(m['description'])},")
            L.append(f"        series       = {lua_str(m['series'])},")
            L.append(f"        previous     = {lua_str(m['previous'])},")
            L.append(f"        next         = {lua_str(m['next'])},")
            # Assault-specific fields (empty string for non-assault missions)
            if m.get('assault_rank'):
                L.append(f"        assault_rank = {lua_str(m['assault_rank'])},")
            if m.get('time_limit'):
                L.append(f"        time_limit   = {lua_str(m['time_limit'])},")
            if m.get('mission_orders'):
                L.append(f"        mission_orders = {lua_str(m['mission_orders'])},")
            if m.get('recommended_lv'):
                L.append(f"        recommended_lv = {lua_str(m['recommended_lv'])},")
            if m['walkthrough']:
                L.append('        walkthrough  = {')
                L.extend(emit_walkthrough(m['walkthrough'], 12))
                L.append('        },')
            else:
                L.append('        walkthrough  = {},')
            if m.get('notes'):
                L.append('        notes        = {')
                L.extend(emit_walkthrough(m['notes'], 12))
                L.append('        },')
            # Every other H2 section (Plot_Details, Reward, Trivia, Boss_Fight,
            # Trust:_Name, Enemies, Drops, Map, Reacquisition, ...). Keyed by
            # the section's display title — the panel renders them as
            # additional `═══ Title ═══` blocks after Walkthrough/Notes.
            if m.get('sections'):
                L.append('        sections     = {')
                for sec_title, items in m['sections'].items():
                    L.append(f'            [{lua_str(sec_title)}] = {{')
                    L.extend(emit_walkthrough(items, 16))
                    L.append('            },')
                L.append('        },')
            L.append('    },')
        L.append('}')
        L.append('')
    L.append('return quest_info')
    L.append('')
    with open(outpath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(L))

def main():
    result = {}
    for cat_slug, subtab, nation in CATEGORIES:
        print(f'=== {subtab} ({cat_slug}) ===', flush=True)
        try:
            pages = fetch_category_pages(cat_slug)
        except Exception as e:
            print(f'  ERROR fetching category {cat_slug}: {e}')
            continue
        print(f'  {len(pages)} pages')
        missions = []
        skipped = 0
        for i, (slug, title) in enumerate(pages):
            try:
                m = scrape_mission(slug, title)
                if m is None:
                    skipped += 1
                    continue
                missions.append(m)
                if (i+1) % 25 == 0:
                    print(f'    [{i+1}/{len(pages)}] {title}', flush=True)
            except Exception as e:
                print(f'    ERROR {slug}: {e}')
        if skipped:
            print(f'  (skipped {skipped} non-mission pages)')
        result[subtab] = missions
        print(f'  -> {len(missions)} parsed', flush=True)

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'quest_info.lua')
    emit_lua(result, out)
    print('Wrote', out)
    for subtab, arr in result.items():
        print(f'  {subtab}: {len(arr)}')

if __name__ == '__main__':
    main()

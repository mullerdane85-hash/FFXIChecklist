#!/usr/bin/env python3
# Scrape BG-Wiki mission pages for Bastok, Windurst, San d'Oria starter missions.
# Output: quest_info.lua data file.
import re, sys, os, json, html as htmllib, urllib.parse, urllib.request, time

sys.stdout.reconfigure(encoding='utf-8')

NATIONS = [
    ('Bastok',   'Bastok_Mission',  range(1,10), [1,2,3]),  # 1-1..1-3, 2-1..2-3, 3-1..3-3 etc — handled below
    ('Windurst', 'Windurst_Mission', None, None),
    ('SanDoria', 'San_d%27Oria_Mission', None, None),
]

UA = {'User-Agent': 'Mozilla/5.0 (FFXIChecklist QuestScraper)'}

def fetch(slug):
    url = f'https://www.bg-wiki.com/ffxi/{slug}'
    fname = re.sub(r'[^A-Za-z0-9._-]','_', slug) + '.html'
    if os.path.exists(fname) and os.path.getsize(fname) > 4000:
        with open(fname,'r',encoding='utf-8') as f: return f.read()
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read().decode('utf-8','replace')
    with open(fname,'w',encoding='utf-8') as f: f.write(data)
    time.sleep(0.3)
    return data

def strip_tags(s):
    # Replace <a ...>X</a> with X, <i>X</i> with X, etc — but FIRST inline <img alt="X">
    s = re.sub(r'<img[^>]*alt="([^"]*)"[^>]*/?>', r'\1', s)
    # Replace <br/> with newline
    s = re.sub(r'<br\s*/?>', '\n', s)
    # Remove all other tags
    s = re.sub(r'<[^>]+>', '', s)
    s = htmllib.unescape(s).strip()
    # Collapse internal whitespace newlines
    s = re.sub(r'[ \t]+', ' ', s)
    s = re.sub(r'\n[ \t]+', '\n', s)
    s = re.sub(r'\n+', ' ', s)
    return s.strip()

def parse_info_table(html):
    # Find the Mission_Header template's table. Class is typically "bdrwhite missions"
    # but we just scan all tables and pick the one containing Series + Starting NPC.
    tables = re.findall(r'<table[^>]*>(.*?)</table>', html, re.DOTALL)
    info = {}
    for t in tables:
        if 'Series' in t and ('Starting NPC' in t or 'Starting_NPC' in t):
            # Title is in header row with colspan="100%"
            mtitle = re.search(r'<th[^>]*colspan="?100%"?[^>]*>(.*?)</th>', t, re.DOTALL)
            if mtitle:
                info['_title'] = strip_tags(mtitle.group(1))
            # Walk rows
            rows = re.findall(r'<tr[^>]*>(.*?)</tr>', t, re.DOTALL)
            for row in rows:
                m = re.search(r'<th[^>]*>(.*?)</th>\s*<td[^>]*>(.*?)</td>', row, re.DOTALL)
                if not m: continue
                k = strip_tags(m.group(1))
                v = strip_tags(m.group(2))
                if k: info[k] = v
            break
    return info

def parse_walkthrough(html):
    # Find <h2>...id="Walkthrough"...</h2> and consume until next <h2> or end of parser-output.
    m = re.search(r'<h2><span[^>]*id="Walkthrough"[^>]*>.*?</span>\s*</h2>(.*?)(?=<h2>|<!--|</div></div><div class="printfooter")', html, re.DOTALL)
    if not m: return []
    chunk = m.group(1)
    # Strip <figure>...</figure> wrappers (images don't render anyway)
    chunk = re.sub(r'<figure[^>]*>.*?</figure>', '', chunk, flags=re.DOTALL)
    # Find the outer <ul>
    return parse_ul(chunk)

def parse_ul(chunk):
    """Return a list of [text, sublist] from the first top-level <ul> in chunk."""
    # Find first <ul> (not nested inside another)
    start = chunk.find('<ul>')
    if start < 0: return []
    # Find its matching </ul>
    depth = 0
    i = start
    while i < len(chunk):
        if chunk[i:i+4] == '<ul>':
            depth += 1; i += 4
        elif chunk[i:i+5] == '</ul>':
            depth -= 1; i += 5
            if depth == 0: break
        else:
            i += 1
    body = chunk[start+4:i-5]
    return parse_li_list(body)

def parse_li_list(body):
    """Parse <li>...</li> entries, splitting nested <ul>...</ul> as sublist."""
    out = []
    i = 0
    while i < len(body):
        if body[i:i+4] != '<li>':
            # skip stray whitespace
            i += 1; continue
        # Find matching </li>
        depth = 1; j = i + 4
        while j < len(body) and depth > 0:
            if body[j:j+4] == '<li>':
                depth += 1; j += 4
            elif body[j:j+5] == '</li>':
                depth -= 1; j += 5
            else:
                j += 1
        item = body[i+4 : j-5]
        # Split off any inner <ul>...</ul>
        sub = []
        mul = re.search(r'<ul>(.*)</ul>\s*$', item, re.DOTALL)
        if mul:
            # Find balanced sub-ul start
            sstart = item.find('<ul>')
            if sstart >= 0:
                # find matching close
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
    return {
        'page'         : display_title,
        'title'        : info.get('_title') or info.get('Title') or display_title,
        'series'       : info.get('Series',''),
        'starting_npc' : info.get('Starting NPC',''),
        'subtitle'     : info.get('Title',''),
        'repeatable'   : info.get('Repeatable',''),
        'description'  : info.get('Description',''),
        'walkthrough'  : walk,
        'previous'     : info.get('Previous Mission',''),
        'next'         : info.get('Next Mission',''),
    }

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

def emit_lua(missions_by_nation, outpath):
    L = []
    L.append('-- Auto-generated by FFXIChecklist quest scraper.')
    L.append('-- Source: BG-Wiki (https://www.bg-wiki.com/ffxi/Category:Missions)')
    L.append('-- Do not edit by hand - re-run scrape_missions.py to regenerate.')
    L.append('')
    L.append('local quest_info = {}')
    L.append('')
    for nation, missions in missions_by_nation.items():
        L.append(f"quest_info['{nation}'] = {{")
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
            if m['walkthrough']:
                L.append('        walkthrough  = {')
                L.extend(emit_walkthrough(m['walkthrough'], 12))
                L.append('        },')
            else:
                L.append('        walkthrough  = {},')
            L.append('    },')
        L.append('}')
        L.append('')
    L.append('return quest_info')
    L.append('')
    with open(outpath,'w',encoding='utf-8') as f:
        f.write('\n'.join(L))

# --- Enumerate slugs from cached category html ---
def enumerate_slugs():
    with open('all_slugs.json','r') as f: slugs = json.load(f)
    out = {}
    for nation, arr in slugs.items():
        miss = []
        for slug, title in arr:
            if 'Special:' in slug: continue
            if 'Category:' in slug: continue
            # Decode html entities in title
            title = htmllib.unescape(title)
            miss.append((slug, title))
        # Sort by trailing N-M
        def sk(t):
            m = re.search(r'(\d+)-(\d+)', t[1])
            if m: return (int(m.group(1)), int(m.group(2)))
            return (99,99)
        miss.sort(key=sk)
        out[nation] = miss
    return out

def main():
    slugs = enumerate_slugs()
    result = {}
    for nation, arr in slugs.items():
        result[nation] = []
        for slug, title in arr:
            print(f'  {nation}: {title} ({slug})')
            try:
                m = scrape_mission(slug, title)
                result[nation].append(m)
            except Exception as e:
                print('    ERROR:', e)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'quest_info.lua')
    emit_lua(result, out)
    print('Wrote', out)
    # Quick summary
    for nation, arr in result.items():
        print(f'  {nation}: {len(arr)} missions')
        for m in arr[:2]:
            print(f"    {m['page']}: npc={m['starting_npc'][:40]!r} walk={len(m['walkthrough'])} steps")

if __name__ == '__main__':
    main()

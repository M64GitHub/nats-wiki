#!/usr/bin/env python3
"""Build the static web viewer for an LLM wiki (zero dependencies). Configured by wiki.json in the wiki root.

    python3 tools/build-site.py                    # render everything into site/
    python3 tools/build-site.py --serve            # build, serve http://127.0.0.1:8080/ and rebuild on change
    python3 tools/build-site.py --out DIR          # different output folder
    python3 tools/build-site.py --root DIR --config FILE   # build another wiki, or with another wiki.json

What it renders
  wiki/**/*.md            -> site/wiki/<slug>.html   frontmatter, Markdown, [[wikilinks]], backlinks, local graph
  wiki/index.md           -> site/index.html         home page with stats
  inbox/<toc>.md          -> site/inbox/<toc>.html   filterable, sortable tables (wiki.json "tocs")
  raw/**                  -> site/raw/<collection>/<file>.html  numbered lines, article anchors (+ original copies)
  generated               -> graph.html, cheatsheets.html + cheatsheet/<slug>.html, browse.html + browse/*.html,
                             wanted.html + wanted/<slug>.html, health.html, sources.html,
                             search-index.js, raw-index.js, graph-data.js, assets/types.css

Everything topic-specific comes from wiki.json: the site name and tagline, the page types (id, folder, label,
colour, optional kinds), extra frontmatter facets (e.g. platforms), inbox TOC tables, raw-collection article
anchors and the cheat-sheet rule. See the starter's docs/wiki-json.md for the schema; every key has a default.

Internal links are written with a placeholder (@@R@@) for the path to the site root, so every
page works from file://, from `python3 -m http.server` and from any sub-folder of a bigger site.
"""
import argparse, collections, datetime, glob, html, json, os, re, shutil, sys, threading, time

R = '@@R@@'  # placeholder for the relative path to the site root
esc = html.escape

PALETTE = {  # named colours a wiki.json "color" may use: (colour, soft background)
    'cyan': ('#5fd9e0', 'rgba(95,217,224,.14)'), 'amber': ('#ffb454', 'rgba(255,180,84,.16)'),
    'pink': ('#ff6fa5', 'rgba(255,111,165,.16)'), 'green': ('#7ee787', 'rgba(126,231,135,.14)'),
    'red': ('#ff5c5c', 'rgba(255,92,92,.16)'), 'violet': ('#b48cff', 'rgba(180,140,255,.16)'),
    'blue': ('#6ea8fe', 'rgba(110,168,254,.16)'), 'lime': ('#c8e64a', 'rgba(200,230,74,.14)'),
    'orange': ('#ff8c42', 'rgba(255,140,66,.16)'), 'teal': ('#3fc1a8', 'rgba(63,193,168,.14)'),
    'magenta': ('#e56ce5', 'rgba(229,108,229,.16)'), 'grey': ('#8890ad', 'rgba(136,144,173,.16)')}
DEFAULT_COLORS = ['cyan', 'amber', 'pink', 'green', 'violet', 'blue', 'lime', 'orange', 'teal', 'magenta']
DEFAULT_TYPES = [
    {'id': 'technique', 'folder': 'techniques', 'label': 'Techniques'},
    {'id': 'concept', 'folder': 'concepts', 'label': 'Concepts'},
    {'id': 'entity', 'folder': 'entities', 'label': 'Entities',
     'kinds': [{'id': 'tool', 'label': 'Tools'}, {'id': 'person', 'label': 'People'}, {'id': 'group', 'label': 'Groups'},
               {'id': 'publication', 'label': 'Publications'}, {'id': 'event', 'label': 'Events'}]},
    {'id': 'summary', 'folder': 'summaries', 'label': 'Summaries'}]


def color_pair(c, i=0):
    if not c:
        c = DEFAULT_COLORS[i % len(DEFAULT_COLORS)]
    if c in PALETTE:
        return PALETTE[c]
    m = re.fullmatch(r'#?([0-9a-fA-F]{6})', str(c))
    if m:
        h = m.group(1)
        return '#' + h, f'rgba({int(h[0:2], 16)},{int(h[2:4], 16)},{int(h[4:6], 16)},.16)'
    return PALETTE['grey']


def load_config(path):
    cfg = {'name': 'LLM Wiki', 'mark': '', 'tagline': '', 'search_placeholder': '', 'search_help': '',
           'types': DEFAULT_TYPES, 'facets': [], 'tocs': [], 'raw_collections': {}, 'cheatsheets': None, 'stub_words': 180}
    if path and os.path.exists(path):
        cfg.update(json.load(open(path, encoding='utf-8')))
    types = []
    for i, t in enumerate(cfg['types'] or DEFAULT_TYPES):
        t = dict(t)
        t.setdefault('id', t.get('folder', f'type{i}').rstrip('s'))
        t.setdefault('folder', t['id'] + 's')
        t.setdefault('label', t['id'].replace('-', ' ').title() + 's')
        t.setdefault('plural', t['label'].lower())
        t['color'], t['soft'] = color_pair(t.get('color'), i)
        t['kinds'] = [dict(k) if isinstance(k, dict) else {'id': k} for k in (t.get('kinds') or [])]
        for k in t['kinds']:
            k.setdefault('label', k['id'].replace('-', ' ').title() + 's')
        types.append(t)
    cfg['types'] = types
    facets = []
    for f in cfg['facets'] or []:
        f = dict(f) if isinstance(f, dict) else {'key': f}
        f.setdefault('label', f['key'].replace('-', ' ').title())
        f.setdefault('values', {})
        facets.append(f)
    cfg['facets'] = facets
    tocs = []
    for i, t in enumerate(cfg['tocs'] or []):
        t = dict(t)
        base = os.path.splitext(os.path.basename(t['file']))[0]
        t.setdefault('id', re.sub(r'[^a-z0-9]+', '', base.replace('-toc', ''))[:8] or f'toc{i}')
        t.setdefault('title', base.replace('-', ' '))
        t.setdefault('nav', t['title'].split(' — ')[0].split(' - ')[0])
        t.setdefault('label', t['nav'] + ' article')
        t.setdefault('url', os.path.splitext(t['file'])[0] + '.html')
        t.setdefault('title_column', 'title'); t.setdefault('file_column', ''); t.setdefault('num_column', '#')
        t.setdefault('flags_column', 'flags'); t.setdefault('summary_column', 'summary'); t.setdefault('star', '★')
        t.setdefault('filters', []); t.setdefault('meta_columns', []); t.setdefault('facets', {}); t.setdefault('collection', '')
        tocs.append(t)
    cfg['tocs'] = tocs
    if cfg.get('cheatsheets'):
        c = dict(cfg['cheatsheets'])
        c.setdefault('type', 'entity'); c.setdefault('kind', ''); c.setdefault('heading', 'cheat sheet')
        c.setdefault('section_type', types[0]['id'] if types else 'technique')
        c.setdefault('skip_headings', ['related', 'sources', 'to verify']); c.setdefault('skip_prefixes', [])
        c.setdefault('generic', None); c.setdefault('description', '')
        cfg['cheatsheets'] = c
    return cfg


def configure(root, config_path=None):
    """Point the module at a wiki root and its wiki.json (called at import for the enclosing repo, and from main)."""
    global ROOT, WIKI, INBOX, RAW, ASSETS, CFG, SITE, TYPES, TYPE_ORDER, TYPE_LABEL, TYPE_PLURAL, TYPE_BY_ID, FOLDER_TYPE
    global KIND_LABEL, FACETS, TOCS, RAWCOLL, CHEAT
    ROOT = os.path.abspath(root)
    WIKI, INBOX, RAW = os.path.join(ROOT, 'wiki'), os.path.join(ROOT, 'inbox'), os.path.join(ROOT, 'raw')
    ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'site-assets')
    CFG = load_config(config_path or os.path.join(ROOT, 'wiki.json'))
    SITE = CFG['name']
    TYPES = CFG['types']
    TYPE_ORDER = [t['id'] for t in TYPES]
    TYPE_LABEL = {t['id']: t['label'] for t in TYPES}
    TYPE_PLURAL = {t['id']: t['plural'] for t in TYPES}
    TYPE_BY_ID = {t['id']: t for t in TYPES}
    FOLDER_TYPE = {t['folder']: t['id'] for t in TYPES}
    KIND_LABEL = {k['id']: k['label'] for t in TYPES for k in t['kinds']}
    FACETS = CFG['facets']
    TOCS = CFG['tocs']
    RAWCOLL = CFG['raw_collections'] or {}
    CHEAT = CFG['cheatsheets']


configure(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def types_css():
    """Per-type colour tokens and the rules that use them (badges, links, tiles, legend swatches, headings)."""
    out = [':root{']
    for t in TYPES:
        out.append(f'  --t-{t["id"]}:{t["color"]}; --t-{t["id"]}-soft:{t["soft"]};')
    for tc in TOCS:
        out.append(f'  --t-{tc["id"]}:var(--amber); --t-{tc["id"]}-soft:var(--amber-soft);')
    out.append('  --t-wanted:var(--red); --t-wanted-soft:var(--red-soft); --t-log:var(--dim); --t-index:var(--dim); --t-page:var(--dim);'
               ' --t-cheatsheet:var(--cyan); --t-cheatsheet-soft:var(--cyan-soft); --t-inbox:var(--dim); --t-raw:var(--dim);')
    out.append('}')
    ids = TYPE_ORDER + [tc['id'] for tc in TOCS] + ['wanted', 'cheatsheet']
    for i in ids:
        out.append(f'.badge.t-{i}{{color:var(--t-{i});border-color:var(--t-{i});background:var(--t-{i}-soft)}}')
        out.append(f'.wl.t-{i}{{color:var(--t-{i})}}.tile.t-{i} b{{color:var(--t-{i})}}.sw.t-{i}{{background:var(--t-{i})}}.t-{i} .ph h1{{color:var(--t-{i})}}')
    out.append('@media print{' + ','.join(f'.wl.t-{i}' for i in ids) + '{color:#000;text-decoration:underline}}')
    return '\n'.join(out) + '\n'



# ---------------------------------------------------------------- frontmatter
def split_list(s):
    items, cur, q = [], [], None
    for c in s:
        if q:
            cur.append(c)
            if c == q: q = None
        elif c in '"\'':
            q = c; cur.append(c)
        elif c == ',':
            items.append(''.join(cur)); cur = []
        else:
            cur.append(c)
    items.append(''.join(cur))
    return [i.strip() for i in items if i.strip()]


def unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in '"\'':
        return s[1:-1]
    return s


def yaml_value(v):
    v = v.strip()
    if v.startswith('[') and v.endswith(']'):
        return [unquote(x) for x in split_list(v[1:-1])]
    if v in ('true', 'false'):
        return v == 'true'
    return unquote(v)


def parse_frontmatter(text):
    if not text.startswith('---\n'):
        return {}, text
    end = text.find('\n---\n', 4)
    if end < 0:
        return {}, text
    fm = {}
    for line in text[4:end].split('\n'):
        m = re.match(r'^([\w-]+):\s*(.*)$', line)
        if m:
            fm[m.group(1)] = yaml_value(m.group(2))
    return fm, text[end + 5:]


def aslist(v):
    if v is None or v == '':
        return []
    if isinstance(v, list):
        return [str(x) for x in v]
    return [str(v)]


def slugify(s):
    s = re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')
    return s or 'x'


# ---------------------------------------------------------------- markdown
class Markdown:
    """Renders the Markdown subset the wiki uses: ATX headings, paragraphs, -/1. lists (nested by indent),
    pipe tables, fenced + inline code, blockquotes, bold/italic, [[wikilinks]], [text](url), bare URLs."""
    WIKILINK = re.compile(r'\[\[([^\]|#]+)(?:#([^\]|]*))?(?:\|([^\]]*))?\]\]')
    CODE = re.compile(r'(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)')  # `x`, or ``x ` y`` for literal backticks
    MDLINK = re.compile(r'\[([^\]]+)\]\(([^)\s]+)\)')
    URL = re.compile(r'(?<![\w"\'>=/])(https?://[^\s<>()\[\]]+?)(?=[.,;:!?\'"]*(?:\s|$))')
    BOLD = re.compile(r'\*\*(.+?)\*\*')
    ITALIC = re.compile(r'(?<![\w*\\])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])')
    UNV = re.compile(r'\((unverified[^()]*)\)')
    CITE = re.compile(r'\((sources?:\s[^()]*)\)')
    HEADING = re.compile(r'^(#{1,6})\s+(.*?)\s*#*\s*$')
    ULI = re.compile(r'^(\s*)[-*+]\s+(.*)$')
    OLI = re.compile(r'^(\s*)\d+[.)]\s+(.*)$')
    HR = re.compile(r'^\s*([-*_])(\s*\1){2,}\s*$')
    TABLE_SEP = re.compile(r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$')

    def __init__(self, resolver):
        self.resolver = resolver  # slug -> Page or None

    def render(self, md):
        self.headings, self.links, self.ids = [], [], set()
        return self.blocks(md.split('\n')), self.headings, self.links

    # -- blocks
    def is_block_start(self, l):
        return (self.HEADING.match(l) or l.startswith('```') or l.lstrip().startswith('|') or l.startswith('>')
                or self.ULI.match(l) or self.OLI.match(l) or self.HR.match(l))

    def blocks(self, lines):
        out, i, n = [], 0, len(lines)
        while i < n:
            l = lines[i]
            if not l.strip():
                i += 1; continue
            if l.startswith('```'):
                lang = l[3:].strip(); j = i + 1; buf = []
                while j < n and not lines[j].startswith('```'):
                    buf.append(lines[j]); j += 1
                cls = f' class="lang-{esc(lang)}"' if lang else ''
                out.append(f'<pre><code{cls}>{esc(chr(10).join(buf))}</code></pre>')
                i = j + 1; continue
            m = self.HEADING.match(l)
            if m:
                level, text = len(m.group(1)), m.group(2)
                plain = plain_inline(text); hid = self.uid(slugify(plain))
                self.headings.append((level, plain, hid))
                out.append(f'<h{level} id="{hid}">{self.inline(text)}<a class="hl" href="#{hid}">#</a></h{level}>')
                i += 1; continue
            if l.lstrip().startswith('|') and i + 1 < n and self.TABLE_SEP.match(lines[i + 1]):
                head = self.split_row(l)
                aligns = []
                for c in self.split_row(lines[i + 1]):
                    c = c.strip()
                    aligns.append('center' if c.startswith(':') and c.endswith(':') else 'right' if c.endswith(':') else 'left' if c.startswith(':') else '')
                j = i + 2; rows = []
                while j < n and lines[j].lstrip().startswith('|'):
                    rows.append(self.split_row(lines[j])); j += 1
                out.append(self.table(head, aligns, rows))
                i = j; continue
            if l.startswith('>'):
                j = i; buf = []
                while j < n and lines[j].startswith('>'):
                    buf.append(re.sub(r'^>\s?', '', lines[j])); j += 1
                out.append(f'<blockquote>{self.blocks(buf)}</blockquote>')
                i = j; continue
            if self.HR.match(l):
                out.append('<hr>'); i += 1; continue
            if self.ULI.match(l) or self.OLI.match(l):
                h, i = self.parse_list(lines, i)
                out.append(h); continue
            j = i; buf = [l]; j += 1
            while j < n and lines[j].strip() and not self.is_block_start(lines[j]):
                buf.append(lines[j]); j += 1
            out.append(f'<p>{self.inline(" ".join(x.strip() for x in buf))}</p>')
            i = j
        return '\n'.join(out)

    def parse_list(self, lines, i):
        items, n = [], len(lines)
        while i < n:
            l = lines[i]
            mu, mo = self.ULI.match(l), self.OLI.match(l)
            m = mu or mo
            if m:
                items.append([len(m.group(1).expandtabs(4)), mo is not None and mu is None, m.group(2)]); i += 1
            elif l.strip() and items and (l.startswith('  ') or l.startswith('\t')) and not self.is_block_start(l.lstrip()):
                items[-1][2] += ' ' + l.strip(); i += 1
            else:
                break
        h, _ = self.build_list(items, 0, len(items))
        return h, i

    def build_list(self, items, i, end):
        base, ordered = items[i][0], items[i][1]
        tag = 'ol' if ordered else 'ul'
        parts = [f'<{tag}>']
        while i < end and items[i][0] >= base:
            if items[i][0] > base and len(parts) > 1:
                sub, i = self.build_list(items, i, end)
                parts[-1] = parts[-1][:-5] + sub + '</li>'
                continue
            parts.append(f'<li>{self.inline(items[i][2])}</li>'); i += 1
        parts.append(f'</{tag}>')
        return ''.join(parts), i

    def split_row(self, line):
        s = line.strip()
        if s.startswith('|'): s = s[1:]
        if s.endswith('|') and not s.endswith('\\|'): s = s[:-1]
        cells, cur, code, j = [], [], False, 0
        while j < len(s):
            c = s[j]
            if c == '`':
                code = not code; cur.append(c)
            elif c == '\\' and j + 1 < len(s) and s[j + 1] == '|':
                cur.append('|'); j += 1
            elif c == '|' and not code:
                cells.append(''.join(cur).strip()); cur = []
            else:
                cur.append(c)
            j += 1
        cells.append(''.join(cur).strip())
        return cells

    def table(self, head, aligns, rows):
        def td(tag, cells):
            out = []
            for k, c in enumerate(cells):
                a = aligns[k] if k < len(aligns) and aligns[k] else ''
                out.append(f'<{tag}{" style=\"text-align:" + a + "\"" if a else ""}>{self.inline(c)}</{tag}>')
            return ''.join(out)
        body = ''.join(f'<tr>{td("td", r)}</tr>' for r in rows)
        return f'<div class="tw"><table><thead><tr>{td("th", head)}</tr></thead><tbody>{body}</tbody></table></div>'

    def uid(self, base):
        hid, k = base, 2
        while hid in self.ids:
            hid = f'{base}-{k}'; k += 1
        self.ids.add(hid)
        return hid

    # -- inline
    def inline(self, s, nested=False):
        # `ph` must be shared with nested calls (mdlink re-enters inline for the link
        # label). A label can already hold a placeholder — `[`code`](url)` is substituted
        # by CODE before MDLINK — so a nested call with its own list indexes out of range.
        if not nested:
            self._ph = []
        ph = self._ph
        def keep(h):
            ph.append(h); return f'\x00{len(ph) - 1}\x00'
        s = self.CODE.sub(lambda m: keep(f'<code>{esc(code_body(m.group(2)))}</code>'), s)
        s = self.WIKILINK.sub(lambda m: keep(self.wikilink(m.group(1), m.group(2), m.group(3))), s)
        s = self.MDLINK.sub(lambda m: keep(self.mdlink(m.group(1), m.group(2))), s)
        s = self.URL.sub(lambda m: keep(f'<a class="ext" href="{esc(m.group(1))}">{esc(m.group(1))}</a>'), s)
        s = esc(s, quote=False)
        s = self.BOLD.sub(r'<strong>\1</strong>', s)
        s = self.ITALIC.sub(r'<em>\1</em>', s)
        s = self.UNV.sub(r'<span class="unv" title="model knowledge, not yet confirmed by a source">(\1)</span>', s)
        s = self.CITE.sub(r'<span class="cite">(\1)</span>', s)
        if nested:
            return s  # the top-level call expands the placeholders, including these
        for _ in range(4):
            if '\x00' not in s: break
            s = re.sub(r'\x00(\d+)\x00', lambda m: ph[int(m.group(1))], s)
        return s

    def mdlink(self, label, url):
        if url.startswith(R) or url.startswith('#') or not re.match(r'^[a-z]+:', url):
            return f'<a href="{esc(url)}">{self.inline(label, nested=True)}</a>'
        return f'<a class="ext" href="{esc(url)}">{self.inline(label, nested=True)}</a>'

    def wikilink(self, target, anchor, label):
        slug = target.strip()
        text = label.strip() if label and label.strip() else target.strip()
        self.links.append(slug)
        page = self.resolver(slug)
        a = f'#{slugify(anchor)}' if anchor else ''
        if page:
            return f'<a class="wl t-{page.type}" href="{R}{page.url}{a}" title="{esc(page.title)}">{esc(text)}</a>'
        return f'<a class="wl wanted" href="{R}wanted/{esc(slugify(slug))}.html" title="wanted page: {esc(slug)}">{esc(text)}</a>'


def code_body(c):
    return c[1:-1] if len(c) > 2 and c[0] == c[-1] == ' ' and c.strip() else c


def plain_inline(s):
    s = re.sub(r'\[\[([^\]|#]+)(?:#[^\]|]*)?\|([^\]]*)\]\]', r'\2', s)
    s = re.sub(r'\[\[([^\]|#]+)(?:#[^\]|]*)?\]\]', r'\1', s)
    s = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', s)
    return re.sub(r'[`*]', '', s).strip()


def plain_text(h):
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', h))).strip()


def excerpt_of(h, limit=220):
    m = re.search(r'<p>(.*?)</p>', h, re.S)
    t = plain_text(m.group(1)) if m else ''
    if len(t) > limit:
        t = t[:limit].rsplit(' ', 1)[0] + ' …'
    return t


def strip_h1(body):
    lines = body.lstrip('\n').split('\n')
    if lines and re.match(r'^#\s+', lines[0]):
        return '\n'.join(lines[1:])
    return body


# ---------------------------------------------------------------- pages
class Page:
    def __init__(self, path):
        self.path = path
        self.rel = os.path.relpath(path, ROOT)
        self.slug = os.path.splitext(os.path.basename(path))[0]
        self.folder = os.path.basename(os.path.dirname(path))
        text = open(path, encoding='utf-8').read()
        self.fm, self.body = parse_frontmatter(text)
        fm = self.fm
        self.title = str(fm.get('title') or self.slug)
        self.type = str(fm.get('type') or FOLDER_TYPE.get(self.folder, 'page'))
        self.kind = str(fm.get('kind', ''))
        self.facets = {f['key']: aslist(fm.get(f['key'])) for f in FACETS}
        self.tags = aslist(fm.get('tags'))
        self.aliases = aslist(fm.get('aliases'))
        self.sources = aslist(fm.get('sources'))
        self.created = str(fm.get('created', ''))
        self.updated = str(fm.get('updated', ''))
        self.deprecated = fm.get('deprecated') is True
        self.url = 'index.html' if self.slug == 'index' else f'wiki/{self.slug}.html'
        self.links, self.backlinks, self.headings = [], [], []
        self.html = self.text = self.excerpt = ''
        self.unverified = len(re.findall(r'\(unverified', self.body))
        self.words = len(self.body.split())


def load_pages():
    pages = {}
    for f in sorted(glob.glob(os.path.join(WIKI, '**', '*.md'), recursive=True)):
        p = Page(f)
        if p.slug in pages:
            print(f'warning: duplicate slug {p.slug}: {p.rel} and {pages[p.slug].rel}', file=sys.stderr)
        pages[p.slug] = p
    return pages


# ---------------------------------------------------------------- html helpers
def badge(text, cls=''):
    return f'<span class="badge {cls}">{esc(text)}</span>'


def facet_link(kind, value, label=None):
    return f'<a class="chip" href="{R}browse/{kind}-{slugify(value)}.html">{esc(label or value)}</a>'


def page_link(p, cls=''):
    return f'<a class="wl t-{p.type} {cls}" href="{R}{p.url}">{esc(p.title)}</a>'


def page_list(pages, show_type=True):
    if not pages:
        return '<p class="dim">nothing here yet.</p>'
    out = ['<ul class="plist">']
    for p in pages:
        b = (badge(p.kind or p.type, 't-' + p.type) if show_type else '')
        out.append(f'<li>{page_link(p)} {b}<span class="ex">{esc(p.excerpt)}</span></li>')
    out.append('</ul>')
    return ''.join(out)


def meta_strip(p, pages, raw_url):
    bits = [badge(p.type, 't-' + p.type)]
    if p.kind: bits.append(facet_link('kind', p.kind, p.kind))
    for f in FACETS:
        for v in p.facets[f['key']]: bits.append(facet_link(f['key'], v, f['values'].get(v, v)))
    for t in p.tags: bits.append(facet_link('tag', t, '#' + t))
    rows = [f'<div class="mrow">{" ".join(bits)}</div>']
    if p.aliases:
        rows.append(f'<div class="mrow"><span class="mk">aliases</span> {esc(", ".join(p.aliases))}</div>')
    if p.sources:
        ls = [page_link(pages[s]) if s in pages else f'<a class="wl wanted" href="{R}wanted/{esc(s)}.html">{esc(s)}</a>' for s in p.sources]
        rows.append(f'<div class="mrow"><span class="mk">sources</span> {" · ".join(ls)}</div>')
    if p.type == 'summary':
        for key, label in (('author', 'author'), ('date', 'date'), ('article', 'article')):
            if p.fm.get(key):
                rows.append(f'<div class="mrow"><span class="mk">{label}</span> {esc(str(p.fm[key]))}</div>')
        if p.fm.get('source-path'):
            sp = str(p.fm['source-path'])
            def repl(m):
                u = raw_url(m.group(0))
                return f'<a class="rawl" href="{R}{u}">{esc(m.group(0))}</a>' if u else f'<code>{esc(m.group(0))}</code>'
            rows.append(f'<div class="mrow"><span class="mk">source file</span> {re.sub(r"raw/[\w./-]+", repl, esc(sp))}</div>')
        if p.fm.get('source-url'):
            u = str(p.fm['source-url'])
            link = f'<a class="ext" href="{esc(u)}">{esc(u)}</a>' if re.match(r'^https?://\S+$', u) else f'<code>{esc(u)}</code>'
            rows.append(f'<div class="mrow"><span class="mk">source url</span> {link}</div>')
    dates = ' · '.join(x for x in (f'created {p.created}' if p.created else '', f'updated {p.updated}' if p.updated else '') if x)
    if dates:
        rows.append(f'<div class="mrow dim">{esc(dates)}</div>')
    return f'<div class="meta">{"".join(rows)}</div>'


def toc_html(headings):
    hs = [h for h in headings if h[0] in (2, 3)]
    if len(hs) < 2:
        return ''
    items = ''.join(f'<li class="l{lv}"><a href="#{hid}">{esc(t)}</a></li>' for lv, t, hid in hs)
    return f'<nav class="toc"><h4>On this page</h4><ul>{items}</ul></nav>'


# ---------------------------------------------------------------- layout
def client_config():
    """What app.js / graph.js need to know about this wiki."""
    return {'facets': [f['key'] for f in FACETS], 'types': TYPE_ORDER,
            'tocs': {t['id']: {'label': t['label'], 'nav': t['nav']} for t in TOCS}}


def search_placeholder():
    if CFG.get('search_placeholder'):
        return CFG['search_placeholder']
    bits = ['pages'] + (['cheat sheets'] if CHEAT else []) + [t['nav'] + ' articles' for t in TOCS]
    return 'search ' + ', '.join(bits) + '…'


def search_help():
    parts = ['filters: ' + ' '.join(f'<code>type:{esc(t)}</code>' for t in TYPE_ORDER + [tc['id'] for tc in TOCS])]
    kinds = [k['id'] for t in TYPES for k in t['kinds']][:3]
    if kinds:
        parts.append(' '.join(f'<code>kind:{esc(k)}</code>' for k in kinds) + ' …')
    for f in FACETS:
        vals = list(f['values'].keys())[:3]
        parts.append(' '.join(f'<code>{esc(f["key"])}:{esc(v)}</code>' for v in vals) if vals else f'<code>{esc(f["key"])}:…</code>')
    parts.append('<code>tag:…</code>')
    if CFG.get('search_help'):
        parts.append(CFG['search_help'])
    parts.append('<kbd>↑</kbd><kbd>↓</kbd> <kbd>enter</kbd>')
    return ' · '.join(parts)


class Site:
    def __init__(self, out):
        self.out = out
        self.written = 0

    def write(self, rel, content):
        path = os.path.join(self.out, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        depth = rel.count('/')
        if rel.endswith('.html'):
            content = content.replace(R, '../' * depth)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        self.written += 1

    def layout(self, title, body, rail='', cls='', active='', head='', stats=None):
        nav = [('index.html', 'Home'), ('graph.html', 'Graph')] + ([('cheatsheets.html', 'Cheat sheets')] if CHEAT else []) + [('browse.html', 'Browse')]
        nav += [(t['url'], t['nav']) for t in TOCS] + [('sources.html', 'Sources'), ('health.html', 'Health'), ('wiki/log.html', 'Log')]
        navh = ''.join(f'<a href="{R}{u}" class="{"on" if u == active else ""}">{l}</a>' for u, l in nav)
        railh = f'<aside class="rail">{rail}</aside>' if rail else ''
        shell_cls = 'shell' if rail else 'shell norail'
        return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)} · {SITE}</title>
<link rel="stylesheet" href="{R}assets/style.css">
<link rel="stylesheet" href="{R}assets/types.css">
<script>window.ROOT="{R}";window.WIKI_CFG={json.dumps(client_config())};</script>
{head}
</head>
<body class="{cls}">
<header class="top">
  <a class="logo" href="{R}index.html"><span class="mark">{esc(CFG.get('mark') or SITE.upper())}</span><span class="sub">llm wiki · {self.stats["pages"]} pages</span></a>
  <nav class="topnav">{navh}<a href="#" id="random" title="random page">Random</a></nav>
  <button class="sbtn" id="sopen" type="button">search <kbd>/</kbd></button>
</header>
<div class="{shell_cls}">
  <aside class="side">{self.sidebar}</aside>
  <main class="main">{body}</main>
  {railh}
</div>
<div id="search" class="overlay" hidden>
  <div class="sbox">
    <div class="srow">
      <input id="q" type="search" placeholder="{esc(search_placeholder())}" autocomplete="off" spellcheck="false">
      <label class="qopt" title="also search the full text of every raw source (loads ~9 MB once)"><input type="checkbox" id="qraw"> raw sources</label>
      <button id="qclose" type="button" title="close">esc</button>
    </div>
    <div id="qhelp" class="qhelp">{search_help()}</div>
    <div id="qres" class="qres"></div>
  </div>
</div>
<footer class="foot">built {self.stats["built"]} · {self.stats["pages"]} pages · {self.stats["links"]} links · {self.stats["wanted"]} wanted · plain Markdown + [[wikilinks]] rendered by <code>tools/build-site.py</code></footer>
<script src="{R}graph-data.js" defer></script>
<script src="{R}assets/graph.js" defer></script>
<script src="{R}assets/app.js" defer></script>
</body>
</html>
'''


def build_sidebar(pages):
    def group(name, items, key):
        if not items: return ''
        lis = ''.join(f'<li><a data-slug="{esc(p.slug)}" class="t-{p.type}" href="{R}{p.url}">{esc(p.title)}</a></li>'
                      for p in sorted(items, key=lambda p: p.title.lower()))
        return f'<details class="grp" data-grp="{key}"><summary>{esc(name)} <span class="n">{len(items)}</span></summary><ul>{lis}</ul></details>'
    ps = [p for p in pages.values() if p.slug not in ('index', 'log')]
    out = ['<div class="side-in"><input class="side-filter" type="search" placeholder="filter pages…" spellcheck="false">']
    for t in TYPES:
        tps = [p for p in ps if p.type == t['id']]
        if t['kinds']:
            order = [k['id'] for k in t['kinds']]
            kinds = order + sorted({p.kind for p in tps} - set(order))
            for k in kinds:
                out.append(group(KIND_LABEL.get(k, (k.title() + 's') if k else 'Other ' + t['plural']), [p for p in tps if p.kind == k], f'kind-{k or "none"}'))
        else:
            out.append(group(t['label'], tps, t['id']))
    other = [p for p in ps if p.type not in TYPE_ORDER]
    out.append(group('Other pages', other, 'other'))
    explore = [('graph.html', 'Link graph')] + ([('cheatsheets.html', 'Cheat sheets')] if CHEAT else []) + [('browse.html', 'Browse by facet')]
    explore += [(t['url'], t['nav'] + ' articles') for t in TOCS]
    explore += [('sources.html', 'Raw sources'), ('wanted.html', 'Wanted pages'), ('health.html', 'Wiki health'), ('wiki/log.html', 'Log')]
    lis = ''.join(f'<li><a href="{R}{u}">{l}</a></li>' for u, l in explore)
    out.append(f'<details class="grp" data-grp="explore" open><summary>Explore</summary><ul>{lis}</ul></details>')
    out.append('</div>')
    return ''.join(out)


# ---------------------------------------------------------------- raw sources


class RawFile:
    def __init__(self, path):
        self.path = path
        self.rel = os.path.relpath(path, RAW).replace(os.sep, '/')
        self.collection = self.rel.split('/')[0]
        self.name = os.path.basename(path)
        self.size = os.path.getsize(path)
        self.is_pdf = self.name.lower().endswith('.pdf')
        self.url = f'raw/{self.rel}.html'
        self.copy_url = f'raw/{self.rel}'
        self.original = None   # RawFile of the CP437 original if this is a -utf8 copy
        self.utf8copy = None   # RawFile of the -utf8 copy if this is a CP437 original
        self.text = None
        self.encoding = ''
        self.title = self.name
        self.date = ''
        self.articles = []     # (line_no, anchor_id, num, title) for files whose collection defines article_pattern
        self.summaries = []    # pages whose source-path names this file

    def load(self):
        if self.is_pdf:
            return
        b = open(self.path, 'rb').read()
        try:
            self.text, self.encoding = b.decode('utf-8'), 'utf-8'
        except UnicodeDecodeError:
            self.text, self.encoding = b.decode('cp437'), 'cp437'
        self.text = self.text.replace('\r\n', '\n').replace('\r', '\n')


def collect_raw():
    files = {}
    for f in sorted(glob.glob(os.path.join(RAW, '**', '*'), recursive=True)):
        if os.path.isdir(f) or os.path.basename(f) == 'sources.md' or os.path.basename(f).startswith('.'):
            continue
        rf = RawFile(f)
        files[rf.rel] = rf
    for rf in files.values():
        m = re.match(r'^(.*)-utf8\.txt$', rf.name)
        if m:
            for cand in (m.group(1) + '.TXT', m.group(1) + '.txt', m.group(1)):
                orig = files.get(f'{rf.collection}/{cand}')
                if orig:
                    rf.original, orig.utf8copy = orig, rf
                    rf.title = orig.name
                    break
    dates = collections.defaultdict(dict)   # collection -> file name -> date, from a "dates_file" listed in wiki.json
    for coll, rc in RAWCOLL.items():
        df = files.get(f'{coll}/{rc.get("dates_file", "")}') if rc.get('dates_file') else None
        if df and rc.get('dates_pattern'):
            df.load()
            for m in re.finditer(rc['dates_pattern'], df.text or ''):
                dates[coll][m.group(1)] = m.group(2).strip()
    for rf in files.values():
        if rf.utf8copy:   # the CP437 original: only copied, the UTF-8 copy gets the page
            rf.url = rf.utf8copy.url
            continue
        rf.load()
        if rf.text is None:
            continue
        rc = RAWCOLL.get(rf.collection)
        if not rc:
            continue
        rf.date = dates[rf.collection].get(rf.name, '')
        if rc.get('title'):
            m = re.match(rc['name_pattern'], rf.name) if rc.get('name_pattern') else None
            n = (m.group(1).lstrip('0') or '0') if m else ''
            rf.title = rc['title'].format(n=n, name=rf.name) if (m or not rc.get('name_pattern')) else rf.name
            if rf.date: rf.title += f' — {rf.date}'
        if rc.get('article_pattern'):
            pat = re.compile(rc['article_pattern'])
            lines = rf.text.split('\n')
            start = None
            if rc.get('skip_until'):
                start = next((i for i, l in enumerate(lines[:200]) if re.search(rc['skip_until'], l, re.I)), None)
            seen = set()
            for i, l in enumerate(lines):
                if start is not None and i <= start:
                    continue
                m = pat.match(l)
                if not m:
                    continue
                g = m.groupdict()
                num = g.get('num') or (m.group(1) if m.re.groups >= 2 else None)
                title = g.get('title') or (m.group(2) if m.re.groups >= 2 else m.group(m.re.groups))
                title = re.sub(r'\s+', ' ', title or '').strip()
                aid = f'a{num}' if num else 's-' + slugify(title)
                if aid in seen:
                    aid = f'{aid}-{i}'
                seen.add(aid)
                rf.articles.append((i + 1, aid, num, title))
    return files


def raw_manifest():
    """Rows of raw/sources.md keyed by collection folder."""
    rows = {}
    p = os.path.join(RAW, 'sources.md')
    if not os.path.exists(p):
        return rows, ''
    text = open(p, encoding='utf-8').read()
    for line in text.split('\n'):
        if not line.startswith('|') or re.match(r'^\|\s*-', line) or line.startswith('| collection'):
            continue
        cells = Markdown(lambda s: None).split_row(line)
        if len(cells) < 4:
            continue
        m = re.search(r'raw/([\w-]+)/', cells[1])
        if m:
            rows[m.group(1)] = {'collection': cells[0], 'path': cells[1], 'origin': cells[2], 'fetched': cells[3],
                                'notes': cells[4] if len(cells) > 4 else ''}
    return rows, text


def render_raw_page(site, rf, files, manifest, md, pages):
    lines = rf.text.split('\n')
    anchors = {ln: aid for ln, aid, _, _ in rf.articles}
    out = []
    for i, l in enumerate(lines, 1):
        cls = 'l hd' if i in anchors else 'l'
        pre = f'<span id="{anchors[i]}" class="an"></span>' if i in anchors else ''
        out.append(f'{pre}<span id="L{i}" class="{cls}">{esc(l) or " "}</span>')
    pre = '<pre class="raw">' + '\n'.join(out) + '</pre>'
    man = manifest.get(rf.collection, {})
    meta = [f'<div class="mrow"><span class="mk">collection</span> <a href="{R}sources.html#{slugify(rf.collection)}">{esc(man.get("collection", rf.collection))}</a></div>']
    if man.get('origin'):
        meta.append(f'<div class="mrow"><span class="mk">origin</span> {md.inline(man["origin"])}</div>')
    enc = f'{rf.encoding}' + (f' copy of <code>{esc(rf.original.name)}</code> (CP437 original)' if rf.original else '')
    meta.append(f'<div class="mrow"><span class="mk">file</span> <code>raw/{esc(rf.rel)}</code> · {len(lines)} lines · {rf.size // 1024} KB · {enc}</div>')
    dl = [f'<a href="{R}{rf.copy_url}" download>download this file</a>']
    if rf.original:
        dl.append(f'<a href="{R}{rf.original.copy_url}" download>download the CP437 original</a>')
    meta.append(f'<div class="mrow"><span class="mk">download</span> {" · ".join(dl)}</div>')
    if rf.summaries:
        meta.append(f'<div class="mrow"><span class="mk">summarised in</span> {" · ".join(page_link(pages[s]) for s in rf.summaries)}</div>')
    # prev / next inside the collection
    sibs = [f for f in files.values() if f.collection == rf.collection and f.text is not None and not f.utf8copy]
    idx = sibs.index(rf)
    pn = []
    if idx > 0: pn.append(f'<a href="{R}{sibs[idx-1].url}">← {esc(sibs[idx-1].name)}</a>')
    if idx + 1 < len(sibs): pn.append(f'<a href="{R}{sibs[idx+1].url}">{esc(sibs[idx+1].name)} →</a>')
    pnh = f'<div class="pn">{" · ".join(pn)}</div>' if pn else ''
    rail = ''
    if rf.articles:
        items = ''.join(f'<li class="{"l3" if num else "l2"}"><a href="#{aid}">{esc((num + ". ") if num else "")}{esc(title)}</a></li>'
                        for ln, aid, num, title in rf.articles)
        rail += f'<nav class="toc"><h4>In this file</h4><ul>{items}</ul></nav>'
    if rf.summaries:
        rail += '<section class="bl"><h4>Summaries</h4><ul>' + ''.join(f'<li>{page_link(pages[s])}</li>' for s in rf.summaries) + '</ul></section>'
    body = f'''<article class="page rawpage">
<header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › <a href="{R}sources.html">Sources</a> › {esc(rf.collection)}</div>
<h1>{esc(rf.title)}</h1><div class="meta">{"".join(meta)}</div>{pnh}</header>
{pre}
<footer class="pf">{pnh}</footer></article>'''
    site.write(rf.url, site.layout(rf.title, body, rail=rail, cls='raw-view', active='sources.html'))


def render_pdf_page(site, rf, manifest, pages):
    man = manifest.get(rf.collection, {})
    sums = f'<div class="mrow"><span class="mk">summarised in</span> {" · ".join(page_link(pages[s]) for s in rf.summaries)}</div>' if rf.summaries else ''
    body = f'''<article class="page rawpage">
<header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › <a href="{R}sources.html">Sources</a> › {esc(rf.collection)}</div>
<h1>{esc(rf.name)}</h1><div class="meta">
<div class="mrow"><span class="mk">collection</span> <a href="{R}sources.html#{slugify(rf.collection)}">{esc(man.get("collection", rf.collection))}</a></div>
<div class="mrow"><span class="mk">file</span> <code>raw/{esc(rf.rel)}</code> · {rf.size // 1024} KB · PDF · <a href="{R}{rf.copy_url}">open</a> · <a href="{R}{rf.copy_url}" download>download</a></div>{sums}</div></header>
<iframe class="pdf" src="{R}{rf.copy_url}" title="{esc(rf.name)}"></iframe></article>'''
    site.write(rf.url, site.layout(rf.name, body, cls='raw-view', active='sources.html'))


# ---------------------------------------------------------------- inbox TOC tables (wiki.json "tocs")
def render_tocs(site, pages, files, md):
    """Every configured inbox table becomes a filterable, sortable page; its rows join the search index."""
    all_entries = []
    for tc in TOCS:
        p = os.path.join(ROOT, tc['file'])
        if not os.path.exists(p):
            continue
        text = open(p, encoding='utf-8').read()
        lines = text.split('\n')
        tstart = next((i for i, l in enumerate(lines) if l.startswith('|') and i + 1 < len(lines) and Markdown.TABLE_SEP.match(lines[i + 1])), None)
        intro_md = '\n'.join(lines[:tstart]) if tstart is not None else text
        intro, _, _ = md.render(strip_h1(intro_md))
        entries, rows, cols = [], [], []
        if tstart is not None:
            cols = [c.strip() for c in md.split_row(lines[tstart])]
            ci = {c.lower(): i for i, c in enumerate(cols)}
            def col(cells, name):
                i = ci.get(str(name).lower())
                return cells[i] if i is not None and i < len(cells) else ''
            has_skip = False
            for ri, l in enumerate(lines[tstart + 2:]):
                if not l.startswith('|'):
                    continue
                c = md.split_row(l)
                if len(c) < 2:
                    continue
                fcell, num = col(c, tc['file_column']), col(c, tc['num_column'])
                flags, summary, title = col(c, tc['flags_column']), col(c, tc['summary_column']), col(c, tc['title_column']) or c[0]
                rf = files.get(f'{tc["collection"]}/{fcell}') if tc['collection'] and fcell else None
                key = slugify(fcell) if fcell else str(ri)
                rid = f'r-{key}-{slugify(num) if num else ri}'
                anchor = ''
                if rf and num:
                    for ln, aid, n, t in rf.articles:
                        if n == num:
                            anchor = '#' + aid; break
                tds = []
                for i, cell in enumerate(c[:len(cols)] + [''] * max(0, len(cols) - len(c))):
                    name = cols[i].lower()
                    if name == tc['file_column'].lower() and rf:
                        tds.append(f'<td><a href="{R}{rf.url}">{esc(cell)}</a></td>')
                    elif name == tc['title_column'].lower() and rf:
                        tds.append(f'<td><a href="{R}{rf.url}{anchor}">{esc(cell)}</a></td>')
                    elif name == tc['flags_column'].lower():
                        tds.append('<td>' + ''.join(f'<span class="flag f-{slugify(f)}">{esc(f)}</span>' for f in cell.split()) + '</td>')
                    elif name == tc['summary_column'].lower():
                        tds.append(f'<td>{md.inline(cell) if cell else ""}</td>')
                    elif name == tc['num_column'].lower():
                        tds.append(f'<td class="num">{esc(cell)}</td>')
                    else:
                        tds.append(f'<td>{md.inline(cell) if cell else ""}</td>')
                if 'skip' in flags.split(): has_skip = True
                rows.append(f'<tr id="{rid}" data-flags="{esc(flags)}" data-ing="{"y" if summary else "n"}">{"".join(tds)}</tr>')
                meta = [col(c, m) for m in tc['meta_columns']] or [fcell, flags]
                entries.append({'id': f'{tc["id"]}:{rid}', 'url': f'{tc["url"]}#{rid}', 'raw': f'{rf.url}{anchor}' if rf else '',
                                'title': title, 'type': tc['id'], 'kind': '', 'meta': ' · '.join(x for x in meta if x),
                                'text': ' '.join(c), 'f': dict(tc['facets']), 'tags': [tc['id']], 'aliases': [], 'headings': [],
                                'ingested': bool(summary), 'star': bool(tc['star'] and tc['star'] in flags)})
        n_star = sum(1 for e in entries if e['star'])
        n_ing = sum(1 for e in entries if e['ingested'])
        fl = [(f['flag'], f.get('label', f['flag'])) if isinstance(f, dict) else (f, f) for f in tc['filters']]
        chips = '<button data-f="all" class="on">all</button>' + ''.join(f'<button data-f="{esc(a)}">{esc(b)}</button>' for a, b in fl)
        chips += '<button data-f="ingested">ingested</button><button data-f="open">not ingested</button>' + ('<button data-f="noskip">hide skip</button>' if has_skip else '')
        ths = ''.join(f'<th data-k="{i}">{esc(c)}</th>' for i, c in enumerate(cols))
        counts = f'{len(entries)} rows' + (f' · {n_star} {esc(tc["star"])} candidates' if tc['star'] and n_star else '') + f' · {n_ing} ingested'
        body = f'''<article class="page tocpage">
<header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › inbox</div><h1>{esc(tc['title'])}</h1>
<div class="meta"><div class="mrow">{badge("inbox", "t-inbox")} {counts} · source file <code>{esc(tc['file'])}</code></div></div></header>
<div class="body">{intro}</div>
<div class="tocctl">
  <input id="tocq" type="search" placeholder="filter rows…" spellcheck="false">
  <div class="chips">{chips}</div>
  <span id="tocn" class="dim"></span>
</div>
<div class="tw"><table id="toctab" class="toc-table"><thead><tr>{ths}</tr></thead><tbody>{"".join(rows)}</tbody></table></div>
</article>'''
        site.write(tc['url'], site.layout(tc['title'], body, cls='toc-view', active=tc['url']))
        tc['_stats'] = (len(entries), n_star, n_ing)
        all_entries.extend(entries)
    return all_entries


# ---------------------------------------------------------------- cheat sheets
def split_sections(h, level=2):
    """Split rendered HTML at headings of level <= `level`; deeper headings stay inside their section.
    Returns [(heading_text, id, chunk_html, heading_level)]; the first chunk may be an intro with level 0."""
    out = []
    for chunk in re.split(r'(?=<h[1-6] id=")', h):
        if not chunk.strip():
            continue
        m = re.match(r'<h([1-6]) id="([^"]+)">(.*?)<a class="hl"', chunk, re.S)
        lv = int(m.group(1)) if m else 0
        if m and lv > level and out:
            out[-1][2] += chunk
        else:
            out.append([plain_text(m.group(3)) if m else '', m.group(2) if m else '', chunk, lv])
    return [tuple(x) for x in out]


def tool_patterns(p):
    names = [p.title] + [a for a in p.aliases if not a.startswith('.') and len(a) >= 2]
    pats = []
    for n in names:
        if re.fullmatch(r'[\d ]+', n) or ' — ' in n:
            continue
        pats.append(re.compile(r'(?<![\w-])' + re.escape(n) + r'(?![\w-])', re.I))
    return pats


def build_cheatsheets(pages):
    if not CHEAT:
        return []
    tools = [p for p in pages.values() if p.type == CHEAT['type'] and (not CHEAT['kind'] or p.kind == CHEAT['kind'])]
    sheets = []
    g = CHEAT.get('generic')
    generic = {'slug': g['slug'], 'title': g['title'], 'page': None, 'own': [], 'tech': []} if g else None
    skip = {h.lower() for h in CHEAT['skip_headings']}
    for t in sorted(tools, key=lambda p: p.title.lower()):
        secs = split_sections(t.html, 2)
        own = [s[:3] for s in secs if s[0].lower().startswith(CHEAT['heading'].lower())]
        if not own:
            own = [s[:3] for s in secs if s[0] and s[0].lower() not in skip and not s[0].lower().startswith(tuple(CHEAT['skip_prefixes']))]
        sheets.append({'slug': t.slug, 'title': t.title, 'page': t, 'own': own, 'tech': [], 'pats': tool_patterns(t)})
    for tp in sorted((p for p in pages.values() if p.type == CHEAT['section_type']), key=lambda p: p.title.lower()):
        for htxt, hid, chunk, lv in split_sections(tp.html, 3):
            if lv != 3:
                continue
            hit = False
            for s in sheets:
                if any(r.search(htxt) for r in s['pats']):
                    s['tech'].append((tp, htxt, hid, chunk)); hit = True
            if not hit and generic and g.get('match') and re.search(g['match'], htxt, re.I):
                generic['tech'].append((tp, htxt, hid, chunk))
    sheets = [s for s in sheets if s['tech'] or any('<table' in c or '<pre>' in c for _, _, c in s['own'])]
    if generic and generic['tech']:
        sheets.append(generic)
    return sheets


def sheet_html(s):
    out = []
    if s['own']:
        out.append('<div class="cs-part"><h2 class="cs-h">Reference</h2>')
        for htxt, hid, chunk in s['own']:
            out.append(chunk)
        out.append('</div>')
    if s['tech']:
        out.append('<div class="cs-part"><h2 class="cs-h">Techniques</h2>')
        for tp, htxt, hid, chunk in s['tech']:
            chunk = re.sub(r'^<h3 id="[^"]+">.*?</h3>', '', chunk, count=1, flags=re.S)
            out.append(f'<div class="cs-tech"><h3 class="cs-t">{page_link(tp)} <span class="dim">› {esc(htxt)}</span> <a class="hl" href="{R}{tp.url}#{hid}">#</a></h3>{chunk}</div>')
        out.append('</div>')
    return ''.join(out)


def cheat_subject():
    return CHEAT['kind'] or TYPE_BY_ID.get(CHEAT['type'], {}).get('id', 'page')


def cheat_description():
    st = TYPE_BY_ID.get(CHEAT['section_type'], {}).get('id', CHEAT['section_type'])
    return (f'The reference tables from every {cheat_subject()} page plus the per-{cheat_subject()} ### sections of every {st} page, '
            f'collected by {cheat_subject()}. Pick one, or open the standalone version to print it.')


def render_cheatsheets(site, sheets):
    tabs = ''.join(f'<button data-cs="{esc(s["slug"])}" class="{"on" if i == 0 else ""}">{esc(s["title"])}</button>' for i, s in enumerate(sheets))
    secs = []
    for i, s in enumerate(sheets):
        head = (f'<h1>{page_link(s["page"])} <span class="dim">cheat sheet</span></h1>' if s['page'] else f'<h1>{esc(s["title"])} <span class="dim">cheat sheet</span></h1>')
        secs.append(f'<section class="cs" id="cs-{esc(s["slug"])}" {"" if i == 0 else "hidden"}>{head}<div class="cs-links"><a href="{R}cheatsheet/{esc(s["slug"])}.html">standalone / print version</a></div>{sheet_html(s)}</section>')
    body = f'''<article class="page cspage">
<header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › cheat sheets</div><h1>Cheat sheets</h1>
<p class="dim">{esc(CHEAT.get('description') or cheat_description())}</p></header>
<div class="cstabs">{tabs}<button id="csprint" class="alt" type="button">print current</button></div>
{"".join(secs)}</article>'''
    site.write('cheatsheets.html', site.layout('Cheat sheets', body, cls='cs-view', active='cheatsheets.html'))
    for s in sheets:
        head = (f'<h1>{esc(s["title"])} <span class="dim">cheat sheet</span></h1><p class="dim">From {page_link(s["page"])}' if s['page'] else f'<h1>{esc(s["title"])} <span class="dim">cheat sheet</span></h1><p class="dim">Sections that name no specific {esc(cheat_subject())}')
        body = f'<article class="page cspage standalone"><header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › <a href="{R}cheatsheets.html">cheat sheets</a></div>{head} · <a href="#" onclick="window.print();return false">print</a> · built {site.stats["built"]}</p></header>{sheet_html(s)}</article>'
        site.write(f'cheatsheet/{s["slug"]}.html', site.layout(s['title'] + ' cheat sheet', body, cls='cs-view cs-standalone', active='cheatsheets.html'))


# ---------------------------------------------------------------- build
def build(out):
    t0 = time.time()
    pages = load_pages()
    md = Markdown(lambda s: pages.get(s))
    for p in pages.values():
        p.html, p.headings, links = md.render(strip_h1(p.body))
        seen = set(); p.links = []
        for l in links:
            if l != p.slug and l not in seen:
                seen.add(l); p.links.append(l)
        p.text = plain_text(p.html)
        p.excerpt = excerpt_of(p.html)
    wanted = collections.defaultdict(list)
    for p in pages.values():
        for l in p.links:
            if l in pages:
                if p.slug not in ('index', 'log'):
                    pages[l].backlinks.append(p.slug)
            else:
                wanted[l].append(p.slug)
    files = collect_raw()
    manifest, manifest_md = raw_manifest()
    for p in pages.values():
        if p.type == 'summary' and p.fm.get('source-path'):
            for m in re.finditer(r'raw/([\w./-]+)', str(p.fm['source-path'])):
                rf = files.get(m.group(1).rstrip('.'))
                if rf and p.slug not in rf.summaries:
                    rf.summaries.append(p.slug)
                    if rf.utf8copy and p.slug not in rf.utf8copy.summaries:
                        rf.utf8copy.summaries.append(p.slug)

    def raw_url(path):
        rf = files.get(re.sub(r'^raw/', '', path).rstrip('.'))
        return rf.url if rf else ''

    final_out, out = out, out.rstrip('/\\') + '.building'   # build next to the target, swap at the end
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    site = Site(out)
    n_links = sum(len(p.links) for p in pages.values())
    site.stats = {'pages': len(pages), 'links': n_links, 'wanted': len(wanted), 'built': datetime.date.today().isoformat()}
    site.sidebar = build_sidebar(pages)
    shutil.copytree(ASSETS, os.path.join(out, 'assets'))

    # -- graph data (index and log excluded: they link to everything)
    nodes, nid, glinks = [], {}, set()
    for p in pages.values():
        if p.slug in ('index', 'log'):
            continue
        nid[p.slug] = len(nodes)
        nodes.append({'id': p.slug, 'title': p.title, 'type': p.type, 'kind': p.kind, 'url': p.url, 'deg': 0})
    for w in sorted(wanted):
        nid[w] = len(nodes)
        nodes.append({'id': w, 'title': w, 'type': 'wanted', 'kind': '', 'url': f'wanted/{slugify(w)}.html', 'deg': 0})
    for p in pages.values():
        if p.slug in ('index', 'log'):
            continue
        for l in p.links:
            if l in nid and l != p.slug:
                glinks.add(tuple(sorted((nid[p.slug], nid[l]))))
    for a, b in glinks:
        nodes[a]['deg'] += 1; nodes[b]['deg'] += 1
    gtypes = [{'id': t['id'], 'label': t['label'], 'color': t['color']} for t in TYPES]
    site.write('graph-data.js', 'window.GRAPH=' + json.dumps({'nodes': nodes, 'links': sorted(glinks), 'types': gtypes}, ensure_ascii=False) + ';\n')
    site.write('assets/types.css', types_css())

    # -- wiki pages
    for p in pages.values():
        tcrumb = f'<a href="{R}browse/type-{p.type}.html">{esc(p.type)}</a>' if p.type in TYPE_ORDER else esc(p.type)
        crumbs = f'<div class="crumbs"><a href="{R}index.html">Home</a> › {tcrumb}' + (f' › <a href="{R}browse/kind-{slugify(p.kind)}.html">{esc(p.kind)}</a>' if p.kind else '') + '</div>'
        dep = '<p class="warn">This page is deprecated; follow the link to its replacement.</p>' if p.deprecated else ''
        if p.slug == 'index':
            render_home(site, p, pages, files, wanted); continue
        rail = toc_html(p.headings)
        bl = sorted((pages[b] for b in set(p.backlinks)), key=lambda x: x.title.lower())
        rail += f'<section class="bl"><h4>Backlinks <span class="n">{len(bl)}</span></h4>' + (('<ul>' + ''.join(f'<li>{page_link(b)}</li>' for b in bl) + '</ul>') if bl else '<p class="dim">no page links here yet.</p>') + '</section>'
        if p.slug in nid:
            rail += f'<section class="mg"><h4>Local graph</h4><canvas class="minigraph" data-focus="{esc(p.slug)}" width="260" height="220"></canvas><div class="mgcap"></div><a class="dim" href="{R}graph.html?focus={esc(p.slug)}">open in the full graph →</a></section>'
        unv = f' · <span class="unv">{p.unverified} unverified</span>' if p.unverified else ''
        body = f'''<article class="page t-{p.type}">
<header class="ph">{crumbs}<h1>{esc(p.title)}</h1>{meta_strip(p, pages, raw_url)}{dep}</header>
<div class="body">{p.html}</div>
<footer class="pf">source file <code class="path">{esc(p.rel)}</code>{unv} · <a href="{R}graph.html?focus={esc(p.slug)}">graph</a></footer>
</article>'''
        site.write(p.url, site.layout(p.title, body, rail=rail, cls=f'wiki-view t-{p.type}', active='wiki/log.html' if p.slug == 'log' else ''))

    # -- wanted pages
    wl = sorted(wanted.items(), key=lambda kv: (-len(kv[1]), kv[0]))
    rows = ''.join(f'<tr><td><a class="wl wanted" href="{R}wanted/{slugify(w)}.html">{esc(w)}</a></td><td class="num">{len(refs)}</td><td>{" · ".join(page_link(pages[r]) for r in sorted(set(refs)))}</td></tr>' for w, refs in wl)
    body = f'''<article class="page"><header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › wanted</div><h1>Wanted pages</h1>
<p class="dim">Red links: pages that are linked but do not exist yet. Ingest a source that covers them to fill them in.</p></header>
<div class="tw"><table><thead><tr><th>slug</th><th>links</th><th>linked from</th></tr></thead><tbody>{rows}</tbody></table></div></article>'''
    site.write('wanted.html', site.layout('Wanted pages', body, active='wanted.html'))
    for w, refs in wl:
        body = f'''<article class="page wanted-page"><header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › <a href="{R}wanted.html">wanted</a></div><h1><span class="wl wanted">{esc(w)}</span></h1>
<div class="meta"><div class="mrow">{badge("wanted page", "t-wanted")} no page with this slug exists yet</div></div></header>
<p>This slug is linked from {len(set(refs))} page{"s" if len(set(refs)) != 1 else ""} but has not been written. To create it, ingest a source that covers it (<code>ingest &lt;url or path&gt;</code>) or ask the maintainer to write <code>wiki/…/{esc(w)}.md</code>.</p>
<h2>Linked from</h2>{page_list(sorted((pages[r] for r in set(refs)), key=lambda x: x.title.lower()))}</article>'''
        site.write(f'wanted/{slugify(w)}.html', site.layout(w + ' (wanted)', body, active='wanted.html'))

    # -- browse / facets
    facets = {'type': collections.defaultdict(list), 'kind': collections.defaultdict(list), 'tag': collections.defaultdict(list)}
    for fc in FACETS: facets[fc['key']] = collections.defaultdict(list)
    for p in pages.values():
        if p.slug in ('index', 'log'):
            continue
        facets['type'][p.type].append(p)
        if p.kind: facets['kind'][p.kind].append(p)
        for fc in FACETS:
            for x in p.facets[fc['key']]: facets[fc['key']][x].append(p)
        for x in p.tags: facets['tag'][x].append(p)
    labels = {'type': lambda v: TYPE_LABEL.get(v, v), 'kind': lambda v: KIND_LABEL.get(v, v), 'tag': lambda v: '#' + v}
    for fc in FACETS: labels[fc['key']] = (lambda vals: (lambda v: vals.get(v, v)))(fc['values'])
    kinded = ', '.join(t['label'] for t in TYPES if t['kinds'])
    order = [('type', 'Page types')] + ([('kind', f'Kinds of {kinded}')] if kinded else []) + [(fc['key'], fc['label']) for fc in FACETS] + [('tag', 'Tags')]
    secs = []
    for f, title in order:
        vals = sorted(facets[f].items(), key=lambda kv: (-len(kv[1]), kv[0]))
        chips = ''.join(f'<a class="chip big" href="{R}browse/{f}-{slugify(v)}.html">{esc(labels[f](v))} <span class="n">{len(ps)}</span></a>' for v, ps in vals)
        secs.append(f'<section><h2 id="{f}">{title}</h2><div class="chips">{chips}</div></section>')
        for v, ps in vals:
            body = f'''<article class="page"><header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › <a href="{R}browse.html">browse</a> › {f}</div><h1>{esc(labels[f](v))}</h1>
<div class="meta"><div class="mrow">{badge(f)} {len(ps)} page{"s" if len(ps) != 1 else ""}</div></div></header>{page_list(sorted(ps, key=lambda x: (TYPE_ORDER.index(x.type) if x.type in TYPE_ORDER else 9, x.title.lower())))}</article>'''
            site.write(f'browse/{f}-{slugify(v)}.html', site.layout(labels[f](v), body, active='browse.html'))
    fkeys = ' '.join(f'<code>{esc(f)}:</code>' for f, _ in order)
    body = f'<article class="page"><header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › browse</div><h1>Browse</h1><p class="dim">Every page grouped by frontmatter facet. Use {fkeys} in the search box to combine them.</p></header>{"".join(secs)}</article>'
    site.write('browse.html', site.layout('Browse', body, active='browse.html'))

    # -- raw sources
    for rf in files.values():
        dst = os.path.join(out, 'raw', rf.rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(rf.path, dst)
        if rf.is_pdf:
            render_pdf_page(site, rf, manifest, pages)
        elif rf.text is not None and not rf.utf8copy:
            render_raw_page(site, rf, files, manifest, md, pages)
    man_html, _, _ = md.render(strip_h1(manifest_md)) if manifest_md else ('', [], [])
    colls = collections.defaultdict(list)
    for rf in files.values():
        colls[rf.collection].append(rf)
    csecs = []
    for c, fs in sorted(colls.items()):
        man = manifest.get(c, {})
        lis = []
        for rf in sorted(fs, key=lambda x: x.name):
            if rf.utf8copy:
                continue
            extra = f' <span class="dim">— {esc(rf.date)}</span>' if rf.date else ''
            extra += f' <span class="dim">· {rf.size // 1024} KB</span>'
            extra += f' · {" · ".join(page_link(pages[s]) for s in rf.summaries)}' if rf.summaries else ''
            lis.append(f'<li><a href="{R}{rf.url}">{esc(rf.title)}</a>{extra}</li>')
        csecs.append(f'<section><h2 id="{slugify(c)}">{esc(man.get("collection", c))} <span class="dim">raw/{esc(c)}/</span></h2>' + (f'<p class="dim">{md.inline(man.get("origin", ""))}{(" · fetched " + esc(man["fetched"])) if man.get("fetched") else ""}{(" · " + md.inline(man["notes"])) if man.get("notes") else ""}</p>' if man else '') + f'<ul class="files">{"".join(lis)}</ul></section>')
    n_raw = sum(1 for rf in files.values() if not rf.utf8copy)
    body = f'<article class="page"><header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › sources</div><h1>Raw sources</h1><div class="meta"><div class="mrow">{badge("raw")} {n_raw} files in {len(colls)} collections · immutable originals · tick <em>raw sources</em> in the search box to search their full text</div></div></header><div class="body">{man_html}</div>{"".join(csecs)}</article>'
    site.write('sources.html', site.layout('Raw sources', body, active='sources.html'))

    # -- inbox TOC tables
    tw_entries = render_tocs(site, pages, files, md)

    # -- cheat sheets
    sheets = build_cheatsheets(pages)
    if CHEAT:
        render_cheatsheets(site, sheets)

    # -- graph page
    legend = ''.join(f'<label><input type="checkbox" data-t="{t}" checked> <span class="sw t-{t}"></span>{esc(TYPE_LABEL.get(t, t).lower())}</label>' for t in TYPE_ORDER + ['wanted'])
    body = f'''<article class="page graphpage"><header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › graph</div><h1>Link graph</h1>
<p class="dim">Every <code>[[wikilink]]</code> between pages (index and log excluded). Drag nodes, scroll to zoom, drag the background to pan, click a node to open it, double-click to focus on its neighbourhood.</p></header>
<div class="gctl"><div class="legend">{legend}</div>
<input id="gq" type="search" placeholder="highlight…" spellcheck="false">
<label>focus <input id="gfocus" type="text" placeholder="slug" spellcheck="false"></label>
<label>depth <select id="gdepth"><option>1</option><option selected>2</option><option>3</option></select></label>
<button id="gclear" type="button" class="alt">whole wiki</button>
<label class="qopt"><input type="checkbox" id="glabels" checked> labels</label>
<span id="gn" class="dim"></span></div>
<canvas id="graph" class="biggraph"></canvas>
<div id="gtip" class="gtip" hidden></div></article>'''
    site.write('graph.html', site.layout('Link graph', body, cls='graph-view', active='graph.html'))

    # -- health
    render_health(site, pages, wanted, files, tw_entries)

    # -- search index
    idx = []
    for p in pages.values():
        if p.slug == 'index':
            continue
        fvals = [v for f in FACETS for v in p.facets[f['key']]]
        idx.append({'id': p.slug, 'url': p.url, 'title': p.title, 'type': p.type, 'kind': p.kind, 'f': p.facets,
                    'tags': p.tags, 'aliases': p.aliases, 'headings': [h[1] for h in p.headings], 'text': p.text,
                    'meta': ' · '.join(x for x in ([p.kind] if p.kind else []) + fvals + [('#' + t) for t in p.tags[:4]])})
    for w, refs in wl:
        idx.append({'id': w, 'url': f'wanted/{slugify(w)}.html', 'title': w, 'type': 'wanted', 'kind': '', 'f': {}, 'tags': [],
                    'aliases': [], 'headings': [], 'text': 'wanted page, linked from ' + ', '.join(sorted(set(refs))), 'meta': f'wanted · {len(set(refs))} links'})
    for s in sheets:
        idx.append({'id': 'cs:' + s['slug'], 'url': f'cheatsheet/{s["slug"]}.html', 'title': s['title'] + ' cheat sheet', 'type': 'cheatsheet', 'kind': '',
                    'f': s['page'].facets if s['page'] else {}, 'tags': [], 'aliases': [], 'headings': [h for h, _, _ in s['own']] + [h for _, h, _, _ in s['tech']],
                    'text': plain_text(sheet_html(s)), 'meta': 'cheat sheet'})
    idx.extend(tw_entries)
    site.write('search-index.js', 'window.SEARCH_INDEX=' + json.dumps(idx, ensure_ascii=False) + ';\n')
    ridx = []
    for rf in files.values():
        if rf.text is None or rf.utf8copy:
            continue
        paras, cur, start = [], [], 0
        for i, l in enumerate(rf.text.split('\n'), 1):
            if l.strip():
                if not cur: start = i
                cur.append(l.strip())
            elif cur:
                paras.append([start, ' '.join(cur)]); cur = []
        if cur: paras.append([start, ' '.join(cur)])
        ridx.append({'file': rf.rel, 'title': rf.title, 'url': rf.url, 'paras': paras})
    site.write('raw-index.js', 'window.RAW_INDEX=' + json.dumps(ridx, ensure_ascii=False) + ';\n')
    if os.path.isdir(final_out):
        shutil.rmtree(final_out)
    os.rename(out, final_out)
    out = final_out
    print(f'built {site.written} files into {os.path.relpath(out, ROOT)}/ in {time.time() - t0:.1f}s — {len(pages)} pages, {n_links} links, {len(wanted)} wanted, {n_raw} raw files, {len(tw_entries)} TOC rows, {len(sheets)} cheat sheets')


def render_home(site, p, pages, files, wanted):
    counts = collections.Counter(x.type for x in pages.values())
    n_raw = sum(1 for rf in files.values() if not rf.utf8copy)
    recent = sorted((x for x in pages.values() if x.slug not in ('index', 'log')), key=lambda x: (x.updated, x.title), reverse=True)[:8]
    tiles = ''.join(f'<a class="tile t-{t}" href="{R}browse/type-{t}.html"><b>{counts.get(t, 0)}</b>{esc(TYPE_PLURAL[t])}</a>' for t in TYPE_ORDER)
    tiles += f'<a class="tile" href="{R}sources.html"><b>{n_raw}</b>raw files</a><a class="tile" href="{R}wanted.html"><b>{len(wanted)}</b>wanted</a>'
    tag = f'<p class="tag">{esc(CFG["tagline"])}</p>' if CFG.get('tagline') else ''
    start = ([f'<li><a href="{R}cheatsheets.html">Cheat sheets</a> — the reference tables, one page per {esc(cheat_subject())}</li>'] if CHEAT else [])
    start += [f'<li><a href="{R}graph.html">Link graph</a> — how the pages connect</li>',
              f'<li><a href="{R}browse.html">Browse</a> — by type' + (', kind' if any(t['kinds'] for t in TYPES) else '') + ''.join(', ' + esc(f['label'].lower()) for f in FACETS) + ', tag</li>']
    start += [f'<li><a href="{R}{tc["url"]}">{esc(tc["nav"])}</a> — {tc.get("_stats", (0,))[0]} rows to pick ingests from</li>' for tc in TOCS]
    start += [f'<li><a href="{R}health.html">Wiki health</a> — wanted pages, unverified claims, stubs</li>']
    body = f'''<article class="page home">
<header class="hero"><h1>{esc(SITE)}</h1>{tag}
<button class="herosearch" id="sopen2" type="button">search the wiki… <kbd>/</kbd></button>
<div class="tiles">{tiles}</div></header>
<div class="cols"><div class="body">{p.html}</div>
<aside class="homeside"><h4>Recently updated</h4><ul>{"".join(f"<li>{page_link(x)} <span class='dim'>{esc(x.updated)}</span></li>" for x in recent)}</ul>
<h4>Start here</h4><ul>{"".join(start)}</ul></aside></div>
</article>'''
    site.write('index.html', site.layout('Home', body, cls='home-view', active='index.html'))


def render_health(site, pages, wanted, files, tw_entries):
    ps = [p for p in pages.values() if p.slug not in ('index', 'log')]
    counts = collections.Counter(p.type for p in ps)
    kinds = collections.Counter(p.kind for p in ps if p.kind)
    unv = sorted((p for p in ps if p.unverified), key=lambda p: -p.unverified)
    orphans = [p for p in ps if not p.backlinks]
    idx_text = pages['index'].body if 'index' in pages else ''
    missing = [p for p in ps if f'[[{p.slug}]]' not in idx_text and f'[[{p.slug}|' not in idx_text]
    stubs = sorted((p for p in ps if p.words < CFG['stub_words']), key=lambda p: p.words)
    recent = sorted(ps, key=lambda x: (x.updated, x.title), reverse=True)[:15]
    log = pages.get('log')
    log_secs = [x for x in split_sections(log.html, 2) if x[3] == 2][-5:] if log else []
    log_html = ''.join(c for _, _, c, _ in reversed(log_secs)) if log_secs else '<p class="dim">no log.</p>'
    toc_tiles = ''.join(f'<a class="tile" href="{R}{tc["url"]}"><b>{tc["_stats"][2]}/{tc["_stats"][1] or tc["_stats"][0]}</b>{esc(tc["nav"])} ingested</a>' for tc in TOCS if tc.get('_stats'))
    def plist(items):
        return ('<ul class="compact">' + ''.join(f'<li>{page_link(x)}</li>' for x in items) + '</ul>') if items else '<p class="dim">none.</p>'
    body = f'''<article class="page"><header class="ph"><div class="crumbs"><a href="{R}index.html">Home</a> › health</div><h1>Wiki health</h1>
<p class="dim">What <code>lint</code> looks at, computed at build time ({site.stats["built"]}). The maintainer fixes these by ingesting sources, not by editing pages by hand.</p></header>
<div class="tiles">{''.join(f'<a class="tile t-{t}" href="{R}browse/type-{t}.html"><b>{counts.get(t, 0)}</b>{esc(TYPE_PLURAL[t])}</a>' for t in TYPE_ORDER)}<a class="tile" href="{R}wanted.html"><b>{len(wanted)}</b>wanted pages</a><a class="tile"><b>{sum(p.unverified for p in ps)}</b>unverified claims</a><a class="tile"><b>{len(orphans)}</b>orphans</a>{toc_tiles}</div>
{('<h2>Kinds</h2><div class="chips">' + ''.join(f'<a class="chip big" href="{R}browse/kind-{slugify(k)}.html">{esc(KIND_LABEL.get(k, k))} <span class="n">{n}</span></a>' for k, n in kinds.most_common()) + '</div>') if kinds else ''}
<h2>Pages with unverified claims <span class="n">{len(unv)}</span></h2><p class="dim">Text marked <span class="unv">(unverified)</span> is model knowledge waiting for a source. Highest counts first.</p>
{('<ul class="compact">' + ''.join(f'<li>{page_link(p)} <span class="unv">{p.unverified}</span></li>' for p in unv) + '</ul>') if unv else '<p class="dim">none.</p>'}
<h2>Wanted pages <span class="n">{len(wanted)}</span></h2><p class="dim">Most-linked first — the best candidates for the next <code>ingest</code>.</p>
<ul class="compact">{''.join(f'<li><a class="wl wanted" href="{R}wanted/{slugify(w)}.html">{esc(w)}</a> <span class="n">{len(set(r))}</span></li>' for w, r in sorted(wanted.items(), key=lambda kv: (-len(set(kv[1])), kv[0])))}</ul>
<h2>Stubs <span class="n">{len(stubs)}</span></h2><p class="dim">Pages under {CFG['stub_words']} words of Markdown.</p>{('<ul class="compact">' + ''.join(f'<li>{page_link(p)} <span class="dim">{p.words} words</span></li>' for p in stubs) + '</ul>') if stubs else '<p class="dim">none.</p>'}
<h2>Orphans <span class="n">{len(orphans)}</span></h2><p class="dim">No inbound links except from the index or the log.</p>{plist(orphans)}
<h2>Missing from the index <span class="n">{len(missing)}</span></h2>{plist(missing)}
<h2>Recently updated</h2><ul class="compact">{''.join(f"<li>{page_link(x)} <span class='dim'>{esc(x.updated)}</span></li>" for x in recent)}</ul>
<h2>Latest log entries</h2><div class="body logtail">{log_html}</div><p><a href="{R}wiki/log.html">full log →</a></p>
</article>'''
    site.write('health.html', site.layout('Wiki health', body, active='health.html'))


# ---------------------------------------------------------------- serve / watch
def snapshot():
    sig = []
    for d in (WIKI, INBOX, RAW, ASSETS):
        for f in glob.glob(os.path.join(d, '**', '*'), recursive=True):
            if os.path.isfile(f):
                sig.append((f, os.path.getmtime(f)))
    sig.append((__file__, os.path.getmtime(__file__)))
    return hash(tuple(sorted(sig)))


def serve(out, port):
    import http.server, functools
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=out)
    handler.log_message = lambda *a, **k: None
    srv = http.server.ThreadingHTTPServer(('127.0.0.1', port), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    print(f'serving http://127.0.0.1:{port}/  (rebuilds when wiki/, inbox/, raw/ or the assets change; Ctrl-C to stop)')
    last = snapshot()
    try:
        while True:
            time.sleep(1)
            cur = snapshot()
            if cur != last:
                last = cur
                try:
                    build(out)
                except Exception as e:  # keep serving the last good build
                    print('build failed:', e, file=sys.stderr)
    except KeyboardInterrupt:
        print()


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'site'), help='output folder (default: <root>/site/)')
    ap.add_argument('--serve', action='store_true', help='serve the output on a local port and rebuild on change')
    ap.add_argument('--port', type=int, default=8080)
    ap.add_argument('--root', default=None, help='wiki root (default: the repo this script lives in)')
    ap.add_argument('--config', default=None, help='wiki.json to use (default: <root>/wiki.json)')
    a = ap.parse_args()
    if a.root or a.config:
        configure(a.root or ROOT, a.config)
        if a.out == os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'site'):
            a.out = os.path.join(ROOT, 'site')
    out = os.path.abspath(a.out)
    build(out)
    if a.serve:
        serve(out, a.port)

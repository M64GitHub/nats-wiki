#!/usr/bin/env python3
"""Wiki lint — the mechanical half of the `lint` operation. Zero dependencies; reads wiki.json for the page types.

    python3 tools/lint.py            # report
    python3 tools/lint.py --strict   # exit 1 if there are broken links, frontmatter issues or pages missing from the index

Checks: duplicate slugs, frontmatter (title/type/created/updated, `kind` on kinded types, type matching the folder),
broken [[links]] (minus the intentional "wanted" red links listed in index.md), orphans, pages missing from index.md,
the number of (unverified) markers, **citation drift** (a page's `sources:` frontmatter and its "## Sources" section
naming different sets) and **unlanded ripples** (a summary's "## Pages touched" naming a page that never cites it).

The last two both work the same way: the wiki states its intentions twice, so the two statements can be diffed.
Citation drift is a defect and counts towards --strict. Unlanded ripples are a *review* list, not a defect list —
"pages touched" sometimes means "relevant to" rather than "edited" — so they never fail the build; work them
top-down, one page per sitting. Contradictions are the maintainer's half — read for them.

If the wiki has a `tools/check-staleness.py` (optional and wiki-specific: it knows which authority a page's
`verified-against` names), lint runs it with `--quiet` and prints its summary. Always a warning, never an error.
"""
import re, os, glob, sys, json, collections, subprocess
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIKI = os.path.join(ROOT, 'wiki')
cfg = {}
try:
    cfg = json.load(open(os.path.join(ROOT, 'wiki.json'), encoding='utf-8'))
except (OSError, ValueError):
    pass
types = cfg.get('types') or [{'id': 'technique', 'folder': 'techniques'}, {'id': 'concept', 'folder': 'concepts'},
                             {'id': 'entity', 'folder': 'entities', 'kinds': ['tool', 'person']}, {'id': 'summary', 'folder': 'summaries'}]
folder_type = {t.get('folder', t['id'] + 's'): t['id'] for t in types}
kinded = {t['id'] for t in types if t.get('kinds')}
wanted_heading = cfg.get('wanted_heading', '## Wanted pages')
source_type = cfg.get('source_type', 'summary')          # the type whose pages are the citation anchors
source_folder = next((t.get('folder', t['id'] + 's') for t in types if t['id'] == source_type), 'summaries')
touched_heading = cfg.get('touched_heading', '## Pages touched')   # the section a summary lists its ripple in
sources_key = cfg.get('sources_key', 'sources')                    # frontmatter key listing a page's summaries
sources_heading = cfg.get('sources_heading', '## Sources')         # the section listing the same summaries
strict = '--strict' in sys.argv

def read(f):
    return open(f, encoding='utf-8').read()

def fm_list(txt, key):
    """The value of a frontmatter list key, inline (`key: [a, b]`) or block (`key:\n  - a`). None if absent."""
    if not txt.startswith('---\n'): return None
    fm = txt.split('---\n', 2)[1]
    m = re.search(rf'^{re.escape(key)}:[ \t]*\[(.*?)\][ \t]*$', fm, re.M | re.S)
    if m: return [x.strip() for x in m.group(1).split(',') if x.strip()]
    m = re.search(rf'^{re.escape(key)}:[ \t]*\n((?:[ \t]+-[ \t]*\S.*\n?)+)', fm, re.M)
    if m: return [x.strip() for x in re.findall(r'^[ \t]+-[ \t]*(.+?)[ \t]*$', m.group(1), re.M) if x.strip()]
    return None

pages = {}
for f in sorted(glob.glob(WIKI + '/**/*.md', recursive=True)):
    slug = os.path.splitext(os.path.basename(f))[0]
    if slug in pages: print('DUPLICATE SLUG:', slug, f, pages[slug])
    pages[slug] = f
link_re = re.compile(r'\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]')
inbound = collections.Counter(); broken = collections.defaultdict(set); fm_issues = []
for slug, f in pages.items():
    txt = open(f, encoding='utf-8').read()
    folder = os.path.basename(os.path.dirname(f))
    if not txt.startswith('---\n'):
        fm_issues.append((slug, 'no frontmatter'))
    else:
        fm = txt.split('---\n', 2)[1]
        for key in ('title', 'type', 'created', 'updated'):
            if not re.search(rf'^{key}:', fm, re.M): fm_issues.append((slug, f'missing {key}'))
        t = re.search(r'^type:\s*(\S+)', fm, re.M)
        ptype = t.group(1) if t else ''
        if ptype in kinded and not re.search(r'^kind:', fm, re.M): fm_issues.append((slug, f'{ptype} without kind'))
        if folder in folder_type and ptype and ptype != folder_type[folder] and slug not in ('index', 'log'):
            fm_issues.append((slug, f'type {ptype} but lives in {folder}/'))
    for m in link_re.finditer(txt):
        target = m.group(1).strip()
        if target in pages: inbound[target] += 1 if target != slug else 0
        else: broken[target].add(slug)
print(f'pages: {len(pages)}')
print('frontmatter issues:', fm_issues or 'none')
orphans = [s for s in pages if inbound[s] == 0 and s not in ('index', 'log')]
print('orphans (no inbound links):', orphans or 'none')
idx = open(pages['index'], encoding='utf-8').read() if 'index' in pages else ''
wanted = set()
if wanted_heading in idx:
    sect = idx.split(wanted_heading, 1)[1]
    sect = re.split(r'\n## ', sect, maxsplit=1)[0]
    wanted = set(re.findall(r'\[\[([^\]|]+)\]\]', sect))
real_broken = {k: v for k, v in broken.items() if k not in wanted}
print('broken links (excluding wanted):', {k: sorted(v) for k, v in real_broken.items()} or 'none')
print('wanted (intentional red links):', sorted(wanted) or 'none')
missing_from_index = [s for s in pages if s not in ('index', 'log') and f'[[{s}]]' not in idx and f'[[{s}|' not in idx]
print('pages missing from index:', missing_from_index or 'none')
# index.md and log.md talk *about* the markers; counting them would inflate the number with every write-up
unv = {s: len(re.findall(r'\(unverified', read(f))) for s, f in pages.items() if s not in ('index', 'log')}
print('unverified markers:', sum(unv.values()), 'across', sum(1 for v in unv.values() if v), 'pages')

# Citation drift: `sources:` in the frontmatter and the "## Sources" section should name the same summaries.
drift = {}
for slug, f in pages.items():
    txt = read(f)
    listed = fm_list(txt, sources_key)
    if not listed: continue
    if sources_heading not in txt:
        drift[slug] = (sorted(listed), [], True); continue
    cited = set(link_re.findall(txt.split(sources_heading, 1)[1]))
    missing = sorted(x for x in listed if x not in cited)
    extra = sorted(x for x in cited - set(listed)
                   if x in pages and os.path.basename(os.path.dirname(pages[x])) == source_folder)
    if missing or extra: drift[slug] = (missing, extra, False)
print('citation drift:', len(drift), f'pages -- frontmatter `{sources_key}:` and the "{sources_heading}" section disagree.')
for slug in sorted(drift):
    missing, extra, no_section = drift[slug]
    if no_section: print(f'  {slug}: no {sources_heading} section, but {sources_key}: lists ' + ', '.join(missing))
    else:
        if missing: print(f'  {slug}: in {sources_key}: but not in {sources_heading}: ' + ', '.join(missing))
        if extra: print(f'  {slug}: in {sources_heading} but not in {sources_key}: ' + ', '.join(extra))

# Unlanded ripples: a summary's "## Pages touched" names a page that does not cite that summary --
# the ingest stopped at the summary layer and never reached the reader. A review list, not a defect list.
unlanded = collections.defaultdict(list)
for slug, f in pages.items():
    if os.path.basename(os.path.dirname(f)) != source_folder: continue
    m = re.search(re.escape(touched_heading) + r'[ \t]*\n(.*?)(?=\n##\s|\Z)', read(f), re.S)
    if not m: continue
    for target in {t.strip() for t in link_re.findall(m.group(1))}:
        tf = pages.get(target)
        if not tf or os.path.basename(os.path.dirname(tf)) == source_folder: continue
        if slug not in read(tf): unlanded[target].append(slug)
print('unlanded ripples:', sum(len(v) for v in unlanded.values()), 'across', len(unlanded),
      f'pages -- a summary lists the page under "{touched_heading}" but the page never cites it.')
if unlanded:
    print('  (review, not a defect list: "pages touched" sometimes means "relevant to" rather than "edited".)')
for target in sorted(unlanded, key=lambda t: (-len(unlanded[t]), t)):
    print(f'  {os.path.basename(os.path.dirname(pages[target]))}/{target}: ' + ', '.join(sorted(unlanded[target])))

# Staleness is a *warning*, never an error: `tools/check-staleness.py` is optional and wiki-specific
# (it knows which authority a page's `verified-against` names). If it is not there, lint is unchanged.
# A subprocess, so the wiki's tool can be any script (no `main()` contract, no sys.argv juggling) and
# neither its exit code nor an argparse error can ever fail the lint.
stale_tool = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'check-staleness.py')
if os.path.exists(stale_tool):
    try:
        r = subprocess.run([sys.executable, stale_tool, '--quiet'], capture_output=True, text=True)
        out = (r.stdout + r.stderr).rstrip()
        print(out or f'staleness: not checked (no output, exit {r.returncode})')
        if not r.returncode:
            print('  (run `python3 tools/check-staleness.py` for the table -- and after every release it tracks)')
    except Exception as e:
        print(f'staleness: not checked ({e})')

if strict and (fm_issues or real_broken or missing_from_index or drift):
    sys.exit(1)

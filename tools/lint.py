#!/usr/bin/env python3
"""Wiki lint — the mechanical half of the `lint` operation. Zero dependencies; reads wiki.json for the page types.

    python3 tools/lint.py            # report
    python3 tools/lint.py --strict   # exit 1 if there are broken links, frontmatter issues or pages missing from the index

Checks: duplicate slugs, frontmatter (title/type/created/updated, `kind` on kinded types, type matching the folder),
broken [[links]] (minus the intentional "wanted" red links listed in index.md), orphans, pages missing from index.md,
and the number of (unverified) markers. Contradictions and staleness are the maintainer's half — read for them.
"""
import re, os, glob, sys, json, collections
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
strict = '--strict' in sys.argv

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
unv = {s: len(re.findall(r'\(unverified', open(f, encoding='utf-8').read())) for s, f in pages.items()}
print('unverified markers:', sum(unv.values()), 'across', sum(1 for v in unv.values() if v), 'pages')
if strict and (fm_issues or real_broken or missing_from_index):
    sys.exit(1)

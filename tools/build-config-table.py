#!/usr/bin/env python3
"""Build inbox/config-keys-table.md from the generated config reference in raw/nats-docs/.

    python3 tools/fetch-docs.py https://docs.nats.io --collection nats-docs reference/config   # once, to get the pages
    python3 tools/build-config-table.py              # then this, as often as you like

docs.nats.io ships one page per configuration key under /reference/config, generated from the
server rather than hand-written. Two shapes are used here:

  * a **key page** has the key as its H1, an optional `Hot Reloadable` marker, a paragraph of
    reload semantics, a one-paragraph description and a `## Types` table (type, choices);
  * a **group page** additionally has a `## Properties` table listing its children with
    *Description*, *Type*, **Default** and *Reloadable* — that is where the defaults live.

The table merges both: one row per key, with the dotted key path, the type(s), the default from
its parent's Properties row, whether it reloads, the description, and the doc page the row came
from. Nothing is inferred — a cell is empty when the docs do not state a value.

The result is a lookup table, not a wiki page: `wiki/reference/` pages quote from it with a
citation and a `verified-against` version. Registered in wiki.json under `tocs`, so the viewer
renders it filterable and puts every key into search.
"""
import os, re, glob, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONF = os.path.join(ROOT, 'raw', 'nats-docs', 'reference', 'config')
OUT = os.path.join(ROOT, 'inbox', 'config-keys-table.md')
ROW = re.compile(r'^\|(?P<cells>.+)\|\s*$')


def cells(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]


def table(text, heading):
    """Rows of every table under `## <heading>`, as dicts keyed by that table's header cells.

    A section may hold more than one table, split by `###` subheadings — the root
    `reference/config.md` groups its Properties under Connectivity, Clustering, Logging and so
    on. Each block carries its own header row, so they are read separately and concatenated.
    """
    m = re.search(rf'^## {heading}\s*$', text, re.M)
    if not m:
        return []
    rest = text[m.end():]
    end = re.search(r'^## ', rest, re.M)
    lines = rest[:end.start() if end else len(rest)].splitlines()
    out, head, i = [], None, 0
    while i < len(lines):
        line = lines[i]
        if line.startswith('|'):
            if head is None:                      # first row of a block is its header
                head = [h.lower() for h in cells(line)]
                i += 2                            # skip the |---|---| separator
                continue
            c = cells(line)
            out.append(dict(zip(head, c + [''] * (len(head) - len(c)))))
        elif line.strip():
            head = None                           # prose or a `###` heading ends the block
        i += 1
    return out


def unescape(s):
    return s.replace('\\_', '_').replace('\\*', '*').replace('\\|', '|')


def clean(s, limit=240):
    s = unescape(s).replace('\n', ' ').strip()
    s = re.sub(r'\s+', ' ', s)
    s = s.replace('|', '\\|')
    return s[:limit].rstrip() + ('…' if len(s) > limit else '')


def own_description(text):
    """The key's description paragraph, above the first ## heading.

    Layout is: H1, an optional `Hot Reloadable` marker, then — when the marker is there — one
    paragraph of reload semantics, then the description. A page that stops after the reload
    paragraph simply has no description; returning that paragraph instead would mislabel it.
    """
    body = re.split(r'^## ', text, maxsplit=1, flags=re.M)[0]
    body = re.sub(r'^<!--.*?-->\s*', '', body, flags=re.S)
    body = re.sub(r'^#\s+.*$', '', body, count=1, flags=re.M)
    hot = bool(re.search(r'^Hot Reloadable\s*$', body, re.M))
    paras = [p.strip() for p in body.split('\n\n') if p.strip() and p.strip() != 'Hot Reloadable']
    if hot:
        paras = paras[1:]        # drop the reload-semantics paragraph
    return paras[-1] if paras else ''


def normalise_reload(value):
    """`Hot Reloadable` / `Yes*` / `No` -> one filterable word (`*` = see the page for caveats)."""
    v = value.strip().lower()
    if v.startswith('yes') or v == 'reloadable':
        return 'reloadable*' if '*' in value else 'reloadable'
    if v.startswith('no'):
        return 'restart-only'
    return ''


def previous_citations():
    """Keep the `cited by` cells of an existing table — they are hand-written, the rest is generated."""
    keep = {}
    if os.path.exists(OUT):
        for line in open(OUT, encoding='utf-8'):
            if line.startswith('|'):
                c = cells(line)
                if len(c) >= 7 and c[0] not in ('key', '---'):
                    keep[c[0]] = c[6]
    return keep


def main():
    if not os.path.isdir(CONF):
        sys.exit(f'{os.path.relpath(CONF, ROOT)} not found — run:\n  python3 tools/fetch-docs.py https://docs.nats.io --collection nats-docs reference/config')
    pages = {}
    # The root index `reference/config.md` sits *outside* `reference/config/`, and it is the
    # Properties table that states every top-level key's default. Without it, ~100 keys
    # (`port`, `write_deadline`, `lame_duck_duration`, …) lose defaults the docs do state.
    paths = sorted(glob.glob(os.path.join(CONF, '**', '*.md'), recursive=True))
    if os.path.exists(CONF + '.md'):
        paths.insert(0, CONF + '.md')
    for path in paths:
        rel = os.path.relpath(path, CONF).replace(os.sep, '/')
        key = 'config' if rel == '../config.md' else rel[:-3].replace('/', '.')
        text = open(path, encoding='utf-8').read()
        types = table(text, 'Types')
        pages[key] = {
            'key': key,
            'file': 'reference/config/' + rel,
            'title': unescape((re.search(r'^#\s+(.+)$', text, re.M) or [''])[1] if re.search(r'^#\s+(.+)$', text, re.M) else key),
            'reload': 'reloadable' if re.search(r'^Hot Reloadable\s*$', text, re.M) else '',
            'types': ' / '.join(t.get('type', '') for t in types if t.get('type')),
            'choices': ' '.join(t.get('choices', '') for t in types if t.get('choices') not in ('', '-')),
            'desc': own_description(text),
            'props': table(text, 'Properties'),
            'default': '', 'parent': '',
        }
    # defaults and one-line descriptions come from the parent's Properties table
    linked = re.compile(r'\[`?([^`\]]+)`?\]\(([^)]+)\)')
    for key, p in pages.items():
        for row in p['props']:
            m = linked.search(row.get('name', ''))
            child = m.group(1) if m else row.get('name', '').strip('`')
            ckey = f'{key}.{child}' if key != 'config' else child
            if ckey in pages:
                pages[ckey]['default'] = row.get('default', '')
                pages[ckey]['parent'] = key
                if row.get('description'):
                    pages[ckey]['desc'] = row['description']
                if row.get('reloadable'):
                    pages[ckey]['reload'] = normalise_reload(row['reloadable'])
    keep = previous_citations()
    rows = [p for k, p in sorted(pages.items()) if k != 'config']
    for r in rows:
        r['cited'] = keep.get(r['key'], '')
    n_def = sum(1 for r in rows if r['default'] not in ('', '-'))
    n_rel = sum(1 for r in rows if r['reload'].startswith('reloadable'))
    n_cited = sum(1 for r in rows if r['cited'])
    head = f"""# Config keys — docs.nats.io reference/config

Generated by `tools/build-config-table.py` from `raw/nats-docs/reference/config/` (fetched with
`tools/fetch-docs.py`). **{len(rows)} keys**, {n_def} with a stated default, {n_rel} marked
reloadable, {n_cited} already cited by a wiki page. Re-run both after a server release and diff
this file — that diff is the change layer for configuration. The `cited by` column is hand-kept
(it survives regeneration): put the `[[wikilink]]` there when a page explains the key, and the
viewer will show at a glance how much of the surface the wiki actually covers.

The docs are generated from the server, so this table is close to ground truth, but it is still
a *source*, not a wiki page: quote it in `wiki/reference/` with a citation and the
`verified-against` version. An empty cell means the docs state nothing — never fill one in from
memory. `key` links to the fetched page in `raw/`.

| key | type | default | reload | description | file | cited by |
|---|---|---|---|---|---|---|
"""
    body = ''.join(
        f"| {r['key']} | {clean(r['types'], 60)} | {clean(r['default'], 40)} | {clean(r['reload'], 12)} | "
        f"{clean(r['desc'])} | {r['file']} | {r['cited']} |\n" for r in rows)
    open(OUT, 'w', encoding='utf-8').write(head + body)
    print(f'wrote {os.path.relpath(OUT, ROOT)}: {len(rows)} keys, {n_def} with defaults, '
          f'{n_rel} reloadable, {n_cited} cited by a wiki page')
    top = collections.Counter(r['key'].split('.')[0] for r in rows)
    print('top-level blocks:', ', '.join(f'{k}({v})' for k, v in top.most_common(12)))


if __name__ == '__main__':
    main()

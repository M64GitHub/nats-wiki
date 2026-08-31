#!/usr/bin/env python3
"""Fetch a documentation site into raw/, driven by its own llms.txt index.

    python3 tools/fetch-docs.py https://docs.example.com --list
    python3 tools/fetch-docs.py https://docs.example.com guide/ --dry-run
    python3 tools/fetch-docs.py https://docs.example.com reference guide --collection example-docs

Many documentation sites publish `llms.txt`: a Markdown index of every page, one
`- [Title](/path.md): description` line each, and serve those pages as Markdown. That index is
the only source of paths here — a URL that looks plausible but is not listed is usually a 404
page, and a 404 page saved into raw/ is worse than a missing file.

Files land under `raw/<collection>/<path>`, mirroring the site tree, each with a one-line
provenance header. Existing files are kept unless --refresh, so a big run can be resumed or
repeated cheaply. A `_index.md` manifest lists what is present, and `_llms.txt` keeps the index
that produced it.

Downloading is not ingesting: afterwards, add the printed row to `raw/sources.md` and ingest
article by article (see CLAUDE.md → Operation: ingest).
"""
import argparse, os, re, sys, time, urllib.parse, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = {'User-Agent': 'llm-wiki-fetch/1.0 (local wiki build)'}
# `- [Title](/path.md)` with an optional description after `:` or ` - ` (both are in the wild)
LINK = re.compile(r'^[-*] \[(?P<title>[^\]]*)\]\((?P<href>[^)]+)\)'
                  r'(?:\s*(?::|[-–—])\s*(?P<desc>.*))?$')


def get(url, tries=3):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
                return r.read().decode('utf-8', 'replace')
        except (urllib.error.URLError, TimeoutError):
            if i == tries - 1:
                return None
            time.sleep(1 + i)
    return None


def load_index(url, cache, refresh):
    if os.path.exists(cache) and not refresh:
        return open(cache, encoding='utf-8').read()
    text = get(url)
    if text is None:
        sys.exit(f'could not fetch {url}')
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    open(cache, 'w', encoding='utf-8').write(text)
    return text


def entries(text, base, any_ext, allow_hosts=()):
    """The `- [Title](path)` lines of an llms.txt, as dicts, deduplicated by path.

    Links may be site-relative or absolute. Absolute links to another host are skipped unless
    that host is in `allow_hosts` — several sites publish the index on one host and the pages on
    another, so `other_hosts` is returned too and the caller tells the user what it saw.
    """
    host = urllib.parse.urlparse(base).netloc
    ok_hosts = {host} | set(allow_hosts)
    out, seen, other, section = [], set(), {}, ''
    for line in text.splitlines():
        if line.startswith('#'):
            section = line.lstrip('#').strip()
        m = LINK.match(line.strip())
        if not m:
            continue
        href = m['href'].strip()
        parsed = urllib.parse.urlparse(href)
        if parsed.netloc and parsed.netloc not in ok_hosts:
            other[parsed.netloc] = other.get(parsed.netloc, 0) + 1
            continue
        path = parsed.path
        if not path.startswith('/') or path.endswith('/'):
            continue
        if not any_ext and not path.endswith('.md'):
            continue
        if path in seen:
            continue
        seen.add(path)
        out.append({'title': m['title'], 'path': path, 'desc': (m['desc'] or '').strip(),
                    'section': section, 'url': urllib.parse.urljoin(base + '/', href)})
    return out, other


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('base', help='site root, e.g. https://docs.example.com')
    ap.add_argument('prefix', nargs='*', help='path prefixes to fetch, e.g. guide reference/api')
    ap.add_argument('--collection', default='', help='raw/<collection>/ (default: the host name)')
    ap.add_argument('--index', default='', help='index URL (default: <base>/llms.txt)')
    ap.add_argument('--list', action='store_true', help='print the prefixes with page counts and exit')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--limit', type=int, default=0, help='stop after N pages (smoke test)')
    ap.add_argument('--refresh', action='store_true', help='re-download the index and existing files')
    ap.add_argument('--any-ext', action='store_true', help='also take links that are not .md')
    ap.add_argument('--allow-host', action='append', default=[], metavar='HOST',
                    help='also fetch links pointing at this host (some indexes live on another host)')
    ap.add_argument('--delay', type=float, default=0.15, help='seconds between requests (default 0.15)')
    a = ap.parse_args()

    base = a.base.rstrip('/')
    coll = a.collection or urllib.parse.urlparse(base).netloc.replace('.', '-') or 'docs'
    out = os.path.join(ROOT, 'raw', coll)
    index_url = a.index or base + '/llms.txt'

    all_entries, other_hosts = entries(
        load_index(index_url, os.path.join(out, '_llms.txt'), a.refresh),
        base, a.any_ext, a.allow_host)
    if other_hosts:
        seen = ', '.join(f'{h} ({n})' for h, n in sorted(other_hosts.items(), key=lambda x: -x[1]))
        print(f'note: skipped links on other hosts: {seen} — pass --allow-host to include them',
              file=sys.stderr)
    if not all_entries:
        sys.exit(f'no usable links in {index_url} — try --any-ext, or --allow-host for the hosts above')
    if a.list or not a.prefix:
        counts = {}
        for e in all_entries:
            parts = e['path'].strip('/').split('/')
            for depth in (1, 2):
                if len(parts) > depth:
                    key = '/'.join(parts[:depth])
                    counts[key] = counts.get(key, 0) + 1
        print(f'{len(all_entries)} pages in {index_url}  ->  raw/{coll}/')
        for k in sorted(counts):
            print(f'  {counts[k]:5d}  {k}')
        if not a.prefix:
            print(f'\ngive one or more prefixes to fetch, e.g.:  python3 tools/fetch-docs.py {base} '
                  + (sorted(counts)[0] if counts else 'guide'))
        return

    pre = tuple('/' + p.strip('/') for p in a.prefix)
    todo = [e for e in all_entries if e['path'].startswith(pre)]
    if a.limit:
        todo = todo[:a.limit]
    print(f'{len(todo)} pages match {", ".join(a.prefix)}')
    fetched = skipped = failed = 0
    for e in todo:
        dest = os.path.join(out, e['path'].lstrip('/'))
        if a.dry_run:
            print(('have ' if os.path.exists(dest) else 'get  ') + e['path'])
            continue
        if os.path.exists(dest) and not a.refresh:
            skipped += 1
            continue
        text = get(e['url'])
        # a site that answers a missing .md with its HTML 404 page must not land in raw/
        if text is None or (e['path'].endswith('.md') and text.lstrip()[:9].lower() == '<!doctype'):
            print('FAILED', e['path'], file=sys.stderr)
            failed += 1
            continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        stamp = time.strftime('%Y-%m-%d')
        open(dest, 'w', encoding='utf-8').write(
            f'<!-- source: {e["url"]} · fetched {stamp}'
            + (f' · section: {e["section"]}' if e['section'] else '') + ' -->\n' + text)
        fetched += 1
        time.sleep(a.delay)
    if a.dry_run:
        return
    have = {e['path'] for e in all_entries
            if os.path.exists(os.path.join(out, e['path'].lstrip('/')))}
    manifest = os.path.join(out, '_index.md')
    with open(manifest, 'w', encoding='utf-8') as f:
        f.write(f'# {base} — fetched pages\n\nGenerated by `tools/fetch-docs.py` from the site\'s '
                f'llms.txt. One row per page present in `raw/{coll}/`.\n\n'
                '| path | title | section | description |\n|---|---|---|---|\n')
        for e in all_entries:
            if e['path'] in have:
                f.write(f'| {e["path"]} | {e["title"]} | {e["section"]} | {e["desc"]} |\n')
    print(f'fetched {fetched}, already had {skipped}, failed {failed} — {len(have)} pages in raw/{coll}/')
    print(f'manifest: {os.path.relpath(manifest, ROOT)}')
    print('add to raw/sources.md if not there yet:')
    print(f'| {coll} | `raw/{coll}/` | {base} (paths from llms.txt) | {time.strftime("%Y-%m-%d")} '
          '| fetched with `tools/fetch-docs.py` |')


if __name__ == '__main__':
    main()

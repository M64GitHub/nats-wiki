#!/usr/bin/env python3
"""Find the wiki pages that are now lying: version-bearing claims verified against an older release.

    python3 tools/check-staleness.py                  # report to inbox/staleness.md, summary to stdout
    python3 tools/check-staleness.py --fetch          # ask GitHub for the current nats-server release
    python3 tools/check-staleness.py --current 2.14.7 # or say what the current release is
    python3 tools/check-staleness.py --quiet          # just the counts (this is what lint.py prints)

`CLAUDE.md` says a page that states **a default, a limit, a config key, a CLI flag, an API subject or
an error code** must carry `verified-against` and `verified-on`, because "a stale page is worse than a
missing one when someone is configuring production". This finds the pages where that has stopped
being true — and, just as important, leaves alone the pages that state none of those six things,
because they do not go stale the same way. That distinction is the whole point of the tool: a wiki
this size cannot be re-verified page by page, and a list that flags everything is a list nobody works.

Each page is checked against **the authority it names**, not against one global version:

  nats-server 2.14.6   the newest non-prerelease tag in `raw/release-notes/_tags-and-dates.md`
                       (or `--current`, or `--fetch` for the live one)
  natscli v0.4.0       `raw/github-repos/nats-io__natscli.release.json`, already fetched by
  nsc v2.15.0          `tools/fetch-repo-facts.py --refresh` — so a client or tool release is
  nats.zig v0.1.0      detected by the same run that refreshes the entity pages
  anything else        listed separately as an authority the tool cannot check (a site capture,
                       a date, a spec) — never silently treated as current

A version stated as a **minor** (`2.14`) is compared as a minor: a page that says "since 2.11" is not
stale because 2.14.6 shipped. Only a page that pins a patch is compared at patch level.

The report is `inbox/staleness.md` — page, what it was verified against, what is current, which of the
six claim kinds it makes, and **which summary pages it was verified from**, so re-verifying is a
re-read of one named source rather than a re-derivation.
"""
import argparse, glob, json, os, re, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIKI = os.path.join(ROOT, 'wiki')
TAGS = os.path.join(ROOT, 'raw', 'release-notes', '_tags-and-dates.md')
REPOS = os.path.join(ROOT, 'raw', 'github-repos')
OUT = os.path.join(ROOT, 'inbox', 'staleness.md')
LATEST = 'https://api.github.com/repos/nats-io/nats-server/releases/latest'

# The six things CLAUDE.md says must carry a version, and how to spot them in a page body.
CLAIMS = [
    ('default',    re.compile(r'(?i)\bdefaults?\s+(?:to|is|are|of)\b|\|\s*default\s*\||`default`')),
    ('limit',      re.compile(r'`?\bmax_[a-z_]+|\bMax[A-Z]\w+\b|\blimit of\b|\bhard limit\b')),
    ('config key', re.compile(r'`[a-z][a-z0-9]*_[a-z0-9_]+`|`[a-z][a-z0-9_]*\s*\{|^\s*[a-z_]+\s*\{\s*$', re.M)),
    ('CLI flag',   re.compile(r'`?--[a-z][a-z0-9-]{2,}|^\s*\$?\s*(?:nats|nats-server|nsc|nk)\s', re.M)),
    ('subject',    re.compile(r'\$JS\.|\$SYS\.|\$KV\.|\$OBJ\.|\$MQTT\.|\$G\b')),
    ('error code', re.compile(r'\b10\d{3}\b')),
]
VERSION = re.compile(r'^(?P<name>[A-Za-z][\w./\-]*(?:\s+[A-Za-z][\w./\-]*)*?)\s+v?(?P<ver>\d+(?:\.\d+)*)\s*$')
SKIP_TYPES = {'summary', 'index'}          # a summary is a snapshot of its source; it carries `version`


def frontmatter(text):
    if not text.startswith('---\n'):
        return {}
    fm = text.split('---\n', 2)[1]
    out, key = {}, None
    for line in fm.splitlines():
        m = re.match(r'^([a-z-]+):\s*(.*)$', line)
        if m:
            key = m.group(1); out[key] = m.group(2).strip()
        elif key and line.strip():          # a value wrapped over several indented lines
            out[key] += ' ' + line.strip()
    return out


def current_versions(args):
    """{authority name: current version} — nats-server plus every repo with a fetched release."""
    cur = {}
    if args.current:
        cur['nats-server'] = args.current.lstrip('v')
    elif args.fetch:
        with urllib.request.urlopen(LATEST, timeout=20) as r:
            cur['nats-server'] = json.load(r)['tag_name'].lstrip('v')
    elif os.path.exists(TAGS):
        for line in open(TAGS, encoding='utf-8'):
            m = re.match(r'\|\s*(v[\d.]+)\s*\|\s*([\d-]+)\s*\|\s*False\s*\|', line)
            if m:                                     # the file is newest first
                cur['nats-server'] = m.group(1).lstrip('v')
                break
    for f in sorted(glob.glob(os.path.join(REPOS, '*.release.json'))):
        try:
            tag = json.load(open(f, encoding='utf-8')).get('tag_name', '')
        except (OSError, ValueError):
            continue
        name = os.path.basename(f)[:-len('.release.json')].split('__')[-1]
        if tag:
            cur.setdefault(name, tag.lstrip('v'))
    return cur


def resolve_authority(name, cur):
    """The key in `cur` a `verified-against` name refers to: `nats-io/nkeys` -> `nkeys`,
    `nats-pure` -> `nats-pure.rb`. None when nothing matches, or more than one does."""
    name = name.split('/')[-1]
    if name in cur:
        return name
    near = [k for k in cur if k == name or k.split('.')[0] == name]
    return near[0] if len(near) == 1 else None


def behind(seen, current):
    """Is `seen` behind `current`, compared only as far as `seen` is specific?"""
    a = [int(x) for x in seen.split('.') if x.isdigit()]
    b = [int(x) for x in current.split('.') if x.isdigit()][:len(a)]
    return a < b


def scan(args):
    cur = current_versions(args)
    rows, unversioned, unknown = [], [], []
    for path in sorted(glob.glob(WIKI + '/**/*.md', recursive=True)):
        slug = os.path.splitext(os.path.basename(path))[0]
        text = open(path, encoding='utf-8').read()
        fm = frontmatter(text)
        if fm.get('type') in SKIP_TYPES or slug in ('index', 'log'):
            continue
        body = text.split('---\n', 2)[-1]
        kinds = [name for name, rx in CLAIMS if rx.search(body)]
        va = fm.get('verified-against', '')
        page = (slug, fm.get('type', ''), va, fm.get('verified-on', ''), ', '.join(kinds),
                fm.get('sources', '').strip('[]'))
        m = VERSION.match(va)
        name = resolve_authority(m.group('name'), cur) if m else None
        if name and name != 'nats-server':
            # an entity page pinned to a repo's release: the version *is* the claim, so it is
            # checked whether or not the page states one of the six
            if behind(m.group('ver'), cur[name]):
                rows.append(page + (cur[name],))
            continue
        if not kinds:
            continue                                   # states none of the six: does not rot this way
        if not va:
            unversioned.append(page)
            continue
        if not name:
            unknown.append(page)
            continue
        if behind(m.group('ver'), cur[name]):
            rows.append(page + (cur[name],))
    return cur, rows, unversioned, unknown


def report(cur, stale, unversioned, unknown):
    def table(rows, current_col):
        head = ('| page | type | verified against | ' + ('current | ' if current_col else '') +
                'verified on | claims | verified from |\n|---|---|---|' +
                ('---|' if current_col else '') + '---|---|---|\n')
        body = ''
        for r in sorted(rows):
            slug, typ, va, vo, kinds, src = r[:6]
            cells = [f'[[{slug}]]', typ, f'`{va}`' if va else '**none**']
            if current_col:
                cells.append(f'**{r[6]}**')
            cells += [vo or '—', kinds, ' · '.join(f'[[{s.strip()}]]' for s in src.split(',') if s.strip()) or '—']
            body += '| ' + ' | '.join(cells) + ' |\n'
        return head + body if rows else '_none._\n'
    known = ', '.join(f'`{k} {v}`' for k, v in sorted(cur.items()) if k in ('nats-server', 'natscli', 'nsc'))
    return f"""# Staleness — pages whose version-bearing claims need re-checking

Generated by `python3 tools/check-staleness.py`. A page is listed only if it states one of the six
things `CLAUDE.md` requires a version for — **a default, a limit, a config key, a CLI flag, an API
subject or an error code** — and its `verified-against` is behind the current release of the
authority it names, or missing. Pages that state none of those are not listed: they do not go stale
this way, and a list that flags everything is a list nobody works.

Current releases used for this run: {known or '(none resolved)'} — `nats-server` from
`raw/release-notes/_tags-and-dates.md` (newest non-prerelease tag; `--fetch` asks GitHub instead),
tools and clients from `raw/github-repos/*.release.json`, refreshed by
`python3 tools/fetch-repo-facts.py --refresh`.

One exception to the filter: a page pinned to a **repo's own release** (`natscli v0.4.0`,
`nats.go v1.53.1`) is checked whether or not it states one of the six — on those pages the version
*is* the claim, and the release feed for it is already in `raw/github-repos/`.

**Working a row**: open the page, re-read the source named in *verified from* at the new release,
change what moved, and bump both `verified-against` and `verified-on`. Bumping the dates without
re-reading the source is the one thing that makes this worse than doing nothing.

## Behind the current release ({len(stale)})

{table(stale, True)}
## No `verified-against` at all ({len(unversioned)})

These state a default, a key, a flag, a subject or an error code with nothing saying when that was
last true.

{table(unversioned, False)}
## Authority the tool cannot check ({len(unknown)})

`verified-against` names something with no release feed here — a site capture, a date, a spec. Not
stale, not verifiable mechanically; re-read them by hand when the thing they name changes.

{table(unknown, False)}"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--current', help='the current nats-server version, e.g. 2.14.7')
    ap.add_argument('--fetch', action='store_true', help='ask GitHub for the current release')
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--quiet', action='store_true', help='print the counts only')
    a = ap.parse_args()
    cur, stale, unversioned, unknown = scan(a)
    if not a.quiet:
        with open(a.out, 'w', encoding='utf-8') as fh:
            fh.write(report(cur, stale, unversioned, unknown))
    print('staleness: %d behind %s, %d with no verified-against, %d authority unknown%s'
          % (len(stale), cur.get('nats-server', '?'), len(unversioned), len(unknown),
             '' if a.quiet else ' · report: ' + os.path.relpath(a.out, ROOT)))
    for r in sorted(stale)[:10]:
        print('  %-42s %-20s -> %-8s %s' % (r[0], r[2], r[6], r[4]))
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Build inbox/relnotes-toc.md — one row per nats-server release from v2.10.0 on — and, with --fetch
or --offline, write every release body into raw/release-notes/ first.

    python3 tools/triage-releases.py --fetch                          # GitHub -> local/scratch/releases/ -> raw/ -> table
    python3 tools/triage-releases.py --fetch --include v2.15.0-preview.1   # also write a named prerelease body
    python3 tools/triage-releases.py --offline                        # raw/ from the newest cached pages, then the table
    python3 tools/triage-releases.py                                  # just the table, from what raw/release-notes/ holds

The archive is `gh api repos/nats-io/nats-server/releases?per_page=100`, paged until the last page,
every reply written verbatim to local/scratch/releases/releases-<DATE>-p<n>.json (a cache, never a
source). From it, one file raw/release-notes/<tag>.md per **release** whose minor is 2.10 or later:
the provenance line, `# Release <tag> — published <date>`, a blank line, the body with CRLF
normalised to LF — the exact form of the files written by hand on 2026-08-31 … 2026-09-03. Only
non-prerelease tags are written (the two `-binary` tags count as releases); RC and preview bodies are
not, because each GA body is the consolidated changelog of its RCs and `_tags-and-dates.md` already
records the RC tags and dates — name one with `--include` when it is wanted (the 2.15 preview is).
raw/ is immutable: **a file that exists is never rewritten**; the tool reports it, and reports
whether the fetched body still matches it, so an edited release body is noticed rather than lost.

The table's columns: tag · minor · published · go · items · flags · file · summary. `go` is the
`### Go Version` line; `items` counts the changelog bullets outside *Go Version*, *Dependencies*,
*Complete Changes* and *Credits*. Flags are read off the body's own sections — the 70 bodies of
2.10–2.15 surveyed on 2026-09-03 use `### Fixed` (67), `### Improved` (53), `### Dependencies` (53),
`### Added` (29), `### CVEs` (12), `### Changed` (6), `### Downgrade compatibility note` (3),
`### Removed` (2), and `> [!WARNING]` / `> [!IMPORTANT]` admonitions (5):

    added      a `### Added` section
    changed    a `### Changed` section
    removed    a `### Removed` section
    cve        a `### CVEs` section, or a CVE-/GHSA- identifier anywhere in the body
    downgrade  a `### Downgrade compatibility note` section, or *downgrade* / *downgrades* in the body
               (not *downgraded*, which the MQTT QoS fix lines use)
    warning    a `> [!WARNING]` / `> [!IMPORTANT]` / `> [!CAUTION]` admonition
    withdrawn  the body says the release "contains a regression" or to upgrade to another "instead"
    default    the word *default* appears in the changelog — a filter for the change layer, not a verdict
    binary     a `-binary` tag: a CVE fix shipped as binaries only, before the tagged release
    first      the first release of a minor (`x.y.0`)
    preview    a prerelease body written with --include (`-preview`, `-RC`)
    cited      a wiki page outside summaries/ names the tag
    ★          the triage star, STAR() below: changed, removed, downgrade, withdrawn, warning, cve, or
               first — the releases an operator must read before or after upgrading, because something
               they configured, relied on, or must patch moved. A proposal to tune; printed with the
               counts on every run.

The `summary` column is preserved from the existing table on re-run, and filled from
wiki/summaries/*.md whose `source-path` names the file or whose `aliases` list the tag (a per-minor
summary aliases every tag it folds in). Needs the `gh` CLI, logged in, for --fetch.
"""
import argparse, collections, glob, json, os, re, subprocess, sys
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'raw', 'release-notes')
SUMMARIES = os.path.join(ROOT, 'wiki', 'summaries')
WIKI = os.path.join(ROOT, 'wiki')
OUT = os.path.join(ROOT, 'inbox', 'relnotes-toc.md')
SCRATCH = os.path.join(ROOT, 'local', 'scratch', 'releases')
FLOOR = (2, 10)            # the oldest minor this wiki covers (CLAUDE.md: 2.10, 2.11, 2.12, 2.14)

TAG_RE = re.compile(r'^v(\d+)\.(\d+)\.(\d+)(?:-(.+))?$')
SKIP_SECTIONS = {'go version', 'dependencies', 'complete changes', 'credits'}
CVE_RE = re.compile(r'\bCVE-\d{4}-\d+|\bGHSA-[\w-]+')
WITHDRAWN_RE = re.compile(r'(?i)contains a regression|upgrade to [^.\n]{0,60}\binstead\b')
ADMONITION_RE = re.compile(r'^>\s*\[!(WARNING|IMPORTANT|CAUTION)\]', re.M)


def STAR(r):
    """The triage star. Stated here so the head of the table can quote it."""
    return any(f in r['flagset'] for f in ('changed', 'removed', 'downgrade', 'withdrawn', 'warning', 'cve', 'first'))


def parse_tag(tag):
    m = TAG_RE.match(tag)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4) or ''


def sort_key(tag, published):
    p = parse_tag(tag) or (0, 0, 0, tag)
    return (p[0], p[1], p[2], 0 if p[3] else 1, published or '')


def norm(body):
    return (body or '').replace('\r\n', '\n').replace('\r', '\n').strip()


# ---------------------------------------------------------------- fetch and write raw/

def gh_pages(repo):
    pages, n = [], 1
    while True:
        cmd = ['gh', 'api', f'repos/{repo}/releases?per_page=100&page={n}']
        out = subprocess.run(cmd, capture_output=True, text=True)
        if out.returncode != 0:
            sys.exit(f'gh api failed: {out.stderr.strip()}')
        page = json.loads(out.stdout)
        print(f'fetched page {n}: {len(page)} releases')
        if not page:
            break
        pages.append(page)
        if len(page) < 100:
            break
        n += 1
    return pages


def cached_set():
    sets = collections.defaultdict(list)
    for f in glob.glob(os.path.join(SCRATCH, 'releases-*-p*.json')):
        m = re.search(r'releases-(\d{4}-\d{2}-\d{2})-p(\d+)\.json$', f)
        if m:
            sets[m.group(1)].append((int(m.group(2)), f))
    if not sets:
        sys.exit(f'no cached pages in {SCRATCH}; run with --fetch first')
    d = sorted(sets)[-1]
    files = [f for _, f in sorted(sets[d])]
    return d, [json.load(open(f, encoding='utf-8')) for f in files]


def write_raw(releases, fetched, include, cached_on=None):
    """One raw/release-notes/<tag>.md per release at or above FLOOR; never overwrite."""
    os.makedirs(RAW, exist_ok=True)
    written, kept, differs, skipped = [], [], [], collections.Counter()
    today = date.today().isoformat()
    for r in releases:
        tag = r['tag_name']
        p = parse_tag(tag)
        if not p or (p[0], p[1]) < FLOOR:
            skipped['below floor or odd tag'] += 1
            continue
        if r.get('draft'):
            skipped['draft'] += 1
            continue
        if r.get('prerelease') and tag not in include:
            skipped['prerelease (not --include)'] += 1
            continue
        path = os.path.join(RAW, f'{tag}.md')
        body = norm(r.get('body'))
        if os.path.exists(path):
            have = open(path, encoding='utf-8').read().split('\n', 3)
            old = have[3].strip() if len(have) > 3 else ''
            (kept if old == body else differs).append(tag)
            continue
        via = (f'releases?per_page=100 — the same body `releases/tags/{tag}` returns'
               + (f'; cached {cached_on}, written here {today}' if cached_on else ''))
        pre = ' (prerelease)' if r.get('prerelease') else ''
        head = (f'<!-- source: https://github.com/nats-io/nats-server/releases/tag/{tag} '
                f'(GitHub REST API, {via}) · fetched {fetched} -->\n'
                f'# Release {tag} — published {(r.get("published_at") or "")[:10]}{pre}\n\n')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(head + body + '\n')
        written.append(tag)
    by_minor = collections.Counter(f'{parse_tag(t)[0]}.{parse_tag(t)[1]}' for t in written)
    print(f'raw/release-notes/: wrote {len(written)} ' + ', '.join(f'{k} ×{v}' for k, v in sorted(by_minor.items())))
    print(f'  kept {len(kept)} existing (body unchanged); skipped: {dict(skipped)}')
    if differs:
        print(f'  ** {len(differs)} existing file(s) whose body no longer matches the fetched one — raw/ is immutable, '
              f'so record the edit in raw/sources.md: {", ".join(differs)}')
    return written, kept, differs


# ---------------------------------------------------------------- the table

def tag_dates():
    """tag -> published date from raw/release-notes/_tags-and-dates.md, for a body whose header has none."""
    out = {}
    path = os.path.join(RAW, '_tags-and-dates.md')
    if os.path.exists(path):
        for m in re.finditer(r'^\|\s*(v[\d.]+(?:-[\w.]+)?)\s*\|\s*(\d{4}-\d{2}-\d{2})\s*\|', open(path, encoding='utf-8').read(), re.M):
            out[m.group(1)] = m.group(2)
    return out


def read_raw():
    rows, dates = [], tag_dates()
    for path in glob.glob(os.path.join(RAW, 'v*.md')):
        name = os.path.basename(path)
        tag = name[:-3]
        if not parse_tag(tag):
            continue
        text = open(path, encoding='utf-8').read()
        m = re.search(r'^# Release \S+ — published (\d{4}-\d{2}-\d{2})( \(prerelease\))?', text, re.M)
        rows.append({'tag': tag, 'file': name, 'published': m.group(1) if m else dates.get(tag, ''),
                     'prerelease': bool(m and m.group(2)) or bool(parse_tag(tag)[3] and not tag.endswith('-binary')),
                     'body': text.split('\n', 3)[3] if text.count('\n') >= 3 else ''})
    return rows


def sections(body):
    """{heading (lower): [lines]} of the ### sections under ## Changelog; the preamble under ''."""
    out, cur = collections.OrderedDict(), ''
    out[cur] = []
    for line in body.split('\n'):
        m = re.match(r'^###\s+(.+?)\s*$', line)
        if m:
            cur = m.group(1).strip().lower()
            out.setdefault(cur, [])
            continue
        out[cur].append(line)
    return out


def analyse(r, cited):
    secs = sections(r['body'])
    p = parse_tag(r['tag'])
    go = ''
    for line in secs.get('go version', []):
        m = re.match(r'^\s*[-*]\s*([\d.]+)', line)
        if m:
            go = m.group(1)
            break
    items = sum(1 for h, lines in secs.items() if h not in SKIP_SECTIONS
                for l in lines if re.match(r'^\s*[-*]\s+\S', l))
    changelog = '\n'.join(l for h, lines in secs.items() if h not in SKIP_SECTIONS for l in lines)
    flags = []
    for sec, flag in (('added', 'added'), ('changed', 'changed'), ('removed', 'removed')):
        if sec in secs:
            flags.append(flag)
    if 'cves' in secs or CVE_RE.search(r['body']):
        flags.append('cve')
    # the noun or the verb ("after a downgrade", "need to downgrade"), not "downgraded to QoS0"
    if 'downgrade compatibility note' in secs or re.search(r'(?i)\bdowngrades?\b', r['body']):
        flags.append('downgrade')
    if ADMONITION_RE.search(r['body']):
        flags.append('warning')
    if WITHDRAWN_RE.search(r['body']):
        flags.append('withdrawn')
    if re.search(r'(?i)\bdefault', changelog):
        flags.append('default')
    if r['tag'].endswith('-binary'):
        flags.append('binary')
    if p[2] == 0 and not p[3]:
        flags.append('first')
    if r['prerelease']:
        flags.append('preview')
    if r['tag'] in cited:
        flags.append('cited')
    r.update({'minor': f'{p[0]}.{p[1]}', 'go': go, 'items': items, 'flagset': set(flags)})
    if STAR(r):
        flags.insert(0, '★')
    r['flags'] = ' '.join(flags)
    return r


def cited_tags(tags):
    """The tags a wiki page outside summaries/ names (v2.10.17 or a bare 2.10.17)."""
    pats = {t: re.compile(r'(?<![\w.])v?' + re.escape(t[1:]) + r'(?![\w.])') for t in tags}
    found = set()
    for path in glob.glob(os.path.join(WIKI, '*', '*.md')):
        if os.sep + 'summaries' + os.sep in path:
            continue
        text = open(path, encoding='utf-8').read()
        for t, pat in pats.items():
            if t not in found and pat.search(text):
                found.add(t)
    return found


def summary_links():
    """tag -> [[summary slugs]] whose source-path names its file or whose aliases list the tag."""
    links = collections.defaultdict(list)
    for path in sorted(glob.glob(os.path.join(SUMMARIES, '*.md'))):
        head = open(path, encoding='utf-8').read(4000)
        fm = head.split('---\n', 2)[1] if head.startswith('---\n') and head.count('---\n') >= 2 else ''
        slug = '[[' + os.path.basename(path)[:-3] + ']]'
        names = set()
        for m in re.finditer(r'^source-path:\s*(.*)$', fm, re.M):
            names |= set(re.findall(r'release-notes/(v[\d.]+(?:-[\w.]+)?)\.md', m.group(1)))
        for m in re.finditer(r'^aliases:\s*\[(.*)\]\s*$', fm, re.M):
            names |= {a.strip().strip('"\'') for a in m.group(1).split(',') if a.strip().startswith(('v', '"v', "'v"))}
        for n in names:
            links[n].append(slug)
    return links


def previous_summaries():
    keep = {}
    if not os.path.exists(OUT):
        return keep
    for line in open(OUT, encoding='utf-8'):
        if not line.startswith('|'):
            continue
        c = [x.strip() for x in line.strip().strip('|').split('|')]
        if len(c) >= 8 and TAG_RE.match(c[0]):
            keep[c[0]] = c[7]
    return keep


def build_table():
    rows = read_raw()
    cited = cited_tags([r['tag'] for r in rows])
    rows = [analyse(r, cited) for r in rows]
    rows.sort(key=lambda r: sort_key(r['tag'], r['published']))
    keep, links = previous_summaries(), summary_links()
    for r in rows:
        prev = keep.get(r['tag'], '')
        auto = [l for l in links.get(r['tag'], []) if l not in prev]
        r['summary'] = ' · '.join(x for x in [prev] + auto if x)
    c = collections.Counter(f for r in rows for f in r['flags'].split())
    per_minor = collections.OrderedDict()
    for r in rows:
        m = per_minor.setdefault(r['minor'], {'n': 0, 'star': 0, 'items': 0, 'bytes': 0, 'ingested': 0})
        m['n'] += 1; m['star'] += '★' in r['flags']; m['items'] += r['items']; m['bytes'] += len(r['body'])
        m['ingested'] += bool(r['summary'])
    minors = ' · '.join(f'**{k}** {v["n"]} releases, {v["star"]} ★, {v["items"]} items, {v["bytes"] // 1024} KB'
                        for k, v in per_minor.items())
    first, last = rows[0]['tag'], rows[-1]['tag']
    head = f"""# Releases — nats-io/nats-server, v2.10.0 onward

One row per release body in `raw/release-notes/`, generated by `tools/triage-releases.py` (re-run it
after `--fetch`; it preserves the `summary` column and fills it from `wiki/summaries/`). {len(rows)}
releases from {first} to {last}, oldest first: {minors}. **{c['★']} flagged ★**, {c['cited']} named by a
wiki page, {sum(1 for r in rows if r['summary'])} with a summary. RC and preview bodies are not
here — each GA body is the consolidated changelog of its RCs, and `raw/release-notes/_tags-and-dates.md`
lists every tag with its date; the `preview` rows were written by name.

**The ★ rule**, as the script states it: *changed, removed, downgrade, withdrawn, warning, cve, or
first* — the releases an operator must read before or after upgrading, because something they
configured, relied on, or must patch moved. The other flags are the body's own sections (`added`,
`changed`, `removed`, `cve`), its admonitions (`warning`), its "upgrade to … instead" (`withdrawn`),
the word *downgrade* (`downgrade`), the word *default* in the changelog (`default` — a filter, not a
verdict), a `-binary` tag (`binary`), `x.y.0` (`first`), and `cited` when a wiki page outside
`summaries/` names the tag. `go` is the Go version the release was built with; `items` counts the
changelog bullets outside the Go, dependency and compare-link sections.

Ingest a line by writing `wiki/summaries/s-relnotes-<minor>.md` with every folded tag in `aliases`
(or one release as `s-relnotes-<tag>.md` with the file as `source-path`), and the link appears in the
last column on the next run. The tag links to the raw body.

| tag | minor | published | go | items | flags | file | summary |
|---|---|---|---|---|---|---|---|
"""
    body_ = ''.join(f"| {r['tag']} | {r['minor']} | {r['published']} | {r['go']} | {r['items']} | {r['flags']} | "
                    f"{r['file']} | {r['summary']} |\n" for r in rows)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(head + body_)
    print(f'wrote {OUT}: {len(rows)} rows, {c["★"]} ★')
    print(f'flags: {dict(c)}')
    for k, v in per_minor.items():
        print(f'  {k}: {v["n"]} releases · {v["star"]} ★ · {v["items"]} items · {v["bytes"] // 1024} KB · {v["ingested"]} with a summary')
    print('rule: ★ = changed | removed | downgrade | withdrawn | warning | cve | first')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--repo', default='nats-io/nats-server')
    ap.add_argument('--fetch', action='store_true', help='page the releases API into local/scratch/releases/, then write raw/')
    ap.add_argument('--offline', action='store_true', help='write raw/ from the newest cached pages; no GitHub call')
    ap.add_argument('--include', action='append', default=[], metavar='TAG',
                    help='also write this prerelease tag (repeatable)')
    a = ap.parse_args()
    if a.fetch or a.offline:
        if a.fetch:
            fetched = date.today().isoformat()
            os.makedirs(SCRATCH, exist_ok=True)
            pages = gh_pages(a.repo)
            for i, p in enumerate(pages, 1):
                with open(os.path.join(SCRATCH, f'releases-{fetched}-p{i}.json'), 'w', encoding='utf-8') as f:
                    json.dump(p, f, indent=1)
            print(f'cached {len(pages)} pages under {SCRATCH}/releases-{fetched}-p*.json')
            cached_on = None
        else:
            fetched, pages = cached_set()
            cached_on = fetched
            print(f'offline: cached pages of {fetched}, {len(pages)} pages')
        releases = [r for p in pages for r in p]
        print(f'{len(releases)} releases in the archive')
        write_raw(releases, fetched, set(a.include), cached_on)
    build_table()


if __name__ == '__main__':
    main()

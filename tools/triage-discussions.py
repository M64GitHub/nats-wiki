#!/usr/bin/env python3
"""Build inbox/gh-discussions-toc.md — one row per nats-io/nats-server GitHub discussion.

    python3 tools/triage-discussions.py                  # fetch today's index into raw/, then build the table
    python3 tools/triage-discussions.py --offline        # rebuild the table from the newest index already in raw/
    python3 tools/triage-discussions.py --with-comments  # also cache every thread's comments and replies in
                                                         # local/scratch/gh-index/ (for grepping; never cited)

The index is fetched through `gh api graphql` (`repository.discussions`, 100 per page, ascending by
creation): number, title, URL, category, author, opened, last updated, whether an answer was chosen
and by whom, upvotes, comment count, closed, labels, and the original post's body. Every reply page is
written verbatim to raw/gh-discussions-index/discussions-<DATE>-p<n>.json, and one rendering —
discussions-<DATE>.md, a `## gh#<n> — <title>` section per thread with its meta line and original
post — is written next to them, so the viewer can serve it and the table can anchor into it
(wiki.json → raw_collections → article_pattern). raw/ is immutable: a set that exists for today is
not overwritten; use --offline to rebuild from it.

The table's columns: # · title · category · opened · answered · upvotes · comments · area · bank ·
flags · link · file · summary. `area` is guessed from the title's keywords (AREA_WORDS) and says so
in the table head. `bank` lists the question-bank rows whose *asked at* names the thread. Flags:

    answered   an answer was chosen (Q&A only; the other categories cannot be answered)
    upvoted    upvotes >= 2 — a discussion opens with its author's own upvote, so 2 means somebody else
    design     the title has a design shape (DESIGN_RE): vs / or … ?, best practice, how should,
               recommended, architecture, pattern, strategy, multi-tenant, one X per Y, …
    in-bank    a question-bank row already cites the thread
    in-raw     raw/gh-discussions/gh-<n>.md holds the full thread
    skip       category Polls or Show and tell — outside this wiki's focus
    ★          the triage star, STAR() below: answered and upvoted, or design-shaped and answered.
               The rule is a proposal to tune; it is printed with the counts on every run.

The `summary` column is preserved from the existing table on re-run, and filled from
wiki/summaries/*.md whose `source-url` names the thread. Needs the `gh` CLI, logged in.
"""
import argparse, collections, glob, json, os, re, subprocess, sys
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'raw', 'gh-discussions-index')
THREADS = os.path.join(ROOT, 'raw', 'gh-discussions')
SUMMARIES = os.path.join(ROOT, 'wiki', 'summaries')
BANK = os.path.join(ROOT, 'inbox', 'question-bank.md')
OUT = os.path.join(ROOT, 'inbox', 'gh-discussions-toc.md')
SCRATCH = os.path.join(ROOT, 'local', 'scratch', 'gh-index')

LIST_QUERY = """
query($owner:String!, $name:String!, $after:String) {
  rateLimit { cost remaining }
  repository(owner:$owner, name:$name) {
    discussions(first:100, after:$after, orderBy:{field:CREATED_AT, direction:ASC}) {
      totalCount pageInfo { hasNextPage endCursor }
      nodes { number title url createdAt updatedAt closed closedAt isAnswered upvoteCount
        author { login } category { name } answer { author { login } createdAt }
        comments { totalCount } labels(first:10) { nodes { name } } body } } } }
"""
# The comment cache: 25 threads a page, 30 comments and 5 replies each (~45 rate-limit points a page);
# a thread past those bounds is reported, and the scout fetches it whole with tools/fetch-discussion.py.
COMMENTS_QUERY = """
query($owner:String!, $name:String!, $after:String) {
  rateLimit { cost remaining }
  repository(owner:$owner, name:$name) {
    discussions(first:25, after:$after, orderBy:{field:CREATED_AT, direction:ASC}) {
      pageInfo { hasNextPage endCursor }
      nodes { number title url
        comments(first:30) { totalCount
          nodes { author { login } createdAt isAnswer body
            replies(first:5) { totalCount nodes { author { login } createdAt body } } } } } } } }
"""

# area facet guessed from the title — first match wins per group, at most two groups
AREA_WORDS = [
    ('kv', r'\bkv\b|key[- ]?value|watcher'),
    ('objectstore', r'object[- ]?store|\bblob\b|\bchunk'),
    ('interop', r'\bmqtt\b|websocket|kafka|rabbit|\bstan\b|nats[- ]streaming|\bgrpc\b|pulsar|redis|nsq|zeromq|amqp'),
    ('security', r'\bauth|\bjwt|nkey|\bnsc\b|operator|account|permission|\btls\b|\bcert|password|token|callout|resolver|\bacl\b'),
    ('topology', r'leaf[- ]?node|gateway|super[- ]?cluster|\broute|cluster|multi[- ]region|\bregion|\bedge\b|\bmesh\b|\bhub\b|\bspoke'),
    ('monitoring', r'monitor|prometheus|metric|grafana|varz|healthz|\bjsz\b|connz|advisor|surveyor|\balert|\btrac(e|ing)|\blogs?\b|\bnats-top\b'),
    ('deploy', r'kubernetes|\bk8s\b|helm|docker|container|systemd|deploy|install|upgrade|\bconfig|reload|memory|\bcpu\b|\bdisk|sizing|performance|throughput|latency|benchmark|\bram\b|\biops\b'),
    ('jetstream', r'jetstream|\bjs\b|\bstream|consumer|\back\b|redeliver|retention|work[- ]?queue|mirror|\bsource|snapshot|backup|restore|purge|filestore|replica|\braft\b|meta[- ]?layer|leader|durable|ephemeral|dedup|sequence|\bttl\b|schedul'),
    ('clients', r'\bclient|nats\.go|nats\.js|nats\.py|nats\.rs|nats\.net|nats\.c\b|\bjava\b|python|\brust\b|\bc#|\.net|golang|\bgo\b|\bsdk\b|reconnect|node\.?js|typescript|deno|\bruby\b|elixir|swift|\bzig\b'),
    ('core', r'subject|wildcard|queue[- ]group|request|reply|respond|header|payload|core nats|pub/?sub|publish|subscri'),
]
# a design-shaped title: the trade-off is in the question
DESIGN_RE = re.compile(
    r'\bvs\.?\b|\bversus\b|best[- ]practi|how (should|would|do you|do i (design|structure|organi[sz]e|model))'
    r'|how to (design|structure|organi[sz]e|model|architect)|recommend|\badvice|\bapproach|architect'
    r'|\bpattern|strateg|trade-?off|pros and cons|multi-?tenan|per[- ](tenant|service|customer)'
    r'|one (stream|bucket|account|consumer|subject) (per|for|vs)|which (is|one|should|to|way)|should (i|we|one)'
    r'|when to|is it (better|ok|okay|good|advisable|recommended|wise|correct)'
    r'|what is the (best|right|proper|correct|recommended|preferred|idiomatic)|\bdesign|\bmodel(l)?ing\b'
    r'|\bor\b.*\?\s*$', re.I)
SKIP_CATEGORIES = {'Polls', 'Show and tell'}
UPVOTED_AT = 2


def STAR(r):
    """The triage star. Stated here so the head of the table can quote it."""
    return (r['answered'] and r['upvotes'] >= UPVOTED_AT) or (r['design'] and r['answered'])


def gql(query, **vars):
    cmd = ['gh', 'api', 'graphql', '-f', f'query={query}']
    for k, v in vars.items():
        if v is not None:
            cmd += ['-f', f'{k}={v}']
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f'gh api failed: {out.stderr.strip()}')
    data = json.loads(out.stdout)
    if data.get('errors'):
        sys.exit(f'GraphQL error: {data["errors"]}')
    return data


def fetch_pages(query, owner, name, label):
    after, pages = None, []
    while True:
        reply = gql(query, owner=owner, name=name, after=after)
        pages.append(reply)
        d = reply['data']['repository']['discussions']
        rl = reply['data']['rateLimit']
        print(f'{label}: page {len(pages)} — {len(d["nodes"])} threads, cost {rl["cost"]}, remaining {rl["remaining"]}')
        if not d['pageInfo']['hasNextPage']:
            return pages
        after = d['pageInfo']['endCursor']


def login(x):
    return x['login'] if x else 'ghost'


def day(s):
    return (s or '')[:10]


def body(x):
    return (x or '').replace('\r\n', '\n').replace('\r', '\n').strip()


def nodes_of(pages):
    return [n for p in pages for n in p['data']['repository']['discussions']['nodes']]


def render_index(nodes, owner, name, fetched):
    out = [f'<!-- source: https://github.com/{owner}/{name}/discussions (GitHub GraphQL API, repository.discussions) · fetched {fetched} -->',
           f'# {owner}/{name} discussions — index fetched {fetched}', '',
           f'{len(nodes)} threads, ascending by creation date: the meta line and the original post of each. '
           f'Comments and replies are not here; a thread that matters is fetched whole into raw/gh-discussions/ '
           f'with tools/fetch-discussion.py. Generated by tools/triage-discussions.py.', '']
    for n in nodes:
        ans = n.get('answer')
        answered = f'yes (@{login(ans["author"])}, {day(ans["createdAt"])})' if ans else ('no' if n['isAnswered'] is not None else 'n/a')
        labels = ', '.join(l['name'] for l in n['labels']['nodes']) or '—'
        out += [f'## gh#{n["number"]} — {n["title"].strip()}', '',
                f'Category: {n["category"]["name"]} · opened {day(n["createdAt"])} by @{login(n["author"])} · '
                f'updated {day(n["updatedAt"])} · answer chosen: {answered} · comments: {n["comments"]["totalCount"]} · '
                f'closed: {day(n["closedAt"]) or "no"} · upvotes: {n["upvoteCount"]} · labels: {labels} · {n["url"]}', '',
                body(n['body']), '']
    return '\n'.join(out)


def render_threads(nodes, fetched):
    """The scratch rendering of comments and replies — for grep, never for citation."""
    out = [f'<!-- comments and replies cache, fetched {fetched}; a cache, never a source (local/CLAUDE-MD-EXTENSION.md) -->', '']
    trunc = []
    for n in nodes:
        c = n['comments']
        out += [f'## gh#{n["number"]} — {n["title"].strip()}', '', f'{n["url"]} · comments: {c["totalCount"]}', '']
        if c['totalCount'] > len(c['nodes']):
            trunc.append((n['number'], 'comments', c['totalCount']))
        for cm in c['nodes']:
            mark = ' · **chosen answer**' if cm.get('isAnswer') else ''
            out += [f'### Comment — @{login(cm["author"])} ({day(cm["createdAt"])}){mark}', '', body(cm['body']), '']
            if cm['replies']['totalCount'] > len(cm['replies']['nodes']):
                trunc.append((n['number'], 'replies', cm['replies']['totalCount']))
            for r in cm['replies']['nodes']:
                out += [f'#### Reply — @{login(r["author"])} ({day(r["createdAt"])})', '', body(r['body']), '']
    return '\n'.join(out), trunc


def newest_set():
    dates = sorted({m.group(1) for f in glob.glob(os.path.join(RAW, 'discussions-*-p*.json'))
                    for m in [re.search(r'discussions-(\d{4}-\d{2}-\d{2})-p\d+\.json$', f)] if m})
    if not dates:
        sys.exit(f'no index in {RAW}; run without --offline first')
    d = dates[-1]
    files = sorted(glob.glob(os.path.join(RAW, f'discussions-{d}-p*.json')),
                   key=lambda f: int(re.search(r'-p(\d+)\.json$', f).group(1)))
    return d, [json.load(open(f, encoding='utf-8')) for f in files]


def guess_area(title):
    found = []
    for area, pat in AREA_WORDS:
        if re.search(pat, title, re.I):
            found.append(area)
        if len(found) == 2:
            break
    return ' '.join(found)


def bank_rows():
    """discussion number -> the bank rows whose *asked at* cites it."""
    rows = collections.defaultdict(list)
    if not os.path.exists(BANK):
        return rows
    for line in open(BANK, encoding='utf-8'):
        m = re.match(r'^\|\s*(\d+)\s*\|', line)
        if not m:
            continue
        for n in re.findall(r'nats-server/discussions/(\d+)', line):
            rows[int(n)].append(m.group(1))
    return rows


def summary_links():
    """discussion number -> [[summary slugs]] whose frontmatter source-url names it."""
    links = collections.defaultdict(list)
    for path in sorted(glob.glob(os.path.join(SUMMARIES, '*.md'))):
        head = open(path, encoding='utf-8').read(3000)
        for n in re.findall(r'^source-url:.*nats-server/discussions/(\d+)', head, re.M):
            links[int(n)].append('[[' + os.path.basename(path)[:-3] + ']]')
    return links


def previous_summaries():
    keep = {}
    if not os.path.exists(OUT):
        return keep
    for line in open(OUT, encoding='utf-8'):
        if not line.startswith('|'):
            continue
        c = [x.strip() for x in line.strip().strip('|').split('|')]
        if len(c) >= 13 and re.match(r'^\d+$', c[0]):
            keep[c[0]] = c[12]
    return keep


def cell(s):
    return re.sub(r'\s+', ' ', (s or '').replace('|', '\\|')).strip()


def build_table(nodes, fetched, index_file):
    keep, bank, links = previous_summaries(), bank_rows(), summary_links()
    rows = []
    for n in nodes:
        num = n['number']
        title = n['title'].strip()
        ans = n.get('answer')
        r = {'n': num, 'title': cell(title), 'category': n['category']['name'], 'opened': day(n['createdAt']),
             'answered': ans is not None, 'answered_by': f'yes (@{login(ans["author"])}, {day(ans["createdAt"])})' if ans
             else ('no' if n['isAnswered'] is not None else 'n/a'),
             'upvotes': n['upvoteCount'], 'comments': n['comments']['totalCount'],
             'area': guess_area(title), 'design': bool(DESIGN_RE.search(title)),
             'bank': ' · '.join(bank.get(num, [])), 'url': n['url'],
             'in_raw': os.path.exists(os.path.join(THREADS, f'gh-{num}.md')),
             'skip': n['category']['name'] in SKIP_CATEGORIES}
        flags = []
        if STAR(r) and not r['skip']:
            flags.append('★')
        if r['answered']:
            flags.append('answered')
        if r['upvotes'] >= UPVOTED_AT:
            flags.append('upvoted')
        if r['design']:
            flags.append('design')
        if r['bank']:
            flags.append('in-bank')
        if r['in_raw']:
            flags.append('in-raw')
        if r['skip']:
            flags.append('skip')
        r['flags'] = ' '.join(flags)
        prev = keep.get(str(num), '')
        auto = [l for l in links.get(num, []) if l not in prev]
        r['summary'] = ' · '.join(x for x in [prev] + auto if x)
        rows.append(r)
    rows.sort(key=lambda r: r['n'])
    c = collections.Counter()
    for r in rows:
        for f in r['flags'].split():
            c[f] += 1
    star_new = sum(1 for r in rows if '★' in r['flags'] and not r['bank'])
    design_new = sum(1 for r in rows if r['design'] and not r['bank'] and not r['skip'])
    head = f"""# Discussions — nats-io/nats-server

One row per GitHub discussion of `nats-io/nats-server`, generated by `tools/triage-discussions.py` from
the index fetched {fetched} into `raw/gh-discussions-index/` (re-run it to refresh; it preserves the
`summary` column and fills it from `wiki/summaries/`). {len(rows)} threads · **{c['★']} flagged ★**
({star_new} not yet in the question bank) · {c['answered']} answered · {c['upvoted']} upvoted ·
{c['design']} design-shaped ({design_new} not yet in the bank) · {c['in-bank']} already cited by a bank
row · {c['in-raw']} fetched whole into `raw/gh-discussions/` · {c['skip']} skip (Polls, Show and tell).

**The ★ rule**, as the script states it: *answered and upvoted (upvotes ≥ {UPVOTED_AT}: a discussion opens with
its author's own upvote), or design-shaped and answered*. `design` is a title regex — the trade-off is
in the question (*vs*, *X or Y?*, *best practice*, *how should*, *recommended*, *architecture*,
*pattern*, *strategy*, *multi-tenant*, *one X per Y* …). `area` is **guessed from the title's
keywords**; correct it on the bank row, not here. `bank` names the question-bank rows whose *asked
at* cites the thread; `answered` is the chosen answer (Q&A only — `n/a` in the other categories).

Ingest a row by fetching the thread whole (`python3 tools/fetch-discussion.py <n> --out
raw/gh-discussions`), writing `wiki/summaries/s-gh-<n>-<slug>.md` with the thread as `source-url`, and
the link appears in the last column on the next run. The title links to the original post in the
index rendering; `link` is the thread on GitHub.

| # | title | category | opened | answered | upvotes | comments | area | bank | flags | link | file | summary |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
"""
    body_ = ''.join(f"| {r['n']} | {r['title']} | {r['category']} | {r['opened']} | {r['answered_by']} | {r['upvotes']} | "
                    f"{r['comments']} | {r['area']} | {r['bank']} | {r['flags']} | [gh#{r['n']}]({r['url']}) | {index_file} | "
                    f"{r['summary']} |\n" for r in rows)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(head + body_)
    print(f'wrote {OUT}: {len(rows)} rows')
    print(f'flags: {dict(c)}')
    print(f'★ not in bank: {star_new} · design-shaped not in bank (not skip): {design_new}')
    print('categories:', dict(collections.Counter(r['category'] for r in rows)))
    print('upvotes:', dict(sorted(collections.Counter(min(r['upvotes'], 10) for r in rows).items())), '(10 = ten or more)')
    print('rule: ★ = (answered and upvotes >= %d) or (design and answered)' % UPVOTED_AT)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--repo', default='nats-io/nats-server')
    ap.add_argument('--offline', action='store_true', help='rebuild the table from the newest index in raw/; no GitHub call')
    ap.add_argument('--with-comments', action='store_true', help='also cache comments and replies under local/scratch/gh-index/')
    a = ap.parse_args()
    owner, name = a.repo.split('/', 1)
    if a.offline:
        fetched, pages = newest_set()
        print(f'offline: index of {fetched}, {len(pages)} pages')
    else:
        fetched = date.today().isoformat()
        os.makedirs(RAW, exist_ok=True)
        if os.path.exists(os.path.join(RAW, f'discussions-{fetched}-p1.json')):
            sys.exit(f'{RAW}/discussions-{fetched}-p*.json exists; raw/ is immutable — use --offline, or wait a day')
        pages = fetch_pages(LIST_QUERY, owner, name, 'index')
        for i, p in enumerate(pages, 1):
            with open(os.path.join(RAW, f'discussions-{fetched}-p{i}.json'), 'w', encoding='utf-8') as f:
                json.dump(p, f, indent=1)
        with open(os.path.join(RAW, f'discussions-{fetched}.md'), 'w', encoding='utf-8') as f:
            f.write(render_index(nodes_of(pages), owner, name, fetched) + '\n')
        print(f'wrote {RAW}/discussions-{fetched}-p1..{len(pages)}.json and discussions-{fetched}.md')
    nodes = nodes_of(pages)
    build_table(nodes, fetched, f'discussions-{fetched}.md')
    if a.with_comments:
        os.makedirs(SCRATCH, exist_ok=True)
        cpages = fetch_pages(COMMENTS_QUERY, owner, name, 'comments')
        today = date.today().isoformat()
        for i, p in enumerate(cpages, 1):
            with open(os.path.join(SCRATCH, f'comments-{today}-p{i}.json'), 'w', encoding='utf-8') as f:
                json.dump(p, f, indent=1)
        md, trunc = render_threads(nodes_of(cpages), today)
        with open(os.path.join(SCRATCH, f'threads-{today}.md'), 'w', encoding='utf-8') as f:
            f.write(md + '\n')
        print(f'wrote {SCRATCH}/threads-{today}.md ({len(cpages)} pages); truncated: {len(trunc)}')
        for n, what, total in trunc:
            print(f'  gh#{n}: {total} {what}, more than the cache holds — fetch whole with tools/fetch-discussion.py')


if __name__ == '__main__':
    main()

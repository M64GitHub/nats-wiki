#!/usr/bin/env python3
"""Fetch public GitHub repository facts into raw/github-repos/, one JSON file per repo.

    python3 tools/fetch-repo-facts.py                    # the repos this wiki has entity pages for
    python3 tools/fetch-repo-facts.py nats-io/nats.go    # just these
    python3 tools/fetch-repo-facts.py --readme nats-io/nsc   # also save the README verbatim
    python3 tools/fetch-repo-facts.py --refresh          # re-fetch what is already there
    python3 tools/fetch-repo-facts.py --list             # print the default repo list and exit

Entity pages state facts that go stale — is a client archived, what is its latest release, what
licence is it under. Those facts live in the GitHub API, so they are fetched verbatim rather than
recalled: `repos/<owner>/<name>` and `repos/<owner>/<name>/releases/latest`, saved unmodified as
`<owner>__<name>.json` and `<owner>__<name>.release.json`.

Uses the `gh` CLI so the call is authenticated (60 requests/hour unauthenticated is not enough).
A repo with no published release gets no `.release.json` — that absence is itself a fact.

Existing files are kept unless --refresh: raw/ is immutable, and a refresh is a deliberate act
that changes the date in raw/sources.md. `_index.md` is regenerated every run from whatever JSON
is present, so it always describes the directory.

Downloading is not ingesting: afterwards, add the printed row to `raw/sources.md` and write the
summary page (see CLAUDE.md -> Operation: ingest).
"""
import argparse, base64, json, os, subprocess, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'raw', 'github-repos')

# The repos this wiki writes entity pages for, grouped the way wiki/index.md groups them.
DEFAULT = {
    'client (tier 1)': ['nats-io/nats.go', 'nats-io/nats.js', 'nats-io/nats.py',
                        'nats-io/nats.java', 'nats-io/nats.rs', 'nats-io/nats.net',
                        'nats-io/nats.c'],
    'client (tier 2)': ['nats-io/nats.zig', 'nats-io/nats.swift', 'nats-io/nats-pure.rb',
                        'nats-io/nats.rb', 'nats-io/nats.ex'],
    'orbit': ['synadia-io/orbit.go', 'synadia-io/orbit.js', 'synadia-io/orbit.py',
              'synadia-io/orbit.java', 'synadia-io/orbit.rs', 'synadia-io/orbit.net',
              'synadia-io/orbit.c'],
    'tool': ['nats-io/natscli', 'nats-io/nsc', 'nats-io/nkeys', 'nats-io/nats-top',
             'nats-io/nats-box', 'nats-io/prometheus-nats-exporter', 'nats-io/nats-surveyor',
             'nats-io/k8s', 'nats-io/nack'],
    'repo': ['nats-io/nats-server', 'nats-io/nats-architecture-and-design', 'nats-io/jsm.go',
             'nats-io/nats-streaming-server'],
}


def gh(path):
    """One `gh api` call. Returns (json, error-string). A 404 is data, not a crash."""
    p = subprocess.run(['gh', 'api', path], capture_output=True, text=True)
    if p.returncode != 0:
        return None, (p.stderr.strip().splitlines() or ['failed'])[-1]
    return p.stdout, None


def slug(repo):
    return repo.replace('/', '__')


def fetch(repo, refresh, readme=False):
    base = os.path.join(OUT, slug(repo))
    got = []
    if refresh or not os.path.exists(base + '.json'):
        body, err = gh(f'repos/{repo}')
        if err:
            return f'{repo}: {err}'
        open(base + '.json', 'w').write(body)
        got.append('repo')
    if refresh or not os.path.exists(base + '.release.json'):
        body, err = gh(f'repos/{repo}/releases/latest')
        if err is None:
            open(base + '.release.json', 'w').write(body)
            got.append('release')
        elif '404' not in err:            # no releases at all is normal; anything else is not
            got.append(f'release: {err}')
    if readme and (refresh or not os.path.exists(base + '.README.md')):
        body, err = gh(f'repos/{repo}/readme')
        if err is None:
            d = json.loads(body)
            text = base64.b64decode(d['content']).decode('utf-8', 'replace')
            with open(base + '.README.md', 'w') as f:
                f.write(f'<!-- source: https://github.com/{repo}/blob/{d.get("html_url","").split("/blob/")[-1]}'
                        f' · fetched {datetime.date.today().isoformat()} · {d["name"]} of {repo} -->\n')
                f.write(text)
            got.append('readme')
        elif '404' not in err:
            got.append(f'readme: {err}')
    return f'{repo}: {", ".join(got) if got else "already present"}'


def index():
    """Regenerate _index.md from the JSON on disk. Facts only, all of them from the API."""
    rows, seen = [], {}
    for group, repos in DEFAULT.items():
        for r in repos:
            seen[r] = group
    for name in sorted(os.listdir(OUT)):
        if not name.endswith('.json') or name.endswith('.release.json'):
            continue
        d = json.load(open(os.path.join(OUT, name)))
        rel_path = os.path.join(OUT, name[:-5] + '.release.json')
        rel = json.load(open(rel_path)) if os.path.exists(rel_path) else {}
        full = d.get('full_name', '')
        rows.append('| `{}` | {} | {} | {} | {} | {} | {} |'.format(
            full, seen.get(full, ''), d.get('language') or '—',
            (d.get('license') or {}).get('spdx_id') or '—',
            'yes' if d.get('archived') else 'no',
            '`{}`'.format(rel['tag_name']) if rel.get('tag_name') else '—',
            (rel.get('published_at') or d.get('pushed_at') or '')[:10]))
    today = datetime.date.today().isoformat()
    with open(os.path.join(OUT, '_index.md'), 'w') as f:
        f.write(f'<!-- source: GitHub REST API v3 (`gh api repos/<owner>/<name>` and '
                f'`.../releases/latest`) · fetched {today} · generated by '
                f'tools/fetch-repo-facts.py -->\n')
        f.write('# GitHub repo facts\n\nOne JSON file per repo, verbatim from the API. This '
                'table is regenerated from those files; the JSON is the source.\n'
                'The date column is the latest release\'s publish date, or the last push when '
                'the repo has published no release.\n\n')
        f.write('| repo | role | language | license | archived | latest release | date |\n')
        f.write('|---|---|---|---|---|---|---|\n')
        f.write('\n'.join(rows) + '\n')
    return len(rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('repos', nargs='*', help='owner/name (default: this wiki\'s entity repos)')
    ap.add_argument('--refresh', action='store_true', help='re-fetch files already present')
    ap.add_argument('--readme', action='store_true', help='also save each repo README verbatim')
    ap.add_argument('--list', action='store_true', help='print the default repo list and exit')
    a = ap.parse_args()

    repos = a.repos or [r for g in DEFAULT.values() for r in g]
    if a.list:
        print('\n'.join(repos))
        return 0
    if subprocess.run(['which', 'gh'], capture_output=True).returncode != 0:
        print('needs the `gh` CLI, authenticated (`gh auth status`)', file=sys.stderr)
        return 1
    os.makedirs(OUT, exist_ok=True)
    for r in repos:
        print(fetch(r, a.refresh, a.readme))
    print(f'\n_index.md: {index()} repos')
    print('Now add the row to raw/sources.md and ingest (CLAUDE.md -> Operation: ingest).')
    return 0


if __name__ == '__main__':
    sys.exit(main())

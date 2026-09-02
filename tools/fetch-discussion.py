#!/usr/bin/env python3
"""Fetch GitHub discussions through the GraphQL API and render them the way raw/gh-discussions/ stores them.

    python3 tools/fetch-discussion.py 8001 8333            # nats-io/nats-server, into local/scratch/gh/
    python3 tools/fetch-discussion.py 760 --repo nats-io/k8s
    python3 tools/fetch-discussion.py 8001 --out raw/gh-discussions   # promote at ingest time

Each thread becomes <slug>.json (the raw GraphQL reply) and <slug>.md (the rendering) in --cache;
--render-only re-renders from that JSON without calling GitHub. Bodies are normalised to LF.
The slug is gh-<n> for nats-io/nats-server and <repo-name>-<n> for any other repository, as
raw/sources.md says. With --out the Markdown is also written there, and an existing file is never
overwritten: raw/ is immutable. Needs the `gh` CLI, logged in. Comments and replies are fetched 100
at a time and paged until complete.
"""
import argparse, json, os, subprocess, sys
from datetime import date

QUERY = """
query($owner:String!, $name:String!, $n:Int!, $after:String) {
  repository(owner:$owner, name:$name) {
    discussion(number:$n) {
      number title url category { name } createdAt closedAt upvoteCount isAnswered
      author { login } answer { author { login } createdAt } body
      comments(first:100, after:$after) {
        totalCount pageInfo { hasNextPage endCursor }
        nodes { author { login } createdAt body isAnswer
          replies(first:100) { totalCount pageInfo { hasNextPage endCursor }
            nodes { author { login } createdAt body } } } } } } }
"""
REPLIES_QUERY = """
query($id:ID!, $after:String) {
  node(id:$id) { ... on DiscussionComment {
    replies(first:100, after:$after) { pageInfo { hasNextPage endCursor }
      nodes { author { login } createdAt body } } } } }
"""

def gql(query, **vars):
    cmd = ["gh", "api", "graphql", "-f", f"query={query}"]
    for k, v in vars.items():
        if v is None:
            continue
        cmd += (["-F", f"{k}={v}"] if isinstance(v, int) else ["-f", f"{k}={v}"])
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"gh api failed: {out.stderr.strip()}")
    data = json.loads(out.stdout)
    if data.get("errors"):
        sys.exit(f"GraphQL error: {data['errors']}")
    return data["data"]

def fetch(owner, name, n):
    first = gql(QUERY, owner=owner, name=name, n=n)["repository"]["discussion"]
    if first is None:
        sys.exit(f"{owner}/{name}#{n}: no such discussion")
    comments = first["comments"]
    nodes = list(comments["nodes"])
    page = comments["pageInfo"]
    while page["hasNextPage"]:
        more = gql(QUERY, owner=owner, name=name, n=n, after=page["endCursor"])["repository"]["discussion"]["comments"]
        nodes += more["nodes"]; page = more["pageInfo"]
    first["comments"]["nodes"] = nodes
    # Replies past the first 100 of a comment are rare; the comment id is not in QUERY, so just warn.
    for c in nodes:
        if c["replies"]["pageInfo"]["hasNextPage"]:
            print(f"warning: a comment has more than 100 replies; only the first 100 were fetched", file=sys.stderr)
    return first

def login(x):
    return x["login"] if x else "ghost"

def day(s):
    return (s or "")[:10]

def body(x):
    # GitHub returns bodies with CRLF; the wiki is LF-only.
    return (x or "").replace("\r\n", "\n").replace("\r", "\n").strip()

def render(d, fetched):
    ans = d.get("answer")
    answered = f'yes (@{login(ans["author"])}, {day(ans["createdAt"])})' if ans else "no"
    out = [f'<!-- source: {d["url"]} (GitHub GraphQL API) · fetched {fetched} -->',
           f'# {slug_prefix(d["url"])}#{d["number"]} — {d["title"]}', "",
           f'Category: {d["category"]["name"]} · opened {day(d["createdAt"])} by @{login(d["author"])} · '
           f'answer chosen: {answered} · comments: {d["comments"]["totalCount"]} · '
           f'closed: {day(d["closedAt"]) or "no"} · upvotes: {d["upvoteCount"]}', "",
           "## Original post", "", body(d["body"]), ""]
    for c in d["comments"]["nodes"]:
        mark = " · **chosen answer**" if c.get("isAnswer") else ""
        out += [f'## Comment — @{login(c["author"])} ({day(c["createdAt"])}){mark}', "", body(c["body"]), ""]
        for r in c["replies"]["nodes"]:
            out += [f'### Reply — @{login(r["author"])} ({day(r["createdAt"])})', "", body(r["body"]), ""]
    return "\n".join(out)

def slug_prefix(url):
    # "gh" for the server repo, the repository name otherwise — the convention of raw/sources.md.
    parts = url.split("/")
    owner, name = parts[3], parts[4]
    return "gh" if (owner, name) == ("nats-io", "nats-server") else name

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("numbers", nargs="+", type=int)
    ap.add_argument("--repo", default="nats-io/nats-server")
    ap.add_argument("--cache", default="local/scratch/gh", help="where the JSON and the rendering go")
    ap.add_argument("--out", help="also write the Markdown here (e.g. raw/gh-discussions); never overwrites")
    ap.add_argument("--fetched", help="with --render-only: the date to stamp in the header (default today)")
    ap.add_argument("--render-only", action="store_true", help="do not call GitHub; re-render from the JSON already in --cache")
    a = ap.parse_args()
    owner, name = a.repo.split("/", 1)
    fetched = date.today().isoformat()
    os.makedirs(a.cache, exist_ok=True)
    for n in a.numbers:
        if a.render_only:
            slug = f"{'gh' if (owner, name) == ('nats-io', 'nats-server') else name}-{n}"
            with open(os.path.join(a.cache, slug + ".json")) as f:
                d = json.load(f)["data"]["repository"]["discussion"]
            fetched = a.fetched or fetched
        else:
            d = fetch(owner, name, n)
            slug = f"{slug_prefix(d['url'])}-{n}"
            with open(os.path.join(a.cache, slug + ".json"), "w") as f:
                json.dump({"data": {"repository": {"discussion": d}}}, f, indent=1)
        md = render(d, fetched)
        with open(os.path.join(a.cache, slug + ".md"), "w") as f:
            f.write(md + "\n")
        if a.out:
            os.makedirs(a.out, exist_ok=True)
            target = os.path.join(a.out, slug + ".md")
            if os.path.exists(target):
                print(f"{slug}: {target} exists, not overwritten (raw/ is immutable)", file=sys.stderr)
            else:
                with open(target, "w") as f:
                    f.write(md + "\n")
        replies = sum(len(c["replies"]["nodes"]) for c in d["comments"]["nodes"])
        print(f'{slug}: {d["title"]} · {d["category"]["name"]} · opened {day(d["createdAt"])} · '
              f'answered={"yes" if d["answer"] else "no"} · comments={d["comments"]["totalCount"]} replies={replies} · '
              f'upvotes={d["upvoteCount"]} → {a.cache}/{slug}.md')

if __name__ == "__main__":
    main()

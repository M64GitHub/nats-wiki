# NATS Wiki

An **LLM wiki** — Andrej Karpathy's pattern: a human curates sources and asks questions; an
LLM agent (Claude Code) reads the sources, writes and cross-links the pages, and keeps the whole
thing consistent. The wiki is plain Markdown with `[[wikilinks]]`, browsable in Obsidian or in
the built-in web viewer.

**Focus:** running NATS in production. Everything a solution architect or operator needs to
install, configure, size, cluster, secure, monitor, upgrade and debug `nats-server` and
**JetStream** (with KV and Object Store, which are streams underneath). Internals are covered
where they explain observable behaviour — why a consumer redelivers, why a stream leader moved,
what the filestore does on disk.

**Not covered:** per-language client API documentation (each client gets one entity page pointing
at its own docs), application development guidance, and commercial products beyond a thin "where
they sit" layer. Everything here comes from **public sources only** — docs, repos, release notes,
ADRs, public issues and discussions, blogs, talks and the server source.

Every page that states a default, a limit or a command carries `verified-against:
nats-server <version>` and `verified-on: <date>`. A stale page is worse than a missing one.

## Layout

| path | what |
|---|---|
| `CLAUDE.md` | the maintainer rulebook the agent reads before every operation |
| `wiki.json` | site name, page types/folders, kinds, facets, TOC tables — read by the tools |
| `raw/` | immutable original sources (`raw/sources.md` is the manifest) |
| `inbox/question-bank.md` | the questions the wiki must answer, asked in public or posed by the maintainer — the map and the scoreboard |
| `inbox/adr-toc.md` | one row per ADR of `nats-architecture-and-design` |
| `inbox/config-keys-table.md` | every documented config key with type, default and reload behaviour |
| `inbox/plan-*.md` | the step list a session works through — say `start the plan` |
| `inbox/` | scout results and plans waiting to be processed |
| `tools/` | `build-site.py` (viewer generator, assets in `site-assets/`), `lint.py`, extractors, and the source tools below |
| `tools/fetch-docs.py` | mirror a doc site into `raw/` from its `llms.txt` — here: `python3 tools/fetch-docs.py https://docs.nats.io --collection nats-docs <prefix…>` |
| `tools/build-config-table.py` | turn the generated config reference into `inbox/config-keys-table.md` |
| `tools/triage-adrs.py` | turn `raw/adr/` into `inbox/adr-toc.md` |
| `site/` | generated web viewer (git-ignored; `python3 tools/build-site.py`) |
| `local/` | git-ignored overlay: put your own `CLAUDE-MD-EXTENSION.md` there (what you are working on, local conventions) and the agent reads it after `CLAUDE.md` |
| `wiki/index.md` | catalog of every page — start here |
| `wiki/log.md` | append-only log of every ingest / query / lint |
| `wiki/concepts/` | what a thing is and how it behaves |
| `wiki/internals/` | how the server does it, and what you can observe |
| `wiki/operations/` | runbooks, sizing procedures, deployment patterns (`kind:`) |
| `wiki/gotchas/` | symptom → causes → fix |
| `wiki/reference/` | defaults and limits, config keys, `$JS.API` subjects, endpoints |
| `wiki/entities/` | repos, clients, tools, releases, products, orgs, people (`kind:`) |
| `wiki/summaries/` | one page per ingested source — the citation anchor for every claim |

## Using it

Open Claude Code in this folder and say:

- `ingest <url or path>` — file a source into the wiki
- `triage <collection>` — build a table of contents for a big multi-article collection
- `query <question>` — answer from the wiki with citations and a version
- `lint` — health-check links, orphans, contradictions, stale versions, unanswered questions
- `scout <topic>` — find candidate sources on the web, without ingesting
- `start the plan` — work the newest `inbox/plan-*.md`, step by step, logging as it goes
- `build` — regenerate the viewer (`python3 tools/build-site.py --serve` for a live preview)

## The viewer

```
python3 tools/build-site.py           # renders everything into site/
python3 tools/build-site.py --serve   # …and serves http://127.0.0.1:8080/, rebuilding on change
open site/index.html                  # works from file:// too
```

Zero dependencies. Search with facet filters (`type:`, `kind:`, `tag:`, `area:`, `since:`),
backlinks and a local link graph on every page, a whole-wiki graph, browse by area and version,
wanted (red-link) pages, a health page, every raw source as a line-addressable page, per-tool
cheat sheets, and the question bank, the ADR list and the 621 config keys as filterable tables.

## Page format

Every page has YAML frontmatter (`title`, `type`, `kind`, `area`, `since`, `verified-against`,
`verified-on`, `tags`, `aliases`, `sources`, `created`, `updated`) and links other pages with
`[[slug]]` or `[[slug|text]]`, where `slug` is the filename without `.md`, unique across all wiki
folders. No Obsidian-only syntax is used, so any Markdown renderer that resolves `[[slug]]` can
display it.

## License

The wiki's own pages, summaries and tools are licensed under [Apache-2.0](LICENSE). The originals
under `raw/` belong to their authors and keep their own licenses and copyright notices, recorded per
collection in `raw/sources.md`: Apache-2.0 for the NATS docs, ADRs, server and client source and
repository READMEs; the Synadia blog posts and the CNCF project page are reproduced there as the
maintainer's citation anchors and remain © their owners.

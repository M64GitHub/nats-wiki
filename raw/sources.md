# Raw sources manifest

Immutable originals live in subfolders of `raw/`, one folder per collection. Never edit them
after creation; derived copies (UTF-8 conversions, PDF text extracts) go next to the original
with a suffix (`-utf8.txt`, `.txt`). One row per collection; the viewer shows this table on the
Sources page.

| collection | path | origin | fetched | notes |
|---|---|---|---|---|
| adr | `raw/adr/` | https://github.com/nats-io/nats-architecture-and-design (tarball of `main`) | 2026-08-31 | 54 ADRs plus the repo index (`_repo-index.md`) and the ADR template. Apache-2.0. Triaged into `inbox/adr-toc.md` by `tools/triage-adrs.py`. |
| nats-docs | `raw/nats-docs/` | https://docs.nats.io — paths taken from the site's `llms.txt`, fetched by `tools/fetch-docs.py` | 2026-08-31 | 861 pages of the docs in their Markdown form, mirroring the site tree (`concepts/`, `learn/`, `reference/`, `tutorials/`, `release-notes/`). `reference/config/` (621 pages) is generated from the server, not hand-written — `tools/build-config-table.py` turns it into `inbox/config-keys-table.md`. Docs are versioned; this is the 2.14 (latest) tree. Each file carries a one-line provenance header. Copyright Synadia Communications, Inc. |

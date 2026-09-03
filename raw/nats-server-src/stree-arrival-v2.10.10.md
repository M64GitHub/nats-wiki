<!-- source: https://github.com/nats-io/nats-server — `server/filestore.go` and `server/stree/` at tags v2.10.9 and v2.10.10, read through the GitHub contents API (`repos/nats-io/nats-server/contents/<path>?ref=<tag>`) and the commits API (`commits?path=server/stree/stree.go`) on 2026-09-03 -->
# When the per-subject index became a subject tree: v2.10.10, not v2.10.9

A maintainer answered a question about the number of unique subjects a stream can hold with
"the recent versions of the server, >= 2.10.9, use a modified Adaptive Radix Trie" (nats-server
discussion #5202, in `raw/gh-discussions/`). This wiki repeated "since 2.10.9" on three pages.
The source tree at the two tags says the tree shipped one release later.

## `server/stree/` at each tag

| tag | published | `server/stree/` |
|---|---|---|
| v2.10.8 | 2024-01-10 | absent (`404 Not Found`) |
| v2.10.9 | 2024-01-11 | absent (`404 Not Found`) |
| v2.10.10 | 2024-02-02 | `dump.go helper_test.go leaf.go node.go node16.go node256.go node4.go parts.go stree.go stree_test.go util.go` |
| v2.10.17 | 2024-06-27 | as above plus `node48.go` |

## `fileStore.psim` at each tag

`server/filestore.go` at **v2.10.9**, lines 172–184 (the field is line 179):

```go
	fcfg        FileStoreConfig
	prf         keyGen
	oldprf      keyGen
	aek         cipher.AEAD
	lmb         *msgBlock
	blks        []*msgBlock
	bim         map[uint32]*msgBlock
	psim        map[string]*psi
	tsl         int
	adml        int
	hh          hash.Hash64
	qch         chan struct{}
	fch         chan struct{}
```

The file contains no reference to `stree` at v2.10.9 (0 matches) or v2.10.8 (0 matches).

`server/filestore.go` at **v2.10.10**, lines 172–184 (the field is line 180):

```go
	cfg         FileStreamInfo
	fcfg        FileStoreConfig
	prf         keyGen
	oldprf      keyGen
	aek         cipher.AEAD
	lmb         *msgBlock
	blks        []*msgBlock
	bim         map[uint32]*msgBlock
	psim        *stree.SubjectTree[psi]
	tsl         int
	adml        int
	hh          hash.Hash64
	qch         chan struct{}
```

The three `stree` references at v2.10.10: line 43 `"github.com/nats-io/nats-server/v2/server/stree"`,
line 180 above, line 387 `psim:   stree.NewSubjectTree[psi](),`.

## The commit

The oldest commit touching `server/stree/stree.go`, from the commits API with `until=2024-02-03`:

```
d9235abb 2024-01-20 [IMPROVED] NumPending calculations and subject index memory in filestore (#4960)
```

That PR is the one the v2.10.10 release body lists under *Improved / JetStream*: "NumPending
calculations and subject index memory in filestore and memstore (#4960, #4983)". v2.10.9's body
lists a single fix (#4950). So: **the subject tree is in every release from v2.10.10 on; v2.10.9
still keyed the per-subject index on a Go map.** The maintainer's ">= 2.10.9" was off by one.

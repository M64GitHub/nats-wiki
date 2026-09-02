<!-- source: https://github.com/nats-io/nats.go at tag v1.53.1, jetstream/kv.go and jetstream/object.go fetched from raw.githubusercontent.com · fetched 2026-09-02 -->
# nats.go v1.53.1 — how the KV and object-store clients address a mirrored bucket

Extracted line ranges, verbatim, with their real line numbers at the tag
(`https://github.com/nats-io/nats.go/blob/v1.53.1/jetstream/<file>#L<line>`). Read for step 2 of
`inbox/plan-the-runnable-scouts-2026-09-02.md`, to explain what `raw/nats-server-src/mirrors-observed-v2.14.6.md`
shows: a same-domain KV mirror is not readable by its own bucket name, a cross-domain one is, and an
object-store mirror needs a subject transform the client never adds. The `nats` CLI (0.4.0) uses
this client.

## jetstream/kv.go

### The subject templates


```go
   486		kvBucketNamePre         = "KV_"
   487		kvBucketNameTmpl        = "KV_%s"
   488		kvSubjectsTmpl          = "$KV.%s.>"
   489		kvSubjectsPreTmpl       = "$KV.%s."
   490		kvSubjectsPreDomainTmpl = "%s.$KV.%s."
   491	)
```

### Creating a bucket with `Mirror` set — `MirrorDirect` is forced on, no transform is added


```go
   695		if cfg.Mirror != nil {
   696			// Copy in case we need to make changes so we do not change caller's version.
   697			m := cfg.Mirror.copy()
   698			if !strings.HasPrefix(m.Name, kvBucketNamePre) {
   699				m.Name = fmt.Sprintf(kvBucketNameTmpl, m.Name)
   700			}
   701			scfg.Mirror = m
   702			scfg.MirrorDirect = true
```

### Binding a bucket — the read prefix stays the bucket's own name unless the mirror is `External`

`kv.pre` (reads, watches, listing) is `$KV.<this bucket>.`; only when the mirror carries an
`external.api` prefix is it rewritten to `$KV.<origin>.`. `kv.putPre` (writes) always goes to the
origin.


```go
  1593	func mapStreamToKVS(js *jetStream, pushJS nats.JetStreamContext, stream Stream) *kvs {
  1594		info := stream.CachedInfo()
  1595		bucket := strings.TrimPrefix(info.Config.Name, kvBucketNamePre)
  1596		kv := &kvs{
  1597			name:       bucket,
  1598			streamName: info.Config.Name,
  1599			pre:        fmt.Sprintf(kvSubjectsPreTmpl, bucket),
  1600			js:         js,
  1601			pushJS:     pushJS,
  1602			stream:     stream,
  1603			// Determine if we need to use the JS prefix in front of Put and Delete operations
  1604			useJSPfx:  js.opts.apiPrefix != DefaultAPIPrefix,
  1605			useDirect: info.Config.AllowDirect,
  1606		}
  1607	
  1608		// If we are mirroring, we will have mirror direct on, so just use the mirror name
  1609		// and override use
  1610		if m := info.Config.Mirror; m != nil {
  1611			bucket := strings.TrimPrefix(m.Name, kvBucketNamePre)
  1612			if m.External != nil && m.External.APIPrefix != "" {
  1613				kv.useJSPfx = false
  1614				kv.pre = fmt.Sprintf(kvSubjectsPreTmpl, bucket)
  1615				kv.putPre = fmt.Sprintf(kvSubjectsPreDomainTmpl, m.External.APIPrefix, bucket)
  1616			} else {
  1617				kv.putPre = fmt.Sprintf(kvSubjectsPreTmpl, bucket)
  1618			}
  1619		}
  1620	
```

## jetstream/object.go

### The templates, and binding a bucket by its stream name

`ObjectStore(ctx, bucket)` looks the stream up **by name** (`OBJ_<bucket>`) — the shape nats.go
#1568 introduced in 2024-02 so that a mirror, which answers no subject lookup, can be bound. The
chunk and metadata subjects are then derived from the bucket name, which is why a mirror must carry
`$O.<origin>.>` → `$O.<mirror>.>`.


```go
   478	
   479	const (
   480		objNameTmpl         = "OBJ_%s"     // OBJ_<bucket> // stream name
   481		objAllChunksPreTmpl = "$O.%s.C.>"  // $O.<bucket>.C.> // chunk stream subject
   482		objAllMetaPreTmpl   = "$O.%s.M.>"  // $O.<bucket>.M.> // meta stream subject
   483		objChunksPreTmpl    = "$O.%s.C.%s" // $O.<bucket>.C.<object-nuid> // chunk message subject
```

```go
   598	func (js *jetStream) ObjectStore(ctx context.Context, bucket string) (ObjectStore, error) {
   599		if !validBucketRe.MatchString(bucket) {
   600			return nil, ErrInvalidStoreName
   601		}
   602	
   603		streamName := fmt.Sprintf(objNameTmpl, bucket)
   604		stream, err := js.Stream(ctx, streamName)
   605		if err != nil {
   606			if errors.Is(err, ErrStreamNotFound) {
```

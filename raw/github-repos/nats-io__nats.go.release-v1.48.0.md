<!-- source: https://github.com/nats-io/nats.go/releases/tag/v1.48.0 through the GitHub REST API (`gh api repos/nats-io/nats.go/releases/tags/v1.48.0`) · fetched 2026-09-03 · the release body verbatim (CRLF normalised to LF) -->
# nats.go v1.48.0 — release body

- tag: `v1.48.0` · published: 2025-12-17T13:35:53Z · https://github.com/nats-io/nats.go/releases/tag/v1.48.0

## Changelog

### ADDED
- Core NATS:
  - Add publish subject validation and a connection option to skip it (#1974, #1979)
- KeyValue:
  - Enable custom subject transforms on KV sourcing (#1960)

### FIXED
- JetStream:
  - Fix function pointer check in `js.apiRequestWithContext`. Thanks @svenfoo for the contribution (#1957)
  - Use QueueSubscribe if DeliverGroup is configured on PushConsumer (#1966)
- KeyValue:
  - Fix data race when closing watcher updates channel in kv.go (#1965)

### IMPROVED
- Remove extraneous PullThresholdMessages type definition from README. Thanks @PeterBParker for the contribution (#1959)
- Fix typo in README for service creation method (#1962)
- Mention performance implications of using Consumer.Fetch in docs (#1983)

### Complete Changes

https://github.com/nats-io/nats.go/compare/v1.47.0...v1.48.0

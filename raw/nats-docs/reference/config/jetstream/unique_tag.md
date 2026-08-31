<!-- source: https://docs.nats.io/reference/config/jetstream/unique_tag.md · fetched 2026-08-31 · section: unique_tag -->
# unique\_tag

Requires Restart

Defines a tag prefix as a constraint for placement of assets across a JetStream domain. For example, if the value is `az:` then replicas of an assets will be required to be placed on servers having different `az:` tags.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |

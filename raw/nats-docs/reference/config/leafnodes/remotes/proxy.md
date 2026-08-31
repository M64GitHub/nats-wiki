<!-- source: https://docs.nats.io/reference/config/leafnodes/remotes/proxy.md · fetched 2026-08-31 · section: proxy -->
# proxy

Available since NATS Server `2.12`

Requires Restart

Reach the remote through an HTTP proxy.

## Properties

| Name                                                                | Description                                             | Type       | Default | Reloadable |
| ------------------------------------------------------------------- | ------------------------------------------------------- | ---------- | ------- | ---------- |
| [`url`](/reference/config/leafnodes/remotes/proxy/url.md)           | Proxy URL, e.g. `http://proxy.example.com:3128`.        | `string`   | -       | No         |
| [`username`](/reference/config/leafnodes/remotes/proxy/username.md) | User name for proxy authentication.                     | `string`   | -       | No         |
| [`password`](/reference/config/leafnodes/remotes/proxy/password.md) | Password for proxy authentication.                      | `string`   | -       | No         |
| [`timeout`](/reference/config/leafnodes/remotes/proxy/timeout.md)   | How long to wait for the proxy to establish the tunnel. | `duration` | -       | No         |

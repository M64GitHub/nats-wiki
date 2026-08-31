<!-- source: https://docs.nats.io/reference/config/websocket/same_origin.md · fetched 2026-08-31 · section: same_origin -->
# same\_origin

Requires Restart

This option is relevant for clients used within a Web Browser, such as [nats.js](https://github.com/nats-io/nats.js).

When set to `true`, the HTTP `Origin` header must match the request’s hostname. Refer to [cross-origin resource sharing](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) documentation for more details.

The check only applies when the request carries an `Origin` header, which browsers send and non-browser clients generally do not.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |

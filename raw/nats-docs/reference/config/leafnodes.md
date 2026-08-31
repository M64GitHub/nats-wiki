<!-- source: https://docs.nats.io/reference/config/leafnodes.md · fetched 2026-08-31 · section: leafnodes -->
# leafnodes

Aliases:

<!-- -->

`leaf`

Hot Reloadable

Remotes can be added, removed and re-solicited on reload. Changing the leafnode `host`, `port`, `advertise` or `authorization` fails the reload.

Configuration for setting up leaf node connections.

## Properties

### Incoming Connections

A server that has been configured to *accept* connections from one or more leaf nodes. This would be the *hub* in a hub-and-spoke topology, for example.

| Name                                                                                    | Description                                                                                                         | Type         | Default   | Reloadable |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------ | --------- | ---------- |
| [`host`](/reference/config/leafnodes/host.md)                                           | Host name the server will listen on for incoming leaf node connections.                                             | `string`     | `0.0.0.0` | No         |
| [`port`](/reference/config/leafnodes/port.md)                                           | Port the server will listen for incoming leaf node connections.                                                     | `integer`    | `7422`    | No\*       |
| [`listen`](/reference/config/leafnodes/listen.md)                                       |                                                                                                                     | `string`     | -         | No         |
| [`tls`](/reference/config/leafnodes/tls/.md)                                            | TLS configuration for securing leaf node connections.                                                               | `object`     | -         | Yes\*      |
| [`advertise`](/reference/config/leafnodes/advertise.md)                                 | Hostport to advertise how this sever be contacted by leaf nodes. This is useful for setups with a NAT.              | `string`     | -         | No         |
| [`no_advertise`](/reference/config/leafnodes/no_advertise.md)                           | If true, the server will not be advertised to leaf nodes.                                                           | `boolean`    | `false`   | No         |
| [`authorization`](/reference/config/leafnodes/authorization/.md)                        | Authorization scoped to accepting leaf node connections.                                                            | `object`     | -         | No         |
| [`isolate_leafnode_interest`](/reference/config/leafnodes/isolate_leafnode_interest.md) | Do not propagate subscription interest learned from one leaf node to the others attached to this server.            | `boolean`    | `false`   | No         |
| [`write_deadline`](/reference/config/leafnodes/write_deadline.md)                       | How long a leaf node write may block before the connection is treated as stalled.                                   | `duration`   | `10s`     | No         |
| [`write_timeout`](/reference/config/leafnodes/write_timeout.md)                         | What to do when a leaf node connection misses its `write_deadline`.                                                 | `string`     | `default` | No         |
| [`min_version`](/reference/config/leafnodes/min_version.md)                             | The minimum server version required of the connecting leaf node. This must be at least version `2.8.0`.             | `string`     | -         | No         |
| [`compression`](/reference/config/leafnodes/compression/.md)                            | Defines the compression mode to use for an incoming leafnode connection. If set to `on`, it will use the `s2_auto`. | `(multiple)` | -         | Yes\*      |

\* See the property page for reload caveats.

### Outgoing Connections

A server that has been configured to *connect* to another server configured to accept leaf node connections. In a hub-and-spoke topology, this would be the *spoke*, typically in a remote location or on an edge device.

| Name                                                    | Description                                                                            | Type      | Default | Reloadable |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------- | --------- | ------- | ---------- |
| [`remotes`](/reference/config/leafnodes/remotes/.md)    | List of entries specifiying servers where the leaf node client connection can be made. | `object`  | -       | Yes        |
| [`reconnect`](/reference/config/leafnodes/reconnect.md) | Interval in seconds at which reconnect attempts to a remote server are made.           | `integer` | -       | No         |

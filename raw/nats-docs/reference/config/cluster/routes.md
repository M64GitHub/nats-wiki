<!-- source: https://docs.nats.io/reference/config/cluster/routes.md · fetched 2026-08-31 · section: routes -->
# routes

Hot Reloadable

Routes are diffed on reload: added ones are solicited and removed ones torn down. The cluster listener is not restarted.

A list of server URLs to cluster with. Self-routes are ignored. Should authentication via token or username/password be required, specify them as part of the URL.

## Types

| Type         | Description | Choices |
| ------------ | ----------- | ------- |
| `[ string ]` | -           | -       |

## Examples

### Simple Route URLs

```
routes: [

  nats-route://localhost:6222,

  nats-route://localhost:6223,

  nats-route://localhost:6224,

]
```

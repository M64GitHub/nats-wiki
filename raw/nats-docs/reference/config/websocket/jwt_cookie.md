<!-- source: https://docs.nats.io/reference/config/websocket/jwt_cookie.md · fetched 2026-08-31 · section: jwt_cookie -->
# jwt\_cookie

Requires Restart

Name of the HTTP cookie, that, if present, will be used as a client JWT. The cookie should be set by the HTTP server as described [here](https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies#restrict_access_to_cookies). This setting is useful when generating NATS `Bearer` client JWTs as the result of some authentication mechanism. The HTTP server after correct authentication can issue a JWT for the user, that is set securely preventing access by unintended scripts. Note these JWTs must be [NATS JWTs](https://docs.nats.io/nats-server/configuration/securing_nats/jwt).

**Note:** If the client specifies a JWT in the `CONNECT` protocol, this option is ignored.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |

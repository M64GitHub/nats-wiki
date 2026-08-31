<!-- source: https://docs.nats.io/reference/config/gateway/authorization/default_permissions.md · fetched 2026-08-31 · section: default_permissions -->
# default\_permissions

Ignored Until Restart

Parsed and thrown away; there is no gateway permissions field in the server at any version.

The default permissions applied to users, if permissions are not explicitly defined for them.

## Properties

| Name                                                                                                 | Description                                                                                                                                                                                                   | Type         | Default | Reloadable |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------- | ---------- |
| [`publish`](/reference/config/gateway/authorization/default_permissions/publish/.md)                 | A single subject, list of subjects, or a allow-deny map of subjects for publishing. Specifying a single subject or list of subjects denotes an *allow* and implcitly denies publishing to all other subjects. | `(multiple)` | -       | Ignored    |
| [`subscribe`](/reference/config/gateway/authorization/default_permissions/subscribe/.md)             | A single subject, list of subjects, or a allow-deny map of subjects for subscribing. Note, that the subject permission can have an optional second value declaring a queue name.                              | `(multiple)` | -       | Ignored    |
| [`allow_responses`](/reference/config/gateway/authorization/default_permissions/allow_responses/.md) |                                                                                                                                                                                                               | `(multiple)` | -       | Ignored    |

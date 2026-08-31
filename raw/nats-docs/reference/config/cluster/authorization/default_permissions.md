<!-- source: https://docs.nats.io/reference/config/cluster/authorization/default_permissions.md · fetched 2026-08-31 · section: default_permissions -->
# default\_permissions

Hot Reloadable

Deprecated form; also ignored entirely if a top-level cluster{permissions} block is present (opts.go:2074).

The default permissions applied to users, if permissions are not explicitly defined for them.

## Properties

| Name                                                                                                 | Description                                                                                                                                                                                                   | Type         | Default | Reloadable |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------- | ---------- |
| [`publish`](/reference/config/cluster/authorization/default_permissions/publish/.md)                 | A single subject, list of subjects, or a allow-deny map of subjects for publishing. Specifying a single subject or list of subjects denotes an *allow* and implcitly denies publishing to all other subjects. | `(multiple)` | -       | Yes        |
| [`subscribe`](/reference/config/cluster/authorization/default_permissions/subscribe/.md)             | A single subject, list of subjects, or a allow-deny map of subjects for subscribing. Note, that the subject permission can have an optional second value declaring a queue name.                              | `(multiple)` | -       | Yes        |
| [`allow_responses`](/reference/config/cluster/authorization/default_permissions/allow_responses/.md) |                                                                                                                                                                                                               | `(multiple)` | -       | Ignored\*  |

\* See the property page for reload caveats.

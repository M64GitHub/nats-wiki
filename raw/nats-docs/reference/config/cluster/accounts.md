<!-- source: https://docs.nats.io/reference/config/cluster/accounts.md · fetched 2026-08-31 · section: accounts -->
# accounts

Hot Reloadable

Reload fails if a newly added pinned account cannot be resolved by s.LookupAccount.

A list of accounts to *pin*, each of which will have their own dedicated route connection between servers. Note, this is not take up a connection from the pool.

## Types

| Type         | Description | Choices |
| ------------ | ----------- | ------- |
| `[ string ]` | -           | -       |

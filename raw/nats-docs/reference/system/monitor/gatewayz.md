<!-- source: https://docs.nats.io/reference/system/monitor/gatewayz.md · fetched 2026-08-31 · section: gatewayz -->
# Gatewayz

<!-- -->

## Request Schema

Request options for gatewayz monitoring endpoint

account\_namestring

AccountName will limit the list of accounts to that account name (makes Accounts implicit)

accountsboolean

Accounts indicates if accounts with its interest should be included in the results.

namestring

Name will output only remote gateways with this name

subscriptionsboolean

AccountSubscriptions indicates if subscriptions should be included in the results. Note: This is used only if \`Accounts\` or \`AccountName\` are specified.

subscriptions\_detailboolean

AccountSubscriptionsDetail indicates if subscription details should be included in the results. Note: This is used only if \`Accounts\` or \`AccountName\` are specified.

## Response Schema

Response from gatewayz monitoring endpoint

hoststring

inbound\_gateways{ \[key: string]: object\[] }required

namestring

nowstring\<date-time>required

outbound\_gateways{ \[key: string]: object }required

portinteger

server\_idstringrequired

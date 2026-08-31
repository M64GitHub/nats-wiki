<!-- source: https://docs.nats.io/reference/system/monitor/connz.md · fetched 2026-08-31 · section: connz -->
# Connz

<!-- -->

## Request Schema

Request options for connz monitoring endpoint

accstring

Filter by account.

authboolean

Username indicates if user names should be included in the results.

cidinteger

Filter for this explicit client connection.

filter\_subjectstring

Filter by subject interest

limitinteger

Limit is the maximum number of connections that should be returned by Connz().

mqtt\_clientstring

Filter for this explicit client connection based on the MQTT client ID

offsetinteger

Offset is used for pagination. Connz() only returns connections starting at this offset from the global results.

sortstring

Sort indicates how the results will be sorted. Check SortOpt for possible values. Only the sort by connection ID (ByCid) is ascending, all others are descending.

Allowed values:`cid``start``subs``pending``msgs_to``msgs_from``bytes_to``bytes_from``last``idle``uptime``stop``reason``rtt`

statestring

Filter by connection state.

Allowed values:`open``closed``all`

subscriptionsboolean

Subscriptions indicates if subscriptions should be included in the results.

subscriptions\_detailboolean

SubscriptionsDetail indicates if subscription details should be included in the results

userstring

Filter by username.

## Response Schema

Response from connz monitoring endpoint

Expand All

▶connectionsobject\[]required

limitintegerrequired

nowstring\<date-time>required

num\_connectionsintegerrequired

offsetintegerrequired

server\_idstringrequired

totalintegerrequired

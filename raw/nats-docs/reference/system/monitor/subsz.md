<!-- source: https://docs.nats.io/reference/system/monitor/subsz.md · fetched 2026-08-31 · section: subsz -->
# Subsz

<!-- -->

## Request Schema

Request options for subsz monitoring endpoint

accountstring

Filter based on this account name.

limitinteger

Limit is the maximum number of subscriptions that should be returned by Subsz().

offsetinteger

Offset is used for pagination. Subsz() only returns connections starting at this offset from the global results.

subscriptionsboolean

Subscriptions indicates if subscription details should be included in the results.

teststring

Test the list against this subject. Needs to be literal since it signifies a publish subject. We will only return subscriptions that would match if a message was sent to this subject.

## Response Schema

Response from subsz monitoring endpoint

Expand All

avg\_fanoutnumberrequired

cacheCntinteger

cacheHitsinteger

cache\_hit\_ratenumberrequired

limitintegerrequired

max\_fanoutintegerrequired

nowstring\<date-time>required

num\_cacheintegerrequired

num\_insertsintegerrequired

num\_matchesintegerrequired

num\_removesintegerrequired

num\_subscriptionsintegerrequired

offsetintegerrequired

server\_idstringrequired

▶subscriptions\_listobject\[]

totFanoutinteger

totalintegerrequired

<!-- source: https://docs.nats.io/reference/system/monitor/jsz.md · fetched 2026-08-31 · section: jsz -->
# JSz

<!-- -->

## Request Schema

Request options for jsz monitoring endpoint

accountstring

accountsboolean

configboolean

consumerboolean

direct\_consumerboolean

leader\_onlyboolean

limitinteger

offsetinteger

raftboolean

stream\_leader\_onlyboolean

streamsboolean

## Response Schema

Response from jsz monitoring endpoint

Expand All

▶account\_detailsobject\[]

accountsintegerrequired

▶apiobjectrequired

bytesintegerrequired

▶configobject

consumersintegerrequired

consumers\_leaderinteger

disabledboolean

ha\_assetsintegerrequired

▶limitsobject

memoryintegerrequired

messagesintegerrequired

▶meta\_clusterobject

nowstring\<date-time>required

reserved\_memoryintegerrequired

reserved\_storageintegerrequired

server\_idstringrequired

storageintegerrequired

streamsintegerrequired

streams\_leaderinteger

totalintegerrequired

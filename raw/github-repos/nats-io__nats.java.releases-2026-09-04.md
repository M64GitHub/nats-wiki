<!-- source: https://github.com/nats-io/nats.java through the GitHub REST API (`gh api repos/nats-io/nats.java/releases?per_page=10` and `gh api repos/nats-io/nats.java/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.java — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `2.26.2` — 2.26.2 Minor enhancements — published 2026-08-13

https://github.com/nats-io/nats.java/releases/tag/2.26.2

### Core
* Update the status before tearing the socket down in closeSocket #1609  @scottf

### JetStream
* Fix regression of PublishOptions getStreamTimeout #1611 @utamas @scottf 

### Miscellaneous
* test user pass with special characters fixed to run on all platforms #1605 @scottf 
* Connection Listener Stale State Tests #1607 @scottf 
* Fix Test Flappers #1612 @scottf

---

### `2.26.1` — 2.26.1 Minor connection enhancements — published 2026-08-04

https://github.com/nats-io/nats.java/releases/tag/2.26.1

### Core
* Reset Reader Connection #1592 @scottf 
* Simplify set reader connection #1594 @scottf 
* Count connect failure once per server, not once per resolved IP #1595 @stasimus
* Address forceReconnectImpl reader/writer stop race #1601 @scottf 

### JetStream
* Better exception raising on create consumer #1598 @scottf 

### Miscellaneous
* Additional tests for reader repoint #1593 @scottf 
* Add provider dependency note to readme #1599 @scottf 
* Add docs.nats.io examples to main #1600 @scottf 
* Instructions for Building a Canary #1602 @scottf

---

### `2.26.0` — 2.26.0 Bug fixes, docs and minor enhancements — published 2026-07-09

https://github.com/nats-io/nats.java/releases/tag/2.26.0

### Core
Reconnect Delay Behavior and options cleanup #1578 @scottf 
Advanced Request Behavior Option #1582 @scottf 
Optional individual thread factories for reader and writer #1583 @scottf 
Tidy executor options and additional testing #1590 @scottf 

### JetStream
Handle consume initial subscription failure. #1573 @scottf 
Miscellaneous Improvements based on V3 work #1577 @scottf 
Properly default idle heartbeat during setter. #1580 @scottf 
Consumer Source Field Nullability #1587 @scottf 

### Misc
Add Client and Orbit section, drop duplicate Orbit link #1572 @Jarema 
Change optional skip claude target #1574 @scottf 
Update README.md - Fix example links #1584 @github-pawo

### New Nats Docs
[New Nats Docs Examples] fixed missing marker #1571 @scottf 
[New Nats Docs Examples] Normalize examples host #1575 @scottf

---

### `2.25.3` — 2.25.3 Server 2.14 Support — published 2026-05-07

https://github.com/nats-io/nats.java/releases/tag/2.25.3

### Core
* More schedule headers to match updated server implementation #1543
* Headers object toString bug #1545
* WebSocket masking used % 8 instead of % 4 — #1546
* NatsConnection fine tuning variable access #1547
* Flush Immediately After Publish Fix #1550
* Finds while building J3 #1554

### JetStream
* Update api objects based on schema review #1549
* ObjectInfo getObjectName() should be marked @NonNull #1559
* 2.14 Stream Configuration #1561
* 2.14 Reset Consumer #1562
* Flow Control $JS.FC support #1563
* 2.14 Stream Consumer Source support #1565
* Reset Consumer Test Flapper #1567
* Reset Consumer correct API response and improve test #1568

### Testing
* Fix test, server 2.12.5 allows update max consumers #1538

### Miscellaneous
* Document use of ConsumerInfo management call #1539
* Add Readme index to Consumer Info Calls #1541
* Move examples to subproject #1544

### CI/CD
* Setup claude to only manually trigger #1540
* Testing claude script v2 #1542
* Fix Claude workflow configuration #1551 @Jarema 
* Change claude to always review #1569

### New Nats Docs Examples
* Queue Group Doc Examples were switched #1553
* [New Nats Docs Examples] Complete Missing Examples #1556
* [New Nats Docs Examples] SubjectsSingleWildcard #1557
* [New Nats Docs Examples] Update Single and Multi Wildcard #1558
* [New Nats Docs Examples] Misc Examples Improvements #1560
* [New Nats Docs Examples] Improved Comment #1564
* [New Nats Docs Examples] Fix start marker #1566

---

### `2.25.2` — 2.25.2 Bug Fixes and Housekeeping — published 2026-03-03

https://github.com/nats-io/nats.java/releases/tag/2.25.2

### Core
* fix race condition in reconnect #1523 @scottf @jkraml-staffbase 
* "Payload Size" includes header bytes, not just data #1525 @scottf @francoisprunier
* NatsConnection improvements: reader and writer replace, options executors use #1526 @scottf 
* HostnameResolveMode better organizes the 4 possible modes #1536 @scottf @bartosz822

### JetStream
* Simplification track user processed not client received. #1528 @scottf 
* New Examples for Priority Groups #1529 @roeschter 
* StreamInfo fix active to handle -1 and not supplied correctly #1531 @scottf 

### Testing
* SSL Error Raising Testing #1532 @scottf 
* Cleanup temp files and folders in tests #1534 @scottf 

### Miscellaneous
* Updating Badges #1521 @scottf 
* Housekeeping #1535 @scottf

---

### `2.25.1` — 2.25.1 Options Additions and Message Queue Improvements — published 2026-01-15

https://github.com/nats-io/nats.java/releases/tag/2.25.1

### Core
* Fix setting options via properties #1489 @scottf 
* Lazy initialize Options executors #1492 @scottf 
* Adding flexibility for executor options #1493 @scottf 
* [bug] Properly count message/bytes when in discardWhenFull mode #1498 @scottf 
* Subject validation #1501 @scottf 
* Call to error listener should have been done in a callback, not directly #1502 @scottf 
* Message Queue Splitting #1505 @scottf 
* NatsConnectionReader better ReadListener call #1507 @scottf 
* NatsConnectionReader better exceptions #1509 @scottf 
* Enable path component when connecting via WebSocket #1514 @jbaeck
* Faster JsonValue equals and hashcode #1517 @scottf 

### Object Store
* Object Store purge on re-put #1491 @scottf 

### Miscellaneous
* Documenting Uber Jar and fixing example class usages. #1496 @scottf 
* Fix Flapper Test testSocketDataPortTimeout #1500 @scottf 
* Subject validation readme and backfill #1503 @scottf 
* Doc examples #1508 @scottf 
* Fix line ends #1511 @scottf 
* Doc examples #1513 @scottf

---

### `2.24.1` — 2.24.1 Minor and Automatic-Module-Name — published 2025-11-24

https://github.com/nats-io/nats.java/releases/tag/2.24.1

### Build
* Fix removed Automatic-Module-Name #1486 @scottf @derklaro

### Core
* Properly unsubscribe from dispatcher subject #1483 @scottf 
* Internal Options Executor Awareness #1484 @scottf

---

### `2.24.0` — 2.24.0 — published 2025-11-10

https://github.com/nats-io/nats.java/releases/tag/2.24.0

### Core
* [BUG] Properly return pending bytes #1437 @scottf 
* Improve ConnectionListener #1438 @scottf 
* Server Pool Improvement #1443 @scottf 
* Improved reconnect determining when to switch queues #1444 @scottf 
* Improve output queue push locking and error message #1446 @scottf 
* ConnectionListener event time #1448 @scottf 
* Optimize header reading #1449 @scottf 
* Header fine tuning #1451 @scottf 
* Header tuning don't over engineer #1453 @scottf 
* Micro-optimization getBytes(ISO_8859_1) vs getBytes(US_ASCII) #1455 @scottf 
* Reduce calls to stats by combining. #1465 @scottf 
* [BUG] MessageQueue drainTo was not properly copying length and size. #1468 @scottf 
* MessageQueue drainTo more #1469 @scottf 
* Auth Error is allowed to be set before being connected #1475 @scottf 

### JetStream
* Stream Config Persist mode #1436 @scottf 
* Review methods with varargs for proper validation #1456 @scottf 
* [BUG] AccountTier read reserved values as int instead of long #1457 @scottf 
* Handle both wrong last sequence 10071 / 10164 #1463 @scottf 
* Pinned Consumer Support #1472 @scottf 

### Docs
* Fixed the Typo in the Example Code #1450  @sikandar

### Test
* Refactor test to validate issue 1426 #1447 @scottf 
* Additional test coverage #1452 @scottf 
* Demonstrate Pull Status Warning Handling #1454 @scottf 
* Miscellaneous Test Coverage #1460 @scottf 
* Fix and Enable ReconnectTests testForceReconnectQueueBehaviorCheck #1473 @scottf 
* Javadoc Technical Debt #1476 @scottf 

### Build
* Build modifications for Coveralls #1459 @scottf

---

### `2.23.0` — 2.23.0 Server 2.12 Support and Core Socket Customizations — published 2025-09-25

https://github.com/nats-io/nats.java/releases/tag/2.23.0

### Server 2.12 Specific 
* (2.12) All 2.12 PRs combined #1403* @scottf 
    * (2.12) ClusterInfo field updates #1408 @scottf 
    * (2.12) Support Stream Config allow_msg_schedules #1422 @scottf 
    * (2.12) Message Counter support #1423 @scottf 
    * (2.12) Support Batch Publish #1425 @scottf 
    * (2.12) Prioritized Consumer Support #1433 @scottf 

### Core
* Make NatsStatistics public so it can be extended #1414 @scottf 
* Statistics classes improvements #1415 @scottf 
* Lock around access to pending message and byte counts #1416 @scottf 
* Socket Read Timeout remove validation #1417 @scottf 
* Ensure write timeout is not less than 100 nanoseconds #1429 @scottf 
* Options to set underlying socket configuration of SO_SNDBUF and SO_RCVBUF #1432 @scottf 


### JetStream
* Exposed StreamName #1431 @roeschter 

### Misc
* Add getter for ObjectMeta Metadata to ObjectInfo #1418 @scottf 
* Update SocketDataPortBlockSimulator #1430 @scottf

---

### `2.22.0` — 2.22.0 Fixes and catch-up — published 2025-09-05

https://github.com/nats-io/nats.java/releases/tag/2.22.0

### Core
* Expose connection outgoingPendingMessageCount and outgoingPendingBytes #1412 @scottf 

### JetStream
* Add publish header "Nats-Expected-Last-Subject-Sequence-Subject" #1401 @scottf 
* Add publish header "Nats-Expected-Last-Subject-Sequence-Subject" part b. #1402 @scottf 
* [Fix] Reset cached consumer info when re-making ordered consumers #1405 @scottf 
* consumers - metadata comparison #1410 @scottf 

### ObjectStore
* ObjectMeta metadata #1399 @scottf 

### Misc
* Clarify documentation for JetStreamSubscription #1400 @davidmorley 
* Build (CI/CD) Stuff #1404 @scottf 
* Update version of bouncycastle to resolve CVE-2025-9341 #1406 @vkolomeyko

---

## Open issues at 2026-09-04 (4) — number, opened, title

- #1616 — 2026-08-18 — drain() future completes true even when the drain timed out
- #1596 — 2026-07-13 — Ordered consumer create failures throw unrelated exception
- #1579 — 2026-06-11 — Provide KV Configuration builder from Json
- #1576 — 2026-05-22 — NatsJetStreamPullSubscription.iterate() can block far beyond `maxWait` under high subject cardinality

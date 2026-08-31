<!-- source: https://github.com/nats-io/nats-server/issues/5871 (GitHub GraphQL API) · fetched 2026-08-31 -->
# nats-server issue #5871 — Dynamic config of JetStream file store does not account for its own space taken after restart

State: CLOSED — closed, no linked PR · opened 2024-09-10 by @rafsawicki

## Original post

### Observed behavior

It seems that when NATS starts up, it sets the default JetStream store size limit to 75% of a free disk space if it's not specified in the config, without taking into account size of files that it has created. This behavior seems dangerous, as it can result with a server being unable to start after a restart, despite having a free space on the drive itself, due to stream size limits.

### Expected behavior

NATS should either take into account how much data was created by it when setting the default limit, or simply default to some percentage of total disk space, instead of the currently taken percentage.

### Server and client version

2.10.20

### Host environment

_No response_

### Steps to reproduce

1. Start NATS server with 512MB of empty storage attached, which results in a file store limit of 338MB
2. Create a stream with a limit of 300 MB
3. Send enough messages to fill in 250 MB storage in a stream
4. Restart a NATS server
5. A server sets a file store limit of 196 MB and then refuses to start, as it's unable to restore a stream with an error `insufficient storage resources available (10047)`

## Comment — @derekcollison (2024-09-10)

We do not recommend auto-sizing for real world production uses. You should always configure JetStream to use as much disk as you want / need explicitly in the configuration.

Auto detection is for development and testing.

## Comment — @rafsawicki (2024-09-11)

Thank you for the response.

Is this recommendation to avoid the default value mentioned anywhere in the docs? I've read through most of them related to server configuration I believe (including server configuration in beta docs, where some descriptions are more up to date) and don't recall seeing it, but maybe I've simply missed it. If not, it might be worth explicitly mentioning it there, or maybe even printing a warning in the console during the startup if unsafe defaults are used.

Since our configuration file is quite minimal, there's a chance we're using some other unsafe defaults - is there a place where I can look to know if there are any other defaults that are explicitly not safe for production? Obviously some default values might simply not be optimal in all scenarios, but if there are other options that have similar severity as this one (can randomly crash the server during a simple restart if not specified), I would love to be able to find them and make sure they are configured properly.

On a related note, is there a way to specify that NATS should simply use the whole storage, or some percentage of it, as a store limit? We were hoping to not have to manually sync NATS configuration every time we increase the EBS storage size. It also no longer seems to be possible to specify there should be no limit, as setting the value to 0 (as mentioned in the docs) prevents the creation of any stream.

## Comment — @derekcollison (2024-09-11)

Not sure about the docs, but any production system should be explicit about the disk resources it utilizes.

## Comment — @rafsawicki (2024-09-12)

I totally agree on the explicit part. It's simply that with cloud deployment on kubernetes cluster, it would be nice to specify the necessary disk resources in a single place (definition of the attached persistent volume, with nats always using 100% of it), instead of two that must be kept in sync (both volume definition, and nats config), so we've been looking if that's possible without introducing the additional complexity of generating the NATS config file from the template during deployment.

## Comment — @derekcollison (2024-09-12)

Do you use the helm chart?

## Comment — @rafsawicki (2024-09-16)

Yes we do

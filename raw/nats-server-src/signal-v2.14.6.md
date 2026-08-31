<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, server/signal.go and server/const.go fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats-server v2.14.6 — the signal handler

What each signal actually does, read because the docs teach `SIGUSR2` and `SIGHUP` but never state
what `SIGTERM` does *during* a drain, and because `nats-server --signal <command>` maps command
names to signals in a way that surprises. Line numbers are the real ones at v2.14.6:
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/signal.go#L57`.

## server/signal.go — `handleSignal`

```go
    57	func (s *Server) handleSignal(sig os.Signal) {
    58		s.Noticef("Trapped %q signal", sig)
    59		switch sig {
    60		case syscall.SIGINT:
    61			s.Shutdown()
    62			s.WaitForShutdown()
    63			os.Exit(0)
    64		case syscall.SIGTERM:
    65			// Shutdown unless graceful shutdown already in progress.
    66			s.mu.Lock()
    67			ldm := s.ldm
    68			s.mu.Unlock()
    69	
    70			if !ldm {
    71				s.Shutdown()
    72				s.WaitForShutdown()
    73				os.Exit(0)
    74			}
    75		case syscall.SIGUSR1:
    76			// File log re-open for rotating file logs.
    77			s.ReOpenLogFile()
    78		case syscall.SIGUSR2:
    79			go s.lameDuckMode()
    80		case syscall.SIGHUP:
    81			// Config reload.
    82			if err := s.Reload(); err != nil {
    83				s.Errorf("Failed to reload server configuration: %s", err)
    84			}
    85		}
    86	}
    87	
```

## server/signal.go — `CommandToSignal`

```go
   148	// Translates a command to a signal number
   149	func CommandToSignal(command Command) (syscall.Signal, error) {
   150		switch command {
   151		case CommandStop:
   152			return syscall.SIGKILL, nil
   153		case CommandQuit:
   154			return syscall.SIGINT, nil
   155		case CommandReopen:
   156			return syscall.SIGUSR1, nil
   157		case CommandReload:
   158			return syscall.SIGHUP, nil
   159		case commandLDMode:
   160			return syscall.SIGUSR2, nil
   161		case commandTerm:
   162			return syscall.SIGTERM, nil
   163		default:
   164			return 0, fmt.Errorf("unknown signal %q", command)
   165		}
   166	}
```

## server/const.go — the command names

```go
    23	type Command string
    24	
    25	// Valid Command values.
    26	const (
    27		CommandStop   = Command("stop")
    28		CommandQuit   = Command("quit")
    29		CommandReopen = Command("reopen")
    30		CommandReload = Command("reload")
    31	
    32		// private for now
    33		commandLDMode = Command("ldm")
    34		commandTerm   = Command("term")
    35	)
```

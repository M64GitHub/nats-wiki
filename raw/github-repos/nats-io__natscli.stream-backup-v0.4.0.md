<!-- source: https://github.com/nats-io/natscli at tag v0.4.0, cli/stream_command.go fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# natscli v0.4.0 — `nats stream backup` and `nats stream restore`

The flag definitions and the one client-side check, read because
`learn/backup-recovery/stream-backup-restore.md` attributes a CLI error message to the server and
never mentions the three restore flags that make a cross-site restore possible. natscli **v0.4.0**
(released 2026-05-01) is the current release per `raw/github-repos/nats-io__natscli.release.json`.
Line numbers are real at that tag.

## The two commands and every flag they take

```go
   417		strBackup := str.Command("backup", "Creates a backup of a stream over the NATS network").Alias("snapshot").Action(c.backupAction)
   418		strBackup.Tag("scope:user", "impact:ro")
   419		strBackup.Arg("stream", "Stream to backup").Required().StringVar(&c.stream)
   420		strBackup.Arg("target", "Directory to create the backup in").Required().StringVar(&c.backupDirectory)
   421		strBackup.Flag("progress", "Enables or disables progress reporting using a progress bar").Default("true").BoolVar(&c.showProgress)
   422		strBackup.Flag("check", "Checks the stream for health prior to backup").UnNegatableBoolVar(&c.healthCheck)
   423		strBackup.Flag("consumers", "Enable or disable consumer backups").Default("true").BoolVar(&c.snapShotConsumers)
   424		strBackup.Flag("chunk-size", "Sets a specific chunk size that the server will send").StringVar(&c.chunkSize)
   425		strBackup.Flag("window-size", "Sets a specific window size that the server will send").StringVar(&c.wndSize)
   426	
   427		strRestore := str.Command("restore", "Restore a stream over the NATS network").Action(c.restoreAction)
   428		strRestore.Tag("scope:user", "impact:rw")
   429		strRestore.Arg("file", "The directory holding the backup to restore").Required().ExistingDirVar(&c.backupDirectory)
   430		strRestore.Flag("progress", "Enables or disables progress reporting using a progress bar").Default("true").BoolVar(&c.showProgress)
   431		strRestore.Flag("config", "Load a different configuration when restoring the stream").ExistingFileVar(&c.inputFile)
   432		strRestore.Flag("cluster", "Place the stream in a specific cluster").StringVar(&c.placementCluster)
   433		strRestore.Flag("tag", "Place the stream on servers that has specific tags (pass multiple times)").StringsVar(&c.placementTags)
   434		strRestore.Flag("replicas", "Override how many replicas of the data to create").Int64Var(&c.replicas)
```

## The rename check — client-side, and only when `--config` is used

```go
  1296		}
  1297	
  1298		if c.inputFile != "" {
  1299			cfg, err = c.loadConfigFile(c.inputFile)
  1300			if err != nil {
  1301				return err
  1302			}
  1303	
  1304			// we need to confirm this new config has the same stream
  1305			// name as the snapshot else the server state can get confused
  1306			// see https://github.com/nats-io/nats-server/issues/2850
  1307			if bm.Config.Name != cfg.Name {
  1308				return fmt.Errorf("stream names may not be changed during restore")
  1309			}
  1310		} else {
  1311			cfg = &bm.Config
  1312		}
```

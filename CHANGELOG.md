# Changelog

## v0.8.0 - 2026-10-05

### Fixes

- resolve bugs found in project review (#43) (fa7d4d0)

### Other changes

- Fix retry handling: honour retries, fix undefined scriptstart and writeable check (#49) (e00f53c)
- Fix retry wait time in log message after failed transfer (#48) (563069c)
- install.sh: use the GitHub releases API for all version lookups (#47) (feddcc6)
- README: simplify install instructions (#46) (f3c45c1)

## v0.7.0 - 2026-10-05

### Fixes

- send failure notification when transfer fails (#41) (1b2784d)
- make incomplete->complete move idempotent and log lftp output (#40) (aeaf0cf)

### Other changes

- Release workflow: open release PR and publish after manual merge (#44) (f5b95d8)
- Add release workflow and install from release assets (#42) (3da45a6)
- Update sorting.sh (#39) (be93e3b)

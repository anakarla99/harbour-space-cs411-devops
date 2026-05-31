# PROMPTS.md

## What I asked / decided

- Asked how to move the Jenkinsfile to the root because Jenkins was looking for a branch
  called main/app instead of the file path app/Jenkinsfile
- Decided to use `CGO_ENABLED=0` to produce a static binary after understanding the glibc
  version mismatch error — the build machine runs Ubuntu 24.04 (glibc 2.39) but the target
  runs an older version, so the binary would fail at runtime without this flag
- Asked why `sshagent` was failing → the SSH Agent plugin was not installed in this Jenkins
  instance, so I switched to `withCredentials` with `sshUserPrivateKey` instead
- Copied the binary to `/tmp/` first before moving it to `/usr/local/bin/` because the
  `laborant` user does not have direct write permissions there, but can use `sudo cp` from
  a temp location
- For the stretch task, changed `User=root` to `User=myapp` in the systemd unit to satisfy
  the non-root requirement, and created a dedicated system user with `useradd --system`
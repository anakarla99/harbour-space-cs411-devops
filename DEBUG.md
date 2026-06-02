# DEBUG.md

## Scenario
The pipeline shows green and the "Copy + run on target" stage logs say it succeeded.
From any machine on the network you run `curl http://target:4444/` and get
`Connection refused`. You SSH into target, run `./main` in the foreground. It works,
`curl localhost:4444` returns the expected JSON. The moment you exit the SSH session,
the app dies. Next pipeline run, same thing.

## Hypotheses

**Hypothesis 1 (most likely): The binary is being started in the foreground inside the
SSH session, so it is a child process of the SSH daemon. When the session closes, the
kernel sends SIGHUP to the process group and the app exits.**

There is no process supervisor keeping it alive — the pipeline ran something like
`ssh target './main &'` or `ssh target './main'` without detaching the process from
the session's control group. A process that exists only as long as its parent SSH
session is not supervised; it is just a foreground job that happens to be running
right now.

**Hypothesis 2 (secondary): The app starts correctly but binds only to localhost
(127.0.0.1:4444) instead of all interfaces (0.0.0.0:4444), so it is unreachable
from outside the machine even when the process is running.**

If `http.ListenAndServe` were called with `"localhost:4444"` instead of `":4444"`,
the server would accept connections only from within target itself, making every
external `curl` return `Connection refused` regardless of process supervision.

## Verification steps

**For Hypothesis 1 — run on target while the app is supposed to be running:**
```bash
systemctl status myapp
```
If the service is inactive or failed, systemd never took ownership of the process.
Also check:
```bash
ps aux | grep main
```
If the process disappears the moment you close the SSH session that started it,
the root cause is missing process supervision.

**For Hypothesis 2 — run on target with the app in the foreground:**
```bash
ss -tlnp | grep 4444
```
If the output shows `127.0.0.1:4444` instead of `0.0.0.0:4444` or `*:4444`,
the app is binding only to loopback and will never be reachable from outside.

## Fix
Deploy and start the app as a systemd service so the process lifecycle is owned
by the init system, not by the SSH session:

```bash
# On target, as part of the pipeline deploy stage:
sudo cp /tmp/main /usr/local/bin/myapp
sudo cp /tmp/myapp.service /etc/systemd/system/myapp.service
sudo systemctl daemon-reload
sudo systemctl enable myapp
sudo systemctl restart myapp
```

With this in place, the process survives SSH session termination because systemd
is its parent, not the SSH daemon. Killing the process manually triggers
`Restart=on-failure` and brings it back automatically.

## One-sentence lesson
"Process exists right now" means a binary is running at this moment as a child of
some shell or SSH session; "process is supervised" means a init system like systemd
owns it, restarts it on failure, and keeps it alive independently of who started it
or whether that session is still open.

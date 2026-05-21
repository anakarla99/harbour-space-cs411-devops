# Debug — GLIBC_2.34 not found

## Scenario
The binary `./main` was built on the playground's jenkins machine and runs perfectly there.
When copied to a fresh Ubuntu 18.04 VM and executed, the terminal prints: ./main: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by ./main)

## Hypotheses

**Hypothesis 1 (most likely): The binary is dynamically linked to glibc, and the target
machine has an older glibc version than the one it was compiled against.**

When I ran `file ./main` on the build machine, it showed:
`dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2`

This confirms the binary has a runtime dependency on the host's glibc. The jenkins machine
runs Ubuntu 24.04 (glibc 2.39), but Ubuntu 18.04 ships with glibc 2.27. glibc is
forward-compatible (newer runs old code) but NOT backward-compatible (older cannot satisfy
symbols introduced in newer versions). The binary was linked against glibc 2.34+ symbols,
so it fails on 2.27.

**Hypothesis 2 (secondary): CGO is implicitly enabled, causing the Go `net` package to
link against the system C resolver instead of Go's pure-Go implementation.**

Go's `net` package uses CGO by default on Linux to call the system's `getaddrinfo()`.
This forces a dynamic link against glibc even if no C code was written explicitly. The
developer didn't set `CGO_ENABLED=0`, so the build silently pulled in a glibc dependency.

## Verification steps

**For Hypothesis 1 — run on the customer's Ubuntu 18.04 VM:**
```bash
ldd ./main
```
If it shows `libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6`, the binary is dynamically
linked. Then check the installed version:
```bash
ldd --version
```
If the output shows `2.27` (or any version below `2.34`), this confirms the version
mismatch is the root cause.

**For Hypothesis 2 — run on the build machine before copying the binary:**
```bash
go build -v main.go 2>&1 | grep -i cgo
```
Alternatively, inspect the binary itself:
```bash
objdump -p ./main | grep NEEDED
```
If `libc.so.6` appears in the NEEDED section, CGO introduced the dynamic dependency.

## Fix

Recompile on the jenkins machine with CGO disabled:

```bash
CGO_ENABLED=0 go build -o main main.go
```

Verify the result is now static:
```bash
file ./main
# Should say: statically linked
```

This tells the Go toolchain to use its own pure-Go implementations of `net`, `os/user`,
and other packages that normally delegate to C, producing a binary with zero shared library
dependencies that runs identically on any Linux version regardless of which glibc is installed.

## One-sentence lesson
Go binaries are dynamically linked to the host's glibc by default when CGO is enabled,
and since glibc is forward- but not backward-compatible, a binary built on Ubuntu 24.04
will fail on Ubuntu 18.04 unless you compile with `CGO_ENABLED=0` to produce a truly
static binary that carries all its dependencies inside itself.
# Reflection — introduction-to-builds

## What did I do?
I created a `main.go` file inside the `~/app/` folder containing a Go HTTP server
that listens on port 4444 and returns a JSON response with three fields: Name, 
Description, and Url. I installed the Go compiler with `apt install golang`, compiled
the program with `go build main.go`, and ran it with `./main`. Once the server was 
running, I verified it worked by hitting `curl localhost:4444` from a second terminal,
which returned `{"Name":"Hello","Description":"World","Url":"..."}` as expected.
I then pushed `main.go` to a new GitHub repository on the `main` branch.

For the stretch tasks, I cross-compiled the binary for ARM64 using
`GOOS=linux GOARCH=arm64 go build -o main-arm64 main.go` — no extra toolchain needed,
just two environment variables. I also built a stripped binary with
`go build -ldflags='-s -w' -o main-stripped main.go` and compared sizes with `du -b`.
Finally, I installed Ruby and Sinatra and wrote an equivalent `app.rb` that serves the
same JSON shape on the same port.

## What was most surprising?
The most surprising thing was what `file ./main` vs `file ./main-arm64` revealed about
linking. The x86-64 binary — built normally on my machine — came out **dynamically linked**,
while the ARM64 cross-compiled binary came out **statically linked**, even though I used
the exact same source file and only changed `GOOS` and `GOARCH`. That means the two
binaries have completely different runtime dependencies despite being compiled from
identical source code. The size difference from stripping was also striking: going from
7,281,464 bytes down to 4,964,612 bytes (about 32% smaller) just by dropping debug
symbols, with no change to runtime behavior.

## What's still unclear?
I don't fully understand why the default `go build` on x86-64 produces a dynamically
linked binary while the ARM64 cross-compile produces a static one. I know it has something
to do with CGO being implicitly enabled when building natively (because packages like `net`
use the system's C resolver), but I'm not sure exactly what triggers CGO in one case and
not the other, or whether setting `CGO_ENABLED=0` explicitly would always force static
linking regardless of target architecture.
Core Task: Docker Build and Deploy Pipeline
What I asked
I asked the agent to help me add Docker build and deploy stages to an existing Jenkinsfile
that previously deployed a Go binary directly via SSH and systemd. The goal was to
containerize the app, push it to ttl.sh, and run it on a separate docker VM.

What I decided
Keep the existing Build stage that compiles the Go binary with CGO_ENABLED=0.
Add three new stages: Docker Build, Docker Push, and Deploy.
Use ttl.sh/anakarla99-harbour:2h as the image name — ttl.sh requires no authentication.
Deploy by SSH-ing from the Jenkins VM into the docker VM (laborant@docker) and running
docker pull + docker run -p 4444:4444 there, since the docker VM was not registered
as a Jenkins agent.

What I pushed back on / problems encountered

Initial attempt used agent { label 'docker' } in the Deploy stage, which caused Jenkins
to wait indefinitely for an agent that did not exist in the playground.
Fixed by removing the nested agent declaration and using a plain ssh command from the
Jenkins node into the docker VM.
The SSH connection failed at first because Jenkins runs as the jenkins OS user, not
laborant. Had to generate a new ed25519 key for the jenkins user and add it to
~laborant/.ssh/authorized_keys on the docker VM (required sudo because the file
was read-only).


Stretch Task 1: Multi-Stage Build — Minimal Final Image
What I asked
Replace the single-stage golang:1.24 Dockerfile with a multi-stage build so the final
image is under 50 MB.
What I decided

Build stage: golang:1.24 — compiles the binary with CGO_ENABLED=0 GOOS=linux.
Final stage: alpine:3.19 — chosen over scratch because the HEALTHCHECK directive
requires wget, which is not available in scratch.
The resulting image is well under 50 MB (alpine ~8 MB + static Go binary ~10 MB).

What I pushed back on

First attempt used scratch as the final stage and copied the HEALTHCHECK line directly.
This silently fails because scratch has no shell and no wget, so the healthcheck
command can never execute. Switched to alpine:3.19 with apk add --no-cache wget.


Stretch Task 2: HEALTHCHECK Directive
What I asked
Add a HEALTHCHECK to the Dockerfile so docker inspect reports the container status
as healthy.
What I decided
HEALTHCHECK --interval=10s --timeout=2s CMD wget -qO- http://localhost:4444/ || exit 1
This polls the app's root endpoint every 10 seconds with a 2-second timeout.
Orchestrator behavior — Docker Compose
In Docker Compose, the HEALTHCHECK signal is used by the depends_on directive with
condition: service_healthy. This means a dependent service (e.g., a frontend or a
database migration job) will not start until this container's health status transitions
from starting to healthy. Without the HEALTHCHECK, depends_on only waits for the
container to start, not for the application inside it to be ready.
# PROMPTS.md — Challenge: Deploy to Kubernetes


## Session Log

### 1. Initial setup — understanding what was needed

**What I asked:** I shared the full challenge description and asked the agent to summarize what files and steps were required to complete it.

**What I decided:** To tackle the core task first (Pod running and serving on :4444), then layer in stretch tasks (probes, resource limits) and the debug track (DEBUG.md).

**Reasoning:** The core auto-check is the hard gate — no point writing stretch manifests if the Pod never reaches Running state.

---

### 2. Jenkinsfile — adapting from Docker SSH deploy to Kubernetes

**What I asked:** I shared my existing Jenkinsfile, which deployed via SSH to a Docker host (`docker run`). I asked how to replace that stage with a Kubernetes deploy.

**What I decided:** Keep the existing Build, Docker Build, and Docker Push stages untouched. Replace only the Deploy stage with `kubectl apply`, authenticated via a ServiceAccount token stored in Jenkins Credentials.

**Push-back:** The agent initially suggested using the Kubernetes CLI plugin's `withKubeConfig` block. I pushed back because the lab environment did not have that plugin confirmed, and the simpler approach of passing `--token`, `--server`, and `--insecure-skip-tls-verify` directly to `kubectl` commands was more portable and explicit.

---

### 3. Authentication issue — token not being accepted

**What I asked:** The pipeline kept failing with `the server has asked for the client to provide credentials` even though the token was masked and apparently present.

**What I decided:** The root cause was that `kubectl create token jenkins-robot` generates a short-lived token (default: ~1 hour). By the time I debugged the pipeline, the token had expired.

**Fix applied:** Created a long-lived Secret of type `kubernetes.io/service-account-token` bound to the `jenkins-robot` ServiceAccount, extracted the token with `base64 -d`, and updated the Jenkins Credential. This token does not expire.

**Push-back on agent suggestion:** The agent first suggested `--validate=false` as the fix. I tried it and it did not resolve the issue. I pushed back and asked to dig deeper into why the server was still rejecting credentials — which led to identifying the expired token as the actual root cause.

---

### 4. Pod manifest — adding stretch tasks

**What I asked:** Whether I should add probes and resource limits to the same `pod.yaml` or keep them separate.

**What I decided:** Add both to the same manifest since the auto-checker inspects the live Pod spec, not separate files. This keeps the repo clean and the diff minimal.

**Liveness vs Readiness — what each controls:**
- `livenessProbe` determines whether the container should be **restarted**. If it fails, the kubelet kills and recreates the container. Use it to detect deadlocks or hung processes.
- `readinessProbe` determines whether the Pod should **receive traffic**. If it fails, the Pod is removed from the Service's Endpoints but continues running. Use it to signal that the app is not yet ready to serve (e.g., warming up a cache).

They are not redundant: a Pod can be alive but not ready (warming up), or ready but later become unhealthy (needs restart). Running both gives the cluster independent control over traffic routing and container lifecycle.

---

### 5. Resource requests vs limits — what goes wrong in each case

**What I asked:** What are the real consequences of misconfiguring or omitting resource fields?

**Without requests or limits:** The scheduler has no resource information and may place the Pod on an already-saturated node. Under memory pressure, this Pod is the first candidate for eviction (OOMKill) because it has no guaranteed allocation.

**With limits but no requests:** Kubernetes uses the limit as an implicit request, making the Pod class `Burstable` with an effective request of zero. The scheduler can dangerously overcommit nodes, and the Pod will be evicted first under resource pressure — even if it is behaving normally — because it has no reserved baseline.

**Best practice:** Always set both. Requests define the guaranteed minimum the scheduler uses for placement; limits cap the maximum to protect other workloads on the same node.

---

### 6. Service manifest — why Pod IPs are a poor target for clients

**What I asked:** The stretch task asks for a Service in front of the Pod. I asked what concrete problem this solves.

**What I decided:** Add a ClusterIP Service selecting `app: myapp` targeting port 4444.

**Concrete reason Pod IPs are a bad target:** Pod IPs are ephemeral — they change every time a Pod is rescheduled, crashes and restarts, or is replaced by a rolling update. Any client hardcoded to a Pod IP breaks silently on the next restart. A Service provides a stable virtual IP (ClusterIP) and DNS name (`myapp.default.svc.cluster.local`) that persists regardless of Pod lifecycle, and load-balances across all matching Pods automatically.

---

## What I pushed back on

| Agent suggestion | My decision | Reason |
|---|---|---|
| Use Kubernetes CLI plugin `withKubeConfig` | Pass flags directly to `kubectl` | Plugin availability not confirmed in lab |
| `--validate=false` fixes the credentials error | Investigate the token instead | The error was auth, not schema validation |
| Short-lived token from `kubectl create token` | Long-lived Secret-based token | Pipeline runs may be spaced more than 1 hour apart |
| Separate manifests per stretch task | Single `pod.yaml` with all fields | Auto-checker reads live Pod spec; fewer files, cleaner diff |
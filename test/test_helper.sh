#!/usr/bin/env bash

PASS=0
FAIL=0
TOTAL=0

check() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    echo "  PASS: $1"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $1"
  fi
}

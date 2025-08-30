#!/usr/bin/env bash
set -euo pipefail
env="${1:-dev}"
case "$env" in
  dev)  firebase use default  ;;
  prod) firebase use prod     ;;
  *) echo "usage: $0 [dev|prod]"; exit 1 ;;
esac
firebase use

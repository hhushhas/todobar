#!/bin/zsh

set -euo pipefail

if [[ $# -ne 1 ]]; then
  print -u2 "Usage: $0 <restore-directory>"
  exit 64
fi

project_root="${0:A:h:h}"
manifest="$project_root/release-manifest.json"
restore_directory="$1"
document_item="$(jq -r '.signing.p12DocumentItem' "$manifest")"
expected_hash="$(jq -r '.signing.p12Sha256' "$manifest")"
restore_path="$restore_directory/developer-id.p12"

mkdir -p "$restore_directory"
op document get "$document_item" \
  --vault "Mobile App Releases" \
  --out-file "$restore_path" >/dev/null

actual_hash="$(shasum -a 256 "$restore_path" | awk '{print $1}')"
if [[ "$actual_hash" != "$expected_hash" ]]; then
  print -u2 "Developer ID archive hash mismatch: expected $expected_hash, got $actual_hash"
  exit 1
fi

chmod 600 "$restore_path"
print "Restored Developer ID archive ($actual_hash)"

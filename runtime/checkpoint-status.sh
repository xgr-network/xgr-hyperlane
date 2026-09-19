#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${ROOT}/runtime-state/checkpoints"

echo "--- checkpoint storage ---"
if [[ ! -d "${DIR}" ]]; then
  echo "checkpoint_dir=missing"
  exit 0
fi

echo "checkpoint_dir=present"
count="$(find "${DIR}" -maxdepth 1 -type f | wc -l | tr -d ' ')"
echo "file_count=${count}"

for f in announcement.json index.json metadata_latest.json reorg_flag.json; do
  if [[ -f "${DIR}/${f}" ]]; then
    echo "--- ${f} ---"
    cat "${DIR}/${f}"
    echo
  fi
done

latest="$(find "${DIR}" -maxdepth 1 -type f -name '*_with_id.json' -printf '%f\n' | sort -V | tail -n 1 || true)"
if [[ -n "${latest}" ]]; then
  echo "--- latest_checkpoint_file=${latest} ---"
  cat "${DIR}/${latest}"
  echo
else
  echo "latest_checkpoint_file=none"
fi

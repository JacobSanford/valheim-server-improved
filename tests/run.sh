#!/usr/bin/env bash
# Runs every test file and exits non-zero if any fails.
#
#   tests/run.sh             all tests
#   tests/run.sh --no-image  skip image.test.sh, which needs Docker and the
#                            Valheim image (about 1.4 GB on first pull)
set -uo pipefail
cd "$(dirname "$0")" || exit 1

skip_image=false
[[ "${1:-}" == "--no-image" ]] && skip_image=true

failed=()
for test in *.test.sh; do
  if [[ "${test}" == image.test.sh && "${skip_image}" == true ]]; then
    echo "== ${test}: skipped (--no-image)"
    continue
  fi
  echo "== ${test}"
  bash "${test}" || failed+=("${test}")
done

if (( ${#failed[@]} > 0 )); then
  echo "FAILED: ${failed[*]}"
  exit 1
fi
echo "All test files passed."

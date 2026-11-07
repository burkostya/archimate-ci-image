#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat VERSION)
image=${TEST_IMAGE:-archimate-ci-test}
artifacts=${TEST_OUTPUT:-$PWD/test-results}
mkdir -p "$artifacts"
bash -n entrypoint.sh scripts/*.sh
python3 scripts/check-release.py
docker build --platform linux/amd64 -t "$image:$version" . 2>&1 | tee "$artifacts/build.log"
docker build --platform linux/amd64 -f Dockerfile.rootless \
  --build-arg "ARCHIMATE_CI_IMAGE=$image" --build-arg "ARCHIMATE_CI_VERSION=$version" \
  -t "$image:$version-rootless" . 2>&1 | tee "$artifacts/build-rootless.log"
python3 tests/integration.py "$image:$version" --output "$artifacts/root"
python3 tests/integration.py "$image:$version-rootless" --rootless --output "$artifacts/rootless"

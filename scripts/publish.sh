#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat VERSION)
image=ghcr.io/burkostya/archimate-ci-image
package=archimate-ci-image
metadata=test-results/package.json
mkdir -p test-results

case "${1:?Expected preflight or publish}" in
  preflight)
    # A missing package is expected for the first release. Other API errors fail closed.
    if gh api "/users/burkostya/packages/container/$package" > "$metadata" 2>test-results/package-error.log; then
      gh api --paginate "/users/burkostya/packages/container/$package/versions?per_page=100" \
        --jq '.[].metadata.container.tags[]' > test-results/existing-tags.txt
      if grep -Fxq "$version" test-results/existing-tags.txt || grep -Fxq "$version-rootless" test-results/existing-tags.txt; then
        echo 'Versioned image tags already exist; choose a new release version.' >&2
        exit 1
      fi
    else
      grep -q 'HTTP 404' test-results/package-error.log || { cat test-results/package-error.log >&2; exit 1; }
    fi
    ;;
  publish)
    # Bootstrap the package before assigning immutable release tags. A first
    # release can be rerun after the owner makes this package public.
    candidate="candidate-${GITHUB_SHA:?Missing commit SHA}"
    for suffix in '' '-rootless'; do
      docker tag "$image:$version$suffix" "$image:$candidate$suffix"
      docker push "$image:$candidate$suffix"
    done
    # The package must be public for Docker-based GitHub Actions to use it.
    # GitHub does not expose a visibility write API: configure it in package settings.
    gh api "/users/burkostya/packages/container/$package" > "$metadata"
    if [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["visibility"])' "$metadata")" != public ]; then
      echo "Set https://github.com/users/burkostya/packages/container/$package/settings to Public, then rerun this job." >&2
      exit 1
    fi
    mkdir -p test-results/anonymous-docker
    for suffix in '' '-rootless'; do
      docker push "$image:$version$suffix"
      # Empty Docker config verifies anonymous registry access.
      docker --config "$PWD/test-results/anonymous-docker" manifest inspect "$image:$version$suffix" \
        > "test-results/manifest${suffix}.json"
      docker image inspect --format '{{join .RepoDigests "\n"}}' "$image:$version$suffix" \
        >> test-results/digests.txt
    done
    for suffix in '' '-rootless'; do
      docker tag "$image:$version$suffix" "$image:latest$suffix"
      docker push "$image:latest$suffix"
    done
    {
      archi=$(sed -n 's/^ARG ARCHI_VERSION=//p' Dockerfile)
      coarchi=$(sed -n 's/^ARG COARCHI_VERSION=//p' Dockerfile)
      echo "Archi $archi, coArchi $coarchi. Platform: linux/amd64."
      echo
      echo "Docker images:"
      for suffix in '' '-rootless'; do
        echo "* \`docker pull $image:$version$suffix\`"
      done
      echo
      echo "GitHub Action: \`uses: burkostya/archimate-ci-image@$version\`"
      echo
      echo 'Image digests:'
      cat test-results/digests.txt
      echo
      echo "[Changelog](https://github.com/burkostya/archimate-ci-image/blob/$version/CHANGELOG.md)"
    } > test-results/release.md
    gh release create "$version" --verify-tag --title "$version" --notes-file test-results/release.md
    ;;
  *) echo 'Expected preflight or publish' >&2; exit 1 ;;
esac

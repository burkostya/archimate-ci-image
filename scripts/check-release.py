#!/usr/bin/env python3
"""Fail before publishing if the public image references disagree."""
from pathlib import Path
import re
import sys


def require(condition, message):
    if not condition:
        sys.exit(message)


root = Path(__file__).resolve().parents[1]
version = (root / 'VERSION').read_text().strip()
require(re.fullmatch(r'\d+\.\d+\.\d+-\d+\.\d+\.\d+', version), 'Invalid VERSION format')
if len(sys.argv) > 1:
    require(sys.argv[1] == version, 'Git tag and VERSION differ')
archi = re.search(r'^ARG ARCHI_VERSION=(.+)$', (root / 'Dockerfile').read_text(), re.M)
require(archi and version.split('-')[0] == archi[1], 'Archi and release version differ')
require(f'ARG ARCHIMATE_CI_VERSION={version}\n' in (root / 'Dockerfile.rootless').read_text(),
        'Rootless and release version differ')
require('ARG ARCHIMATE_CI_IMAGE=ghcr.io/burkostya/archimate-ci-image\n' in (root / 'Dockerfile.rootless').read_text(),
        'Unexpected rootless base image')
require(f'image: docker://ghcr.io/burkostya/archimate-ci-image:{version}\n' in (root / 'action.yml').read_text(),
        'Action and release image differ')
print(f'Release versions agree: {version}')

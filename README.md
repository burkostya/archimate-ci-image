# Archimate container image for CI <!-- omit in toc -->

[Archi][Archi repository] container image for use in continuous integration
pipelines. With this container, you can implement automatic report generation
and model export in your pipeline.

The [Archi][] modelling toolkit is targeted toward all levels of Enterprise
Architects and Modellers.

For collaboration with models in the git repository, the [coArchi][] plugin
is installed in the container.

<!-- markdownlint-disable -->
<p align="center" width="100%">
  <img src="https://raw.githubusercontent.com/WoozyMasta/archimate-ci-image/master/extras/scheme.png" />
</p>

For ease of use, the entrypoint.sh script is run in the container,
which processes the environment variables, and the native git client is used
for cloning.

## Table of Contents <!-- omit in toc -->

* [Examples and Demo](#examples-and-demo)
* [Container image](#container-image)
* [Run Container](#run-container)
* [Configuration](#configuration)
  * [GitHub Actions Configuration](#github-actions-configuration)
    * [Variables](#variables)
    * [Inputs](#inputs)
* [GitHub Actions Example](#github-actions-example)
* [GitLab CI Example](#gitlab-ci-example)
* [Build Container](#build-container)
* [Solving Potential Problems](#solving-potential-problems)

## Examples and Demo

[View GitHub Pages demo][demo-gh-pages] | [Example GitHub repository][example-gh]

[View GitLab Pages demo][demo-gl-pages] | [Example GitLab repository][example-gl]

## Container image

This fork packages **Archi 5.10.0** and **coArchi 0.9.8** for `linux/amd64`.
It is maintained independently of [WoozyMasta/archimate-ci-image](https://github.com/WoozyMasta/archimate-ci-image).

You can pull the image from GitHub Container Registry:

* `ghcr.io/burkostya/archimate-ci-image:5.10.0-1.0.7`

And rootless image:

* `ghcr.io/burkostya/archimate-ci-image:5.10.0-1.0.7-rootless`

## Run Container

Example with cloning a remote repository and render HTML report:

```bash
mkdir -p ./report
chmod o+rw ./report

docker run --rm -ti \
  -v $(pwd)/report:/archi/report \
  -e GIT_REPOSITORY=https://github.com/WoozyMasta/archimate-ci-image-example.git \
  -e ARCHI_HTML_REPORT_ENABLED=true \
  -e ARCHI_JASPER_REPORT_ENABLED=false \
  -e ARCHI_CSV_REPORT_ENABLED=true \
  -e ARCHI_EXPORT_MODEL_ENABLED=true \
  ghcr.io/burkostya/archimate-ci-image:5.10.0-1.0.7
```

An example with handling a local repository:

```bash
cd /path/to/exist/repository
mkdir -p ./report
chmod o+rw ./report

docker run --rm -ti \
  -v $(pwd):/archi/project \
  -v $(pwd)/report:/archi/report \
  ghcr.io/burkostya/archimate-ci-image:5.10.0-1.0.7
```

Working with the CLI directly:

```bash
docker run --rm -ti ghcr.io/burkostya/archimate-ci-image:5.10.0-1.0.7 --help
```

Example on how to write preferences:

```bash
mkdir -p ./settings

# Change the setting to increase the resolution of the images in the HTML report.

cat << EOF > ./settings/com.archimatetool.editor.prefs
eclipse.preferences.version=1
scaleImageExport=true
EOF

docker run --rm -ti \
  -v $(pwd)/settings:/root/.archi/.metadata/.plugins/org.eclipse.core.runtime/.settings \
  ...
```

## Configuration

Configuration for connecting to the git repository:

* **`GIT_REPOSITORY`** - Git repository address;
* **`GIT_TOKEN`** - Token for accessing the git repository. Preferred
  for private repositories, or use a key mounted in an ssh container;
* **`GIT_USERNAME`** - Username (_it is better to use token or ssh key_);
* **`GIT_PASSWORD`** - Password (_it is better to use token or ssh key_).

Options for managing model export:

* **`ARCHI_PROJECT_PATH`**=`/archi/project` - The path where the git repository
  with the architectural model will be cloned or connected;
* **`ARCHI_REPORT_PATH`**=`/archi/report` - Path where reports will be saved;
* **`ARCHI_HTML_REPORT_ENABLED`**=`true` - Generate HTML report;
* **`ARCHI_HTML_REPORT_PATH`**=`$ARCHI_REPORT_PATH/html` - Path for save HTML
  report;
* **`ARCHI_JASPER_REPORT_ENABLED`**=`false` - Generate Jasper reports;
* **`ARCHI_JASPER_REPORT_PATH`**=`$ARCHI_REPORT_PATH/jasper` - Path for save
  Jasper report;
* **`ARCHI_JASPER_REPORT_FORMATS`**=`PDF,DOCX` - Formats for Jasper reports
  should be separated by commas. Valid values: `PDF`, `HTML`, `RTF`, `PPT`,
  `ODT`, `DOCX`;
* **`ARCHI_JASPER_REPORT_TITLE`** - The title for the Jasper report, the
  default is the model/project name;
* **`ARCHI_CSV_REPORT_ENABLED`**=`false` - Generate CSV report;
* **`ARCHI_CSV_REPORT_PATH`**=`$ARCHI_REPORT_PATH/csv` - Path for save CSV
  report;
* **`ARCHI_EXPORT_MODEL_ENABLED`**=`true` - Export model in `*.archimate`
  format.
* **`ARCHI_EXPORT_MODEL_PATH`**=`$ARCHI_REPORT_PATH` - Path for save model;
* **`ARCHI_APP`**=`com.archimatetool.commandline.app` application name.
* **`ARCHI_EXTRA_ARGS`** - Additional CLI arguments, split on whitespace; use environment variables for paths containing spaces.
* **`DEBUG`**=`false` - enable `bash -x`

### GitHub Actions Configuration

#### Variables

* **`GITHUB_TOKEN`** - Use default token, or you can set some token from secrret `${{ secrets.ACCESS_TOKEN }}`
* **`GITHUB_SERVER_URL`**=`https://github.com` - GitHub server URL;
* **`GITHUB_PAGES_DOMAIN`** - Custom domain CNAME for pages;
* **`GITHUB_PAGES_BRANCH`**=`gh-pages` - Branch for store reports used in pages;
* **`GIT_SUBTREE_PREFIX`**=`.archi_report` - Directory for store reports in
  model branch.

#### Inputs

All inputs equivalent to environment variables:

* `githubToken` **required**
* `archiHtmlReportEnabled`
* `archiJasperReportEnabled`
* `archiJasperReportFormats`
* `archiJasperReportTitle`
* `archiCsvReportEnabled`
* `archiExportModelEnabled`
* `githubServerURL`
* `githubPagesDomain`
* `githubPagesBranch`
* `gitSubtreePrefix`
* `debugAction`

## GitHub Actions Example

Add a configuration like this to your actions `.github/workflows/main.yml` file:

```yml
jobs:
  archi_report:
    permissions:
      contents: write
      pages: write
    runs-on: ubuntu-latest
    name: Deploy Archi report HTML to GitHub Pages
    steps:
      - name: Check out the repo
        uses: actions/checkout@v7.0.1

      - name: Deploy Archi report
        id: archi
        uses: burkostya/archimate-ci-image@5.10.0-1.0.7
        with:
          archiHtmlReportEnabled: true
          archiJasperReportEnabled: true
          archiJasperReportFormats: PDF,DOCX
          archiCsvReportEnabled: false
          archiExportModelEnabled: true
          githubToken: ${{ secrets.GITHUB_TOKEN }}
```

In the repository settings, set the branch for publishing pages that you
specified in `githubPagesBranch` or the `GITHUB_PAGES_BRANCH` variable
(`gh-pages` by default).

![pages](extras/github_pages.png)

## GitLab CI Example

Add a configuration like this to your `./.gitlab-ci.yml` file:

```yml
pages:
  stage: build
  image:
    name: ghcr.io/burkostya/archimate-ci-image:5.10.0-1.0.7
    entrypoint: [""]

  script:
    - /opt/Archi/entrypoint.sh
    
  variables:
    ARCHI_HTML_REPORT_ENABLED: "true"
    ARCHI_JASPER_REPORT_ENABLED: "true"
    ARCHI_JASPER_REPORT_FORMATS: "PDF,DOCX"
    ARCHI_CSV_REPORT_ENABLED: "false"
    ARCHI_EXPORT_MODEL_ENABLED: "true"

  rules:
    - if: $CI_COMMIT_BRANCH != null || $CI_PIPELINE_SOURCE == "merge_request_event"
      exists:
        - model/folder.xml

  artifacts:
    name: "$CI_JOB_NAME from $CI_PROJECT_NAME on $CI_COMMIT_REF_SLUG"
    expire_in: 30d
    paths:
      - public
```

In GitLab CI if `ARCHI_PROJECT_PATH` is undefined is set to `$CI_PROJECT_DIR`
and all report paths are automatically set to `$CI_PROJECT_DIR/public`

## Build Container

```bash
ARCHI_VERSION=5.10.0
ARCHI_RELEASE_TAG=5.10
COARCHI_VERSION=0.9.8

docker build \
  --tag "archimate-ci-image:$ARCHI_VERSION-dev" \
  --build-arg="ARCHI_VERSION=$ARCHI_VERSION" \
  --build-arg="ARCHI_RELEASE_TAG=$ARCHI_RELEASE_TAG" \
  --build-arg="COARCHI_VERSION=$COARCHI_VERSION" \
  ./

docker build \
  --file Dockerfile.rootless \
  --tag "archimate-ci-image:$ARCHI_VERSION-dev-rootless" \
  --build-arg="ARCHIMATE_CI_IMAGE=archimate-ci-image" \
  --build-arg="ARCHIMATE_CI_VERSION=$ARCHI_VERSION-dev" \
  ./
```

## Verify and release this fork

Run the same builds and integration checks as CI (Docker and Python 3 required):

```bash
scripts/build-test.sh
```

Use a fresh `TEST_OUTPUT` directory for each run. Logs and generated reports are
saved under `test-results/` by default. Tests use an included coArchi model,
exercise both images, and publish Pages only to a temporary local Git remote.
Rootless bind mounts must be writable by UID 1000 (or the UID selected at build).

`VERSION` records the container release. Before tagging, keep it aligned with
`action.yml`, `Dockerfile.rootless`, and the Archi version in `Dockerfile`:

```bash
python3 scripts/check-release.py 5.10.0-1.0.7
```

After merging a verified change, push the matching version tag to trigger the
release workflow. It tests both images before publishing the same built images
to GHCR; Docker Hub credentials are not needed. Versioned tags are never reused.

On the first release GHCR may create a private package. The workflow first pushes
`candidate-<commit>` images and stops before assigning release tags if the package
is private. Set the package visibility to **Public** in
[package settings](https://github.com/users/burkostya/packages/container/archimate-ci-image/settings),
then rerun the workflow. GitHub does not offer a package visibility write API.
After anonymous access is verified, the workflow updates `latest` and
`latest-rootless` and creates a GitHub Release with image digests.

Consumers should pin versioned image or Action tags. To roll back, use the
previous upstream release `ghcr.io/woozymasta/archimate-ci-image:5.7.0-1.0.6`
or `WoozyMasta/archimate-ci-image@5.7.0-1.0.6`. Model repositories are not migrated.

## Solving Potential Problems

If you use podman, unshare mounted volumes to user with id 1000.

```bash
mkdir -p ./report

podman unshare chown 1000 -R $(pwd)/model
podman run --rm -ti \
  -v $(pwd)/report:/archi/report \
  -e GIT_REPOSITORY=https://github.com/WoozyMasta/archimate-ci-image-example.git \
  -e ARCHI_JASPER_REPORT_ENABLED=false \
  ghcr.io/burkostya/archimate-ci-image:5.10.0-1.0.7
```

---

If you are using a private git repository hosted behind a VPN, the tunnel
interface or name resolution might not be available in the container, use the
host network in the container and force the DNS record forward.

```bash
docker run --rm -ti \
  -v $(pwd)/archi:/archi \
  -e GIT_REPOSITORY=https://github.com/WoozyMasta/archimate-ci-image-example.git
  --network=host
  --add-host="$(getent hosts gitlab.internal.tld | awk '{print $2 ":" $1}')"
  ghcr.io/burkostya/archimate-ci-image:5.10.0-1.0.7
```

<!-- links -->

[Archi]: https://www.archimatetool.com "The Open Source modelling toolkit for creating ArchiMate models and sketches."
[Archi repository]: https://github.com/archimatetool/archi "Archi: ArchiMate Modelling Tool"
[coArchi]: https://github.com/archimatetool/archi-modelrepository-plugin "coArchi – Model Collaboration for Archi"

[example-gh]: https://github.com/WoozyMasta/archimate-ci-image-example.git
[demo-gh-pages]: https://woozymasta.github.io/archimate-ci-image-example/?view=6213
[example-gl]: https://gitlab.com/WoozyMasta/archimate-ci-image-example
[demo-gl-pages]: https://woozymasta.gitlab.io/archimate-ci-image-example/?view=6213

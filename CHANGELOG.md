<!-- markdownlint-disable no-duplicate-heading -->
# Changelog

Versioning comes in the form of a double tag, where the first version is the
[Archi][] version, and the second version is the version of the container
itself. For example `4.9.1-1.0.1`

## [Unreleased]

## [5.10.0-1.0.7] - Unreleased

### Changed

* Upgrade Archi to `5.10.0` and coArchi to `0.9.8`.
* Publish this fork to `ghcr.io/burkostya/archimate-ci-image` only.
* Separate the Archi download release tag from the application version.
* Run custom CLI commands with D-Bus and Xvfb, as report generation does.
* Fix export links when HTML and other reports are in different directories.
* Keep shell tracing disabled in GitHub Actions unless DEBUG is enabled.
* Abort on CLI exceptions without opening a blocking Eclipse dialog.
* Fail early when an export directory cannot be created or written.
* Use a fully qualified destination when creating the Pages branch.

### Added

* Root and rootless integration tests with a fixed local coArchi model.
* Pull request verification and a release workflow that publishes tested images.
* Release version consistency checks and anonymous GHCR access checks.


## [5.7.0-1.0.6] - 2025-10-09

### Added

* Support `ARCHI_EXTRA_ARGS` to append custom Archi CLI args

### Changed

* Restore Nav-bar links to reports (again)

## [5.7.0-1.0.5] - 2025-10-09

### Added

* `smsg()` function to hide tokens and passwords in logs
* Eliminating possible li-duplicates
* Fast fail on git subtree split

### Changed

* Restore Nav-bar links to reports
* Update Archi version to `5.7.0` (#21 and upper)
* Update coArchi version to `0.9.4` (#22 and upper)
* Incorrect protocol extraction from URL
* Check for file existence has been added to update_html
* Fragile regexp for validating repo URLs
* Dockerfile use more granular dependencies
* Use `dbus-run-session` for run `xvfb-run`

## [5.0.2-1.0.4] - 2023-05-09

### Changed

* Update Archi version to `5.0.2`
* Update coArchi version to `0.8.7`
* Fix [#7](https://github.com/WoozyMasta/archimate-ci-image/issues/7)
  model name selection changed to use only the first occurrence

### Added

* `DEBUG` env

### Deleted

* Image hosting in the quay.io registry

## [4.9.2-1.0.3] - 2022-02-17

### Changed

* Update Archi version to `4.9.2`
* Update coArchi version to `0.8.2`

## [4.9.1-1.0.2] - 2021-12-20

### Added

* In GitLab CI, if HTML report rendering is enabled, links to other reports
  selected for creation will be added to the HTML report header

## [4.9.1-1.0.1] - 2021-12-20

### Added

* Added improved support for GitLab CI

## [4.9.1-1.0] - 2021-12-15

### Added

* Release of the first finished and working version 🥳

<!-- Links -->
[Archi]: https://github.com/archimatetool/archi "Archi: ArchiMate Modelling Tool"
<!-- Version compare links -->
[Unreleased]: https://github.com/burkostya/archimate-ci-image/compare/5.10.0-1.0.7...HEAD
[5.10.0-1.0.7]: https://github.com/burkostya/archimate-ci-image/compare/5.7.0-1.0.6...5.10.0-1.0.7
[5.0.2-1.0.4]: https://github.com/WoozyMasta/archimate-ci-image/compare/4.9.2-1.0.3...5.0.2-1.0.4
[4.9.2-1.0.3]: https://github.com/WoozyMasta/archimate-ci-image/compare/4.9.1-1.0.2...4.9.2-1.0.3
[4.9.1-1.0.2]: https://github.com/WoozyMasta/archimate-ci-image/compare/4.9.1-1.0.1...4.9.1-1.0.2
[4.9.1-1.0.1]: https://github.com/WoozyMasta/archimate-ci-image/compare/4.9.1-1.0...4.9.1-1.0.1
[4.9.1-1.0]: https://github.com/WoozyMasta/archimate-ci-image/tree/4.9.1-1.0

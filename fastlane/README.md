fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios tests

```sh
[bundle exec] fastlane ios tests
```

Run the unit test suite on the iPhone 17 simulator

### ios setup_match

```sh
[bundle exec] fastlane ios setup_match
```

One-time local setup: generate certs and profiles into the Match repo

### ios build_only

```sh
[bundle exec] fastlane ios build_only
```

Build + private-API scan gate without uploading (for CI validation)

### ios upload_beta

```sh
[bundle exec] fastlane ios upload_beta
```

Build, scan-gate, and upload to TestFlight (no distribution)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

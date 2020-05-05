# NetNewsWire Continuous Integration

CI for NetNewsWire is enabled through Github Actions. The CI workflow configuration (hosted in
[`.github/workflows/build.yml`](https://github.com/brentsimmons/NetNewsWire/blob/master/.github/workflows/build.yml)
uses `xcodebuild` to build the project after syncing the repository and the various submodules.

The build itself focuses on the scheme NetNewsWire for macOS and NetNewsWire-iOS for iOS. Also it leverages the
`NetNewsWire.xcworkspace` configuration.

Private keys, certificates and provisioning profiles are stored in Github under `buildscripts` folder. Decrypting neccessary certificates, copy to build machine keychain and delete the certificates are handled by the [`buildscripts/ci-build.sh`](https://github.com/Ranchero-Software/NetNewsWire/blob/master/buildscripts/ci-build.sh) script.

Each submodule also has it's own CI configuration, which are set up and built from
their own repositories. The submodule CI systems are entirely independent so that
those libraries can grow and change, getting CI verification, indepdent of NetNewsWire.

Build failures are notified to our slack group via [Notify Slack](https://github.com/8398a7/action-slack) GitHub action.

The submodule CI are typically set to run a build and any available tests. Refer to the
project repository for the current and complete list of submodules, but for quick reference:

- [RSCore](https://github.com/brentsimmons/RSCore)![CI](https://github.com/Ranchero-Software/RSCore/workflows/CI/badge.svg)

- [RSWeb](https://github.com/brentsimmons/RSWeb) ![CI](https://github.com/Ranchero-Software/RSWeb/workflows/CI/badge.svg)

- [RSParser](https://github.com/brentsimmons/RSParser)![CI](https://github.com/Ranchero-Software/RSParser/workflows/CI/badge.svg)

- [RSTree](https://github.com/brentsimmons/RSTree)![CI](https://github.com/Ranchero-Software/RSTree/workflows/CI/badge.svg)

- [RSDatabase](https://github.com/brentsimmons/RSDatabase) ![CI](https://github.com/Ranchero-Software/RSDatabase/workflows/CI/badge.svg)

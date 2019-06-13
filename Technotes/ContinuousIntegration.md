# NetNewsWire Continuous Integration

CI for NetNewsWire is enabled through CircleCI, hosted at
<https://circleci.com/gh/brentsimmons/NetNewsWire>. The CI configuration (hosted in
[`.circleci/config.yml`](https://github.com/brentsimmons/NetNewsWire/blob/master/.circleci/config.yml)
uses `xcodebuild` to build the project after syncing the repository and
the various submodules.

As of June 2019, CircleCI offered Xcode 10.2.1, so IOS 13 and Catalina support are not available
via CI as yet.

The build itself focuses on the scheme NetNewsWire and leverages the
`NetNewsWire.xcworkspace` configuration.

Each submodule also has it's own CI configuration, which are set up and built from
their own repositories. The submodule CI systems are entirely independent so that
those libraries can grow and change, getting CI verification, indepdent of NetNewsWire.

The submodule CI are typically set to run a build and any available tests. Refer to the
project repository for the current and complete list of submodules, but for quick reference:

- [RSCore](https://github.com/brentsimmons/RSCore) [![CircleCI](https://circleci.com/gh/brentsimmons/RSCore.svg?style=svg)](https://circleci.com/gh/brentsimmons/RSCore)

- [RSWeb](https://github.com/brentsimmons/RSWeb) [![CircleCI](https://circleci.com/gh/brentsimmons/RSWeb.svg?style=svg)](https://circleci.com/gh/brentsimmons/RSWeb)

- [RSParser](https://github.com/brentsimmons/RSParser) [![CircleCI](https://circleci.com/gh/brentsimmons/RSParser.svg?style=svg)](https://circleci.com/gh/brentsimmons/RSParser)

- [RSTree](https://github.com/brentsimmons/RSTree) [![CircleCI](https://circleci.com/gh/brentsimmons/RSTree.svg?style=svg)](https://circleci.com/gh/brentsimmons/RSTree)

- [RSDatabase](https://github.com/brentsimmons/RSDatabase) [![CircleCI](https://circleci.com/gh/brentsimmons/RSDatabase.svg?style=svg)](https://circleci.com/gh/brentsimmons/RSDatabase)

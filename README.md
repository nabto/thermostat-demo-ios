# Native iOS Nabto Edge Thermostat Control App

Full example application showing how to control a Nabto Edge enabled thermostat device using the Nabto Edge Client SDK for iOS.

The app is written in SwiftUI and Swift 6 with all Nabto SDK access confined to a single actor, `NabtoClient`.

Precompiled version is available for download from the App Store as described in the [guide on docs.nabto.com](https://docs.nabto.com/developer/guides/platforms/ios/thermostat.html).

## Building

Dependencies are resolved with Swift Package Manager and the Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`, so `NabtoEdgeThermostat.xcodeproj` is not checked in.

1. Install XcodeGen: `$ brew install xcodegen`

2. Generate the project: `$ xcodegen generate`

3. Open it and work from there: `$ open NabtoEdgeThermostat.xcodeproj`

Xcode resolves the Swift packages on first open — this needs network access, as the Nabto Edge Client C SDK is downloaded as a binary XCFramework.

To build and test from the command line:

```
xcodebuild -scheme NabtoEdgeThermostat -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme NabtoEdgeThermostat -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Requires iOS 17 or later.

## Dependencies

| Package | Purpose |
|---|---|
| [edge-client-swift](https://github.com/nabto/edge-client-swift) | Nabto Edge Client SDK |
| [edge-iamutil-swift](https://github.com/nabto/edge-iamutil-swift) | Pairing and user management |
| [CBORCoding](https://github.com/SomeRandomiOSDev/CBORCoding) | CBOR encoding of the thermostat CoAP payloads |

## Questions?

In case of questions or problems, please write to support@nabto.com or contact us through the live chat on [www.nabto.com](https://www.nabto.com).

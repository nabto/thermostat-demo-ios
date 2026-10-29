# Native iOS Nabto Edge Thermostat Control App

Full example application showing how to control a Nabto Edge enabled thermostat device using the Nabto Edge Client SDK for iOS.

Precompiled version is available for download from the App Store as described in the [guide on docs.nabto.com](https://docs.nabto.com/developer/guides/platforms/ios/thermostat.html).

## Building

The app uses Swift Package Manager for all dependencies, following the [Nabto iOS SDK installation instructions](https://www.nabto.com/docs/developer/platforms/ios/intro.html). CocoaPods is not required.

1. Open `NabtoEdgeThermostat.xcodeproj` in Xcode.

2. Let Xcode resolve the Swift packages.

3. Select the `Nabto Edge Thermostat` scheme, your signing team and a physical iOS device, then build and run.

The project pins Nabto Edge Client Swift **4.0.2** (C SDK **5.15.5**) and Nabto Edge IAM Util **2.0.1**. CBORCoding (**1.3.2**), NotificationBannerSwift (**3.0.6**), SnapKit (**5.0.1**) and MarqueeLabel (**4.0.5**) retain their previous versions. Commit `NabtoEdgeThermostat.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` when updating packages.

## Questions?

In case of questions or problems, please write to support@nabto.com or contact us through the live chat on [www.nabto.com](https://www.nabto.com).

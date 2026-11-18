# MealWise

MealWise is a native SwiftUI meal planner for iOS 27 and Swift 6. Open `MealWise.xcodeproj` in Xcode, select the shared **MealWise** scheme and run it on an iOS 27 simulator. Tap **Get started** to enter the local walkthrough.

The app uses bundled sample recipes and synthetic grocery prices. Plans, ratings, pantry and history are saved on the current installation so you can close the app and continue later. The simulator demo requires no credentials or backend setup. See the [local walkthrough](docs/presentation-guide.md) and [implementation progress](docs/implementation-progress.md).

```sh
xcodebuild -project MealWise.xcodeproj -scheme MealWise \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -parallel-testing-enabled NO test
```

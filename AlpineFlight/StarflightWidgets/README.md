# Starflight Home Screen widget

The small widget opens the hangar. The medium widget has separate shortcuts for the hangar, Flight planner, and Space free roam. It is an offline launcher: it does not claim to show a live wallet, fuel level, flight, or cloud-save status.

After installing and opening the updated Starflight app on iPhone or iPad:

1. Touch and hold an empty part of the Home Screen.
2. Choose **Edit → Add Widget** (or the **+** button).
3. Search for **Starflight**, select Small or Medium, and choose **Add Widget**.
4. Tap the widget or an individual shortcut to open the game.

If a flight is already in progress, the app handles shortcuts safely: it pauses the flight and asks the player to return to base before switching activity. The widget never starts a flight or spends credits on its own.

## Integration

- Extension source: `StarflightWidget.swift`, a WidgetKit `StaticConfiguration` with kind `StarflightQuickLaunch`.
- URL destinations: `starflight://hangar`, `starflight://planner`, and `starflight://space`.
- Required app target URL scheme: `starflight`.
- Extension point: `com.apple.widgetkit-extension`.
- Target bundle identifier: `com.alpineflight.prototype.widgets`.
- Deployment target: iOS/iPadOS 26.0, device families iPhone and iPad.
- No network requests, tracking, account access, App Group, or additional permission is needed.
- No imported ship models, app font, images, or app code belongs in the extension target. Its visual mark and star field are simple SwiftUI vectors.
- Build with `APPLICATION_EXTENSION_API_ONLY = YES` and `SKIP_INSTALL = YES`; match the app's version/build and signing team.
- Include it in the app target's **Embed App Extensions** phase for iOS only. Exclude it from the Mac Catalyst dependency and embedding phases; macOS desktop widgets need a separate compatible target.

`StarflightWidgetPreviews` provides native small and medium previews. The timeline contains one current entry and requests refresh after six hours; there is no per-frame work or background polling. WidgetKit controls the actual refresh schedule.

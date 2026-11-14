# Starflight icon choices

Settings → Starflight app icon offers Starflight, Original, Hyperspace, and Gold on supported iPhone and iPad installations. These are still images, changed only when the player chooses one. Starflight restores the new primary icon; Original selects the previous primary artwork. iPadOS may show its own icon-change notice.

The system stores the selected icon. The Settings screen reads the actual system selection when opened and after every change; errors are shown without claiming the change succeeded.

While a change is pending, a short monitor checks the actual system selection. It releases the controls when the change appears, or after ten seconds with an explanation, so a delayed system callback cannot leave Settings permanently disabled. The simulator test passed selection, persistence after relaunch, and restoration of Classic with this safeguard.

The Mac Catalyst build currently reports alternate icons unsupported. Its choices are disabled with an explanation. There is no automatic inactivity-driven switch, background icon animation, or widget in this feature.

The two additional designs are original vector starfighter emblems rendered offline by `Tools/create_icon_variants.swift`. Run that script from the project root with `swift Tools/create_icon_variants.swift AlpineFlight/Resources/Assets.xcassets` to regenerate them. It also copies the existing primary icon into the Classic preview. The app does no icon rendering at runtime.

Xcode's Alternate App Icon Sets includes `HyperspaceIcon` and `GoldIcon` in Debug and Release. Check both `CFBundleIcons` and `CFBundleIcons~ipad` in the built Info.plist before shipping. The icon-switching UI test checks selection, persistence after relaunch, and restoring Classic. It explicitly skips a simulator icon-service error only when the simulator reports “Resource temporarily unavailable”; other errors fail the test. Test the full switch on physical hardware before release.

The source catalogue must stay at `AlpineFlight/Resources/Assets.xcassets` and be registered as an asset catalogue in the app resource phase. Placing it inside the copied `BlenderAssets/Ships` folder only bundles its source files; it does not compile the Home Screen icons, previews, or required icon metadata.

The default icon is now `AlpineFlight/Resources/StarflightIcon.icon`, copied from the supplied Icon Composer document. Settings calls it Starflight. The previous primary `AppIcon` asset is retained as the Original alternate, alongside Hyperspace and Gold. Both build configurations compile the Composer document, use StarflightIcon as the primary icon name, and include AppIcon among the alternate names. To refresh its Settings preview after editing the Composer document, export its Default iOS rendition to `Assets.xcassets/IconPreview_standard.imageset/Icon.png` with Icon Composer's ictool. The original source in Downloads is left untouched.

The improved primary icon centres a larger pale metallic emblem over the navy gradient. A separate SVG orbital-accent layer adds restrained arcs and stars; unused off-canvas image layers are no longer referenced. Other selectable icons and the source document in Downloads are unchanged.

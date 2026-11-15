# Embedded widget signing repair — 2026-11-15

## Observed failure

Xcode's failed build log identified StarflightWidgets.appex as ad-hoc signed,
while AlpineFlight.app used Apple Development. The app and widget already had
the same team and distinct bundle identifiers. The widget copy phase did not
request Code Sign On Copy.

A fresh signed build also revealed that the cached app and widget provisioning
profiles admitted only an Apple Development certificate that macOS reported as
revoked. This was not an expiry diagnosis: the inspected profiles had not yet
expired. Their certificate selection was stale.

## Changes

- Enabled CodeSignOnCopy for the existing widget embedding entry, so the
  embedded copy uses the parent app's selected certificate.
- Set shared project defaults in Debug and Release to team 3C594V2263 and
  Apple Development for the iphoneos SDK. All four targets now resolve these
  consistently, including the test bundle and UI-test runner.
- Retained Automatic signing and every existing bundle identifier, capability,
  entitlement, deployment target and target. No manual profile UUID or certificate
  fingerprint is pinned in the project. The Mac-only local ad-hoc override is
  unchanged; it does not apply to iOS and the widget is not embedded on Catalyst.
- Refreshed automatic provisioning using the existing Apple account/team.
  Xcode supplied compatible profiles and a valid development identity. No
  account was changed and no old certificates were deleted or revoked.

## Validation

Debug and Release effective build settings were checked for all four targets:
Automatic, Apple Development, team 3C594V2263, no manual provisioning override.
Bundle identifiers are distinct:

| Target | iOS bundle identifier |
|---|---|
| AlpineFlight | com.alpineflight.prototype |
| StarflightWidgets | com.alpineflight.prototype.widgets |
| AlpineFlightTests | com.alpineflight.prototype.AlpineFlightTests |
| AlpineFlightUITests | com.alpineflight.prototype.AlpineFlightUITests |

The signed generic-iOS Debug build passed, including ValidateEmbeddedBinary.
The app, embedded widget and all four embedded Debug/preview dylibs passed
codesign verification and had the identical leaf certificate SHA-1:
9987BC9E2A36D87176478257317169AE66FE40D0. Both embedded provisioning profiles
allowed that certificate. Aether products are linked statically; the built app
has no separately embedded third-party .framework bundles to re-sign.

## Xcode instructions if a stale warning remains

1. Open AlpineFlight.xcodeproj. Select AlpineFlight under TARGETS, then Signing
   & Capabilities. Leave Automatically manage signing enabled and choose the
   existing team with ID 3C594V2263.
2. Check StarflightWidgets the same way. Do not choose a manual profile; Xcode
   should select its separate widgets provisioning profile automatically.
3. For device Debug builds the signing certificate must be Apple Development,
   not Sign to Run Locally or Apple Distribution. Test targets inherit the same
   development defaults.
4. Select Product > Clean Build Folder (Shift-Command-K), then Run on the phone.
   If Xcode reports an account problem, use Settings > Accounts to refresh the
   existing account; do not switch accounts or delete certificates. If a keychain
   prompt appears, approve it directly on the Mac and keep the password private.

The successful build verifies signing and embedding, not installation or launch
on every connected phone. Release settings were inspected; an archive/distribution
export was not performed.

A second ordinary signed generic-iOS Debug build, without provisioning-refresh
flags, also passed. The attempted Bullet Pad destination build could not start
because that iPad was locked. No device installation or launch is claimed.

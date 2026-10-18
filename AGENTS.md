# Stuffy

iOS app (SwiftUI + SwiftData + CloudKit) for tracking personal belongings: cost, uses, cost per use, what to retire, and a cooling-off wishlist to curb impulse buys. UI is English only for now (use String Catalogs when adding languages).

## Workflow
- MVP phase: commit and push straight to `main`, no PRs.
- Plans and todos live in GitHub issues (`fuermosi777/stuffy-ios`). Reference them in commits (`Closes #N`).
- Design source: Claude Design project `23407821-2259-4035-b5a3-4dbdf4f702ae` (`Stuffy.dc.html`); follow it closely.
- No attribution lines (Claude links, Co-Authored-By) in issues or comments.

## Build and test
- Deployment target is iOS 27.0 and the Mac has no iOS 27 simulator. Do **not** try to run in a simulator; the owner tests on simulator/device.
- Verify changes by compiling only: `xcodebuild -project Stuffy.xcodeproj -scheme Stuffy -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- Don't lower the deployment target.

## Code conventions
- Models in `Stuffy/Models`, theme and shared components in `Stuffy/Theme`, screens in `Stuffy/Views`. The Xcode project uses synchronized folders: just add files, don't edit the pbxproj.
- SwiftData models must stay CloudKit-compatible: defaults on every property, optional relationships with inverses, no `@Attribute(.unique)`.
- Money and cost formatting go through `fmt` / `money` in `Theme.swift`; value colors through `ValueTone`.
- Terms: "wear" is the user-facing word for a use; code says `uses`. Retire = archived by the user; Sold records resale price and lowers net cost.

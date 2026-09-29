# Sandbox feasibility and App Store preparation

DockChord now has two runnable sandbox prototypes and an Xcode application target. This is a feasibility result, **not an App Store-ready release or an approval from Apple**. The installed direct-distribution app is unchanged.

## What the local probes established

Tested on macOS 27.0 (26A5421a), using independently signed test applications and the production `DockReader` and `HotKeyRegistry` implementations. The helper is a dedicated app created by the test; no personal applications are opened or hidden.

| Check | No sandbox (control) | Standard sandbox | Sandbox + Dock exception |
| --- | --- | --- | --- |
| Access to Dock preference domain | Available | Blocked | Available |
| Pinned-app parsing | Available | Empty because access is blocked | Matches control |
| Global hotkey registration | Status 0 | Status 0 | Status 0 |
| Launch separate test application | Succeeded | Succeeded | Succeeded |
| Test app changes from visible to hidden | Observed | Observed | Observed |
| Own preference write/read | Passed | Passed | Passed |
| Read workspace README outside container | Allowed | Denied | Denied |
| Container home directory | No | Yes | Yes |
| Real user keypress delivery | Not tested | Not tested | Not tested |

Important limits:

- Registration success does not prove that a physical shortcut arrives while another app has focus. Run the interactive probe below to check delivery.
- `NSRunningApplication.hide()` returned `false` even though the helper changed from visible to hidden, including in the unsandboxed control. This macOS-version discrepancy needs validation with real applications and on supported release versions.
- The helper was not active before the hide check in one standard-sandbox run. Successful launch is established; reliable foreground activation across apps is not yet established.
- The read-only `com.apple.dock` preference exception restores technical access locally. Apple still needs to accept the exception and the API usage. The Dock preference schema is not a stable public Dock-order API.
- No full Xcode installation or valid code-signing identity was available on this machine. The generated project was structurally checked; an Xcode archive and App Store validation have not been run.

## Reproduce the comparison

```sh
./scripts/sandbox-probe.py
```

The runner compiles local test bundles into a temporary directory, opens each through Launch Services, and writes reports under `.build/sandbox-reports/` (ignored by Git). It checks a unique run ID to reject stale reports. Sandbox enforcement is demonstrated by both container home redirection and denial of the workspace file read. The helper exits after 45 seconds even if cleanup fails.

For actual keyboard delivery:

```sh
./scripts/sandbox-probe.py --interactive
```

Press **Control + Option + Shift + Command + V** when each test window appears. Each sandbox variant waits up to 30 seconds; there are two variants. The helper app is brought forward to test the shortcut from another application. No Accessibility permission or synthesized keypresses are used. A timeout is reported as a timeout, never a pass.

## Try the actual app in a sandbox

```sh
./scripts/build-sandbox-app.sh strict
./scripts/build-sandbox-app.sh dock
```

Each command prints a temporary `.app` location and saves that path to `dist/sandbox-strict-path.txt` or `dist/sandbox-dock-path.txt`. Open the printed application in Finder. Both use their own app identity and container; they do not overwrite the installed app or its preferences. Quit other DockChord copies before testing shortcuts to avoid conflicts.

- **strict:** No shared-preference exception. Automatic Dock access is explicitly disabled; the UI directs users to custom app shortcuts. This is the conservative default for the Xcode target.
- **dock:** Experimental read-only Dock preference exception. The numbered Dock feature stays available for testing.

These builds are locally ad-hoc signed. Neither is a distribution-signed App Store artifact.

## Xcode and signing

Open `DockChord.xcodeproj` in Xcode 26 or newer. Select Vinitha's Apple Developer team under Signing & Capabilities. Do not put signing credentials or provisioning profiles in Git.

- **Debug / Release:** App Sandbox, hardened runtime, user-selected read-only access, and app-scoped bookmark entitlement. Cross-app Dock preferences are disabled.
- **SandboxDockExperimental:** Adds the `com.apple.dock` read-only shared-preference exception. Do not submit this configuration without resolving the review and privacy questions.
- The shared `DockChord` scheme archives **Release**, not the experimental configuration.
- Bundle identifier: `io.github.code4vinitha.dockchord`; register it under Vinitha's developer team. The direct local build keeps its existing identifier to avoid changing installed users' settings.
- `Resources/PrivacyInfo.xcprivacy` is included as a resource. `CA92.1` describes only the app's own saved preferences. It does **not** claim to authorize reading the Dock's preferences; cross-domain usage requires a separate policy/API assessment before submission.

After adding Swift source files, regenerate the project with `./scripts/generate-xcode-project.py`. This overwrites generated project settings; signing team selection is intentionally left unset in the generator.

## Remaining before submission

1. Complete real shortcut-delivery, foreground activation, hide/show, and supported-macOS testing with normal applications.
2. Persist security-scoped bookmarks for user-selected apps, renew stale bookmarks, and test restoring them across relaunches—especially for apps outside standard application directories. The entitlement alone does not implement this lifecycle; the current app still saves paths.
3. Decide whether to request approval for automatic Dock access or release with manual shortcuts first. Seek guidance from Apple about both the sandbox exception and cross-domain preference use; do not label it covered by the own-preferences privacy reason.
4. Install full Xcode, enroll/select Vinitha's developer team, register the app identifier, and configure distribution signing and provisioning. Build a universal Apple silicon/Intel archive if both architectures will be supported.
5. Add the app icon, current screenshots, support and privacy-policy pages, in-app privacy-policy access, App Store metadata, privacy answers, versioning, and a reviewed privacy manifest covering the final code.
6. Validate the archive in Xcode, test the distributed build through TestFlight, and submit the final build for App Review.

## Apple references

- [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Shared preference temporary exceptions](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html)
- [Accessing files from the App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Required-reason API declarations](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
- [Preparing for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)

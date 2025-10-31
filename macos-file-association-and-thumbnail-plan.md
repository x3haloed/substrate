## Substrate macOS File Association and Thumbnail Integration Plan

### Goals
- Associate Substrate’s custom file extensions with the app so double‑click opens Substrate with the file path.
- Provide dynamic, content‑based Finder thumbnails/icons for `.scrd` (Substrate Card) and `.scrt` (Substrate Cartridge) files.
- Ship on the Mac App Store with a compliant sandboxed implementation.

### Scope
- Define custom UTIs and document types in the app `Info.plist`.
- Build a Quick Look Thumbnail extension to render thumbnails from Substrate Card (`.scrd`) and Substrate Cartridge (`.scrt`) files.
- Embed, sign, and ship the extension within the app bundle.
- Handle file open events in Godot.
- Provide automation for post‑export embedding and codesigning.

### Deliverables
- Updated macOS export with `UTTypeExportedTypeDeclarations` and `CFBundleDocumentTypes`.
- Xcode target: Quick Look Thumbnail extension (`.appex`) with Swift `ThumbnailProvider`.
- Post‑export script to embed `.appex` under `Contents/PlugIns/` and codesign the bundle.
- QA checklist (Finder thumbnails, Quick Look, double‑click open, App Store validation).

---

### Identifiers and Conventions
- App Name: `Substrate`
- Bundle Identifier (app): `com.substrate.app` (update to your actual identifier)
- File Extensions:
  - `.scrd` (Substrate Card) — UTI: `com.substrate.card`
  - `.scrt` (Substrate Cartridge) — UTI: `com.substrate.cartridge`
- Display Names:
  - "Substrate Card"
  - "Substrate Cartridge"

---

### 1) App `Info.plist` additions (UTI + Document Types)
Add these keys to the exported app's `Info.plist` (Godot macOS export can inject, or post‑process after export):

```xml
<!-- UTI declarations for Substrate Card and Substrate Cartridge file types -->
<key>UTTypeExportedTypeDeclarations</key>
<array>
  <dict>
    <key>UTTypeIdentifier</key>
    <string>com.substrate.card</string>
    <key>UTTypeDescription</key>
    <string>Substrate Card</string>
    <key>UTTypeConformsTo</key>
    <array>
      <string>public.data</string>
      <string>public.text</string>
    </array>
    <key>UTTypeTagSpecification</key>
    <dict>
      <key>public.filename-extension</key>
      <array>
        <string>scrd</string>
      </array>
      <key>public.mime-type</key>
      <string>application/x-substrate-card</string>
    </dict>
  </dict>
  <dict>
    <key>UTTypeIdentifier</key>
    <string>com.substrate.cartridge</string>
    <key>UTTypeDescription</key>
    <string>Substrate Cartridge</string>
    <key>UTTypeConformsTo</key>
    <array>
      <string>public.data</string>
      <string>public.text</string>
    </array>
    <key>UTTypeTagSpecification</key>
    <dict>
      <key>public.filename-extension</key>
      <array>
        <string>scrt</string>
      </array>
      <key>public.mime-type</key>
      <string>application/x-substrate-cartridge</string>
    </dict>
  </dict>
  </array>

<!-- Document type associations so LaunchServices opens Substrate on double‑click -->
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>Substrate Card</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>com.substrate.card</string>
    </array>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>LSHandlerRank</key>
    <string>Owner</string>
    <!-- Optional static fallback icon(s) for the document type -->
    <!--
    <key>CFBundleTypeIconFiles</key>
    <array>
      <string>SceneDocIcon</string>
    </array>
    -->
  </dict>
  <dict>
    <key>CFBundleTypeName</key>
    <string>Substrate Cartridge</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>com.substrate.cartridge</string>
    </array>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>LSHandlerRank</key>
    <string>Owner</string>
  </dict>
</array>
```

Notes:
- Keep a static icon as a fallback; Finder will prefer thumbnails from the extension when available.
- For development, you can force re‑registration via `lsregister` or log out/in; see Testing.

---

### 2) Quick Look Thumbnail Extension (dynamic icons in Finder)
Implement a modern app extension (`com.apple.quicklook.thumbnail`) that reads `.scrd` (Substrate Card) and `.scrt` (Substrate Cartridge) files and draws a thumbnail.

Extension `Info.plist` essentials:
```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key>
  <string>com.apple.quicklook.thumbnail</string>
  <key>NSExtensionPrincipalClass</key>
  <string>$(PRODUCT_MODULE_NAME).ThumbnailProvider</string>
  <key>NSExtensionAttributes</key>
  <dict>
    <key>QLSupportedContentTypes</key>
    <array>
      <string>com.substrate.card</string>
      <string>com.substrate.cartridge</string>
    </array>
  </dict>
</dict>
```

Swift outline for `ThumbnailProvider` (prefers precomputed thumbnails, then falls back to portrait):
```swift
import QuickLookThumbnailing
import AppKit
import AVFoundation

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let text = try String(contentsOf: request.fileURL, encoding: .utf8)
            let image = extractPreviewImage(fromTresText: text, at: request.fileURL)
            let size = request.maximumSize
            let reply = QLThumbnailReply(contextSize: size) {
                let rect = CGRect(origin: .zero, size: size)
                NSColor.clear.set(); rect.fill()
                if let img = image {
                    let inset: CGFloat = 8
                    let target = rect.insetBy(dx: inset, dy: inset)
                    let aspect = img.size
                    let fit = AVMakeRect(aspectRatio: aspect, insideRect: target)
                    img.draw(in: fit)
                } else {
                    let style = NSMutableParagraphStyle(); style.alignment = .center
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: min(size.width, size.height) * 0.12, weight: .semibold),
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: style
                    ]
                    let s = "Substrate"
                    s.draw(in: rect.insetBy(dx: 12, dy: 12), withAttributes: attrs)
                }
                return true
            }
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }

    private func extractPreviewImage(fromTresText text: String, at fileURL: URL) -> NSImage? {
        // Prefer precomputed thumbnails in descending size, then fall back to portrait_base64
        let orderedKeys = [
            "thumbnail_1024_base64",
            "thumbnail_512_base64",
            "thumbnail_256_base64"
        ]
        for key in orderedKeys {
            if let b64 = regexMatch(text, pattern: "#\\b" + key + "\\s*=\\s*\\\"([A-Za-z0-9+/=]+)\\\"#").first,
               let data = Data(base64Encoded: b64), let img = NSImage(data: data) {
                return img
            }
        }
        // Fallback: portrait_base64 (full-resolution portrait)
        if let b64 = regexMatch(text, pattern: #"\bportrait_base64\s*=\s*\"([A-Za-z0-9+/=]+)\""#).first,
           let data = Data(base64Encoded: b64), let img = NSImage(data: data) {
            return img
        }
        return nil
    }

    private func regexMatch(_ s: String, pattern: String) -> [String] {
        let re = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let re = re, let m = re.firstMatch(in: s, options: [], range: range) else { return [] }
        var out: [String] = []
        for i in 1..<m.numberOfRanges {
            if let r = Range(m.range(at: i), in: s) { out.append(String(s[r])) }
        }
        return out
    }
}
```

Project layout recommendation:
```
YourGame.xcodeproj/
  YourGame (macOS app target)  <-- optional, if you build wrapper here
  YourGameThumbnail (QL Thumbnail Extension target)
    ThumbnailProvider.swift
    Info.plist
```

Build product to embed:
```
YourGameThumbnail.appex
```

---

### 3) Handle file opens in Godot
In the app’s main script (early in startup), parse command‑line arguments to detect an opened file path:

```gdscript
var args := OS.get_cmdline_args()
for a in args:
    if a.ends_with(".scrd"):
        _open_substrate_card(a)
    elif a.ends_with(".scrt"):
        _open_substrate_cartridge(a)
```

Notes:
- When the user double‑clicks a file in Finder, the path appears in `OS.get_cmdline_args()` for sandboxed apps.
- Ensure the app can handle both cold starts and already‑running instances (consider single‑instance or inter‑process messaging if needed).

---

### 4) Post‑export embedding and codesigning
After exporting the `.app` from Godot, embed the extension and codesign the entire bundle.

Assumptions:
- Exported app path: `build/Substrate.app`
- Built extension path: `build/SubstrateThumbnail.appex`
- Team ID and signing identities set in environment variables.

Script outline:
```bash
#!/usr/bin/env bash
set -euo pipefail

APP="build/Substrate.app"
APPEX_SRC="build/SubstrateThumbnail.appex"
APPEX_DST="$APP/Contents/PlugIns/SubstrateThumbnail.appex"
IDENTITY="Developer ID Application: Substrate (TEAMID)"  # or 3rd‑party Mac App Store identity

# 1) Embed extension
mkdir -p "$(dirname "$APPEX_DST")"
rm -rf "$APPEX_DST"
cp -R "$APPEX_SRC" "$APPEX_DST"

# 2) Ensure Info.plist contains UTI + document type (inject if not already)
#    Optionally use /usr/libexec/PlistBuddy here

# 3) Codesign extension first
codesign --force --options runtime --timestamp \
  --sign "$IDENTITY" "$APPEX_DST"

# 4) Codesign frameworks (if any) and the app last
codesign --force --options runtime --timestamp \
  --entitlements path/to/YourGame.entitlements \
  --sign "$IDENTITY" "$APP"

# 5) Verify
codesign --verify --deep --strict --verbose=2 "$APP"
spctl -a -t exec -vv "$APP" || true
```

For Mac App Store:
- Use the 3rd‑party Mac Developer Application/Installer identities and create an `.pkg` via Xcode or `productbuild`.
- Upload with Transporter. App extensions are supported.

---

### 5) Testing and Validation
- Reset Quick Look caches during development:
```bash
qlmanage -r; qlmanage -r cache
```
- Preview a file explicitly:
```bash
qlmanage -p /path/to/example.scrd
qlmanage -p /path/to/example.scrt
```
- Force LaunchServices to refresh (use with care):
```bash
/usr/bin/sudo /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -kill -r -domain local -domain system -domain user
```
- Finder behavior:
  - Toggle view modes or rename file to re‑render a thumbnail.
  - Thumbnails are cached; expect delays without cache reset.
- App open handling:
  - Log `OS.get_cmdline_args()` on startup; double‑click file and confirm path is present.

---

- ### 6) File format guidance for reliable thumbnails
- Add explicit metadata directly into the `.scrd` (Substrate Card) and `.scrt` (Substrate Cartridge) files as storage‑only properties:
  - `thumbnail_1024_base64` — PNG, sRGB, 8‑bit, exactly 1024×1024 px
  - `thumbnail_512_base64` — PNG, sRGB, 8‑bit, exactly 512×512 px
  - `thumbnail_256_base64` — PNG, sRGB, 8‑bit, exactly 256×256 px
  - Fallback: `portrait_base64` — full‑res PNG if thumbnails are missing
- The Quick Look extension will prefer the largest available precomputed thumbnail, then fall back to smaller ones, then the portrait.
- Precompute once at save time in Godot to minimize decode work in the extension.
- Keep referenced images embedded (base64) to avoid sandbox path issues and to allow a single self‑contained `.scrd` file.
- Target render cost <50–100 ms; avoid unnecessarily large images.

---

### 7) Sandbox, Entitlements, and App Store notes
- Thumbnail extensions run out‑of‑process and are allowed to read the target file without extra entitlements.
- The host app should use hardened runtime and sandbox entitlements suitable for the game.
- No network/file system entitlements are required for the extension.

---

### 8) Risks and Mitigations
- Finder cache confusion → provide dev scripts to clear caches; use versioned UTI if necessary.
- Performance of thumbnailing large files → constrain image size and decode paths; add timeouts.
- Relative path resolution → resolve `res://` relative to the document location; avoid dependencies on app bundle.
- App not set as default → users can change default app in Finder; for dev, use `duti` to set defaults.
- App Store review → ensure no private APIs; use modern QL app extension (not legacy `.qlgenerator`).

---

### 9) Acceptance Criteria
- Double‑clicking `.scrd` opens Substrate and loads the referenced card content.
- Double‑clicking `.scrt` opens Substrate and loads the referenced cartridge content.
- Finder shows per‑file thumbnails derived from precomputed fields for grid/list/column views.
- `qlmanage -p` previews render correctly.
- App bundle passes local codesign verification and App Store validation.
- No additional permissions requested at runtime solely due to the extension.

---

### 10) Execution Checklist (suggested order)
1. Finalize identifiers: extension, UTI, bundle IDs.
2. Add `Info.plist` UTI + document types to macOS export config for `.scrd` and `.scrt`.
3. Create Xcode QL Thumbnail extension target; implement `ThumbnailProvider` to prefer `thumbnail_*_base64` for both UTIs.
4. Build extension product (`.appex`).
5. Export Godot macOS app.
6. Embed `.appex` under `Contents/PlugIns/` and re‑sign.
7. Verify with `codesign --verify` and `qlmanage` tests.
8. QA in Finder; confirm open handling from double‑click.
9. Prepare MAS archive and upload.

---

### Notes for Automation
- Integrate post‑export step in your CI (e.g., Fastlane or a shell script) to:
  - Merge plist keys if not present.
  - Embed and sign the `.appex`.
  - Zip or package for distribution.
- Keep the extension target as a separate Xcode project to avoid coupling with Godot export.



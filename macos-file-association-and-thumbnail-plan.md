## macOS File Association and Thumbnail Integration Plan

### Goals
- Associate a custom file extension with the Godot app so double‑click opens the app with the file path.
- Provide dynamic, content‑based Finder thumbnails/icons for that file type.
- Ship on the Mac App Store with a compliant sandboxed implementation.

### Scope
- Define a custom UTI and document type in the app `Info.plist`.
- Build a Quick Look Thumbnail extension to render thumbnails from renamed `.tres` files.
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
- Bundle Identifier (app): `com.yourcompany.yourgame`
- File Extension: `.ygscene` (example)
- UTI Identifier: `com.yourcompany.yourgame.scene`
- Display Name: "YourGame Scene"

Update names as needed before implementation.

---

### 1) App `Info.plist` additions (UTI + Document Types)
Add these keys to the exported app's `Info.plist` (Godot macOS export can inject, or post‑process after export):

```xml
<!-- UTI declaration for the custom file type -->
<key>UTTypeExportedTypeDeclarations</key>
<array>
  <dict>
    <key>UTTypeIdentifier</key>
    <string>com.yourcompany.yourgame.scene</string>
    <key>UTTypeDescription</key>
    <string>YourGame Scene</string>
    <key>UTTypeConformsTo</key>
    <array>
      <string>public.data</string>
      <string>public.text</string>
    </array>
    <key>UTTypeTagSpecification</key>
    <dict>
      <key>public.filename-extension</key>
      <array>
        <string>ygscene</string>
      </array>
      <key>public.mime-type</key>
      <string>application/x-yourgame-scene</string>
    </dict>
  </dict>
  </array>

<!-- Document type association so LaunchServices opens the app on double‑click -->
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>YourGame Scene</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>com.yourcompany.yourgame.scene</string>
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
</array>
```

Notes:
- Keep a static icon as a fallback; Finder will prefer thumbnails from the extension when available.
- For development, you can force re‑registration via `lsregister` or log out/in; see Testing.

---

### 2) Quick Look Thumbnail Extension (dynamic icons in Finder)
Implement a modern app extension (`com.apple.quicklook.thumbnail`) that reads `.ygscene` (renamed `.tres`) and draws a thumbnail.

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
      <string>com.yourcompany.yourgame.scene</string>
    </array>
  </dict>
</dict>
```

Swift outline for `ThumbnailProvider`:
```swift
import QuickLookThumbnailing
import AppKit

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
                    let s = "YourGame"
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
        // Heuristics; prefer explicit metadata in file content.
        // 1) preview_image = "res://relative/path.png"
        if let path = regexMatch(text, pattern: #"preview_image\s*=\s*\"([^\"]+)\""#).first {
            let url: URL
            if path.hasPrefix("res://") {
                url = fileURL.deletingLastPathComponent().appendingPathComponent(String(path.dropFirst(6)))
            } else {
                url = URL(fileURLWithPath: path)
            }
            if let img = NSImage(contentsOf: url) { return img }
        }
        // 2) preview_image_base64 = "..."
        if let b64 = regexMatch(text, pattern: #"preview_image_base64\s*=\s*\"([A-Za-z0-9+/=]+)\""#).first,
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
    if a.ends_with(".ygscene"):
        _open_custom_scene(a)
```

Notes:
- When the user double‑clicks a file in Finder, the path appears in `OS.get_cmdline_args()` for sandboxed apps.
- Ensure the app can handle both cold starts and already‑running instances (consider single‑instance or inter‑process messaging if needed).

---

### 4) Post‑export embedding and codesigning
After exporting the `.app` from Godot, embed the extension and codesign the entire bundle.

Assumptions:
- Exported app path: `build/YourGame.app`
- Built extension path: `build/YourGameThumbnail.appex`
- Team ID and signing identities set in environment variables.

Script outline:
```bash
#!/usr/bin/env bash
set -euo pipefail

APP="build/YourGame.app"
APPEX_SRC="build/YourGameThumbnail.appex"
APPEX_DST="$APP/Contents/PlugIns/YourGameThumbnail.appex"
IDENTITY="Developer ID Application: Your Company (TEAMID)"  # or 3rd‑party Mac App Store identity

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
qlmanage -p /path/to/example.ygscene
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

### 6) File format guidance for reliable thumbnails
- Prefer adding explicit metadata in your renamed `.tres` file:
  - `preview_image = "res://relative/path.png"`
  - or `preview_image_base64 = "..."`
- Keep referenced images near the file to avoid sandbox path issues.
- Keep thumbnail work fast (<50–100ms) and memory‑efficient; avoid loading large textures.

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
- Double‑clicking `.ygscene` opens the app and loads the referenced content.
- Finder shows per‑file thumbnails derived from the content for grid/list/column views.
- `qlmanage -p` previews render correctly.
- App bundle passes local codesign verification and App Store validation.
- No additional permissions requested at runtime solely due to the extension.

---

### 10) Execution Checklist (suggested order)
1. Finalize identifiers: extension, UTI, bundle IDs.
2. Add `Info.plist` UTI + document types to macOS export config.
3. Create Xcode QL Thumbnail extension target; implement `ThumbnailProvider`.
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



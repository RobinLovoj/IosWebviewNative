# Built-in Local HTTP Server (No Packages Needed)

We now ship a **pure Swift** HTTP server that runs entirely on-device using Apple's `Network.framework`.  
No third-party dependencies, no package installs, and zero extra setup.

## Why this approach?

✅ Works exactly like `http://localhost:9000` on Android  
✅ Handles all assets (HTML, JS, CSS, GLB, fonts, images)  
✅ Supports hash-based routing, fetch(), Three.js, dynamic imports  
✅ No `file://` issues, no ATS exceptions, no extra frameworks  
✅ 100% offline and App Store friendly

## How it works

1. ZIP is extracted to `Documents/offline_web/dist/`
2. `LocalWebServer` (pure Swift) starts `NWListener` on port 9000
3. WebView loads `http://localhost:9000/index.html`
4. Every request (including `/assets/...`, `/3dmodel/...`, etc.) is served by our Swift code
5. Works with React/Vue routing, Three.js GLB loader, and all fetch calls

## What you need to do

Nothing. Just build & run. The server boots automatically when `OfflineWebViewModel` loads content.

## Troubleshooting

- **White screen?** Check Xcode logs to confirm:
  ```
  🚀 Local HTTP server running on http://localhost:9000
  📁 Serving files from: /.../Documents/offline_web/dist
  ```
- **Port already in use?** Rebuild or change the `port` parameter when creating `LocalWebServer`.
- **Need HTTPS?** Wrap the existing listener with `NWListener(using: tlsOptions, on: port)` (not required for local WebView use).

## Want to customize?

`Services/LocalWebServer.swift` exposes:
- `mimeType(for:)` — add custom types (e.g., `.hdr`, `.ktx2`)
- `sanitize(path:)` — adjust routing rules
- `getProductURL(...)` — Android-style query builder for hash routes

No external packages, no manual setup — just run the app and enjoy a full-featured offline website on iOS. 🚀

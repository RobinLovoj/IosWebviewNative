# Setup Instructions

## Required Dependencies

### 1. ZipFoundation (for ZIP extraction) - **REQUIRED**
Add via Swift Package Manager:
1. In Xcode: **File > Add Package Dependencies...**
2. Enter URL: `https://github.com/weichsel/ZIPFoundation`
3. Select version: **Up to Next Major Version**
4. Click **Add Package**

### 2. Swifter (for localhost server - SwiftLocalhost pattern) - **RECOMMENDED**
Add via Swift Package Manager:
1. In Xcode: **File > Add Package Dependencies...**
2. Enter URL: `https://github.com/httpswift/swifter`
3. Select version: **Up to Next Major Version**
4. Click **Add Package**

**Note:** 
- Swifter provides reliable localhost server (SwiftLocalhost pattern: https://github.com/depoon/SwiftLocalhost)
- The code uses conditional compilation (`#if canImport(Swifter)`), so it will automatically use Swifter once you add the package
- If Swifter is not available, it falls back to Foundation's Network framework
- URLs generated: `http://localhost:8080/index.html#/cache-data?...` and `http://localhost:8080/index.html#/product?...`

## Project Structure

```
offlineweb/
├── Services/
│   ├── ContentManager.swift      # ZIP download & extraction
│   ├── LocalWebServer.swift      # Local HTTP server
│   ├── ZipExtractor.swift        # ZIP extraction utility
│   ├── ProductService.swift      # Product API service
│   ├── AuthService.swift         # Login API
│   └── UserDataManager.swift     # Data storage
├── ViewModels/
│   └── OfflineWebViewModel.swift # Main view model
├── Views/
│   ├── OfflineWebView.swift      # Main view
│   ├── DownloadProgressView.swift # Progress screen
│   └── WebViewWrapper.swift      # WKWebView wrapper
└── Models/
    ├── Product.swift              # Product model
    └── LoginResponse.swift        # API models
```


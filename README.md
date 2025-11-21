# iOS Native WebView Application

A native iOS application built with SwiftUI that provides an offline-capable web view experience. The app allows users to download web content as a ZIP file, extract it locally, and serve it through a local HTTP server for seamless offline browsing.

## 📱 Overview

This iOS application implements a hybrid architecture where web content is downloaded, cached locally, and served through a custom local HTTP server. The app provides a complete offline experience with features like user authentication, product selection, and web content viewing.

## ✨ Features

### Core Functionality
- **Splash Screen**: Beautiful animated splash screen on app launch
- **User Authentication**: Secure login with email and password validation
- **Offline Content Download**: Download web content as ZIP files and extract locally
- **Local HTTP Server**: Built-in HTTP server using Network.framework to serve cached content
- **Product Selection**: Browse and select from a catalog of men's and women's products
- **WebView Integration**: Seamless WKWebView integration for displaying web content
- **Progress Tracking**: Real-time download and extraction progress indicators
- **Network Status**: Visual indicator for online/offline status
- **Screen Rotation**: Toggle between portrait and landscape orientations
- **Navigation**: Back button support for WebView navigation

### User Experience
- Modern, clean UI with gradient backgrounds
- Smooth animations and transitions
- Password visibility toggle
- Form validation with real-time feedback
- Haptic feedback for user interactions
- Error handling with user-friendly messages

## 🏗️ Architecture

### MVVM Pattern
The app follows the Model-View-ViewModel (MVVM) architecture:

- **Models**: Data structures (`Product`, `LoginResponse`)
- **Views**: SwiftUI views (`LoginView`, `OfflineWebView`, `ProductSelectionView`)
- **ViewModels**: Business logic (`OfflineWebViewModel`)
- **Services**: Core functionality (`AuthService`, `ContentManager`, `LocalWebServer`)

### Key Components

#### 1. **LocalWebServer**
- Pure Swift implementation using Network.framework
- Serves static files from local directory
- Handles HTTP requests and routing
- Supports MIME type detection
- Runs on localhost (default port: 9000)

#### 2. **ContentManager**
- Downloads ZIP files from remote server
- Extracts ZIP archives with progress tracking
- Manages local file system operations
- Handles content caching

#### 3. **OfflineWebViewModel**
- Manages application state
- Coordinates download, extraction, and content loading
- Handles navigation between screens
- Manages product selection and WebView URLs

#### 4. **WebViewWrapper**
- UIViewRepresentable wrapper for WKWebView
- Handles JavaScript communication
- Manages navigation history
- Provides back button functionality

## 📁 Project Structure

```
offlineweb/
├── Assets.xcassets/              # Image assets and app icons
│   ├── AppIcon.appiconset/       # App icons
│   ├── LoginBackground.imageset/ # Login background images
│   ├── SplashImage.imageset/     # Splash screen image
│   └── [Product Images]/         # Product category images
├── Components/
│   └── SnackbarView.swift        # Toast notification component
├── Models/
│   ├── LoginResponse.swift       # Login API response model
│   └── Product.swift             # Product data model
├── Services/
│   ├── AuthService.swift         # Authentication service
│   ├── ContentManager.swift      # ZIP download & extraction
│   ├── LocalWebServer.swift      # Local HTTP server
│   ├── NetworkMonitor.swift      # Network connectivity monitoring
│   ├── ProductService.swift      # Product API service
│   ├── UserDataManager.swift     # User data persistence
│   └── ZipExtractor.swift        # ZIP extraction utility
├── Utilities/
│   └── OrientationManager.swift  # Screen orientation management
├── ViewModels/
│   └── OfflineWebViewModel.swift # Main view model
├── Views/
│   ├── DownloadProgressView.swift # Download progress screen
│   ├── OfflineWebView.swift      # Main container view
│   ├── ProductSelectionView.swift # Product selection screen
│   └── WebViewWrapper.swift      # WKWebView wrapper
├── ContentView.swift             # Root content view
├── LoginView.swift               # Login screen
├── SplashScreenView.swift        # Splash screen
├── offlinewebApp.swift           # App entry point
└── offlineweb.entitlements       # App capabilities
```

## 🚀 Setup Instructions

### Prerequisites
- Xcode 14.0 or later
- iOS 15.0 or later
- Swift 5.7 or later
- macOS 12.0 or later (for development)

### Dependencies

#### Required Dependencies

1. **ZipFoundation** (for ZIP extraction)
   - Add via Swift Package Manager:
   - URL: `https://github.com/weichsel/ZIPFoundation`
   - Version: Up to Next Major Version

#### Optional Dependencies

2. **Swifter** (for enhanced localhost server)
   - URL: `https://github.com/httpswift/swifter`
   - Version: Up to Next Major Version
   - Note: The app works without Swifter using Network.framework fallback

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/RobinLovoj/IosWebviewNative.git
   cd IosWebviewNative
   git checkout iosnativewebview
   ```

2. **Open in Xcode**
   ```bash
   open offlineweb.xcodeproj
   ```
   Or open the `.xcworkspace` file if using CocoaPods

3. **Add Dependencies**
   - In Xcode: **File > Add Package Dependencies...**
   - Add ZipFoundation package (URL provided above)
   - Click **Add Package**

4. **Configure Signing**
   - Select your project in Xcode
   - Go to **Signing & Capabilities**
   - Select your development team
   - Ensure bundle identifier is unique

5. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

## 📖 Usage

### First Launch
1. App displays splash screen
2. Navigate to login screen
3. Enter email and password
4. Tap "SIGN IN" button
5. App authenticates and downloads content

### Content Download Flow
1. After login, app checks for existing cached content
2. If content exists, loads directly (offline mode)
3. If not, downloads ZIP file from server
4. Shows download progress with percentage
5. Extracts ZIP file with file-by-file progress
6. Starts local HTTP server
7. Loads web content in WebView

### Product Selection
1. After content is ready, product selection screen appears
2. Browse products by category (Men/Women)
3. Tap on a product to view details
4. WebView loads product-specific content
5. Use back button to return to product selection

### Offline Mode
- App automatically detects cached content
- Works completely offline after initial download
- No internet connection required for browsing
- Local HTTP server serves all content

## 🔧 Configuration

### API Endpoints
Configure API endpoints in respective service files:
- `AuthService.swift` - Login endpoint
- `ProductService.swift` - Product list endpoint
- `ContentManager.swift` - ZIP download endpoint

### Server Configuration
- Default port: 9000
- Can be changed in `LocalWebServer` initialization
- Base directory: `Documents/offline_web/dist`

### Product Images
- Product images are stored in `Assets.xcassets`
- Image names match Android drawable names
- Supported formats: PNG, JPEG

## 🛠️ Build Instructions

### Debug Build
```bash
xcodebuild -scheme offlineweb -configuration Debug -sdk iphonesimulator
```

### Release Build
```bash
xcodebuild -scheme offlineweb -configuration Release -sdk iphoneos
```

### Archive for Distribution
1. In Xcode: **Product > Archive**
2. Wait for archive to complete
3. Click **Distribute App**
4. Choose distribution method (Ad Hoc, App Store, etc.)
5. Follow export wizard

See `BUILD_AND_SHARE_IPA.md` for detailed IPA build and sharing instructions.

## 🧪 Testing

### Manual Testing Checklist
- [ ] Splash screen displays correctly
- [ ] Login validation works
- [ ] Content download completes
- [ ] ZIP extraction succeeds
- [ ] Local server starts correctly
- [ ] WebView loads content
- [ ] Product selection works
- [ ] Back button navigation works
- [ ] Screen rotation works
- [ ] Offline mode functions correctly
- [ ] Network status indicator updates

## 🐛 Troubleshooting

### Common Issues

#### 1. Local Server Not Starting
- **Problem**: Server fails to start
- **Solution**: 
  - Check if port 9000 is available
  - Verify base directory exists
  - Check console logs for errors

#### 2. Content Not Loading
- **Problem**: WebView shows blank screen
- **Solution**:
  - Verify ZIP extraction completed
  - Check local server is running
  - Verify `index.html` exists in dist directory
  - Check console for JavaScript errors

#### 3. Download Fails
- **Problem**: ZIP download doesn't complete
- **Solution**:
  - Check internet connection
  - Verify API endpoint is correct
  - Check server response in network logs

#### 4. Product Images Missing
- **Problem**: Product images don't display
- **Solution**:
  - Verify images exist in Assets.xcassets
  - Check image names match product names
  - Ensure images are added to target

#### 5. Build Errors
- **Problem**: Package dependencies not found
- **Solution**:
  - Re-add packages via Swift Package Manager
  - Clean build folder (Cmd + Shift + K)
  - Reset package caches

## 📝 Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and single-purpose
- Use SwiftUI best practices

## 🔐 Security Considerations

- User credentials stored securely using UserDefaults
- Token-based authentication
- Local content served only on localhost
- No sensitive data in logs
- HTTPS for API communications (when online)

## 📄 License

This project is proprietary. All rights reserved.

## 👤 Author

**Robin Lovoj**
- GitHub: [@RobinLovoj](https://github.com/RobinLovoj)

## 🙏 Acknowledgments

- ZipFoundation library for ZIP handling
- SwiftUI framework
- Network.framework for local server implementation

## 📞 Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation files:
  - `SETUP_INSTRUCTIONS.md`
  - `BUILD_AND_SHARE_IPA.md`
  - `GCDWEBSERVER_SETUP.md`

## 🔄 Version History

### Version 1.1
- Added splash screen
- Improved login UI
- Added screen rotation toggle
- Added WebView back button
- Network status indicator
- Product image assets
- Offline mode improvements

### Version 1.0
- Initial release
- Basic offline web view functionality
- User authentication
- Product selection
- Local HTTP server

---

**Note**: This application is designed for offline-first usage. Ensure initial content download completes before using offline mode.


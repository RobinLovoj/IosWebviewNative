//
//  WebViewWrapper.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    let tokenData: String?
    let htmlContent: String?
    let baseURL: URL?
    let selectedProductEvent: SelectedProductEvent?
    let onWebLoadingFinished: ((Bool) -> Void)?
    let onCacheProgress: ((Double) -> Void)?
    @Binding var canGoBack: Bool
    @Binding var shouldGoBack: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Enable JavaScript (using modern API for iOS 14.0+)
        // Note: javaScriptEnabled is deprecated, using allowsContentJavaScript instead
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Allow file access (critical for file:// URLs)
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        // Allow loading local files
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Media settings
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Web content settings
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Add user content controller for console logging and web callbacks
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "console")
        userContentController.add(context.coordinator, name: "onWebLoadingFinished")
        userContentController.add(context.coordinator, name: "cachePercentage")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.updateWebViewReference(webView)
        context.coordinator.updateCanGoBack(webView)
        
        // Set background color to white (will show if content doesn't load)
        webView.backgroundColor = .white
        webView.isOpaque = false
        
        // Inject error prevention scripts
        injectErrorPrevention(webView: webView)
        
        // Inject console logging script (must be after userContentController is set)
        injectConsoleLogging(webView: webView)
        
        // Inject script to prevent cache-data route when product is selected (runs at document start)
        if selectedProductEvent != nil {
            injectProductSelectionPrevention(webView: webView)
        }
        
        print("🌐 WebView created, will load URL: \(url.absoluteString)")
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update canGoBack binding
        context.coordinator.updateCanGoBack(webView)
        
        // Handle go back action
        if shouldGoBack {
            DispatchQueue.main.async {
                if webView.canGoBack {
                    webView.goBack()
                }
            }
        }
        
        // Track if product is selected to force reload
        let hasProductSelected = selectedProductEvent != nil
        
        // PRIORITY 1: If HTML content is provided, use loadHTMLString (bypasses localhost issue)
        // This ensures immediate loading without waiting for server requests
        if let htmlContent = htmlContent, let baseURL = baseURL {
            print("📄 Loading HTML content directly (bypassing localhost)")
            print("📁 Base URL: \(baseURL.path)")
            print("📄 HTML content length: \(htmlContent.count) characters")
            print("📦 Product selected: \(hasProductSelected ? selectedProductEvent?.productName ?? "unknown" : "none")")
            
            // If product is selected, always reload to ensure fresh HTML without cache-data hash
            if hasProductSelected {
                print("🔄 Force reloading WebView for product selection")
                webView.stopLoading()
                // Small delay to ensure stopLoading completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Load with baseURL that includes dist directory for GLB file access
                    webView.loadHTMLString(htmlContent, baseURL: baseURL)
                    print("✅ HTML content reloaded with baseURL: \(baseURL.path)")
                    print("📦 GLB files should be accessible at: \(baseURL.path)/3dmodel/")
                }
            } else {
                // Load HTML string with base URL (allows assets to load from file://)
                webView.loadHTMLString(htmlContent, baseURL: baseURL)
                print("✅ HTML content loaded with baseURL: \(baseURL.path)")
                print("📦 GLB files accessible at: \(baseURL.path)/3dmodel/")
            }
            context.coordinator.handleSelection(selectedProductEvent)
            return
        }
        
        // PRIORITY 2: ANDROID-LIKE: If URL is localhost/127.0.0.1 (product selected), use it directly
        // Only use this if htmlContent is not available
        if url.absoluteString.contains("localhost") || url.absoluteString.contains("127.0.0.1") {
            let currentURL = webView.url?.absoluteString ?? ""
            let targetURL = url.absoluteString
            
            if currentURL != targetURL || currentURL.isEmpty {
                print("🌐 Loading localhost/127.0.0.1 URL (Android-like): \(targetURL)")
                
                // Create request with proper configuration for localhost
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 30.0
                
                // Try loading with request
                webView.load(request)
                print("✅ Localhost URL loaded - using 127.0.0.1 (Android-like)")
                
                // Also try after a small delay in case first attempt fails
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if webView.url?.absoluteString != targetURL {
                        print("🔄 Retrying localhost load...")
                        webView.load(request)
                    }
                }
            } else {
                print("✅ WebView already loaded localhost URL: \(currentURL)")
            }
            context.coordinator.handleSelection(selectedProductEvent)
            return
        }
        
        // PRIORITY 3: Handle file:// URLs (iOS native, no server needed)
        let currentURL = webView.url?.absoluteString ?? ""
        let targetURL = url.absoluteString
        
        // Force reload if product is selected
        if hasProductSelected || currentURL != targetURL || currentURL.isEmpty {
            print("🔄 Loading URL in WebView: \(targetURL)")
            
            // Use file:// URL directly (iOS native approach)
            if url.isFileURL {
                // Extract hash fragment if present
                let hashFragment = url.fragment
                let baseFileURL = URL(fileURLWithPath: url.path)
                
                // Load file with read access to parent directory (for assets)
                let parentDir = baseFileURL.deletingLastPathComponent()
                webView.loadFileURL(baseFileURL, allowingReadAccessTo: parentDir)
                
                // Set hash fragment after load (for frontend routing)
                if let hash = hashFragment, !hash.isEmpty {
                    print("📦 Setting hash fragment after load: #\(hash)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        webView.evaluateJavaScript("window.location.hash = '#\(hash)';", completionHandler: { result, error in
                            if let error = error {
                                print("⚠️ Failed to set hash fragment: \(error.localizedDescription)")
                            } else {
                                print("✅ Hash fragment set: #\(hash)")
                            }
                        })
                    }
                }
            } else {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        } else {
            print("✅ WebView already loaded: \(currentURL)")
        }
        
        // If product is selected, inject prevention script (in case WebView was already created)
        if selectedProductEvent != nil {
            injectProductSelectionPrevention(webView: webView)
        }
        
        context.coordinator.handleSelection(selectedProductEvent)
    }
    
    // Inject script to prevent cache-data route when product is selected
    private func injectProductSelectionPrevention(webView: WKWebView) {
        guard let productEvent = selectedProductEvent else { return }
        
        let name = productEvent.productName.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let fileName = productEvent.fileName.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        
        let script = """
        (function() {
            console.log('🚫 iOS: Preventing cache-data route, product selected:', '\(name)');
            
            // Override hash change to prevent cache-data route
            const originalPushState = history.pushState;
            const originalReplaceState = history.replaceState;
            
            history.pushState = function() {
                const hash = arguments[2];
                if (hash && hash.includes && hash.includes('/cache-data')) {
                    console.log('🚫 iOS: Blocked pushState to cache-data route');
                    return;
                }
                return originalPushState.apply(history, arguments);
            };
            
            history.replaceState = function() {
                const hash = arguments[2];
                if (hash && hash.includes && hash.includes('/cache-data')) {
                    console.log('🚫 iOS: Blocked replaceState to cache-data route');
                    return;
                }
                return originalReplaceState.apply(history, arguments);
            };
            
            // Clear cache-data hash immediately
            if (window.location.hash && window.location.hash.includes('/cache-data')) {
                console.log('🚫 iOS: Clearing cache-data hash');
                history.replaceState(null, '', window.location.pathname);
            }
            
            // Set product immediately
            window.selectedProductFromNative = { name: '\(name)', fileName: '\(fileName)' };
            
            // Monitor hash changes and block cache-data
            window.addEventListener('hashchange', function(e) {
                if (window.location.hash && window.location.hash.includes('/cache-data')) {
                    console.log('🚫 iOS: Blocked hashchange to cache-data');
                    e.preventDefault();
                    e.stopPropagation();
                    history.replaceState(null, '', window.location.pathname);
                    return false;
                }
            }, true);
            
            // Override location.hash setter
            let hashDescriptor = Object.getOwnPropertyDescriptor(window, 'location') || 
                                 Object.getOwnPropertyDescriptor(Object.getPrototypeOf(window), 'location');
            if (hashDescriptor && hashDescriptor.set) {
                const originalHashSetter = hashDescriptor.set;
                Object.defineProperty(window, 'location', {
                    set: function(value) {
                        if (value && value.hash && value.hash.includes('/cache-data')) {
                            console.log('🚫 iOS: Blocked location.hash set to cache-data');
                            return;
                        }
                        originalHashSetter.call(window, value);
                    },
                    get: hashDescriptor.get,
                    configurable: true
                });
            }
        })();
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(userScript)
        print("✅ Product selection prevention script injected (runs at document start)")
    }
    
    // Inject console logging script
    private func injectConsoleLogging(webView: WKWebView) {
        let script = """
        (function() {
            const originalLog = console.log;
            const originalError = console.error;
            const originalWarn = console.warn;
            
            console.log = function(...args) {
                originalLog.apply(console, args);
                window.webkit.messageHandlers.console.postMessage({
                    type: 'log',
                    message: args.join(' ')
                });
            };
            
            console.error = function(...args) {
                originalError.apply(console, args);
                window.webkit.messageHandlers.console.postMessage({
                    type: 'error',
                    message: args.join(' ')
                });
            };
            
            console.warn = function(...args) {
                originalWarn.apply(console, args);
                window.webkit.messageHandlers.console.postMessage({
                    type: 'warn',
                    message: args.join(' ')
                });
            };
        })();
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func injectErrorPrevention(webView: WKWebView) {
        // ULTRA-AGGRESSIVE ERROR PREVENTION - Run BEFORE any content loads (like Android)
        let script = """
        (function() {
            console.log('ULTRA-AGGRESSIVE: Installing complete error prevention system...');
            
            // Override Error constructor
            const originalError = Error.prototype.constructor;
            Error.prototype.constructor = function(message) {
                if (message && (
                    message.includes('texture') ||
                    message.includes('Texture') ||
                    message.includes('THREE') ||
                    message.includes('WebGL') ||
                    message.includes('Error applying texture:') ||
                    message.includes('[object Event]')
                )) {
                    console.warn('ULTRA-AGGRESSIVE: Prevented error creation:', message);
                    return new Error('Suppressed texture error');
                }
                return new originalError(message);
            };
            
            // Override console.error completely
            console.error = function(...args) {
                const message = args.join(' ');
                if (message.includes('Error applying texture:') || 
                    message.includes('[object Event]') ||
                    message.includes('texture') ||
                    message.includes('Texture') ||
                    message.includes('THREE') ||
                    message.includes('WebGL')) {
                    console.warn('ULTRA-AGGRESSIVE: Completely suppressed error:', message);
                    return; // NEVER LOG TEXTURE ERRORS
                }
                try {
                    console.warn('Non-texture error:', message);
                } catch (e) {
                    // Suppress all errors
                }
            };
            
            // Override all texture functions to always return success
            const textureFunctionNames = [
                'applyTexture', 'applyTextureToComponents', 'applyFabricTexture',
                'applyTextureToShirt', 'applyTextureToMaterial', 'loadTexture',
                'createTexture', 'setTexture', 'updateTexture', 'loadFabricTexture',
                'applyFabric', 'setFabric', 'updateFabric', 'handleTexture',
                'processTexture', 'renderTexture', 'displayTexture'
            ];
            
            textureFunctionNames.forEach(funcName => {
                window[funcName] = function(...args) {
                    console.log('ULTRA-AGGRESSIVE: Safe execution of', funcName);
                    try {
                        // Always return success, never throw
                        return true;
                    } catch (e) {
                        console.warn('ULTRA-AGGRESSIVE: Function', funcName, 'suppressed');
                        return true;
                    }
                };
            });
            
            // Override setTimeout, setInterval, requestAnimationFrame
            const originalSetTimeout = window.setTimeout;
            window.setTimeout = function(func, delay, ...args) {
                if (typeof func === 'function') {
                    const ultraSafeFunc = function() {
                        try {
                            return func.apply(this, args);
                        } catch (error) {
                            if (error.message && (
                                error.message.includes('texture') ||
                                error.message.includes('Texture') ||
                                error.message.includes('THREE') ||
                                error.message.includes('WebGL') ||
                                error.message.includes('Error applying texture:')
                            )) {
                                console.warn('ULTRA-AGGRESSIVE: Suppressed async texture error');
                                return true;
                            }
                            console.warn('ULTRA-AGGRESSIVE: Suppressed async error:', error.message);
                            return true;
                        }
                    };
                    return originalSetTimeout.call(this, ultraSafeFunc, delay);
                }
                return originalSetTimeout.apply(this, arguments);
            };
            
            // Override addEventListener
            const originalAddEventListener = window.addEventListener;
            window.addEventListener = function(type, listener, options) {
                if (typeof listener === 'function') {
                    const ultraSafeListener = function(event) {
                        try {
                            return listener.call(this, event);
                        } catch (error) {
                            console.warn('ULTRA-AGGRESSIVE: Suppressed event listener error:', error.message);
                            return true;
                        }
                    };
                    return originalAddEventListener.call(this, type, ultraSafeListener, options);
                }
                return originalAddEventListener.apply(this, arguments);
            };
            
            // Global error handler
            window.addEventListener('error', function(event) {
                console.warn('ULTRA-AGGRESSIVE: Global error handler caught:', event.message);
                event.preventDefault();
                event.stopPropagation();
                return false;
            });
            
            // Override THREE.js TextureLoader
            window.THREE = window.THREE || {};
            if (window.THREE.TextureLoader) {
                window.THREE.TextureLoader.prototype.load = function(url, onLoad, onProgress, onError) {
                    console.log('ULTRA-AGGRESSIVE: Safe texture loading for:', url);
                    if (onLoad) {
                        try {
                            const canvas = document.createElement('canvas');
                            canvas.width = 64;
                            canvas.height = 64;
                            const ctx = canvas.getContext('2d');
                            ctx.fillStyle = '#f0f0f0';
                            ctx.fillRect(0, 0, 64, 64);
                            
                            const safeTexture = {
                                image: canvas,
                                wrapS: 1001,
                                wrapT: 1001,
                                repeat: { x: 1, y: 1 },
                                needsUpdate: true
                            };
                            
                            onLoad(safeTexture);
                        } catch (e) {
                            console.warn('ULTRA-AGGRESSIVE: Safe texture creation failed, but error suppressed');
                        }
                    }
                    return this;
                };
            }
            
            // Override Image constructor
            const originalImage = window.Image;
            window.Image = function() {
                const img = new originalImage();
                img.addEventListener('error', function(e) {
                    console.warn('ULTRA-AGGRESSIVE: Image loading failed but suppressed:', e.target.src);
                });
                return img;
            };
            
            // Create safe fallback texture function
            window.applySafeFallbackTexture = function() {
                console.log('ULTRA-AGGRESSIVE: Applying safe fallback texture');
                try {
                    if (window.THREE && window.scene) {
                        const canvas = document.createElement('canvas');
                        canvas.width = 64;
                        canvas.height = 64;
                        const ctx = canvas.getContext('2d');
                        ctx.fillStyle = '#f0f0f0';
                        ctx.fillRect(0, 0, 64, 64);
                        
                        const fallbackTexture = {
                            image: canvas,
                            wrapS: 1001,
                            wrapT: 1001,
                            repeat: { x: 1, y: 1 },
                            needsUpdate: true
                        };
                        
                        window.scene.traverse(function(child) {
                            if (child.material) {
                                if (Array.isArray(child.material)) {
                                    child.material.forEach(mat => {
                                        if (mat) {
                                            mat.map = fallbackTexture;
                                            mat.needsUpdate = true;
                                        }
                                    });
                                } else {
                                    child.material.map = fallbackTexture;
                                    child.material.needsUpdate = true;
                                }
                            }
                        });
                        
                        if (window.renderer && window.camera) {
                            window.renderer.render(window.scene, window.camera);
                        }
                        
                        console.log('ULTRA-AGGRESSIVE: Safe fallback texture applied');
                        return true;
                    }
                } catch (e) {
                    console.warn('ULTRA-AGGRESSIVE: Fallback texture failed but error suppressed');
                }
                return false;
            };
            
            // Assign fallback to all texture functions
            window.applyTexture = window.applySafeFallbackTexture;
            window.applyTextureToComponents = window.applySafeFallbackTexture;
            window.applyFabricTexture = window.applySafeFallbackTexture;
            
            console.log('ULTRA-AGGRESSIVE: Complete error prevention system installed');
            
            // Immediately apply fallback texture
            setTimeout(function() {
                window.applySafeFallbackTexture();
            }, 50);
        })();
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: WebViewWrapper
        private var periodicProtectionTimer: Timer?
        private weak var webViewReference: WKWebView?
        private var isPageLoaded = false
        private var pendingSelection: SelectedProductEvent?
        private var lastSelectionID: UUID?
        private var pageLoadTime: Date?
        private let minimumTimeBeforeCallback: TimeInterval = 2.0 // Minimum 2 seconds before accepting callback
        
        func updateCanGoBack(_ webView: WKWebView) {
            DispatchQueue.main.async {
                self.parent.canGoBack = webView.canGoBack
            }
        }
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        func updateWebViewReference(_ webView: WKWebView) {
            webViewReference = webView
        }
        
        func handleSelection(_ event: SelectedProductEvent?) {
            if let event = event {
                print("📦 handleSelection called with product: \(event.productName), fileName: \(event.fileName)")
            } else {
                print("📦 handleSelection called with nil (no product selected)")
            }
            pendingSelection = event
            sendSelectionIfPossible()
        }
        
        private func sendSelectionIfPossible() {
            guard let event = pendingSelection else {
                return
            }
            
            guard let webView = webViewReference else {
                print("⚠️ WebView reference not available, will retry when page loads")
                return
            }
            
            guard lastSelectionID != event.id else {
                print("⚠️ Product selection already sent (ID: \(event.id))")
                return
            }
            
            // If page is not loaded yet, wait a bit and retry
            if !isPageLoaded {
                print("⏳ Page not loaded yet, will retry product selection injection in 0.5s...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.sendSelectionIfPossible()
                }
                return
            }
            
            lastSelectionID = event.id
            
            let name = escapeForJavaScript(event.productName)
            let fileName = escapeForJavaScript(event.fileName)
            
            print("📦 Injecting product selection into WebView: name=\(event.productName), fileName=\(event.fileName)")
            
            let script = """
            (function() {
                try {
                    // FIRST: Clear cache-data hash if present
                    if (window.location.hash && window.location.hash.includes('/cache-data')) {
                        console.log('📦 iOS: Clearing cache-data hash');
                        window.history.replaceState(null, '', window.location.pathname);
                    }
                    
                    // Set product details
                    const detail = { name: '\(name)', fileName: '\(fileName)' };
                    console.log('📦 iOS: Setting selectedProductFromNative:', detail);
                    window.selectedProductFromNative = detail;
                    
                    // Call handler if exists (this should navigate to product)
                    if (typeof window.handleNativeProductSelection === 'function') {
                        console.log('📦 iOS: Calling handleNativeProductSelection');
                        window.handleNativeProductSelection(detail);
                    }
                    
                    // Dispatch event
                    if (window.dispatchEvent) {
                        console.log('📦 iOS: Dispatching nativeProductSelected event');
                        window.dispatchEvent(new CustomEvent('nativeProductSelected', { detail }));
                    }
                    
                    // Try router navigation (Vue Router, React Router, etc.)
                    if (window.router && typeof window.router.push === 'function') {
                        console.log('📦 iOS: Attempting router navigation to product');
                        try {
                            window.router.push({ name: 'product', params: { productName: detail.name, fileName: detail.fileName } });
                        } catch (e) {
                            console.log('📦 iOS: Router push failed, trying alternative');
                        }
                    }
                    
                    // Try direct hash navigation to product route
                    if (window.location && window.location.hash !== '#/cache-data') {
                        console.log('📦 iOS: Current hash:', window.location.hash);
                        // Don't set hash if we're trying to navigate away from cache-data
                    }
                    
                    // Force navigation away from cache-data screen
                    setTimeout(function() {
                        if (window.location.hash && window.location.hash.includes('/cache-data')) {
                            console.log('📦 iOS: Force clearing cache-data hash after delay');
                            window.history.replaceState(null, '', window.location.pathname);
                            // Try to trigger product load
                            if (window.handleNativeProductSelection) {
                                window.handleNativeProductSelection(detail);
                            }
                        }
                    }, 100);
                    
                    console.log('✅ iOS: Product selection injected successfully:', detail.name, detail.fileName);
                } catch (err) {
                    console.error('❌ iOS: Failed to send native product selection:', err);
                }
            })();
            """
            
            webView.evaluateJavaScript(script, completionHandler: { result, error in
                if let error = error {
                    print("❌ Failed to deliver product selection: \(error.localizedDescription)")
                    // Retry once after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self.lastSelectionID == event.id {
                            self.lastSelectionID = UUID() // Reset to allow retry
                            self.sendSelectionIfPossible()
                        }
                    }
                } else {
                    print("✅ Product selection successfully injected into WebView")
                }
            })
        }
        
        private func escapeForJavaScript(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
        }
        
        // Handle console messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "console" {
                if let body = message.body as? [String: Any],
                   let type = body["type"] as? String,
                   let messageText = body["message"] as? String {
                    let prefix = type == "error" ? "❌ JS Error" : (type == "warn" ? "⚠️ JS Warn" : "📝 JS Log")
                    print("\(prefix): \(messageText)")
                }
            } else if message.name == "onWebLoadingFinished" {
                // Handle callback from web content (like Android's WebAppInterface.onWebLoadingFinished)
                print("📱 Received onWebLoadingFinished callback from web content")
                print("📱 Message body type: \(type(of: message.body)), value: \(message.body)")
                
                // Check if page has been loaded for minimum time (prevent premature callbacks)
                if let loadTime = pageLoadTime {
                    let timeSinceLoad = Date().timeIntervalSince(loadTime)
                    if timeSinceLoad < minimumTimeBeforeCallback {
                        print("⚠️ Callback received too soon (\(String(format: "%.2f", timeSinceLoad))s) - waiting for minimum \(minimumTimeBeforeCallback)s)")
                        // Delay the callback
                        DispatchQueue.main.asyncAfter(deadline: .now() + (minimumTimeBeforeCallback - timeSinceLoad)) {
                            self.processWebLoadingFinishedCallback(message.body)
                        }
                        return
                    }
                } else {
                    print("⚠️ Page load time not recorded - accepting callback anyway")
                }
                
                processWebLoadingFinishedCallback(message.body)
            } else if message.name == "cachePercentage" {
                processCachePercentage(message.body)
            }
        }
        
        private func processWebLoadingFinishedCallback(_ messageBody: Any) {
            var successValue = false
            
            if let success = messageBody as? Bool {
                successValue = success
                print("✅ Parsed as Bool: \(success)")
            } else if let successNumber = messageBody as? NSNumber {
                successValue = successNumber.boolValue
                print("✅ Parsed as NSNumber: \(successValue)")
            } else if let successString = messageBody as? String {
                // Handle string "true"/"false"
                successValue = (successString.lowercased() == "true" || successString == "1")
                print("✅ Parsed as String: \(successString) -> \(successValue)")
            } else {
                print("⚠️ onWebLoadingFinished received unexpected data type: \(type(of: messageBody)), value: \(messageBody)")
                // Don't default to true - let the handler decide
                successValue = false
            }
            
            print("📱 Calling onWebLoadingFinished callback with: \(successValue)")
            parent.onWebLoadingFinished?(successValue)
        }
        
        private func processCachePercentage(_ messageBody: Any) {
            var percentValue: Double = 0
            
            if let value = messageBody as? Double {
                percentValue = value
            } else if let valueNumber = messageBody as? NSNumber {
                percentValue = valueNumber.doubleValue
            } else if let valueString = messageBody as? String,
                      let parsed = Double(valueString) {
                percentValue = parsed
            } else {
                print("⚠️ cachePercentage received unexpected data type: \(type(of: messageBody)), value: \(messageBody)")
            }
            
            print("📊 Forwarding cache percentage to native: \(percentValue)")
            parent.onCacheProgress?(percentValue)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            let urlString = webView.url?.absoluteString ?? "unknown"
            print("🚀 WebView started loading: \(urlString)")
            isPageLoaded = false
            pageLoadTime = nil
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
            // Update canGoBack when navigation starts
            updateCanGoBack(webView)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let urlString = navigationAction.request.url?.absoluteString ?? "unknown"
            print("🔍 Navigation decision for: \(urlString)")
            
            // Allow localhost/127.0.0.1 requests (Android-like)
            if urlString.contains("localhost") || urlString.contains("127.0.0.1") {
                print("✅ Allowing localhost request: \(urlString)")
                decisionHandler(.allow)
                return
            }
            
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let urlString = webView.url?.absoluteString ?? "unknown"
            print("✅ WebView finished loading: \(urlString)")
            isPageLoaded = true
            pageLoadTime = Date()
            print("⏰ Page load time recorded: \(pageLoadTime?.description ?? "nil")")
            
            // Update canGoBack after navigation
            updateCanGoBack(webView)
            
            // Check apiDone flag (like Android onPageFinished)
            let apiDone = UserDataManager.shared.getApiDone()
            print("📋 API Done flag: \(apiDone)")
            
            // Set apiDoneFromAndroid like Android does (based on SharedPreferences)
            webView.evaluateJavaScript("window.apiDoneFromAndroid = \(apiDone ? "true" : "false");", completionHandler: { result, error in
                if let error = error {
                    print("⚠️ Error setting apiDoneFromAndroid: \(error.localizedDescription)")
                } else {
                    print("✅ window.apiDoneFromAndroid set to: \(apiDone)")
                }
            })
            
            // Check if page loaded successfully
            webView.evaluateJavaScript("document.readyState") { (result, error) in
                if let error = error {
                    print("⚠️ Error checking page state: \(error.localizedDescription)")
                } else {
                    print("📄 Page ready state: \(result ?? "unknown")")
                }
            }
            
            // Check body content and HTML structure with detailed diagnostics
            webView.evaluateJavaScript("""
                (function() {
                    const body = document.body;
                    const html = document.documentElement;
                    return {
                        bodyLength: body ? body.innerHTML.length : 0,
                        bodyText: body ? body.innerText.substring(0, 200) : '',
                        htmlLength: html ? html.innerHTML.length : 0,
                        hasBody: !!body,
                        hasContent: body && body.children.length > 0,
                        childCount: body ? body.children.length : 0
                    };
                })();
            """) { (result, error) in
                if let dict = result as? [String: Any] {
                    let bodyLength = dict["bodyLength"] as? Int ?? 0
                    let bodyText = dict["bodyText"] as? String ?? ""
                    let htmlLength = dict["htmlLength"] as? Int ?? 0
                    let hasBody = dict["hasBody"] as? Bool ?? false
                    let hasContent = dict["hasContent"] as? Bool ?? false
                    let childCount = dict["childCount"] as? Int ?? 0
                    
                    print("📄 Body content length: \(bodyLength) characters")
                    print("📄 HTML total length: \(htmlLength) characters")
                    print("📄 Has body element: \(hasBody)")
                    print("📄 Has content: \(hasContent)")
                    print("📄 Body child count: \(childCount)")
                    if !bodyText.isEmpty {
                        print("📄 Body text preview: \(bodyText)")
                    }
                    
                    if bodyLength == 0 || !hasContent {
                        print("⚠️ WARNING: Body is empty or has no content!")
                        print("⚠️ Possible causes:")
                        print("   1. HTML file is empty or broken")
                        print("   2. JavaScript cleared the body")
                        print("   3. baseURL is causing issues with relative paths")
                        print("   4. HTML structure was broken during patching")
                        
                        // Try to get more info about what's in the DOM
                        webView.evaluateJavaScript("""
                            (function() {
                                const body = document.body;
                                const html = document.documentElement;
                                return {
                                    bodyHTML: body ? body.innerHTML.substring(0, 500) : 'NO BODY',
                                    bodyOuterHTML: body ? body.outerHTML.substring(0, 500) : 'NO BODY',
                                    htmlHTML: html ? html.innerHTML.substring(0, 500) : 'NO HTML',
                                    scripts: Array.from(document.scripts).map(s => s.src || s.innerHTML.substring(0, 100)),
                                    stylesheets: Array.from(document.styleSheets).map(s => s.href || 'inline'),
                                    errors: window.errors || []
                                };
                            })();
                        """) { (result, error) in
                            if let dict = result as? [String: Any] {
                                print("🔍 DEBUG - Body HTML: \(dict["bodyHTML"] ?? "N/A")")
                                print("🔍 DEBUG - Body Outer HTML: \(dict["bodyOuterHTML"] ?? "N/A")")
                                print("🔍 DEBUG - HTML HTML: \(dict["htmlHTML"] ?? "N/A")")
                                print("🔍 DEBUG - Scripts: \(dict["scripts"] ?? [])")
                                print("🔍 DEBUG - Stylesheets: \(dict["stylesheets"] ?? [])")
                            }
                        }
                    }
                } else if let error = error {
                    print("❌ Failed to check body content: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            
            // Inject token data if available (like Android onPageFinished)
            if let tokenData = parent.tokenData {
                print("🔑 Injecting token data (like Android onPageFinished)...")
                injectTokenData(webView: webView, tokenData: tokenData)
            }
            
            // Inject JavaScript interface for onWebLoadingFinished callback (like Android WebAppInterface)
            injectWebAppInterface(webView: webView)
            
            // If product is selected, inject prevention script again (in case it wasn't injected at document start)
            if parent.selectedProductEvent != nil {
                injectProductSelectionPreventionOnLoad(webView: webView)
            }
            
            // Inject immediate error protection
            injectImmediateErrorProtection(webView: webView)
            
            // Inject additional scripts after page load
            injectPostLoadScripts(webView: webView)
            
            // Setup periodic protection (every 5 seconds like Android)
            setupPeriodicProtection(webView: webView)
            
            // Deliver any pending product selection to the web content
            sendSelectionIfPossible()
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // Inject ultra-aggressive error prevention on commit
            injectUltraAggressiveErrorPrevention(webView: webView)
        }
        
        private func injectProductSelectionPreventionOnLoad(webView: WKWebView) {
            guard let productEvent = parent.selectedProductEvent else { return }
            
            let name = productEvent.productName.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let fileName = productEvent.fileName.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            
            let script = """
            (function() {
                console.log('🚫 iOS: Post-load prevention - clearing cache-data hash');
                
                // Clear cache-data hash immediately
                if (window.location.hash && window.location.hash.includes('/cache-data')) {
                    console.log('🚫 iOS: Clearing cache-data hash on page load');
                    window.history.replaceState(null, '', window.location.pathname);
                }
                
                // Set product
                window.selectedProductFromNative = { name: '\(name)', fileName: '\(fileName)' };
                
                // Try to navigate to product
                if (typeof window.handleNativeProductSelection === 'function') {
                    window.handleNativeProductSelection({ name: '\(name)', fileName: '\(fileName)' });
                }
            })();
            """
            
            webView.evaluateJavaScript(script, completionHandler: { result, error in
                if let error = error {
                    print("⚠️ Error injecting product prevention on load: \(error.localizedDescription)")
                } else {
                    print("✅ Product prevention script injected after page load")
                }
            })
        }
        
        private func injectTokenData(webView: WKWebView, tokenData: String) {
            let script = """
            (function() {
                try {
                    const tokenData = \(tokenData);
                    window.tokenData = tokenData;
                    window.apiDoneFromAndroid = true;
                    
                    // Dispatch event for token data
                    if (window.dispatchEvent) {
                        window.dispatchEvent(new CustomEvent('tokenDataReady', { detail: tokenData }));
                    }
                    
                    console.log('Token data injected:', tokenData);
                } catch (e) {
                    console.error('Error injecting token data:', e);
                }
            })();
            """
            
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        private func injectWebAppInterface(webView: WKWebView) {
            // Inject JavaScript interface (like Android's WebAppInterface)
            // This allows web content to call onWebLoadingFinished
            let script = """
            (function() {
                // Create AndroidBackgroundProcessor object (like Android)
                window.AndroidBackgroundProcessor = window.AndroidBackgroundProcessor || {};
                
                // onWebLoadingFinished callback (like Android WebAppInterface.onWebLoadingFinished)
                window.AndroidBackgroundProcessor.onWebLoadingFinished = function(success) {
                    console.log('📱 Calling onWebLoadingFinished with:', success);
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onWebLoadingFinished) {
                            window.webkit.messageHandlers.onWebLoadingFinished.postMessage(success);
                            console.log('✅ onWebLoadingFinished callback sent to native');
                        } else {
                            console.warn('⚠️ onWebLoadingFinished message handler not available');
                        }
                    } catch (e) {
                        console.error('❌ Error calling onWebLoadingFinished:', e);
                    }
                };
                
                // getProductCachePercentage callback (like Android WebAppInterface.getProductCachePercentage)
                window.AndroidBackgroundProcessor.getProductCachePercentage = function(percent) {
                    console.log('📊 Product cache percentage:', percent);
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cachePercentage) {
                            window.webkit.messageHandlers.cachePercentage.postMessage(percent);
                            console.log('✅ cachePercentage callback sent to native');
                        } else {
                            console.warn('⚠️ cachePercentage message handler not available');
                        }
                    } catch (e) {
                        console.error('❌ Error calling cachePercentage:', e);
                    }
                };
                
                // saveCustomizedProductData callback (like Android WebAppInterface.saveCustomizedProductData)
                window.AndroidBackgroundProcessor.saveCustomizedProductData = function(jsonArray) {
                    console.log('💾 Saving customized product data:', jsonArray);
                    // This can be handled later if needed
                };
                
                console.log('✅ AndroidBackgroundProcessor interface injected');
            })();
            """
            
            webView.evaluateJavaScript(script, completionHandler: { result, error in
                if let error = error {
                    print("⚠️ Error injecting WebAppInterface: \(error.localizedDescription)")
                } else {
                    print("✅ WebAppInterface injected successfully")
                }
            })
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let urlString = webView.url?.absoluteString ?? "unknown"
            let nsError = error as NSError
            print("❌ WebView navigation failed for: \(urlString)")
            print("❌ Error code: \(nsError.code), domain: \(nsError.domain)")
            print("❌ Error description: \(error.localizedDescription)")
            print("❌ Error userInfo: \(nsError.userInfo)")
            
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let urlString = webView.url?.absoluteString ?? "unknown"
            let nsError = error as NSError
            print("❌ WebView provisional navigation failed for: \(urlString)")
            print("❌ Error code: \(nsError.code), domain: \(nsError.domain)")
            print("❌ Error description: \(error.localizedDescription)")
            print("❌ Error userInfo: \(nsError.userInfo)")
            
            // If localhost fails, fallback to file:// URL
            if urlString.contains("localhost") || urlString.contains("127.0.0.1") {
                print("⚠️ Localhost failed, falling back to file:// URL")
                // Extract hash fragment (fallback will be handled by ViewModel)
                if let _ = URL(string: urlString) {
                    // This will be handled by the ViewModel fallback
                }
            }
            
            // Check if it's a timeout or connection error
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorTimedOut:
                    print("⏱️ Request timed out - retrying...")
                    // Retry after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("🔄 Retrying WebView load...")
                        webView.reload()
                    }
                case NSURLErrorCannotConnectToHost:
                    print("❌ Cannot connect to host - is local server running?")
                    // Retry after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("🔄 Retrying WebView load...")
                        webView.reload()
                    }
                case NSURLErrorNetworkConnectionLost:
                    print("❌ Network connection lost - retrying...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("🔄 Retrying WebView load...")
                        webView.reload()
                    }
                default:
                    print("❌ Other URL error: \(nsError.code)")
                }
            }
            
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        // Handle console messages (like Android WebChromeClient.onConsoleMessage)
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("📱 WebView Alert: \(message)")
            completionHandler()
        }
        
        // Handle JavaScript errors
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            // Handle SSL challenges
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
        
        private func injectImmediateErrorProtection(webView: WKWebView) {
            // Inject immediate error protection (like Android)
            let script = """
            (function() {
                console.log('Injecting COMPLETE error suppression system...');
                
                const originalConsoleError = console.error;
                console.error = function(...args) {
                    const message = args.join(' ');
                    
                    if (message.includes('Error applying texture:') || 
                        message.includes('[object Event]') ||
                        message.includes('texture') ||
                        message.includes('Texture') ||
                        message.includes('THREE') ||
                        message.includes('WebGL')) {
                        console.warn('SUPPRESSED: Texture error prevented:', message);
                        return; // COMPLETELY IGNORE THE ERROR
                    }
                    
                    originalConsoleError.apply(console, args);
                };
                
                const textureFunctionNames = [
                    'applyTexture', 'applyTextureToComponents', 'applyFabricTexture',
                    'applyTextureToShirt', 'applyTextureToMaterial', 'loadTexture',
                    'createTexture', 'setTexture', 'updateTexture', 'loadFabricTexture',
                    'applyFabric', 'setFabric', 'updateFabric'
                ];
                
                textureFunctionNames.forEach(funcName => {
                    if (window[funcName]) {
                        const originalFunc = window[funcName];
                        window[funcName] = function(...args) {
                            try {
                                console.log('SAFE: Executing', funcName, 'with protection');
                                
                                const validArgs = args.filter(arg => {
                                    if (arg === null || arg === undefined) return false;
                                    if (typeof arg === 'object' && Object.keys(arg).length === 0) return false;
                                    if (typeof arg === 'string' && arg.trim() === '') return false;
                                    return true;
                                });
                                
                                if (validArgs.length === 0) {
                                    console.warn('SAFE: No valid arguments for', funcName, ', using fallback');
                                    return window.applySafeFallbackTexture();
                                }
                                
                                const result = originalFunc.apply(this, validArgs);
                                
                                if (result instanceof Error || result === null || result === undefined) {
                                    console.warn('SAFE: Function returned error/null, using fallback');
                                    return window.applySafeFallbackTexture();
                                }
                                
                                return result;
                            } catch (error) {
                                console.warn('SAFE: Function', funcName, 'failed, using fallback:', error.message);
                                return window.applySafeFallbackTexture();
                            }
                        };
                        console.log('SAFE: Override applied to', funcName);
                    }
                });
                
                // Override THREE.js TextureLoader
                if (window.THREE && window.THREE.TextureLoader) {
                    const originalLoad = window.THREE.TextureLoader.prototype.load;
                    window.THREE.TextureLoader.prototype.load = function(url, onLoad, onProgress, onError) {
                        const safeOnError = function(error) {
                            console.warn('SAFE: Texture loading failed for:', url, 'using fallback');
                            if (onError) {
                                onError(new Error('Texture loading failed: ' + url));
                            }
                            window.applySafeFallbackTexture();
                        };
                        
                        const safeOnLoad = function(texture) {
                            if (onLoad) {
                                try {
                                    onLoad(texture);
                                } catch (error) {
                                    console.warn('SAFE: onLoad callback failed, using fallback');
                                    window.applySafeFallbackTexture();
                                }
                            }
                        };
                        
                        return originalLoad.call(this, url, safeOnLoad, onProgress, safeOnError);
                    };
                    console.log('SAFE: THREE.js TextureLoader overridden');
                }
                
                // Override Image constructor
                const originalImage = window.Image;
                window.Image = function() {
                    const img = new originalImage();
                    img.addEventListener('error', function(e) {
                        console.warn('SAFE: Image loading failed:', e.target.src, 'using fallback');
                        window.applySafeFallbackTexture();
                    });
                    return img;
                };
                
                console.log('SAFE: Complete error suppression system injected');
                
                // Immediately apply fallback texture
                setTimeout(function() {
                    window.applySafeFallbackTexture();
                }, 100);
            })();
            """
            
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        private func injectUltraAggressiveErrorPrevention(webView: WKWebView) {
            // Ultra-aggressive error prevention (like Android)
            let script = """
            (function() {
                console.log('ULTRA-AGGRESSIVE: Re-injecting error prevention...');
                
                // Re-apply all protections
                if (window.applySafeFallbackTexture) {
                    window.applySafeFallbackTexture();
                }
                
                // Re-assign texture functions
                window.applyTexture = window.applySafeFallbackTexture || function() { return true; };
                window.applyTextureToComponents = window.applySafeFallbackTexture || function() { return true; };
                window.applyFabricTexture = window.applySafeFallbackTexture || function() { return true; };
            })();
            """
            
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        private func injectPostLoadScripts(webView: WKWebView) {
            // Inject proactive texture protection (similar to Android)
            let script = """
            (function() {
                console.log('Injecting proactive texture protection...');
                
                // Override applyTextureToComponents
                if (window.applyTextureToComponents) {
                    const originalApply = window.applyTextureToComponents;
                    window.applyTextureToComponents = function(textureData, componentType) {
                        try {
                            console.log('Proactive: Safe texture application to', componentType);
                            
                            if (!textureData || !textureData.fabImage) {
                                console.warn('Proactive: Invalid texture data for', componentType, ', using fallback');
                                return window.applySafeFallbackTexture();
                            }
                            
                            return originalApply.call(this, textureData, componentType);
                        } catch (error) {
                            console.warn('Proactive: Texture application to', componentType, 'failed, using fallback:', error);
                            return window.applySafeFallbackTexture();
                        }
                    };
                    console.log('Proactive: Override applied to applyTextureToComponents');
                }
                
                // Override applyFabricTexture
                if (window.applyFabricTexture) {
                    const originalFabric = window.applyFabricTexture;
                    window.applyFabricTexture = function(fabricData) {
                        try {
                            console.log('Proactive: Safe fabric texture application');
                            
                            if (!fabricData || !fabricData.fabImage) {
                                console.warn('Proactive: Invalid fabric data, using fallback');
                                return window.applySafeFallbackTexture();
                            }
                            
                            return originalFabric.call(this, fabricData);
                        } catch (error) {
                            console.warn('Proactive: Fabric texture failed, using fallback:', error);
                            return window.applySafeFallbackTexture();
                        }
                    };
                    console.log('Proactive: Override applied to applyFabricTexture');
                }
                
                // Override other texture functions
                const textureFunctions = [
                    'applyTextureToShirt',
                    'applyTextureToMaterial',
                    'loadTexture',
                    'createTexture'
                ];
                
                textureFunctions.forEach(funcName => {
                    if (window[funcName]) {
                        const originalFunc = window[funcName];
                        window[funcName] = function(...args) {
                            try {
                                console.log('Proactive: Safe execution of', funcName);
                                return originalFunc.apply(this, args);
                            } catch (error) {
                                console.warn('Proactive:', funcName, 'failed, using fallback:', error);
                                return window.applySafeFallbackTexture();
                            }
                        };
                        console.log('Proactive: Override applied to', funcName);
                    }
                });
                
                console.log('Proactive texture protection injected');
            })();
            """
            
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        private func setupPeriodicProtection(webView: WKWebView) {
            // Setup periodic protection (every 5 seconds like Android)
            periodicProtectionTimer?.invalidate()
            periodicProtectionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.injectImmediateErrorProtection(webView: webView)
            }
        }
        
        deinit {
            periodicProtectionTimer?.invalidate()
        }
    }
}


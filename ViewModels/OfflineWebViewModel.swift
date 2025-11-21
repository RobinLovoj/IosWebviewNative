//
//  OfflineWebViewModel.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation
import Combine

struct SelectedProductEvent: Identifiable, Equatable {
    let id = UUID()
    let productName: String
    let fileName: String
}

class OfflineWebViewModel: ObservableObject {
    @Published var isDownloading = false
    @Published var isExtracting = false
    @Published var downloadProgress: Int = 0
    @Published var products: [Product] = []
    @Published var overallProgress: Int = 0
    @Published var isContentReady = false
    @Published var webViewURL: URL = URL(string: "about:blank")!
    @Published var tokenData: String?
    @Published var htmlContent: String?
    @Published var baseURL: URL?
    @Published var extractionProgress: Int = 0
    @Published var extractionFileName: String = ""
    @Published var extractionCurrent: Int = 0
    @Published var extractionTotal: Int = 0
    @Published var shouldShowProductSelection = false
    @Published var shouldShowWebView = false
    @Published var selectedProductEvent: SelectedProductEvent?
    @Published var cacheDownloadPercent: Double = 0
    
    // Callback for web content to notify when cache-data is complete
    var onWebLoadingFinished: ((Bool) -> Void)?
    
    // Flag to prevent premature navigation away from cache-data screen
    @Published var isCacheDataScreenActive = false
    private var hasCacheReachedHundred = false
    private var hasReceivedSuccessCallback = false
    
    // Flag to prevent multiple calls to startContentDownload
    private var hasStartedContentDownload = false
    
    private var contentManager: ContentManager?
    private var localWebServer: LocalWebServer?
    private let baseDir: URL
    
    init() {
        // Setup base directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseDir = documentsPath.appendingPathComponent("offline_web")
        
        contentManager = ContentManager(baseDir: baseDir)
        loadProducts()
    }
    
    func startContentDownload() {
        // Prevent multiple calls (e.g., from onAppear being called multiple times)
        if hasStartedContentDownload && (shouldShowWebView || shouldShowProductSelection || isContentReady) {
            print("⚠️ startContentDownload already called - skipping to prevent state reset")
            return
        }
        
        let distDir = baseDir.appendingPathComponent("dist")
        let distIndexFile = distDir.appendingPathComponent("index.html")
        
        // Only reset UI flow if we're not already in the middle of a flow
        if !isCacheDataScreenActive {
            shouldShowProductSelection = false
            shouldShowWebView = false
            selectedProductEvent = nil
        }
        
        hasStartedContentDownload = true
        
        // Check if content already exists (OFFLINE MODE)
        if FileManager.default.fileExists(atPath: distIndexFile.path) {
            print("✅ Content already exists, loading directly (OFFLINE MODE)")
            
            if products.isEmpty {
                if let user = UserDataManager.shared.getUser(),
                   !user.makingProductList.isEmpty {
                    print("✅ Loading products from saved login response (offline)")
                    products = buildProductModels(with: user.makingProductList)
                } else {
                    print("⚠️ Using default products (offline mode)")
                    products = getDefaultProducts()
                }
            }
            
            let token = UserDataManager.shared.getToken() ?? "test_token_123"
            let tokenJson = ["token": token]
            let tokenString = (try? JSONSerialization.data(withJSONObject: tokenJson)).flatMap { String(data: $0, encoding: .utf8) }
            
            if UserDataManager.shared.getApiDone() {
                if ensureLocalServerRunning(distDir: distDir) {
                    print("✅ Cache already complete previously - jumping to product selection")
                    DispatchQueue.main.async {
                        self.tokenData = tokenString
                        self.selectedProductEvent = nil
                        self.shouldShowWebView = false
                        self.shouldShowProductSelection = true
                        self.isCacheDataScreenActive = false
                        self.isContentReady = true
                        self.cacheDownloadPercent = 100
                    }
                    return
                }
            }
            
            self.tokenData = tokenString
            loadContent()
            return
        }
        
        // Load products for display (they're part of ZIP, not separate downloads)
        if products.isEmpty {
            print("📦 Loading products for display...")
            // Use default products immediately to show UI
            products = getDefaultProducts()
        }
        
        // Start ZIP download directly (products are just for display)
        print("🚀 Starting ZIP download...")
        downloadMainZip()
    }
    
    private func downloadMainZip() {
        // Start ZIP download
        print("📥 Starting ZIP download from server...")
        isDownloading = true
        isExtracting = false
        downloadProgress = 0
        
        // Reset all products progress (they'll update based on ZIP progress)
        for index in products.indices {
            products[index].percent = 0
            products[index].isChecked = false
        }
        
        contentManager?.downloadZip(
            onProgress: { [weak self] progress in
                guard let self = self else { return }
                print("📊 ZIP Download Progress: \(progress)%")
                
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    
                    // Update products sequentially based on ZIP download progress
                    // Each product gets its share of ZIP progress
                    let productCount = self.products.count
                    if productCount > 0 {
                        let progressPerProduct = max(1, 100 / productCount)
                        
                        for index in self.products.indices {
                            // Calculate which products should be complete
                            let completedProducts = progress / progressPerProduct
                            
                            if index < completedProducts {
                                // Product is complete
                                self.products[index].percent = 100
                                self.products[index].isChecked = true
                            } else if index == completedProducts {
                                // Current product is downloading
                                let currentProductProgress = (progress % progressPerProduct) * 100 / progressPerProduct
                                self.products[index].percent = currentProductProgress
                                self.products[index].isChecked = false
                            } else {
                                // Product not started yet
                                self.products[index].percent = 0
                                self.products[index].isChecked = false
                            }
                        }
                    }
                    
                    self.calculateOverallProgress()
                }
            },
            onComplete: { [weak self] zipFile in
                guard let self = self else { return }
                
                print("✅ ZIP Download Complete!")
                print("📦 ZIP File Path: \(zipFile.path)")
                
                // Mark all products as complete
                DispatchQueue.main.async {
                    for index in self.products.indices {
                        self.products[index].percent = 100
                        self.products[index].isChecked = true
                    }
                    self.downloadProgress = 100
                    self.calculateOverallProgress()
                }
                
                // Check if this is a dummy file (content already exists)
                if zipFile.path.contains("existing_content.zip") {
                    // Content already exists, skip extraction
                    print("✅ Content already exists, skipping extraction")
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        self.isExtracting = false
                        self.loadContent()
                    }
                    return
                }
                
                // Check if content already exists (extracted)
                let distIndexFile = self.baseDir.appendingPathComponent("dist/index.html")
                let contentExists = FileManager.default.fileExists(atPath: distIndexFile.path)
                
                if contentExists {
                    // Content already extracted, skip extraction
                    print("✅ Content already extracted, skipping extraction")
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        self.isExtracting = false
                        self.loadContent()
                    }
                    return
                }
                
                // Set extracting flag BEFORE starting extraction
                print("🚀 Starting extraction process...")
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isExtracting = true
                    self.downloadProgress = 100
                    self.extractionProgress = 0
                    self.extractionFileName = ""
                    self.extractionCurrent = 0
                    self.extractionTotal = 0
                    print("✅ Extraction UI should be visible now")
                }
                
                // Small delay to ensure UI updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    
                    // Extract ZIP file with progress tracking
                    print("📂 Extracting ZIP file: \(zipFile.path)")
                    self.contentManager?.extractZip(
                        zipFile: zipFile,
                        onProgress: { [weak self] fileName, current, total in
                            DispatchQueue.main.async {
                                self?.extractionFileName = fileName
                                self?.extractionCurrent = current
                                self?.extractionTotal = total
                                self?.extractionProgress = total > 0 ? Int((current * 100) / total) : 0
                                print("📄 Extracting: \(fileName) (\(current)/\(total))")
                            }
                        },
                        onComplete: { [weak self] in
                            print("✅ Extraction complete!")
                            DispatchQueue.main.async {
                                self?.isExtracting = false
                                self?.extractionProgress = 100
                                self?.loadContent()
                            }
                        },
                        onError: { [weak self] error in
                            print("❌ Extraction error: \(error)")
                            DispatchQueue.main.async {
                                // Keep extraction UI visible to show error
                                // Update extraction progress to show error state
                                self?.extractionFileName = "Error: \(error)"
                                self?.extractionProgress = 0
                                
                                // Wait a bit before hiding extraction UI
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                                    self?.isExtracting = false
                                    // Try to load existing content anyway
                                    self?.loadContent()
                                }
                            }
                        }
                    )
                }
            },
            onError: { [weak self] error in
                print("❌ Download error: \(error)")
                DispatchQueue.main.async {
                    self?.isDownloading = false
                    // Try to load existing content anyway
                    self?.loadContent()
                }
            }
        )
    }
    
    private func loadContent() {
        let distDir = baseDir.appendingPathComponent("dist")
        let distIndexFile = distDir.appendingPathComponent("index.html")
        
        guard FileManager.default.fileExists(atPath: distIndexFile.path) else {
            print("❌ Content not found")
            return
        }
        
        let token = UserDataManager.shared.getToken() ?? "test_token_123"
        let tokenJson = ["token": token]
        let tokenString = (try? JSONSerialization.data(withJSONObject: tokenJson)).flatMap { String(data: $0, encoding: .utf8) }
        
        if UserDataManager.shared.getApiDone() {
            print("✅ Cache already complete. Showing product selection.")
            DispatchQueue.main.async {
                self.webViewURL = distIndexFile
                self.htmlContent = nil
                self.baseURL = nil
                self.tokenData = tokenString
                self.isContentReady = true
                self.shouldShowWebView = false
                self.shouldShowProductSelection = true
                self.selectedProductEvent = nil
                self.isCacheDataScreenActive = false
                self.cacheDownloadPercent = 100
            }
            return
        }
        
        guard ensureLocalServerRunning(distDir: distDir), let server = localWebServer else {
            print("❌ Local HTTP server instance missing")
            return
        }
        
        UserDataManager.shared.setApiDone(false)
        
        let cacheURL = server.getCacheDataURL(token: token)
        
        DispatchQueue.main.async {
            self.webViewURL = cacheURL
            self.htmlContent = nil
            self.baseURL = nil
            self.tokenData = tokenString
            self.isContentReady = true
            self.shouldShowWebView = true
            self.shouldShowProductSelection = false
            self.selectedProductEvent = nil
            self.isCacheDataScreenActive = true
            self.cacheDownloadPercent = 0
            self.hasCacheReachedHundred = false
            self.hasReceivedSuccessCallback = false
            
            print("✅ Serving cache-data route from local HTTP server")
            print("🌐 URL: \(cacheURL.absoluteString)")
            print("📁 Assets directory: \(distDir.path)")
        }
    }

    private func loadProducts() {
        // Pre-populate with full men + women catalog so UI shows everything immediately
        products = buildProductModels(with: nil)
        
        // Priority 1: Get products from saved login response (user.makingProductList)
        if let user = UserDataManager.shared.getUser(),
           !user.makingProductList.isEmpty {
            print("✅ Loading products from login response: \(user.makingProductList.count) products")
            products = buildProductModels(with: user.makingProductList)
            return
        }
        
        // Priority 2: Get products from API
        let token = UserDataManager.shared.getToken()
        
        if let token = token {
            print("📡 Fetching products from API...")
            fetchProductsFromAPI(token: token)
        } else {
            print("⚠️ No token found, using default products")
            products = buildProductModels(with: nil)
        }
    }

    private func fetchProductsFromAPI(token: String) {
        Task {
            do {
                let productNames = try await ProductService.shared.fetchMakingProductList(token: token)
                
                await MainActor.run {
                    print("✅ Products fetched from API: \(productNames.count) products")
                    products = buildProductModels(with: productNames)
                    if isDownloading == false && isContentReady == false {
                        print("✅ Products loaded, starting ZIP download...")
                        downloadMainZip()
                    }
                }
            } catch {
                let errorMessage = error.localizedDescription
                if errorMessage.contains("Route not found") {
                    print("⚠️ API endpoint not found, using default products (this is normal)")
                } else {
                    print("⚠️ Failed to fetch products from API: \(errorMessage), using default products")
                }
                
                await MainActor.run {
                    print("✅ Using default products as fallback")
                    products = buildProductModels(with: nil)
                    if isDownloading == false && isContentReady == false {
                        print("✅ Default products loaded, starting ZIP download...")
                        downloadMainZip()
                    }
                }
            }
        }
    }

    private func buildProductModels(with extraNames: [String]?) -> [Product] {
        var seen = Set<String>()
        var result: [Product] = []
        
        func appendIfNeeded(name: String, category: ProductCategory) {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return }
            if seen.insert(key).inserted {
                result.append(
                    Product(
                        name: name,
                        imageName: getProductImageName(name),
                        category: category,
                        fileName: getProductFileName(name)
                    )
                )
            }
        }
        
        DefaultProductLists.allEntries.forEach { entry in
            appendIfNeeded(name: entry.name, category: entry.category)
        }
        
        extraNames?.forEach { name in
            appendIfNeeded(name: name, category: getProductCategory(name))
        }
        
        return result
    }

    private func getDefaultProducts() -> [Product] {
        return DefaultProductLists.allEntries.map { entry in
            Product(
                name: entry.name,
                imageName: getProductImageName(entry.name),
                category: entry.category,
                fileName: getProductFileName(entry.name)
            )
        }
    }
    
    func downloadProductsSequentially() {
        if products.isEmpty {
            print("⚠️ No products to download, using default products")
            products = getDefaultProducts()
        }
        
        print("🚀 Starting sequential download for \(products.count) products")
        
        // Set downloading flag immediately
        isDownloading = true
        isExtracting = false
        downloadProgress = 0
        
        // Reset all products
        for index in products.indices {
            products[index].percent = 0
            products[index].isChecked = false
        }
        
        // Start downloading products one by one
        downloadProductAtIndex(0)
    }
    
    private func downloadProductAtIndex(_ index: Int) {
        if index >= products.count {
            // All products downloaded, now download main ZIP
            print("✅ All products downloaded, starting main ZIP download...")
            downloadMainZip()
            return
        }
        
        let product = products[index]
        print("📥 Downloading product \(index + 1)/\(products.count): \(product.name)")
        
        // Simulate product download (replace with actual API call)
        // For now, we'll use the main ZIP download but show individual progress
        simulateProductDownload(productIndex: index) { [weak self] in
            // Mark product as complete
            DispatchQueue.main.async {
                self?.products[index].percent = 100
                self?.products[index].isChecked = true
                self?.calculateOverallProgress()
                
                // Download next product
                self?.downloadProductAtIndex(index + 1)
            }
        }
    }
    
    private func simulateProductDownload(productIndex: Int, completion: @escaping () -> Void) {
        // Simulate download progress for individual product
        var progress = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            progress += Int.random(in: 2...5)
            
            if progress >= 100 {
                progress = 100
                timer.invalidate()
                completion()
            }
            
            DispatchQueue.main.async {
                self?.products[productIndex].percent = progress
                self?.calculateOverallProgress()
            }
        }
    }
    
    private func updateProductProgress(progress: Int) {
        // Only update products that are not yet complete
        for index in products.indices {
            if !products[index].isChecked {
                products[index].percent = progress
                products[index].isChecked = progress >= 100
            }
        }
    }
    
    private func calculateOverallProgress() {
        if products.isEmpty {
            overallProgress = downloadProgress
        } else {
            let totalPercent = products.reduce(0) { $0 + $1.percent }
            overallProgress = totalPercent / products.count
        }
    }
    
    func cleanup() {
        localWebServer?.stop()
    }
    
    var menProducts: [Product] {
        products.filter { $0.category == .men }
    }
    
    var womenProducts: [Product] {
        products.filter { $0.category == .women }
    }
    
    func selectProduct(_ product: Product) {
        print("📦 Product selected: \(product.name), fileName: \(product.fileName)")
        
        let event = SelectedProductEvent(productName: product.name, fileName: product.fileName)
        selectedProductEvent = event
        
        // Directly show WebView with selected product (skip cache-data)
        shouldShowProductSelection = false
        shouldShowWebView = true
        isCacheDataScreenActive = false // Not showing cache-data, so mark as inactive
        
        // Use Swift Localhost Server (like SwiftLocalhost pattern)
        let distDir = baseDir.appendingPathComponent("dist")
        
        guard ensureLocalServerRunning(distDir: distDir) else {
            print("❌ Local HTTP server not available, staying on product selection")
            shouldShowProductSelection = true
            shouldShowWebView = false
            return
        }
        
        let tokenJson = ["token": UserDataManager.shared.getToken() ?? "test_token_123"]
        let tokenString = (try? JSONSerialization.data(withJSONObject: tokenJson)).flatMap { String(data: $0, encoding: .utf8) }
        self.tokenData = tokenString
        
        guard let server = localWebServer, server.isRunning else {
            print("❌ Local HTTP server not running, cannot load product")
            shouldShowProductSelection = true
            shouldShowWebView = false
            return
        }
        
        let productURL = server.getFabricFormURL(productName: product.name)
        self.webViewURL = productURL
        self.htmlContent = nil
        self.baseURL = nil
        
        print("✅ Loading fabric-form route via localhost: \(productURL.absoluteString)")
        print("📦 Product: \(product.name) (fileName: \(product.fileName))")
        print("🌐 Local HTTP server is running and serving ALL files correctly")
        print("📁 All assets will load from: http://localhost:\(server.port)/")
        
        isContentReady = true
        return
    }
    
    func goBackToProductSelection() {
        print("🔙 Going back to product selection")
        shouldShowWebView = false
        shouldShowProductSelection = true
        selectedProductEvent = nil
        isCacheDataScreenActive = false
    }
    
    func handleCachePercentage(_ percent: Double) {
        DispatchQueue.main.async {
            guard self.isCacheDataScreenActive else { return }
            let clamped = max(0, min(100, percent))
            self.cacheDownloadPercent = clamped
            print("📊 Cache percentage updated: \(clamped)%")
            if clamped >= 100 {
                if !self.hasCacheReachedHundred {
                    print("✅ Cache percentage reached 100%")
                }
                self.hasCacheReachedHundred = true
                self.tryCompletingCacheFlow()
            }
        }
    }
    
    // Handle callback from web content (like Android's onWebLoadingFinished)
    func handleWebLoadingFinished(_ success: Bool) {
        print("📱 Web content finished loading: \(success)")
        print("🔍 Current state - isCacheDataScreenActive: \(isCacheDataScreenActive), shouldShowWebView: \(shouldShowWebView)")
        
        // Only navigate if cache-data screen is actually active
        guard isCacheDataScreenActive else {
            print("⚠️ handleWebLoadingFinished called but cache-data screen is not active - ignoring")
            return
        }
        
        if success {
            hasReceivedSuccessCallback = true
            tryCompletingCacheFlow()
        } else {
            print("⚠️ Web loading finished with failure - staying on cache-data screen")
        }
    }

    private func tryCompletingCacheFlow() {
        guard isCacheDataScreenActive else {
            return
        }
        
        guard hasCacheReachedHundred, hasReceivedSuccessCallback else {
            return
        }
        
        print("🎉 Cache phase complete - showing product selection")
        UserDataManager.shared.setApiDone(true)
        
        DispatchQueue.main.async {
            self.isCacheDataScreenActive = false
            self.shouldShowProductSelection = true
            self.shouldShowWebView = false
            self.selectedProductEvent = nil
        }
    }
    
    private func ensureLocalServerRunning(distDir: URL) -> Bool {
        if localWebServer == nil {
            localWebServer = LocalWebServer(baseDir: distDir, port: 9000)
        }
        
        guard let server = localWebServer else {
            print("❌ Unable to create local HTTP server")
            return false
        }
        
        if !server.isRunning {
            if server.start() != true {
                print("⚠️ Failed to start local HTTP server")
                return false
            }
        }
        return true
    }
}


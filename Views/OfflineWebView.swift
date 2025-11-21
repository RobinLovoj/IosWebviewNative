//
//  OfflineWebView.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import SwiftUI

struct OfflineWebView: View {
    @StateObject private var viewModel = OfflineWebViewModel()
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var shouldGoBack = false
    
    var body: some View {
        ZStack {
            if viewModel.isDownloading {
                // Step 1: ZIP Download Screen (with product-wise percentage)
                DownloadProgressView(
                    progress: viewModel.downloadProgress,
                    products: viewModel.products,
                    overallProgress: viewModel.overallProgress
                )
            } else if viewModel.isExtracting {
                // Step 2: Extraction Dialog with real-time progress
                ExtractionDialogView(
                    progress: viewModel.extractionProgress,
                    fileName: viewModel.extractionFileName,
                    current: viewModel.extractionCurrent,
                    total: viewModel.extractionTotal
                )
            } else if viewModel.shouldShowProductSelection {
                ProductSelectionView(
                    menProducts: viewModel.menProducts,
                    womenProducts: viewModel.womenProducts
                ) { product in
                    viewModel.selectProduct(product)
                }
            } else if viewModel.shouldShowWebView {
                // Step 3: WebView Screen (using file:// or HTML string)
                // This shows cache-data route when apiDone is false (like Android)
                ZStack {
                    WebViewWrapper(
                        url: viewModel.webViewURL,
                        isLoading: $isLoading,
                        tokenData: viewModel.tokenData,
                        htmlContent: viewModel.htmlContent,
                        baseURL: viewModel.baseURL,
                        selectedProductEvent: viewModel.selectedProductEvent,
                        onWebLoadingFinished: { success in
                            viewModel.handleWebLoadingFinished(success)
                        },
                        onCacheProgress: { percent in
                            viewModel.handleCachePercentage(percent)
                        },
                        canGoBack: $canGoBack,
                        shouldGoBack: $shouldGoBack
                    )
                    .edgesIgnoringSafeArea(.all)
                    
                    if viewModel.isCacheDataScreenActive {
                        CacheProgressOverlay(percent: viewModel.cacheDownloadPercent)
                            .transition(.opacity)
                    }
                    
                    // Left side - Back button, rotation button, and status dot (vertical stack)
                    VStack {
                        HStack {
                            VStack(spacing: 12) {
                                // Back button
                                Button(action: {
                                    // If webview has history, go back in webview
                                    if canGoBack {
                                        shouldGoBack = true
                                        // Reset after a moment
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            shouldGoBack = false
                                        }
                                    } else {
                                        // No webview history, go back to product selection
                                        viewModel.goBackToProductSelection()
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(canGoBack ? Color.black.opacity(0.8) : Color.black.opacity(0.5))
                                            .frame(width: 44, height: 44)
                                            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                                        
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .opacity(1.0) // Always visible, even if no webview history (can go back to product selection)
                                
                                // Rotation button below back button
                                RotationToggleButton()
                                
                                // Status dot below rotation button
                                NetworkStatusIndicator(isOnline: networkMonitor.isOnline)
                            }
                            .padding(.leading, 16)
                            .padding(.top, 120) // Position below rotation/share buttons
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .allowsHitTesting(true)
                    
                    // Bottom bar with logo only
                    VStack {
                        Spacer()
                        HStack {
                            Image("logoimage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 50)
                                .padding(.leading, 20)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                }
            } else {
                // Loading Screen
                ProgressView("Initializing...")
            }
        }
        .onAppear {
            networkMonitor.startMonitoring()
            viewModel.startContentDownload()
        }
        .onDisappear {
            networkMonitor.stopMonitoring()
            viewModel.cleanup()
        }
    }
}

struct NetworkStatusIndicator: View {
    let isOnline: Bool
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .fill(isOnline ? Color(red: 0.0, green: 0.6, blue: 0.0) : Color(red: 0.83, green: 0.18, blue: 0.18))
            .frame(width: 18, height: 18)
            .shadow(color: (isOnline ? Color.green : Color.red).opacity(0.5), radius: 6)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
            .opacity(opacity)
        .scaleEffect(scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOnline)
        .onChange(of: isOnline) { newValue in
            // Animate text fade
            withAnimation(.easeInOut(duration: 0.1)) {
                opacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    opacity = 1.0
                }
            }
            
            // Animate scale (pinch animation like Android)
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = newValue ? 0.8 : 1.12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) {
                withAnimation(.easeInOut(duration: 0.33)) {
                    scale = newValue ? 1.12 : 0.8
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.66) {
                withAnimation(.easeInOut(duration: 0.33)) {
                    scale = 1.0
                }
            }
        }
        .onAppear {
            // Start continuous pinch animation
            startContinuousPinchAnimation()
        }
    }
    
    private func startContinuousPinchAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.33)) {
                scale = isOnline ? 0.8 : 1.12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) {
                withAnimation(.easeInOut(duration: 0.33)) {
                    scale = isOnline ? 1.12 : 0.8
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.66) {
                withAnimation(.easeInOut(duration: 0.33)) {
                    scale = 1.0
                }
            }
        }
    }
}

struct CacheProgressOverlay: View {
    let percent: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: percent, total: 100)
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(maxWidth: 220)
                
                Text("Preparing experience…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(Int(percent))% complete. Please wait.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
    }
}

// Extraction Dialog View with real-time progress
struct ExtractionDialogView: View {
    let progress: Int
    let fileName: String
    let current: Int
    let total: Int
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.05, blue: 0.12),
                    Color(red: 0.04, green: 0.03, blue: 0.08),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Dialog Card
            VStack(spacing: 20) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.7, green: 0.2, blue: 0.9),
                                    Color(red: 0.9, green: 0.3, blue: 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: Color.purple.opacity(0.6), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(
                            Animation.linear(duration: 2.0)
                                .repeatForever(autoreverses: false),
                            value: rotationAngle
                        )
                }
                
                // Title
                Text("Extracting Content")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                // Progress percentage
                Text("\(progress)%")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 10)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.7, green: 0.2, blue: 0.9),
                                        Color(red: 0.9, green: 0.3, blue: 0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(progress) / 100, height: 10)
                            .shadow(color: Color.purple.opacity(0.4), radius: 3, x: 0, y: 1)
                            .animation(.linear(duration: 0.2), value: progress)
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 20)
                
                // Current file name or Error - Prominent Display
                if !fileName.isEmpty {
                    VStack(spacing: 10) {
                        // Check if it's an error message
                        if fileName.hasPrefix("Error:") {
                            Text("Extraction Error:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.red.opacity(0.9))
                            
                            // Error message with red styling
                            ScrollView {
                                Text(fileName.replacingOccurrences(of: "Error: ", with: ""))
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.red.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            }
                            .frame(maxHeight: 150)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        } else {
                            Text("Extracting Model:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            // File name with better styling
                            Text(getDisplayFileName(fileName))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 0.7, green: 0.2, blue: 0.9).opacity(0.3),
                                                            Color(red: 0.9, green: 0.3, blue: 0.7).opacity(0.3)
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .padding(.horizontal, 20)
                        }
                    }
                }
                
                // File count
                if total > 0 {
                    HStack(spacing: 6) {
                        Text("\(current)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("/")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("\(total) files")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }  
                    .padding(.top, 4)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.06, blue: 0.15).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 32)
        }
        .onAppear {
            rotationAngle = 360
        }
    }
    
    // Helper function to get clean file name for display
    private func getDisplayFileName(_ path: String) -> String {
        // Extract just the file name from path
        let fileName = (path as NSString).lastPathComponent
        
        // Remove extension if it's a common model file
        if fileName.hasSuffix(".glb") || fileName.hasSuffix(".gltf") || fileName.hasSuffix(".obj") {
            return String(fileName.dropLast(4))
        }
        
        // Return file name or path if it's short
        if fileName.count > 30 {
            return String(fileName.prefix(27)) + "..."
        }
        
        return fileName.isEmpty ? path : fileName
    }
}

#Preview {
    OfflineWebView()
}


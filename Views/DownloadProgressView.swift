//
//  DownloadProgressView.swift
//  offlineweb
//

//  Created by Robin Lovoj on 09/11/25.
//

import SwiftUI
import UIKit

struct DownloadProgressView: View {
    let progress: Int
    let products: [Product]
    let overallProgress: Int
    
    var body: some View {
        ZStack {
            // Dark gray background (like image)
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with rotation button
                HStack {
                    Spacer()
                    RotationToggleButton()
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                }
                
                // Products List - Vertical Scrollable
                if !products.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(products) { product in
                                ProductListItem(product: product)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 100) // Space for bottom progress
                    }
                }
                
                Spacer()
                
                // Bottom Progress Bar - Fixed at bottom
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // "Downloading Resource......" text
                        Text("Downloading Resource......")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track (gray)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 6)
                                
                                // Progress fill (magenta/pink)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.9, green: 0.3, blue: 0.7),
                                                Color(red: 0.7, green: 0.2, blue: 0.9)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(overallProgress) / 100, height: 6)
                                    .animation(.linear(duration: 0.2), value: overallProgress)
                            }
                        }
                        .frame(height: 6)
                        .frame(maxWidth: 120)
                        
                        // Percentage
                        Text("\(overallProgress)%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        Color(red: 0.12, green: 0.12, blue: 0.12)
                            .opacity(0.95)
                    )
                }
            }
        }
    }
}

struct ProductListItem: View {
    let product: Product
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon/Image on the left
            ZStack {
                if let image = UIImage(named: product.imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                } else {
                    // Placeholder icon
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))
                        .frame(width: 50, height: 50)
                }
            }
            .frame(width: 50, height: 50)
            
            // Product name
            Text(product.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track (gray when 0%, magenta when active)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(product.percent > 0 ? Color(red: 0.9, green: 0.3, blue: 0.7).opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress fill (magenta/pink)
                    if product.percent > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.9, green: 0.3, blue: 0.7),
                                        Color(red: 0.7, green: 0.2, blue: 0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(product.percent) / 100, height: 6)
                            .animation(.linear(duration: 0.2), value: product.percent)
                    }
                }
            }
            .frame(height: 6)
            .frame(maxWidth: 100)
            
            // Percentage on the right
            Text("\(product.percent)%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 45, alignment: .trailing)
            
            // Green "ONLINE" button with checkmark when complete
            if product.isChecked {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("ONLINE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(red: 0.0, green: 0.6, blue: 0.3))
                )
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        scale = 1.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            scale = 1.0
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    let shirt: Product = {
        var p = Product(name: "Shirt", imageName: "men_shirt", category: .men)
        p.percent = 24
        p.isChecked = false
        return p
    }()
    
    let suits: Product = {
        var p = Product(name: "Suits", imageName: "suit", category: .men)
        p.percent = 0
        p.isChecked = false
        return p
    }()
    
    let abayas: Product = {
        var p = Product(name: "Abayas", imageName: "men_abayas", category: .men)
        p.percent = 0
        p.isChecked = false
        return p
    }()
    
    let kurti: Product = {
        var p = Product(name: "Kurti", imageName: "kurta", category: .women)
        p.percent = 0
        p.isChecked = false
        return p
    }()
    
    return DownloadProgressView(
        progress: 24,
        products: [shirt, suits, abayas, kurti],
        overallProgress: 3
    )
}

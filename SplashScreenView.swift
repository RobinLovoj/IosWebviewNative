//
//  SplashScreenView.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            if isActive {
                LoginView()
            } else {
                // Dark purple gradient background matching login screen
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.12, green: 0.08, blue: 0.2),
                        Color(red: 0.15, green: 0.1, blue: 0.25),
                        Color(red: 0.1, green: 0.06, blue: 0.18)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // App Logo/Icon with animation
                    if let image = UIImage(named: "SplashImage") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .scaleEffect(scale)
                            .opacity(opacity)
                    } else {
                        // Fallback if image doesn't exist
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 100))
                            .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.7))
                            .scaleEffect(scale)
                            .opacity(opacity)
                    }
                    
                    // App Name
                    Text("OfflineWeb")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(opacity)
                    
                    // Tagline
                    Text("Experience 3D content without boundaries")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            // Animate logo appearance
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Navigate to login after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}

//
//  SnackbarView.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import SwiftUI

struct SnackbarView: View {
    let message: String
    let icon: String
    let backgroundColor: Color
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            if isShowing {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(backgroundColor)
                .cornerRadius(12)
                .shadow(color: backgroundColor.opacity(0.4), radius: 15, x: 0, y: 8)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SnackbarView(
            message: "Successfully logged in!",
            icon: "checkmark.circle.fill",
            backgroundColor: .green,
            isShowing: .constant(true)
        )
    }
}





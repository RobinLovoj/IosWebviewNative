//
//  OrientationManager.swift
//  offlineweb
//
//  Created by AI.
//

import UIKit
import SwiftUI

enum OrientationManager {
    private static var isLandscape = false
    
    static func toggleOrientation() {
        let targetMask: UIInterfaceOrientationMask = isLandscape ? .portrait : .landscapeRight
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }
        
        do {
            try scene.requestGeometryUpdate(.iOS(interfaceOrientations: targetMask))
            isLandscape.toggle()
        } catch {
            print("⚠️ Failed to update orientation: \(error.localizedDescription)")
        }
    }
    
    static func currentIsLandscape() -> Bool {
        return isLandscape
    }
}

struct RotationToggleButton: View {
    @State private var isLandscape = OrientationManager.currentIsLandscape()
    
    var body: some View {
        Button(action: {
            OrientationManager.toggleOrientation()
            isLandscape.toggle()
        }) {
            Image(systemName: isLandscape ? "rectangle.portrait" : "rectangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(12)
                .background(Color(red: 1.0, green: 0.0, blue: 0.76))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
}


import SwiftUI
import UIKit

struct ProductSelectionView: View {
    let menProducts: [Product]
    let womenProducts: [Product]
    var onBack: (() -> Void)? = nil
    var onProductSelected: (Product) -> Void
    
    @State private var activeTab: ProductCategory = .men
    
    private var currentProducts: [Product] {
        activeTab == .men ? menProducts : womenProducts
    }
    
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 16) {
                topBar
                tabSwitcher
                productGrid
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            floatingCartButton
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: {
                onBack?()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.black)
                    .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            
            Image("logoimage")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 50)
                .padding(.leading, 4)
            
            Spacer()
            
            RotationToggleButton()
        }
    }
    
    private var tabSwitcher: some View {
        HStack(spacing: 12) {
            tabButton(title: "Men", icon: "person.crop.circle", tab: .men, isActive: activeTab == .men)
            tabButton(title: "Women", icon: "person.2.crop.square.stack", tab: .women, isActive: activeTab == .women)
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func tabButton(title: String, icon: String, tab: ProductCategory, isActive: Bool) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                activeTab = tab
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isActive ? .white : Color.black.opacity(0.75))
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? Color(red: 1.0, green: 0.0, blue: 0.76) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.08), lineWidth: isActive ? 0 : 1)
                    )
                    .shadow(color: isActive ? Color(red: 1.0, green: 0.0, blue: 0.76).opacity(0.45) : Color.clear, radius: 8, x: 0, y: 6)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var productGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(currentProducts) { product in
                    ProductSelectionCard(product: product) {
                        onProductSelected(product)
                    }
                }
            }
            .padding(.bottom, 120)
        }
    }
    
    private var floatingCartButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Circle()
                    .fill(Color(red: 1.0, green: 0.0, blue: 0.76))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "cart")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.0, blue: 0.76).opacity(0.35), radius: 8, x: 0, y: 6)
                    .padding(.trailing, 18)
                    .padding(.bottom, 24)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ProductSelectionCard: View {
    let product: Product
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .frame(width: 72, height: 72)
                    
                    if let image = UIImage(named: product.imageName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 46, height: 46)
                            .foregroundColor(Color.black.opacity(0.65))
                    } else {
                        Image(systemName: "tshirt")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.3))
                    }
                }
                
                Text(product.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color(red: 0.13, green: 0.75, blue: 0.26), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.white)
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let men = DefaultProductLists.men.map { name in
        Product(name: name, imageName: getProductImageName(name), category: .men)
    }
    let women = DefaultProductLists.women.map { name in
        Product(name: name, imageName: getProductImageName(name), category: .women)
    }
    return ProductSelectionView(menProducts: men, womenProducts: women) { _ in }
}

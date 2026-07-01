import SwiftUI

struct MyShelfView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    
    @State private var selectedCategory: ProductCategory? = nil
    @State private var showScanner = false
    @State private var selectedProduct: Product? = nil
    @State private var showAuthSheet = false
    
    var filteredProducts: [Product] {
        if let category = selectedCategory {
            return store.userProducts.filter { $0.category == category }
        }
        return store.userProducts
    }
    
    var body: some View {
        ZStack {
            Color.hcCream.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Category Segment Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryFilterTag(title: "All Items", isSelected: selectedCategory == nil) {
                            withAnimation(.spring(duration: 0.25)) {
                                selectedCategory = nil
                            }
                        }
                        
                        ForEach(ProductCategory.allCases) { cat in
                            CategoryFilterTag(title: cat.displayName, isSelected: selectedCategory == cat) {
                                withAnimation(.spring(duration: 0.25)) {
                                    selectedCategory = cat
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color.white)
                .shadow(color: .black.opacity(0.02), radius: 4, y: 3)
                
                // Guest Banner Alert
                if authVM.isGuestMode {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud.rainbow.half")
                            .font(.system(size: 24))
                            .foregroundColor(.hcBrown)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Guest Mode Active")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                            Text("Products are stored locally. Sign up to sync them to your cloud account.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Sign Up") {
                            showAuthSheet = true
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.hcBrown)
                        .cornerRadius(8)
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.hcBrown.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                // Content Area
                if filteredProducts.isEmpty {
                    emptyShelfPlaceholder
                } else {
                    List {
                        ForEach(filteredProducts) { product in
                            Button {
                                selectedProduct = product
                            } label: {
                                ProductCabinetRow(product: product)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        }
                        .onDelete(perform: deleteProducts)
                    }
                    .listStyle(.plain)
                    .padding(.top, 8)
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.hcBrown, Color.hcBrownLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.hcBrown.opacity(0.35), radius: 10, x: 0, y: 6)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Bathroom Shelf")
        .navigationBarTitleDisplayMode(.inline)

        .fullScreenCover(isPresented: $showScanner) {
            ScannerView()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product) {
                // Done / Update notes
                selectedProduct = nil
            } onDiscard: {
                // Delete product
                store.removeProduct(product)
                selectedProduct = nil
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showAuthSheet) {
            NavigationStack {
                AuthLandingView(hideGuestButton: true, onProceed: {
                    showAuthSheet = false
                })
            }
        }
    }
    
    private var emptyShelfPlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.hcBrown.opacity(0.04))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.hcBrown.opacity(0.4))
            }
            
            VStack(spacing: 8) {
                Text("Your Shelf is Empty")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Scan and analyze product ingredients to check if they match your scalp's profile before saving them.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
            

            
            Spacer()
            Spacer()
        }
    }
    
    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let product = filteredProducts[index]
            store.removeProduct(product)
        }
    }
}

// MARK: - Category Filter Tag View
struct CategoryFilterTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .hcWarmBrown)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.hcBrown : Color.hcWarmBrown.opacity(0.06))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Product Cabinet Row View
struct ProductCabinetRow: View {
    let product: Product
    
    var compatibilityColor: Color {
        switch product.compatibility {
        case .safe: return .green
        case .caution: return .orange
        case .hazard: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Category Icon background
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hcCream)
                    .frame(width: 52, height: 52)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 22))
                    .foregroundColor(.hcBrown)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.brand.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                Text(product.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(compatibilityColor)
                        .frame(width: 7, height: 7)
                    
                    Text(product.compatibility.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 3)
    }
    
    private var categoryIcon: String {
        switch product.category {
        case .shampoo: return "shower.fill"
        case .conditioner: return "sparkles"
        case .treatment: return "bandage.fill"
        case .styling: return "comb.fill"
        }
    }
}

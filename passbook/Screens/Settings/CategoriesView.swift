import SwiftUI

// MARK: - Data Model

struct AppCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String
    var description: String
    var merchants: [String]

    // Color stored as RGB components for Codable
    var colorR: Double
    var colorG: Double
    var colorB: Double

    var color: Color { Color(red: colorR, green: colorG, blue: colorB) }

    init(id: UUID = UUID(), name: String, emoji: String, color: Color, description: String, merchants: [String]) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.description = description
        self.merchants = merchants
        // Resolve Color to RGB
        let resolved = UIColor(color)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: nil)
        self.colorR = Double(r)
        self.colorG = Double(g)
        self.colorB = Double(b)
    }
}

// MARK: - Category Persistence

enum CategoryStore {
    private static let key = "passbook_custom_categories"

    static func load() -> [AppCategory] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([AppCategory].self, from: data) else {
            return AppCategory.defaults
        }
        return saved
    }

    static func save(_ categories: [AppCategory]) {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Returns the combined list that pickers should use (persisted categories)
    static var all: [AppCategory] { load() }
}

// MARK: - Prepopulated Categories

extension AppCategory {
    static let defaults: [AppCategory] = [
        AppCategory(
            name: "Food & Dining",
            emoji: "🍔",
            color: Color(red: 1.0, green: 0.45, blue: 0.20),
            description: "Swiggy, Zomato, restaurants & cafes",
            merchants: ["Swiggy", "Zomato", "BigBasket", "Blinkit", "Zepto",
                        "Starbucks", "McDonald's", "Domino's", "KFC", "Subway",
                        "Dunkin", "Burger King", "Pizza Hut"]
        ),
        AppCategory(
            name: "Auto & Transport",
            emoji: "🚗",
            color: Color(red: 0.30, green: 0.70, blue: 1.0),
            description: "Uber, Ola, metro, fuel & tolls",
            merchants: ["Uber", "Ola", "Rapido", "Metro", "BMTC", "IRCTC",
                        "FASTag", "Indian Oil", "HP Petrol", "BPCL", "RedBus"]
        ),
        AppCategory(
            name: "Shopping",
            emoji: "🛍️",
            color: Color(red: 0.80, green: 0.30, blue: 1.0),
            description: "Amazon, Flipkart, Myntra & more",
            merchants: ["Amazon", "Flipkart", "Myntra", "Nykaa", "Ajio",
                        "Meesho", "Reliance Digital", "Croma", "Decathlon", "Lenskart"]
        ),
        AppCategory(
            name: "Subscriptions",
            emoji: "📱",
            color: Color(red: 0.455, green: 0.741, blue: 0.910),
            description: "Netflix, Spotify, JioFiber & apps",
            merchants: ["Netflix", "Spotify", "Hotstar", "Disney+", "Jio",
                        "Airtel", "YouTube Premium", "Apple Music", "Prime Video",
                        "Microsoft 365", "Google One", "iCloud"]
        ),
        AppCategory(
            name: "Health & Wellness",
            emoji: "💊",
            color: Color(red: 0.20, green: 0.85, blue: 0.55),
            description: "Pharmacies, clinics & fitness",
            merchants: ["Apollo Pharmacy", "1mg", "Netmeds", "Practo",
                        "Cult.fit", "PharmEasy", "MedPlus", "Healthians"]
        ),
        AppCategory(
            name: "Entertainment",
            emoji: "🎬",
            color: Color(red: 1.0, green: 0.22, blue: 0.45),
            description: "Movies, events & gaming",
            merchants: ["BookMyShow", "PVR Cinemas", "INOX", "Steam",
                        "PlayStation", "Xbox", "Paytm Insider"]
        ),
        AppCategory(
            name: "Housing",
            emoji: "🏠",
            color: Color(red: 1.0, green: 0.75, blue: 0.10),
            description: "Rent, electricity, broadband & gas",
            merchants: ["BESCOM", "Tata Power", "BWSSB", "ACT Fibernet",
                        "Jio Fiber", "Airtel Xstream", "Piped Gas", "LPG Cylinder"]
        ),
        AppCategory(
            name: "Education",
            emoji: "📚",
            color: Color(red: 0.40, green: 0.60, blue: 1.0),
            description: "Courses, schools & coaching",
            merchants: ["Coursera", "Udemy", "Unacademy", "BYJU'S",
                        "Vedantu", "Duolingo", "LinkedIn Learning", "Skillshare"]
        ),
        AppCategory(
            name: "Investments",
            emoji: "📈",
            color: Color(red: 0.20, green: 0.85, blue: 0.45),
            description: "Zerodha, Groww, SIPs & NPS",
            merchants: ["Zerodha", "Groww", "Upstox", "Angel One",
                        "Coin by Zerodha", "PPFAS MF", "LIC", "NPS"]
        ),
        AppCategory(
            name: "Travel & Vacation",
            emoji: "✈️",
            color: Color(red: 0.20, green: 0.75, blue: 0.95),
            description: "Flights, hotels & holidays",
            merchants: ["IndiGo", "Air India", "SpiceJet", "Vistara",
                        "OYO", "MakeMyTrip", "Goibibo", "EaseMyTrip", "Airbnb"]
        ),
        AppCategory(
            name: "Transfers",
            emoji: "💸",
            color: Color(red: 0.70, green: 0.70, blue: 0.75),
            description: "NEFT, IMPS, UPI & credit card payments",
            merchants: ["NEFT", "RTGS", "IMPS", "UPI", "Credit Card Payment",
                        "PhonePe", "Google Pay", "Paytm"]
        ),
    ]
}

// MARK: - Categories View

struct CategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var categories: [AppCategory] = CategoryStore.load()
    @State private var editingCategory: AppCategory? = nil
    @State private var searchText = ""
    @State private var filteredCategories: [AppCategory] = CategoryStore.load()

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────
            CategoriesHeader(onDismiss: { dismiss() })

            // ── Search bar ───────────────────────────────────────────
            CategoriesSearchBar(searchText: $searchText)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // ── Section label + New Group ─────────────────────────────
            HStack {
                Text("EXPENSE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(0.4))
                    .tracking(0.4)

                Spacer()

                Button("New Group", systemImage: "plus") {
                    let newCat = AppCategory(
                        name: "New Category",
                        emoji: "📦",
                        color: AppColors.homeBlue,
                        description: "Custom category",
                        merchants: []
                    )
                    categories.append(newCat)
                    CategoryStore.save(categories)
                    refilter()
                    editingCategory = newCat
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .labelStyle(.titleOnly)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .overlay {
                    Capsule().stroke(AppColors.charcoal.opacity(0.25), lineWidth: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // ── Category list ────────────────────────────────────────
            CategoriesListCard(
                categories: filteredCategories,
                onSelect: { cat in
                    editingCategory = cat
                }
            )
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: searchText) { _, _ in refilter() }
        .sheet(item: $editingCategory) { category in
            EditCategorySheet(
                category: category,
                onSave: { updated in
                    if let idx = categories.firstIndex(where: { $0.id == updated.id }) {
                        categories[idx] = updated
                    }
                    CategoryStore.save(categories)
                    refilter()
                },
                onDelete: { id in
                    categories.removeAll { $0.id == id }
                    CategoryStore.save(categories)
                    refilter()
                }
            )
            .presentationDetents([.large])
        }
    }

    private func refilter() {
        if searchText.isEmpty {
            filteredCategories = categories
        } else {
            let query = searchText.lowercased()
            filteredCategories = categories.filter {
                $0.name.lowercased().contains(query)
            }
        }
    }
}

// MARK: - Categories Header

private struct CategoriesHeader: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text("MANAGE CATEGORIES")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .tracking(0.6)

            Spacer()

            Button("Close", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.charcoal.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }
}

// MARK: - Categories Search Bar

private struct CategoriesSearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.charcoal.opacity(0.3))

            TextField("Search", text: $searchText)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.charcoal.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
                .stroke(AppColors.charcoal.opacity(0.04), lineWidth: 0.5)
        )
    }
}

// MARK: - Categories List Card

private struct CategoriesListCard: View {
    let categories: [AppCategory]
    let onSelect: (AppCategory) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section title inside card
                HStack {
                    Text("Expense")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.charcoal.opacity(0.55))
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 8)

                LazyVStack(spacing: 0) {
                    ForEach(categories) { cat in
                        ManageCategoryRow(
                            category: cat,
                            onTap: { onSelect(cat) }
                        )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
                    .stroke(AppColors.charcoal.opacity(0.04), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Category Row

private struct ManageCategoryRow: View {
    let category: AppCategory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(category.color)
                        .frame(width: 40, height: 40)
                    Text(category.emoji)
                        .font(.system(size: 18))
                }

                Text(category.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.charcoal)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Category Sheet

struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var category: AppCategory
    @State private var newMerchant: String = ""
    @FocusState private var merchantFieldFocused: Bool

    let onSave: (AppCategory) -> Void
    let onDelete: (UUID) -> Void

    init(category: AppCategory, onSave: @escaping (AppCategory) -> Void, onDelete: @escaping (UUID) -> Void) {
        _category = State(initialValue: category)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────────
            EditCategoryHeader(
                onDismiss: { dismiss() },
                onSave: save
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Name card ─────────────────────────────────────────
                    EditSectionLabel("CATEGORY NAME")

                    EditCategoryNameCard(
                        name: $category.name,
                        emoji: category.emoji,
                        color: category.color
                    )

                    // ── Merchants card ────────────────────────────────────
                    EditSectionLabel("MERCHANTS")

                    VStack(spacing: 0) {
                        // Add row — isolated from merchant list
                        EditMerchantInputRow(
                            newMerchant: $newMerchant,
                            isFocused: $merchantFieldFocused,
                            onAdd: addMerchant
                        )

                        if !category.merchants.isEmpty {
                            Divider().padding(.horizontal, 16)

                            EditMerchantListSection(
                                merchants: category.merchants,
                                onRemove: { merchant in
                                    category.merchants.removeAll { $0 == merchant }
                                }
                            )
                        }
                    }
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.charcoal.opacity(0.04), lineWidth: 0.5)
                    }

                    // ── Delete ────────────────────────────────────────────
                    Button {
                        onDelete(category.id)
                        dismiss()
                    } label: {
                        Text("Delete Category")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.settingsBg.ignoresSafeArea())
    }

    private func addMerchant() {
        let trimmed = newMerchant.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !category.merchants.contains(trimmed) else { return }
        category.merchants.append(trimmed)
        newMerchant = ""
    }

    private func save() {
        // Auto-add any pending merchant text before saving
        let trimmed = newMerchant.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, !category.merchants.contains(trimmed) {
            category.merchants.append(trimmed)
        }
        // Persist synchronously before dismissing the sheet
        onSave(category)
        dismiss()
    }
}

// MARK: - Edit Category Header

private struct EditCategoryHeader: View {
    let onDismiss: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Text("EDIT CATEGORY")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .tracking(0.6)

            HStack {
                Button("Cancel", action: onDismiss)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(AppColors.charcoal.opacity(0.5))
                Spacer()
                Button("Save", action: onSave)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.charcoal)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(AppColors.settingsBg)
    }
}

// MARK: - Section label helper

private struct EditSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.charcoal.opacity(0.4))
            .tracking(0.4)
    }
}

// MARK: - Edit category name card (isolated so keystrokes only invalidate this view)

private struct EditCategoryNameCard: View {
    @Binding var name: String
    let emoji: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 44, height: 44)
                Text(emoji)
                    .font(.system(size: 20))
            }

            TextField("Category name", text: $name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.white)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.charcoal.opacity(0.12).opacity(0.35), lineWidth: 0.5)
        )
    }
}

// MARK: - Edit merchant input row (isolated from list to prevent keystroke lag)

private struct EditMerchantInputRow: View {
    @Binding var newMerchant: String
    var isFocused: FocusState<Bool>.Binding
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.charcoal.opacity(0.4))
                .frame(width: 20)

            TextField("Add merchant...", text: $newMerchant)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppColors.charcoal)
                .focused(isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .onSubmit(onAdd)

            if !newMerchant.isEmpty {
                Button("Add", systemImage: "return", action: onAdd)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.charcoal.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Edit merchant list section (isolated from input to prevent re-render on keystroke)

private struct EditMerchantListSection: View {
    let merchants: [String]
    let onRemove: (String) -> Void

    var body: some View {
        ForEach(merchants, id: \.self) { merchant in
            HStack {
                Text(merchant)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(AppColors.charcoal)
                Spacer()
                Button("Remove \(merchant)", systemImage: "xmark.circle.fill") {
                    onRemove(merchant)
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.charcoal.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            if merchant != merchants.last {
                Divider().padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Merchant Input (kept for CategoryPickerSheet reuse)

private struct EditCategoryMerchantInput: View {
    @Binding var newMerchant: String
    var isFocused: FocusState<Bool>.Binding
    let accentColor: Color
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Add merchant name...", text: $newMerchant)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.charcoal)
                .focused(isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(onAdd)

            if !newMerchant.isEmpty {
                Button("Add", systemImage: "plus.circle.fill", action: onAdd)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 22))
                    .foregroundStyle(accentColor)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(.rect(cornerRadius: 12))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: newMerchant.isEmpty)
    }
}

// MARK: - Merchant List

private struct EditCategoryMerchantList: View {
    let merchants: [String]
    let onRemove: (String) -> Void

    var body: some View {
        LazyVStack(spacing: 1) {
            ForEach(merchants, id: \.self) { merchant in
                HStack {
                    Text(merchant)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Remove \(merchant)", systemImage: "xmark.circle.fill") {
                        onRemove(merchant)
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
            }
        }
        .clipShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
}

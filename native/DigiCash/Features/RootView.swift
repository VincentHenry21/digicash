import SwiftUI

enum DCTab: String, CaseIterable {
    case home, transactions, budgets, insights

    var title: String {
        switch self {
        case .home: "Home"
        case .transactions: "Activity"
        case .budgets: "Budgets"
        case .insights: "Insights"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .transactions: "list.bullet"
        case .budgets: "chart.pie.fill"
        case .insights: "chart.bar.fill"
        }
    }
}

/// Floating glass bubble tab bar. The active tab expands into a sliding
/// purple bubble containing its label, like the reference motion.
struct BubbleTabBar: View {
    @Binding var selection: DCTab
    var onAdd: () -> Void
    @Namespace private var bubble
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            tabButton(.home)
            tabButton(.transactions)
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [DCColor.brand, DCColor.brandDeep],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: DCColor.brand.opacity(0.5), radius: 12)
            }
            .padding(.horizontal, 6)
            .accessibilityLabel("Add transaction")
            tabButton(.budgets)
            tabButton(.insights)
        }
        .padding(8)
        .dcGlass(cornerRadius: 28)
        .shadow(color: .black.opacity(0.35), radius: 24)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func tabButton(_ tab: DCTab) -> some View {
        let active = selection == tab
        Button {
            if reduceMotion {
                selection = tab
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    selection = tab
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                if active {
                    Text(tab.title)
                        .font(.subheadline).fontWeight(.semibold)
                }
            }
            .foregroundStyle(active ? .white : .secondary)
            .padding(.horizontal, active ? 16 : 12)
            .frame(minHeight: 48)
            .background {
                if active {
                    Capsule()
                        .fill(
                            LinearGradient(colors: [DCColor.brand, DCColor.brandDeep],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .matchedGeometryEffect(id: "bubble", in: bubble)
                        .shadow(color: DCColor.brand.opacity(0.45), radius: 10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

struct RootView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var tab: DCTab = .home
    @State private var showAdd = false
    @State private var showLock = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home: HomeView(tab: $tab)
                case .transactions: TransactionsView()
                case .budgets: BudgetsView()
                case .insights: InsightsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 96)

            BubbleTabBar(selection: $tab) { showAdd = true }
        }
        .sheet(isPresented: $showAdd) {
            DCSheet { TransactionFormView() }
        }
        .fullScreenCover(isPresented: $showLock) {
            LockView(unlocked: { showLock = false })
        }
        .onAppear {
            if Keychain.getPINHash() != nil && prefs.lockOnLaunch {
                showLock = true
            }
            DCNotifications.checkBudgetAlerts(store: store)
        }
        .preferredColorScheme(prefs.theme == "dark" ? .dark : prefs.theme == "light" ? .light : nil)
    }
}

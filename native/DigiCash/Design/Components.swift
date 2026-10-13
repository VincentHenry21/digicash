import SwiftUI

// MARK: - Buttons

struct DCPrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [DCColor.brand, DCColor.brandDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
        }
        .buttonStyle(.plain)
    }
}

struct DCWhitePillButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(.white)
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.25), radius: 24)
        }
        .buttonStyle(.plain)
    }
}

struct DCGhostButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fields

struct DCField: View {
    var label: String
    var error: String? = nil
    var hint: String? = nil
    var content: AnyView

    init(label: String, error: String? = nil, hint: String? = nil,
         @ViewBuilder content: () -> some View) {
        self.label = label
        self.error = error
        self.hint = hint
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
            content
                .padding(13)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: DCRadius.small)
                        .stroke(error != nil ? DCColor.expense : Color.primary.opacity(0.1), lineWidth: 1)
                )
            if let error {
                Text(error).font(.caption).foregroundStyle(DCColor.expense)
            } else if let hint {
                Text(hint).font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

struct DCSegmented<Item: Hashable>: View {
    var items: [(Item, String)]
    @Binding var selection: Item
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = item.0 }
                } label: {
                    Text(item.1)
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == item.0 ? DCColor.brand : Color.clear)
                        .foregroundStyle(selection == item.0 ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
    }
}

// MARK: - Progress

struct DCProgressBar: View {
    var percent: Int
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(colors: percent >= 100
                                       ? [DCColor.expense, DCColor.expense]
                                       : [DCColor.brand, DCColor.brandSoft],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * CGFloat(min(100, percent)) / 100)
                    .dcAnimation(.easeInOut(duration: 0.4), value: percent)
            }
        }
        .frame(height: 10)
        .accessibilityValue("\(percent) percent")
    }
}

// MARK: - Rows

struct DCCategoryIcon: View {
    var icon: String
    var color: String
    var size: CGFloat = 44
    var body: some View {
        let c = DCColor.category(color)
        Image(systemName: icon)
            .font(.system(size: size * 0.45))
            .foregroundStyle(c)
            .frame(width: size, height: size)
            .background(c.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.32))
    }
}

struct DCTransactionRow: View {
    var tx: TransactionRecord
    var category: Category?
    var accountName: String
    var prefs: Prefs
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if tx.type == .transfer {
                    DCCategoryIcon(icon: "arrow.left.arrow.right", color: "purple")
                } else {
                    DCCategoryIcon(icon: category?.icon ?? "ellipsis", color: category?.color ?? "gray")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text("\(tx.date.formatted(date: .abbreviated, time: .omitted)) · \(accountName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text(amountText)
                    .font(DCFonts.money())
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayTitle), \(amountText)")
    }

    private var displayTitle: String {
        if !tx.title.isEmpty { return tx.title }
        if tx.type == .transfer { return "Transfer" }
        return category?.name ?? "Transaction"
    }

    private var amountText: String {
        let m = tx.money.formatted(useMyanmarDigits: prefs.useMyanmarDigits)
        switch tx.type {
        case .income, .refund: return "+ \(m)"
        case .expense: return "- \(m)"
        case .transfer, .opening, .adjustment: return m
        }
    }

    private var amountColor: Color {
        switch tx.type {
        case .income, .refund: return DCColor.income
        case .expense: return .primary
        default: return .primary
        }
    }
}

// MARK: - Empty state

struct DCEmptyState: View {
    var icon: String
    var title: String
    var body: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            Text(title).font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                DCPrimaryButton(title: actionTitle, action: action)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(36)
    }
}

// MARK: - Sheet close affordance

/// Presents a sheet from an optional value without requiring Identifiable.
/// (SwiftData @Model identity is left to the framework; this is explicit.)
extension View {
    func dcSheet<Value, Content: View>(value: Binding<Value?>,
                                      @ViewBuilder content: @escaping (Value) -> Content) -> some View {
        self.sheet(
            isPresented: Binding(
                get: { value.wrappedValue != nil },
                set: { if !$0 { value.wrappedValue = nil } }
            )
        ) {
            if let v = value.wrappedValue {
                content(v)
            }
        }
    }
}

struct DCSheet<Content: View>: View {
    var content: Content
    @Environment(\.dismiss) var dismiss

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Close")
                    }
                }
        }
    }
}

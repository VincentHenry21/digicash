import SwiftUI
import LocalAuthentication

/// Minimal welcome screen: transparent logo, no boxed banners.
/// Beside-style: aurora glow, centered mark, white pill CTA.
struct OnboardingView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var prefs: Prefs
    @State private var step = 0
    @State private var openingText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Aurora glow
            Ellipse()
                .fill(
                    RadialGradient(colors: [DCColor.brand.opacity(0.55), .clear],
                                   center: .center, startRadius: 20, endRadius: 320)
                )
                .frame(width: 640, height: 420)
                .offset(y: -300)
                .blur(radius: 40)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                switch step {
                case 0: welcomeStep
                case 1: currencyStep
                case 2: balanceStep
                case 3: privacyStep
                default: doneStep
                }
                Spacer()
                stepDots
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(color: DCColor.brand.opacity(0.5), radius: 30)
                .accessibilityLabel("DigiCash logo")
            Text("DIGI:CASH")
                .font(.system(size: 30, weight: .800, design: .rounded))
                .foregroundStyle(.white)
            Text("The best way to manage your money.\nPrivate by default.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            DCWhitePillButton(title: "Get Started") { withAnimation { step = 1 } }
                .padding(.top, 12)
        }
    }

    private var currencyStep: some View {
        VStack(spacing: 16) {
            Text("Your currency")
                .font(DCFonts.title()).foregroundStyle(.white)
            Text("Every new account uses it unless you pick another.")
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Currency.all.prefix(6), id: \.code) { c in
                    Button {
                        prefs.currencyCode = c.code
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.code).font(.headline).foregroundStyle(.white)
                            Text(c.name).font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: DCRadius.small)
                                .fill(prefs.currencyCode == c.code
                                      ? DCColor.brand.opacity(0.35) : .white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DCRadius.small)
                                .stroke(prefs.currencyCode == c.code ? DCColor.brand : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            DCSegmented(items: [(false, "Western (0-9)"), (true, "Myanmar (၀-၉)")],
                        selection: $prefs.useMyanmarDigits)
            navButtons
        }
    }

    private var balanceStep: some View {
        VStack(spacing: 16) {
            Text("Starting balance")
                .font(DCFonts.title()).foregroundStyle(.white)
            Text("Enter the cash you have now, or start from zero. A starting balance is an opening record, never income.")
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            DCField(label: "Amount (\(prefs.currencyCode))", hint: prefs.currencyCode == "MMK" ? "Whole kyat, no decimals." : nil) {
                TextField("0", text: $openingText)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .font(.system(size: 26, weight: .700, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
            navButtons
        }
    }

    private var privacyStep: some View {
        VStack(spacing: 16) {
            Text("Your money stays yours")
                .font(DCFonts.title()).foregroundStyle(.white)
            VStack(spacing: 0) {
                privacyRow("Where is data stored?", "This device only")
                privacyRow("Cloud sync", "Not available")
                privacyRow("Bank connections", "Not available")
                privacyRow("Analytics / ads", "None")
                privacyRow("App lock", "Optional PIN in Settings")
            }
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: DCRadius.card))
            Text("DigiCash works fully offline. Nothing is uploaded, tracked, or shared.")
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            navButtons
        }
    }

    private func privacyRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(v).fontWeight(.semibold).foregroundStyle(.white)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var doneStep: some View {
        VStack(spacing: 18) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(color: DCColor.brand.opacity(0.5), radius: 24)
            Text("You are set")
                .font(DCFonts.title()).foregroundStyle(.white)
            Text("Your \(prefs.currencyCode) wallet is ready.")
                .foregroundStyle(.white.opacity(0.7))
            DCWhitePillButton(title: "Open DigiCash") { finish() }
                .padding(.top, 8)
        }
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<5) { i in
                Capsule()
                    .fill(i == step ? DCColor.brandSoft : .white.opacity(0.2))
                    .frame(width: i == step ? 24 : 8, height: 8)
            }
        }
    }

    private var navButtons: some View {
        HStack(spacing: 10) {
            if step > 0 {
                DCGhostButton(title: "Back") { withAnimation { step -= 1 } }
            }
            DCPrimaryButton(title: step == 2 && openingText.isEmpty ? "Skip" : "Continue") {
                advance()
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Logic

    private func advance() {
        if step == 2, !openingText.isEmpty {
            do {
                _ = try Money.parse(openingText, currency: prefs.currency)
            } catch {
                return // keep user on step; field shows no error text in this minimal UI
            }
        }
        withAnimation { step += 1 }
    }

    private func finish() {
        let store = store
        store.ensureSeeded()
        let ctx = store.context
        let code = prefs.currencyCode
        let acc = Account(name: "Cash", type: .cash, currencyCode: code)
        ctx.insert(acc)
        if !openingText.isEmpty,
           let m = try? Money.parse(openingText, currency: prefs.currency),
           m.minorUnits > 0 {
            ctx.insert(TransactionRecord(type: .opening, amountMinor: m.minorUnits,
                                        currencyCode: code, accountId: acc.id,
                                        title: "Opening balance"))
        }
        store.save()
        prefs.onboardingDone = true
    }
}

/// PIN lock screen. Real SHA-256 verification against the Keychain hash.
struct LockView: View {
    @EnvironmentObject var prefs: Prefs
    var unlocked: () -> Void
    @State private var pin = ""
    @State private var wrong = false
    @State private var biometricFailed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image("Logo")
                    .resizable().scaledToFit()
                    .frame(width: 88, height: 88)
                    .shadow(color: DCColor.brand.opacity(0.5), radius: 24)
                Text("Enter PIN").font(.title2).fontWeight(.bold).foregroundStyle(.white)
                SecureField("PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .700))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DCRadius.small))
                if wrong {
                    Text("Wrong PIN. Try again.").foregroundStyle(DCColor.expense).font(.subheadline)
                }
                if biometricFailed {
                    Text("Biometrics unavailable. Use your PIN.")
                        .foregroundStyle(.secondary).font(.subheadline)
                }
                Button("Use Face ID / Touch ID") { authenticateBiometric() }
                    .foregroundStyle(DCColor.brandSoft)
                    .padding(.top, 4)
                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
        .onChange(of: pin) { _, v in
            wrong = false
            if v.count >= 4 { verify() }
        }
        .onAppear { authenticateBiometric() }
    }

    private func verify() {
        let hash = Keychain.hashPIN(pin)
        if hash == Keychain.getPINHash() {
            unlocked()
        } else {
            wrong = true
            pin = ""
        }
    }

    private func authenticateBiometric() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            biometricFailed = true
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Unlock DigiCash") { ok, _ in
            if ok { DispatchQueue.main.async { unlocked() } }
        }
    }
}

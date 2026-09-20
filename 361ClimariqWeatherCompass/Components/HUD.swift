import Combine
import StoreKit
import SwiftUI
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var confirmReset = false

    func openPrivacy() {
        if let url = URL(string: AppLinks.privacy) {
            UIApplication.shared.open(url)
        }
    }

    func openTerms() {
        if let url = URL(string: AppLinks.terms) {
            UIApplication.shared.open(url)
        }
    }

    func rateApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

struct Bezel: View {
    var body: some View {
        Rectangle()
            .stroke(Color("AppAccent").opacity(0.35), lineWidth: 1)
    }
}

struct ViewfinderCrop: View {
    let image: String
    var height: CGFloat = 96

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .overlay {
                ZStack {
                    Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 1)
                    VStack {
                        HStack {
                            corner
                            Spacer()
                            corner.rotationEffect(.degrees(90))
                        }
                        Spacer()
                        HStack {
                            corner.rotationEffect(.degrees(-90))
                            Spacer()
                            corner.rotationEffect(.degrees(180))
                        }
                    }
                    .padding(6)
                }
            }
    }

    private var corner: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 14))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 14, y: 0))
        }
        .stroke(Color("AppAccent"), lineWidth: 2)
        .frame(width: 14, height: 14)
    }
}

struct RiskMeter: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SURFACE RISK")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color("AppAccent"))
            HStack(spacing: 3) {
                ForEach(0..<14, id: \.self) { index in
                    Rectangle()
                        .fill(Double(index) / 14.0 < progress ? Color("AppAccent") : Color.white.opacity(0.1))
                        .frame(height: 26)
                }
            }
            .shadow(color: Color("AppAccent").opacity(0.35), radius: 6, y: 0)
        }
    }
}

struct SignalCard: View {
    let code: String
    let line: String
    var tint: Color = Color("AppAccent")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(code)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(tint)
            Text(line)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.78))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.4))
        .overlay(Rectangle().stroke(tint.opacity(0.55), lineWidth: 1))
    }
}

struct TerminalRow: View {
    let command: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(">")
                    .foregroundColor(Color("AppAccent"))
                Text(command)
                    .foregroundColor(.white)
                Spacer()
            }
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.45))
            .overlay(Bezel())
        }
        .buttonStyle(.plain)
    }
}

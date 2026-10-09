//
//  DeferredLaunchCanvas.swift
//

import SwiftUI

struct DeferredLaunchCanvas: View {
    @ObservedObject var state: LaunchStagingState

    private var clampedProgress: Double { min(1.0, max(0.05, state.progress)) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.18),
                    Color(red: 0.16, green: 0.11, blue: 0.30),
                    Color(red: 0.30, green: 0.13, blue: 0.32),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 6)
                        .frame(width: 84, height: 84)

                    Circle()
                        .trim(from: 0, to: CGFloat(clampedProgress))
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.74, blue: 0.36),
                                         Color(red: 0.98, green: 0.42, blue: 0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 84, height: 84)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: clampedProgress)

                    Text("\(Int(clampedProgress * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text(state.statusMessage)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 96)
            }
        }
    }
}

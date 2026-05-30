//
//  ContentView.swift
//  OnboardingAnimation
//
//  Created by Yohei Okawa on 2026/05/29.
//

import SwiftUI

struct ContentView: View {

    @State private var phase: OnboardingPhase = .initial
    @State private var isVisible: Bool = false
    @Namespace private var titleNamespace

    var body: some View {
        ZStack {
            meshGradientView
            VStack {
                titleLayer
                buttonLayer
            }
        }
        .onTapGesture {
            Task {
                await runOnboardingAnimation()
            }
        }
    }

    private var meshGradientView: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                .white, .orange.opacity(0.6), .orange.opacity(0.6),
                .white, .white, .white,
                .indigo.opacity(0.6), .indigo.opacity(0.6), .white
            ]
        )
        .ignoresSafeArea()
    }

    private var titleLayer: some View {
        VStack {
            if phase.isTitleVisible {
                titleView
                    .font(.system(size: phase.titleSize, weight: .medium, design: .serif)).italic()
                if phase.isTitleAtTop {
                    Spacer()
                }
            }
        }
    }

    private var buttonLayer: some View {
        VStack {
            VStack {
                if phase.isMessageVisible {
                    Text("Find your rhythm, focus on what matters, and let Flow guide your next step.")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black.opacity(0.4))
                        .padding(.horizontal, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if phase.isButtonVisible {
                    Button {

                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .padding(4)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .buttonSizing(.flexible)
                    .tint(.black)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding()
        .animation(.smooth(duration: 1), value: phase)
    }

    private var titleView: some View {
        Text("Flow")
            .fontDesign(.serif)
            .fontWeight(.medium)
            .padding()
            .transition(TextTransition())
    }

    private func runOnboardingAnimation() async {
        phase = .titleAppeared
        do {
            try await Task.sleep(for: .seconds(1.5))
            withAnimation(.timingCurve(0.7, 0.0, 0.5, 1.0, duration: 1)) {
                phase = .titleMovedToTop
            }
            try await Task.sleep(for: .seconds(0.5))
            phase = .messageVisible
            try await Task.sleep(for: .seconds(0.8))
            phase = .buttonVisible
        } catch {
            return
        }
    }
}

#Preview {
    ContentView()
}

struct TextTransition: Transition {
    static var properties: TransitionProperties {
        TransitionProperties(hasMotion: true)
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        let duration = 0.9
        let elapsedTime = phase.isIdentity ? duration : 0
        let renderer = AppearanceEffectRenderer(
            elapsedTime: elapsedTime,
            totalDuration: duration
        )

        content.transaction { transaction in
            // Force the animation of `elapsedTime` to pace linearly and
            // drive per-glyph springs based on its value.
            if !transaction.disablesAnimations {
                transaction.animation = .linear(duration: duration)
            }
        } body: { view in
            view.textRenderer(renderer)
        }
    }
}

private struct AppearanceEffectRenderer: TextRenderer, Animatable {

    var elapsedTime: TimeInterval

    var elementDuration: TimeInterval

    var totalDuration: TimeInterval

    var animatableData: Double {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }

    init(elapsedTime: TimeInterval, elementDuration: Double = 0.4, totalDuration: TimeInterval) {
        self.elapsedTime = min(elapsedTime, totalDuration)
        self.elementDuration = min(elementDuration, totalDuration)
        self.totalDuration = totalDuration
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for run in layout.flattenedRuns {
            let delay = elementDelay(count: run.count)
            for (index, slice) in run.enumerated() {
                let timeOffset = TimeInterval(index) * delay
                let elementTime = max(0, min(elapsedTime - timeOffset, elementDuration))

                var copy = context
                draw(slice, at: elementTime, in: &copy)
            }
        }
    }

    func draw(_ slice: Text.Layout.RunSlice, at time: TimeInterval, in context: inout GraphicsContext) {
        let progress = time / elementDuration
        let opacity = UnitCurve.easeIn.value(at: 1.4 * progress)
        let scale = Spring.smooth.value(fromValue: 0.0, toValue: 1.0, initialVelocity: 0, time: time)
        let bounds = slice.typographicBounds.rect
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        context.opacity = opacity
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -center.x, y: -center.y)
        // Keep animated glyph scaling smooth by avoiding pixel-grid snapping
        // while the slice is drawn at fractional positions.
        context.draw(slice, options: .disablesSubpixelQuantization)
    }

    func elementDelay(count: Int) -> TimeInterval {
        let count = TimeInterval(count)
        let remainingTime = totalDuration - count * elementDuration
        return max(remainingTime / (count + 1), (totalDuration - elementDuration) / count)
    }

}

extension Text.Layout {
    /// A helper function for easier access to all runs in a layout.
    var flattenedRuns: some RandomAccessCollection<Text.Layout.Run> {
        self.flatMap { line in
            line
        }
    }

    /// A helper function for easier access to all run slices in a layout.
    var flattenedRunSlices: some RandomAccessCollection<Text.Layout.RunSlice> {
        flattenedRuns.flatMap(\.self)
    }
}

private enum OnboardingPhase {
    case initial
    case titleAppeared
    case titleMovedToTop
    case messageVisible
    case buttonVisible

    var isTitleVisible: Bool {
        switch self {
        case .initial:
            return false
        case .titleAppeared, .titleMovedToTop, .messageVisible, .buttonVisible:
            return true
        }
    }

    var isMessageVisible: Bool {
        switch self {
        case .initial, .titleAppeared, .titleMovedToTop:
            return false
        case .messageVisible, .buttonVisible:
            return true
        }
    }

    var isButtonVisible: Bool {
        switch self {
        case .initial, .titleAppeared, .titleMovedToTop, .messageVisible:
            return false
        case .buttonVisible:
            return true
        }
    }

    var titleSize: CGFloat {
        switch self {
        case .initial, .titleAppeared:
            return 100
        case .titleMovedToTop, .messageVisible, .buttonVisible:
            return 20
        }
    }

    var titleScale: CGFloat {
        switch self {
        case .initial, .titleAppeared:
            return 4.0
        case .titleMovedToTop, .messageVisible, .buttonVisible:
            return 1.0
        }
    }

    var isTitleAtTop: Bool {
        switch self {
        case .initial, .titleAppeared:
            return false
        case .titleMovedToTop, .messageVisible, .buttonVisible:
            return true
        }
    }


}

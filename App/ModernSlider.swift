import SwiftUI

struct ModernSlider: View {
    @Binding var value: Double
    var isMuted: Bool = false
    var onEditingChanged: (Bool) -> Void = { _ in }
    
    @State private var isDragging = false
    @State private var isHovering = false
    
    // Constants for layout
    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 16
    private let thumbExpandedSize: CGFloat = 20
    private let hitTargetHeight: CGFloat = 24 // Invisible hit area height
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Invisible hit target area
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: hitTargetHeight)
                    .contentShape(Rectangle())
                
                // Track background
                Capsule()
                    .fill(DesignSystem.Colors.sliderTrack)
                    .frame(height: trackHeight)
                
                // Filled track with gradient
                // Calculate width based on value, constrained to geometry width
                let fillWidth = max(0, min(geometry.size.width, geometry.size.width * CGFloat(value)))
                
                Capsule()
                    .fill(isMuted ? AnyShapeStyle(DesignSystem.Colors.textMuted.opacity(0.3)) : AnyShapeStyle(DesignSystem.Colors.sliderGradient))
                    .frame(width: fillWidth, height: trackHeight)
                    .glow(color: isMuted ? .clear : DesignSystem.Colors.gradientCyan, radius: isDragging ? 12 : 6)
                
                // Thumb
                // Calculate position: 0 aligns left edge, 1 aligns right edge
                // We want center of thumb to align with value position
                // thumbOffset = (totalWidth * value) - (thumbWidth / 2)
                // Constrained so thumb stays fully inside? 
                // Usually sliders let thumb center go from 0 to width.
                // The previous implementation had `min(geometry.size.width - 16, ...)` which caused the overflow/clipping issues.
                // Let's stick to standard behavior: center of thumb follows the value.
                // However, to keep it looking contained, we often inset by half thumb width.
                // Let's use a standard interpolation for center position.
                
                let currentThumbSize = isDragging ? thumbExpandedSize : thumbSize
                let availableWidth = geometry.size.width - currentThumbSize
                let thumbOffset = (availableWidth * CGFloat(value))
                
                Circle()
                    .fill(Color.white)
                    .frame(width: currentThumbSize, height: currentThumbSize)
                    .shadow(color: DesignSystem.Colors.gradientCyan.opacity(isDragging ? 0.5 : 0.3), radius: isDragging ? 8 : 4)
                    .offset(x: thumbOffset)
                    .scaleEffect(isDragging ? 1.0 : 1.0) // Scale handled by frame change to avoid offset calculation mismatch
            }
            // Align in center vertically within the geometry reader
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                            // Optional: Haptic feedback on start
                        }
                        
                        // Calculate value based on touch position relative to the track's interactive width
                        // We want 0 at left edge of track, 1 at right edge of track.
                        // The track is full width of geometry.
                        
                        let newValue = max(0, min(1, Double(gesture.location.x / geometry.size.width)))
                        
                        if value != newValue {
                            value = newValue
                        }
                    }
                    .onEnded { _ in
                        withAnimation(DesignSystem.Animation.spring) {
                            isDragging = false
                        }
                        onEditingChanged(false)
                        // Optional: Haptic feedback on end
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    }
            )
        }

        .frame(height: hitTargetHeight) // Match hit target height
        .disabled(isMuted)
        .opacity(isMuted ? 0.5 : 1)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
        // Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume")
        .accessibilityValue(Text("\(Int(value * 100))%"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                let newValue = min(1.0, value + 0.05)
                value = newValue
                onEditingChanged(true)
                onEditingChanged(false)
            case .decrement:
                let newValue = max(0.0, value - 0.05)
                value = newValue
                onEditingChanged(true)
                onEditingChanged(false)
            @unknown default:
                break
            }
        }
    }
}

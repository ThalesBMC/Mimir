import SwiftUI

struct AppVolumeRow: View {
    let app: AudioApp
    let isHidden: Bool
    let onVolumeChange: (Float) -> Void
    let onMuteToggle: () -> Void
    let onHideToggle: () -> Void
    
    @State private var volume: Double
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var dragOffset: CGFloat = 0
    
    init(app: AudioApp, isHidden: Bool = false, onVolumeChange: @escaping (Float) -> Void, onMuteToggle: @escaping () -> Void, onHideToggle: @escaping () -> Void = {}) {
        self.app = app
        self.isHidden = isHidden
        self.onVolumeChange = onVolumeChange
        self.onMuteToggle = onMuteToggle
        self.onHideToggle = onHideToggle
        self._volume = State(initialValue: Double(app.volume))
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // App Icon with glow
            appIcon
            
            // Main content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // App name row
                HStack {
                    Text(app.name)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Volume percentage with gradient
                    Text("\(Int(volume * 100))")
                        .font(DesignSystem.Typography.mono)
                        .foregroundStyle(app.isMuted ? AnyShapeStyle(DesignSystem.Colors.textMuted) : AnyShapeStyle(DesignSystem.Colors.accentGradient))
                        .frame(width: 28, alignment: .trailing)
                        .scaleEffect(isDragging ? 1.1 : 1)
                        .animation(DesignSystem.Animation.spring, value: isDragging)
                }
                
                // Custom slider
                ModernSlider(
                    value: Binding(
                        get: { volume },
                        set: { newValue in
                             volume = newValue
                             onVolumeChange(Float(newValue))
                        }
                    ),
                    isMuted: app.isMuted
                )
            }
            
            // Control buttons
            controlButtons
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovering ? DesignSystem.Colors.cardBackground : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(app.name)
    }
    
    // MARK: - App Icon
    private var appIcon: some View {
        ZStack {
            // Glow behind icon when not muted
            if !app.isMuted && volume > 0.1 {
                Circle()
                    .fill(DesignSystem.Colors.gradientCyan.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .blur(radius: 8)
            }
            
            // Icon container
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.cardBackground)
                    .frame(width: 40, height: 40)
                
                Group {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "app.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accentGradient)
                    }
                }
            }
            .opacity(app.isMuted ? 0.5 : 1)
        }
        .accessibilityHidden(true) // Decorative, parent has label
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Hide button (only on hover)
            if isHovering {
                Button(action: onHideToggle) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Hide App")
            }
            
            // Mute button
            Button(action: {
                withAnimation(DesignSystem.Animation.spring) {
                    onMuteToggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(app.isMuted ? DesignSystem.Colors.muteAccent.opacity(0.2) : DesignSystem.Colors.cardBackground)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(app.isMuted ? DesignSystem.Colors.muteAccent : (isHovering ? DesignSystem.Colors.gradientCyan : DesignSystem.Colors.textSecondary))
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(app.isMuted ? 1.05 : 1)
            .accessibilityLabel(app.isMuted ? "Unmute" : "Mute")
        }
    }
}

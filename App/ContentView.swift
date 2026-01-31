import SwiftUI
import AVFoundation

struct ContentView: View {
    @ObservedObject var audioManager: AudioProcessManager
    @State private var isRefreshing = false
    @State private var showingHiddenApps = false
    @State private var appearAnimation = false
    @State private var hasPermission = false
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Main Content
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
                
                // Divider
                Rectangle()
                    .fill(DesignSystem.Colors.divider)
                    .frame(height: 1)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                if hasPermission {
                    // App list
                    if audioManager.visibleApps.isEmpty && !showingHiddenApps {
                        emptyStateView
                    } else {
                        appListView
                    }
                    
                    // Hidden apps toggle
                    if !audioManager.hiddenAppsList.isEmpty {
                        hiddenAppsToggle
                    }
                    
                    // Hidden apps list
                    if showingHiddenApps && !audioManager.hiddenAppsList.isEmpty {
                        hiddenAppsList
                    }
                } else {
                    permissionDeniedView
                }
                
                Spacer(minLength: DesignSystem.Spacing.md)
            }
        }
        .frame(width: 360)
        .frame(minHeight: 200, maxHeight: 500)
        .glassPanel()
        .onAppear {
            checkPermission()
            withAnimation(DesignSystem.Animation.spring.delay(0.1)) {
                appearAnimation = true
            }
        }
    }
    
    // MARK: - Permission Check
    private func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        hasPermission = status == .authorized
        
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                }
            }
        }
    }
    
    // MARK: - Permission Denied View
    private var permissionDeniedView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.muteAccent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.muteAccent)
            }
            .scaleEffect(appearAnimation ? 1 : 0.8)
            .opacity(appearAnimation ? 1 : 0)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Permission Required")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Mimir needs audio access to control volume.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DesignSystem.Colors.divider, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            DesignSystem.Colors.background
            
            // Gradient orbs - Blue/Cyan palette
            Circle()
                .fill(DesignSystem.Colors.gradientBlue.opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -80, y: -100)
            
            Circle()
                .fill(DesignSystem.Colors.gradientCyan.opacity(0.12))
                .frame(width: 150, height: 150)
                .blur(radius: 50)
                .offset(x: 100, y: 50)
            
            Circle()
                .fill(DesignSystem.Colors.gradientTeal.opacity(0.1))
                .frame(width: 180, height: 180)
                .blur(radius: 55)
                .offset(x: 50, y: -50)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .scaleEffect(appearAnimation ? 1 : 0.5)
                .opacity(appearAnimation ? 1 : 0)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Mimir")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("\(audioManager.visibleApps.count) apps")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
            .offset(x: appearAnimation ? 0 : -20)
            .opacity(appearAnimation ? 1 : 0)
            
            Spacer()
            
            // Refresh button
            Button(action: refreshApps) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.cardBackground)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(appearAnimation ? 1 : 0.5)
            .opacity(appearAnimation ? 1 : 0)
            
            // Quit button
            Button(action: { NSApplication.shared.terminate(nil) }) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.cardBackground)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(appearAnimation ? 1 : 0.5)
            .opacity(appearAnimation ? 1 : 0)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.cardBackground)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "waveform.slash")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.accentGradient)
            }
            .scaleEffect(appearAnimation ? 1 : 0.8)
            .opacity(appearAnimation ? 1 : 0)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("No Sound")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Play audio to see apps here")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }
    
    // MARK: - App List
    private var appListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(Array(audioManager.visibleApps.enumerated()), id: \.element.id) { index, app in
                    AppVolumeRow(
                        app: app,
                        isHidden: false,
                        onVolumeChange: { volume in
                            audioManager.setVolume(for: app, volume: volume)
                        },
                        onMuteToggle: {
                            audioManager.toggleMute(for: app)
                        },
                        onHideToggle: {
                            withAnimation(DesignSystem.Animation.spring) {
                                audioManager.hideApp(app)
                            }
                        }
                    )
                    .offset(y: appearAnimation ? 0 : 20)
                    .opacity(appearAnimation ? 1 : 0)
                    .animation(DesignSystem.Animation.spring.delay(Double(index) * 0.05), value: appearAnimation)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .frame(maxHeight: 280)
    }
    
    // MARK: - Hidden Apps Toggle
    private var hiddenAppsToggle: some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.spring) {
                showingHiddenApps.toggle()
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 10, weight: .semibold))
                
                Text("\(audioManager.hiddenAppsList.count) hidden")
                    .font(DesignSystem.Typography.caption)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(showingHiddenApps ? 90 : 0))
            }
            .foregroundColor(DesignSystem.Colors.textMuted)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Hidden Apps List
    private var hiddenAppsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(audioManager.hiddenAppsList) { app in
                    HiddenAppRow(app: app) {
                        withAnimation(DesignSystem.Animation.spring) {
                            audioManager.unhideApp(app)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.sm)
        }
        .frame(maxHeight: 150)
        .transition(.asymmetric(
            insertion: .push(from: .top).combined(with: .opacity),
            removal: .push(from: .bottom).combined(with: .opacity)
        ))
    }
    
    // MARK: - Actions
    private func refreshApps() {
        withAnimation(DesignSystem.Animation.spring) {
            isRefreshing = true
        }
        Task {
            await audioManager.updateAudioApps()
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(DesignSystem.Animation.spring) {
                isRefreshing = false
            }
        }
    }
}

// MARK: - Hidden App Row
struct HiddenAppRow: View {
    let app: AudioApp
    let onUnhide: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }
            }
            .frame(width: 20, height: 20)
            .opacity(0.5)
            
            Text(app.name)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onUnhide) {
                Image(systemName: "eye")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isHovering ? DesignSystem.Colors.gradientCyan : DesignSystem.Colors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? DesignSystem.Colors.cardBackground : Color.clear)
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
    }
}

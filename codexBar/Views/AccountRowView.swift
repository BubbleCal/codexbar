import SwiftUI

/// One org/account row under an email group
struct AccountRowView: View {
    let account: TokenAccount
    let rowState: OpenAIAccountRowState
    let isRefreshing: Bool
    let isLaunchingInstance: Bool
    let usageDisplayMode: CodexBarUsageDisplayMode
    let defaultManualActivationBehavior: CodexBarOpenAIManualActivationBehavior?
    let onActivate: (OpenAIManualActivationTrigger) -> Void
    let onLaunchInstance: () -> Void
    let onRefresh: () -> Void
    let onReauth: () -> Void
    let onDelete: () -> Void

    @State private var isHoveringPlanBadge = false

    var body: some View {
        HStack(spacing: 6) {
            if self.usesExpandedTeamBadgeHoverLayout == false {
                self.statusIndicator
            }

            self.planBadge

            if self.usesExpandedTeamBadgeHoverLayout == false {
                usageSummary

                if let runningThreadBadgeTitle = rowState.runningThreadBadgeTitle {
                    Text(runningThreadBadgeTitle)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: MenuDesign.badgeCornerRadius, style: .continuous)
                                .fill(MenuDesign.chipFill)
                        )
                        .foregroundColor(MenuDesign.textSecondary)
                }

                if self.rowState.isNextUseTarget {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 11))
                }
            }

            Spacer(minLength: self.usesExpandedTeamBadgeHoverLayout ? 0 : 6)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .foregroundColor(MenuDesign.textSecondary)

            if account.tokenExpired {
                Button(L.reauth, action: onReauth)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .font(.system(size: 10, weight: .medium))
                    .tint(.orange)
            } else if !account.isBanned {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(
                            isRefreshing
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: isRefreshing
                        )
                }
                .buttonStyle(.borderless)
                .foregroundColor(isRefreshing ? .accentColor : MenuDesign.textSecondary)
                .disabled(isRefreshing)

                if self.canPerformManualActivation {
                    Button(
                        OpenAIAccountPresentation.manualActivationButtonTitle(
                            defaultBehavior: defaultManualActivationBehavior
                        )
                    ) {
                        onActivate(OpenAIAccountPresentation.primaryManualActivationTrigger)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .opacity(account.isBanned ? 0.72 : 1)
        .background(
            RoundedRectangle(cornerRadius: MenuDesign.rowCornerRadius, style: .continuous)
                .fill(self.rowState.isNextUseTarget ? Color.accentColor.opacity(0.13) : MenuDesign.insetRowFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: MenuDesign.rowCornerRadius, style: .continuous)
                .strokeBorder(
                    self.rowState.isNextUseTarget ? Color.accentColor.opacity(0.38) : MenuDesign.cardStroke,
                    lineWidth: 1
                )
        }
        .overlay(alignment: .leading) {
            if self.rowState.isNextUseTarget {
                UnevenRoundedRectangle(
                    topLeadingRadius: MenuDesign.rowCornerRadius,
                    bottomLeadingRadius: MenuDesign.rowCornerRadius,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.accentColor)
                .frame(width: 3)
            }
        }
        .contextMenu {
            if let defaultManualActivationBehavior,
               self.canPerformManualActivation {
                ForEach(
                    OpenAIAccountPresentation.manualActivationContextActions(
                        defaultBehavior: defaultManualActivationBehavior
                    ),
                    id: \.behavior
                ) { action in
                    Button {
                        onActivate(action.trigger)
                    } label: {
                        if action.isDefault {
                            Label(action.title, systemImage: "checkmark")
                        } else {
                            Text(action.title)
                        }
                    }
                }
            }

            if self.canLaunchInstance {
                Button {
                    onLaunchInstance()
                } label: {
                    Label(L.desktopInstanceAction, systemImage: "macwindow.badge.plus")
                }
                .disabled(self.isLaunchingInstance)
            }
        }
    }

    private var canPerformManualActivation: Bool {
        self.account.tokenExpired == false
            && self.account.isBanned == false
            && self.showsManualActivationAction
    }

    private var canLaunchInstance: Bool {
        self.account.tokenExpired == false && self.account.isBanned == false
    }

    private var showsManualActivationAction: Bool {
        self.rowState.showsManualActivationAction(
            defaultBehavior: self.defaultManualActivationBehavior
        )
    }

    @ViewBuilder
    private var usageSummary: some View {
        HStack(spacing: 5) {
            ForEach(Array(account.usageWindowDisplays(mode: self.usageDisplayMode).enumerated()), id: \.offset) { index, window in
                if index > 0 {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(MenuDesign.textTertiary)
                }
                Text(window.label)
                    .font(.system(size: 10))
                    .foregroundColor(MenuDesign.textSecondary)
                Text("\(Int(window.displayPercent))%")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(usageColor(window))
            }
        }
    }

    private var planBadge: some View {
        Text(
            OpenAIAccountPresentation.planBadgeTitle(
                for: self.account,
                isHovered: self.isHoveringPlanBadge
            )
        )
        .font(MenuDesign.badgeFont)
        .lineLimit(1)
        .truncationMode(.tail)
        .allowsTightening(self.usesExpandedTeamBadgeHoverLayout)
        .minimumScaleFactor(self.usesExpandedTeamBadgeHoverLayout ? 0.85 : 1)
        .layoutPriority(self.usesExpandedTeamBadgeHoverLayout ? 1 : 0)
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            RoundedRectangle(cornerRadius: MenuDesign.badgeCornerRadius, style: .continuous)
                .fill(planBadgeColor.opacity(0.17))
        )
        .foregroundColor(planBadgeColor)
        .contentShape(RoundedRectangle(cornerRadius: MenuDesign.badgeCornerRadius))
        .onHover { isHovering in
            self.isHoveringPlanBadge = isHovering
        }
    }

    private var usesExpandedTeamBadgeHoverLayout: Bool {
        OpenAIAccountPresentation.usesExpandedTeamBadgeHoverLayout(
            for: self.account,
            isHovered: self.isHoveringPlanBadge
        )
    }

    /// 左侧状态指示:正常账号显示迷你额度环(环长 = 首个窗口的额度比例),
    /// 异常账号(封禁 / 令牌过期)显示明确的图标,不再用无解释的纯色圆点。
    @ViewBuilder
    private var statusIndicator: some View {
        if account.isBanned {
            Image(systemName: "nosign")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.red)
                .frame(width: 14, height: 14)
        } else if account.tokenExpired {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 14, height: 14)
        } else {
            self.usageRing
        }
    }

    private var usageRing: some View {
        let window = account.usageWindowDisplays(mode: self.usageDisplayMode).first
        let fraction = window.map { min(max($0.displayPercent / 100, 0), 1) } ?? 0
        return ZStack {
            Circle()
                .stroke(MenuDesign.chipStroke, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(fraction, 0.035))
                .stroke(
                    self.ringColor(for: window),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 13, height: 13)
        .padding(.horizontal, 0.5)
    }

    private func ringColor(for window: UsageWindowDisplay?) -> Color {
        if account.quotaExhausted { return .orange }
        guard let window else { return MenuDesign.textTertiary }
        return self.usageColor(window)
    }

    private var planBadgeColor: Color {
        switch account.planType.lowercased() {
        case "team": return .blue
        case "plus": return .purple
        default: return MenuDesign.textSecondary
        }
    }

    private func usageColor(_ window: UsageWindowDisplay) -> Color {
        if window.usedPercent >= 100 { return .red }
        if window.remainingPercent <= OpenAIVisualWarningThreshold.remainingPercent {
            return .orange
        }

        switch self.usageDisplayMode {
        case .remaining:
            return .green
        case .used:
            if window.usedPercent >= 70 { return .orange }
            return .green
        }
    }
}

import SwiftUI

struct CompatibleProviderRowView: View {
    let provider: CodexBarProvider
    let isActiveProvider: Bool
    let activeAccountId: String?
    let onActivate: (CodexBarProviderAccount) -> Void
    let onAddAccount: () -> Void
    let onDeleteAccount: (CodexBarProviderAccount) -> Void
    let onDeleteProvider: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(provider.label)
                    .font(MenuDesign.rowTitleFont)
                    .foregroundColor(isActiveProvider ? .accentColor : MenuDesign.textPrimary)

                Text(provider.hostLabel)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: MenuDesign.badgeCornerRadius, style: .continuous)
                            .fill(MenuDesign.chipFill)
                    )
                    .foregroundColor(MenuDesign.textSecondary)

                if isActiveProvider {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }

                Spacer()

                Button(action: onAddAccount) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundColor(MenuDesign.textSecondary)

                Button(action: onDeleteProvider) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundColor(MenuDesign.textSecondary)
            }

            ForEach(provider.accounts) { account in
                HStack(spacing: 6) {
                    Text(account.label)
                        .font(.system(size: 11, weight: account.id == activeAccountId ? .semibold : .regular))
                        .foregroundColor(MenuDesign.textPrimary)

                    if account.id == activeAccountId {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    Text(account.maskedAPIKey)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(MenuDesign.textTertiary)
                        .lineLimit(1)

                    if account.id != activeAccountId || isActiveProvider == false {
                        Button("Use") {
                            onActivate(account)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .font(.system(size: 10, weight: .medium))
                    }

                    Button {
                        onDeleteAccount(account)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(MenuDesign.textSecondary)
                }
                .padding(.leading, 13)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .menuCard(
            fill: isActiveProvider ? Color.accentColor.opacity(0.10) : MenuDesign.cardFill,
            stroke: isActiveProvider ? Color.accentColor.opacity(0.30) : MenuDesign.cardStroke
        )
    }
}

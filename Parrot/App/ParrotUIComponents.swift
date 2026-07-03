import AppKit
import SwiftUI

enum ParrotStatusKind {
    case info
    case progress
    case success
    case warning
    case error

    var iconName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .progress:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info, .progress:
            return .accentColor
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

struct ParrotSurfaceHeader: View {
    let systemImageName: String
    let title: String
    let subtitle: String
    var iconSize: CGFloat = 40

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImageName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: iconSize, height: iconSize)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.12), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

struct ParrotStatusBanner: View {
    let kind: ParrotStatusKind
    let title: String?
    let message: String

    init(kind: ParrotStatusKind, title: String? = nil, message: String) {
        self.kind = kind
        self.title = title
        self.message = message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if kind == .progress {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18, alignment: .top)
                    .padding(.top, 1)
            } else {
                Image(systemName: kind.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(kind.tint)
                    .frame(width: 18, height: 18, alignment: .top)
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(message)
                    .font(.callout)
                    .foregroundStyle(kind == .error || kind == .warning ? .primary : .secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .parrotPanel(fill: kind.tint.opacity(0.07), stroke: kind.tint.opacity(0.14))
    }
}

struct ParrotEmptyState: View {
    let systemImageName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImageName)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ParrotFooterBar<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(
        @ViewBuilder _ leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 8) {
                leading

                Spacer(minLength: 12)

                trailing
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct ParrotFieldLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

extension View {
    func parrotPanel(
        cornerRadius: CGFloat = 8,
        fill: Color = Color(nsColor: .controlBackgroundColor).opacity(0.72),
        stroke: Color = Color(nsColor: .separatorColor).opacity(0.55)
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            }
    }
}

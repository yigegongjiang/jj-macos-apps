import AppKit

// 列表单元格：拆两个 cell（配合多 tableColumn），行高 30 单行紧凑。
// - NameCellView    : app 列 = 图标 + 名称 + bundleId（灰）+ 完整路径 tooltip
// - DateCellView    : last_focus / last_update 列 = 右对齐；3 日内相对 "Xh"，超过为 JST 日期串

// MARK: - Name 列（图标 + name + bundleId）

final class NameCellView: NSTableCellView {
    static let reuseId = NSUserInterfaceItemIdentifier("NameCellView")

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let bundleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("no xib") }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        // name：保持固有宽度（hugging 高），空间不足时才截断。
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // bundleId：占据 name 右侧余白，过长优先截断。
        bundleLabel.font = .systemFont(ofSize: 11)
        bundleLabel.textColor = .secondaryLabelColor
        bundleLabel.lineBreakMode = .byTruncatingTail
        bundleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bundleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bundleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(bundleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            bundleLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            bundleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            bundleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(_ record: AppRecord, icon: NSImage?) {
        iconView.image = icon
        nameLabel.stringValue = record.name
        bundleLabel.stringValue = record.bundleId
        toolTip = record.path.isEmpty ? nil : record.path
    }
}

// MARK: - Date 列（last_focus / last_update 通用）

final class DateCellView: NSTableCellView {
    static let reuseId = NSUserInterfaceItemIdentifier("DateCellView")

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("no xib") }

    private func setup() {
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.lineBreakMode = .byClipping
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    // 3 日(72h)内 → 相对时间 "Xh"；超过 → JST 前缀 "YYYY-MM-DD HH:MM"（去秒 / 时区尾巴）。
    // 值为 0 / 字段缺失时占位 "—" + 三级灰。
    func configure(epochMs: Int64, jst: String) {
        if epochMs > 0, jst.count >= 16 {
            label.stringValue = Self.display(epochMs: epochMs, jst: jst)
            label.textColor = .secondaryLabelColor
        } else {
            label.stringValue = "—"
            label.textColor = .tertiaryLabelColor
        }
    }

    // 距今 0..72h → 相对 "Xh"（1 位小数，整数去尾 ".0"）；否则绝对 JST 到分钟。
    private static func display(epochMs: Int64, jst: String) -> String {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let deltaH = Double(nowMs - epochMs) / 3_600_000.0
        guard deltaH >= 0, deltaH <= 72 else { return String(jst.prefix(16)) }
        let s = String(format: "%.1f", deltaH)
        return (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + "h"
    }
}

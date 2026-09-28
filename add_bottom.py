import re

def process_file(path, replacements):
    with open(path, 'r') as f:
        content = f.read()
    for old, new in replacements:
        content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)

process_file('Sources/SplitBar/Models/DockPlacement.swift', [
    ('case top', 'case top\n    case bottom')
])

panel_geom = """    case .top:
        let unclampedX = screen.visibleFrame.midX - (panelSize.width / 2.0)
        x = min(max(unclampedX, screen.visibleFrame.minX), screen.visibleFrame.maxX - panelSize.width)
        y = screen.visibleFrame.maxY - panelSize.height - edgeInset
    case .bottom:
        let unclampedX = screen.visibleFrame.midX - (panelSize.width / 2.0)
        x = min(max(unclampedX, screen.visibleFrame.minX), screen.visibleFrame.maxX - panelSize.width)
        y = screen.visibleFrame.minY + edgeInset"""

process_file('Sources/SplitBar/Support/PanelGeometry.swift', [
    ('    case .top:\n        let unclampedX = screen.visibleFrame.midX - (panelSize.width / 2.0)\n        x = min(max(unclampedX, screen.visibleFrame.minX), screen.visibleFrame.maxX - panelSize.width)\n        y = screen.visibleFrame.maxY - panelSize.height - edgeInset', panel_geom)
])

flyout_geom = """    case .top:
        unclampedX = anchorFrame.midX - (flyoutSize.width / 2.0)
        unclampedY = anchorFrame.minY - flyoutSize.height - gap
    case .bottom:
        unclampedX = anchorFrame.midX - (flyoutSize.width / 2.0)
        unclampedY = anchorFrame.maxY + gap"""

process_file('Sources/SplitBar/Support/PanelGeometry.swift', [
    ('    case .top:\n        unclampedX = anchorFrame.midX - (flyoutSize.width / 2.0)\n        unclampedY = anchorFrame.minY - flyoutSize.height - gap', flyout_geom)
])

edge_rect = """    case .top:
        return CGRect(
            x: screen.visibleFrame.minX,
            y: screen.visibleFrame.maxY - thickness,
            width: screen.visibleFrame.width,
            height: thickness
        )
    case .bottom:
        return CGRect(
            x: screen.visibleFrame.minX,
            y: screen.visibleFrame.minY,
            width: screen.visibleFrame.width,
            height: thickness
        )"""

process_file('Sources/SplitBar/Support/PanelGeometry.swift', [
    ('    case .top:\n        return CGRect(\n            x: screen.visibleFrame.minX,\n            y: screen.visibleFrame.maxY - thickness,\n            width: screen.visibleFrame.width,\n            height: thickness\n        )', edge_rect)
])

flyout_rect = """    case .top:
        return CGRect(x: dockFrame.midX - length / 2.0, y: screen.visibleFrame.maxY - thickness - inset, width: length, height: thickness)
    case .bottom:
        return CGRect(x: dockFrame.midX - length / 2.0, y: screen.visibleFrame.minY + inset, width: length, height: thickness)"""

process_file('Sources/SplitBar/Support/PanelGeometry.swift', [
    ('    case .top:\n        return CGRect(x: dockFrame.midX - length / 2.0, y: screen.visibleFrame.maxY - thickness - inset, width: length, height: thickness)', flyout_rect)
])

dock_item = """        case .top:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottom:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))"""
process_file('Sources/SplitBar/Views/Dock/DockItemView.swift', [
    ('        case .top:\n            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))\n            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))\n            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))', dock_item)
])

dock_item_offset = """        case .top:
            return CGSize(width: 0.0, height: amplitude)
        case .bottom:
            return CGSize(width: 0.0, height: -amplitude)"""
process_file('Sources/SplitBar/Views/Dock/DockItemView.swift', [
    ('        case .top:\n            return CGSize(width: 0.0, height: amplitude)', dock_item_offset)
])

tooltip = """        case .top:
            targetX = screenX - (width / 2.0)
            targetY = anchorFrame.minY - height - 10.0
        case .bottom:
            targetX = screenX - (width / 2.0)
            targetY = anchorFrame.maxY + 10.0"""
process_file('Sources/SplitBar/Services/DockTooltipPanelController.swift', [
    ('        case .top:\n            targetX = screenX - (width / 2.0)\n            targetY = anchorFrame.minY - height - 10.0', tooltip)
])

edge = """        case .top:
            return CGVector(dx: 0.0, dy: Self.slideDistance)
        case .bottom:
            return CGVector(dx: 0.0, dy: -Self.slideDistance)"""
process_file('Sources/SplitBar/Services/EdgePanelController.swift', [
    ('        case .top:\n            return CGVector(dx: 0.0, dy: Self.slideDistance)', edge)
])


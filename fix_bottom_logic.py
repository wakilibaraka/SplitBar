import re

def replace_in_file(path, old, new):
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)

# EdgeDockView.swift
replace_in_file('Sources/SplitBar/Views/Dock/EdgeDockView.swift',
    'if viewState.edge == .top {',
    'if viewState.edge == .top || viewState.edge == .bottom {')
replace_in_file('Sources/SplitBar/Views/Dock/EdgeDockView.swift',
    'x: (viewState.edge == .top && isBeingDragged) ? dragOffset : 0.0,',
    'x: ((viewState.edge == .top || viewState.edge == .bottom) && isBeingDragged) ? dragOffset : 0.0,')
replace_in_file('Sources/SplitBar/Views/Dock/EdgeDockView.swift',
    'y: (viewState.edge != .top && isBeingDragged) ? dragOffset : 0.0',
    'y: ((viewState.edge == .left || viewState.edge == .right) && isBeingDragged) ? dragOffset : 0.0')
replace_in_file('Sources/SplitBar/Views/Dock/EdgeDockView.swift',
    'let translation = viewState.edge == .top ? gesture.translation.width : gesture.translation.height',
    'let translation = (viewState.edge == .top || viewState.edge == .bottom) ? gesture.translation.width : gesture.translation.height')

# Add "Bottom Edge" button to the context menu
context_menu_add = """                Button {
                    onAction(.updatePlacement(DockPlacement(edge: .top, verticalOffsetFraction: 0.5, autoHide: autoHide)))
                } label: {
                    HStack {
                        Text("Top Edge")
                        if viewState.edge == .top { Image(systemName: "checkmark") }
                    }
                }
                
                Button {
                    onAction(.updatePlacement(DockPlacement(edge: .bottom, verticalOffsetFraction: 0.5, autoHide: autoHide)))
                } label: {
                    HStack {
                        Text("Bottom Edge")
                        if viewState.edge == .bottom { Image(systemName: "checkmark") }
                    }
                }"""
replace_in_file('Sources/SplitBar/Views/Dock/EdgeDockView.swift',
    """                Button {
                    onAction(.updatePlacement(DockPlacement(edge: .top, verticalOffsetFraction: 0.5, autoHide: autoHide)))
                } label: {
                    HStack {
                        Text("Top Edge")
                        if viewState.edge == .top { Image(systemName: "checkmark") }
                    }
                }""",
    context_menu_add)

# EdgePanelController.swift
replace_in_file('Sources/SplitBar/Services/EdgePanelController.swift',
    'let isVertical = edge != .top',
    'let isVertical = (edge == .left || edge == .right)')

# AppRuntimeController.swift
replace_in_file('Sources/SplitBar/App/AppRuntimeController.swift',
    'if state.placement.edge == .top {',
    'if state.placement.edge == .top || state.placement.edge == .bottom {')

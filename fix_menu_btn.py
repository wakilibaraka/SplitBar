import re

def replace_in_file(path, old, new):
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)

old_str = """                Button {
                    onAction(.updatePlacement(DockPlacement(edge: .top, verticalOffsetFraction: 0.5, autoHide: autoHide)))
                } label: {
                    HStack {
                        Text("Top Edge")
                        if viewState.edge == .top { Image(systemName: "checkmark") }
                    }
                }"""

new_str = old_str + """
                Button {
                    onAction(.updatePlacement(DockPlacement(edge: .bottom, verticalOffsetFraction: 0.5, autoHide: autoHide)))
                } label: {
                    HStack {
                        Text("Bottom Edge")
                        if viewState.edge == .bottom { Image(systemName: "checkmark") }
                    }
                }"""
replace_in_file('Sources/SplitBar/Views/Dock/EdgeDockView.swift', old_str, new_str)

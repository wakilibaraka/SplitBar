import re

def replace_in_file(path, old, new):
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)

replace_in_file('Sources/SplitBar/Views/Settings/SettingsView.swift',
    'Text("Top Edge").tag(DockEdge.top)',
    'Text("Top Edge").tag(DockEdge.top)\n                    Text("Bottom Edge").tag(DockEdge.bottom)')

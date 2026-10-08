import os
html = "<html><body style='background:#333; color:white;'>"
for f in sorted(os.listdir('assets/ui')):
    if f.endswith('.png'):
        path = os.path.join('assets/ui', f)
        html += f"<div style='display:inline-block; margin:10px; border:1px solid #666;'><img src='{f}' /><br/>{f}</div>"
html += "</body></html>"
with open('assets/ui/preview.html', 'w') as f:
    f.write(html)

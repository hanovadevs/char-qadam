"""Check local Markdown/HTML documentation targets without fetching the network."""
from pathlib import Path
import re
import os
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
SKIP = {'.git', '.venv', 'node_modules', 'build', 'dist', '.dart_tool', '.gradle',
        '.kotlin', '.local-test-postgres', '.pytest_cache', '__pycache__', 'Pods',
        '.symlinks', '.pub-cache', 'ephemeral'}
names = []
for directory, folders, files in os.walk(ROOT):
    folders[:] = [name for name in folders if name not in SKIP]
    names.extend(str((Path(directory) / name).relative_to(ROOT))
                 for name in files if name.endswith('.md'))
errors = []
checked = 0
for name in names:
    path = ROOT / name
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    links = re.findall(r'!?\[[^\]]*\]\((<[^>]+>|[^\s)]+)', text)
    links += re.findall(r'(?:src|href)=["\']([^"\']+)["\']', text)
    for href in links:
        href = href.strip('<>')
        if href.startswith(('#', '/')) or re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', href):
            continue
        local = unquote(href.split('#', 1)[0].split('?', 1)[0])
        if not local:
            continue
        target = (path.parent / local).resolve()
        checked += 1
        if not target.exists():
            errors.append(f'{name}: missing {href}')
if errors:
    print('\n'.join(errors))
    raise SystemExit(1)
print(f'Validated {checked} local targets in {len(names)} Markdown files.')

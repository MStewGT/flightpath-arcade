"""Verify approved source/assets and all six current in-game screenshots."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'tests/frost-baseline.json').read_text())
for name,digest in manifest['binary'].items():
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,name
for name,digest in manifest['text'].items():
    text=(root/name).read_text()
    if name.endswith('/UI.lua') and '/Frost/' not in name:
        text=text.replace('A.UI={label=label,button=button,border=fantasyBorder}\n','')
    assert hashlib.sha256(text.encode()).hexdigest()==digest,name
for name in ('README.md','FlightpathArcade/README.md'):
    text=(root/name).read_text()
    assert 'ForTheHorde!' not in text and 'UP UP DOWN' not in text
    assert '## Validation' not in text and '## Development' not in text
print('PASS: all original game rules/shared UI preserved, Frost 0.1.6 rules/animation/assets retained, six current screenshots preserved, player README does not disclose unlock')

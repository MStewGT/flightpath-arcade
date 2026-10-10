"""Checks preserved original rules, gem animation engine and original assets."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1];addon=root/'FlightpathArcade'
m=json.loads((root/'tests/level-baseline.json').read_text())
s=(addon/'Logic.lua').read_text();prefix=s[:s.index('function L.gemLevel')]
assert hashlib.sha256(prefix.encode()).hexdigest()==m['other_rules_sha256']
for path,digest in m['files'].items():
    if path != 'Core.lua':
        assert hashlib.sha256((addon/path).read_bytes()).hexdigest()==digest,path
print('PASS: original Minesweeper, Snake, memory rules, gem animation and original textures unchanged; lifecycle covered by Lua suite')

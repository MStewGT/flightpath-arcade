"""Checks preserved pre-Match-3 rules, animation engine, settings and assets."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1];addon=root/'FlightpathArcade'
m=json.loads((root/'tests/level-baseline.json').read_text())
s=(addon/'Logic.lua').read_text();prefix=s[:s.index('function L.gemLevel')]
assert hashlib.sha256(prefix.encode()).hexdigest()==m['other_rules_sha256']
for path,digest in m['files'].items():assert hashlib.sha256((addon/path).read_bytes()).hexdigest()==digest,path
print('PASS: Minesweeper, Snake, memory rules; animation engine, settings/flight code, and all textures unchanged')

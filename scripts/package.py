"""Build a reproducible install-only ZIP; no third-party Python dependencies."""
from pathlib import Path
import hashlib, re, zipfile

root = Path(__file__).resolve().parents[1]
addon = root / 'FlightpathArcade'
toc = (addon / 'FlightpathArcade.toc').read_text()
version = re.search(r'^## Version: ([\d.]+)$', toc, re.M).group(1)
assert '## Interface: 16001' in toc
load_files = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
allowed = set(load_files + ['FlightpathArcade.toc', 'README.md', 'LICENSE',
    'Media/Arcade.tga', 'Media/Buttons.tga', 'Media/Minimap.tga',
    'Media/CREDITS.md', 'Media/LICENSE.txt'])
frost_names = ['tree','treeTall','deadTree','rock','stump','snowman','ramp','flagRed','flagBlue','skier','skierAir','monster','monster2','monsterAttack','terrain','decor']
allowed.update('Media/Frost/' + name + '.tga' for name in frost_names)
notices = sorted((addon / 'Media/Licenses').glob('*.txt'))
assert len(notices) == 8 and all('CC0' in p.read_text() for p in notices)
allowed.update(p.relative_to(addon).as_posix() for p in notices)
for name in allowed:
    assert (addon / name).is_file(), name
assert set(p.relative_to(addon).as_posix() for p in addon.rglob('*') if p.is_file()) == allowed
out = root / 'dist' / ('FlightpathArcade-' + version + '.zip')
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for name in sorted(allowed):
        info = zipfile.ZipInfo('FlightpathArcade/' + name, (2026, 1, 1, 0, 0, 0))
        info.create_system = 3
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, (addon / name).read_bytes())
with zipfile.ZipFile(out) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {'FlightpathArcade/' + n for n in allowed}
print('PASS: TOC files, eight CC0 notices, explicit install-only allowlist, ZIP integrity')
print(out)
print('Bytes:', out.stat().st_size)
print('SHA256:', hashlib.sha256(out.read_bytes()).hexdigest())

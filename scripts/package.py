"""Local task: python scripts/package.py [--output-dir dist/release].

Standard library only. Builds and verifies an install ZIP; never publishes it.
"""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, re, tempfile, zipfile

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ('Logic.lua','Animation.lua','UI.lua','Frost/Simulation.lua',
           'Frost/Animation.lua','Frost/UI.lua','Core.lua')
FROST = ('tree','treeTall','deadTree','rock','stump','snowman','ramp','flagRed',
         'flagBlue','skier','skierAir','monster','monster2','monsterAttack','terrain','decor')
NOTICES = ('Animal Pack Remastered','Board Game Icons','Fantasy UI Borders',
           'Platformer Assets Base','Puzzle Pack 1','Rune Pack','UI Pack - Adventure','Tiny Ski')
FIXED = {'FlightpathArcade.toc','README.md','LICENSE','Media/Arcade.tga',
         'Media/Buttons.tga','Media/Minimap.tga','Media/CREDITS.md','Media/LICENSE.txt'}

def safe_name(name):
    if ('\\' in name or ':' in name or PurePosixPath(name).is_absolute()
            or any(p in ('', '.', '..') for p in name.split('/'))):
        raise ValueError('Unsafe addon path: ' + name)
    return name

def inputs(addon):
    toc_path = addon / 'FlightpathArcade.toc'
    if not toc_path.is_file():
        raise ValueError('Missing required file: FlightpathArcade.toc')
    toc = toc_path.read_text(encoding='utf-8-sig')
    versions = re.findall(r'^## Version: (\d+\.\d+\.\d+)\s*$', toc, re.M)
    if len(versions) != 1:
        raise ValueError('Expected exactly one major.minor.patch TOC version')
    if not re.search(r'^## Interface: 16001\s*$', toc, re.M):
        raise ValueError('Expected Forever Interface 16001')
    runtime = [safe_name(s.strip()) for s in toc.splitlines()
               if s.strip() and not s.lstrip().startswith('#')]
    if not runtime or len(runtime) != len(set(runtime)) or any(not n.endswith('.lua') for n in runtime):
        raise ValueError('Expected a nonempty, unique Lua TOC runtime list')
    if [n for n in runtime if n in RUNTIME] != list(RUNTIME):
        raise ValueError('TOC runtime dependencies are missing or out of order')
    if any(p.startswith('.') or p.lower() in ('tests','scripts','docs') for n in runtime for p in n.split('/')):
        raise ValueError('TOC must not include development or hidden paths')
    allowed = FIXED | set(runtime) | {'Media/Frost/' + n + '.tga' for n in FROST}
    allowed |= {'Media/Licenses/' + n + '.txt' for n in NOTICES}
    for name in sorted(allowed):
        safe_name(name)
        path = addon / name
        if not path.is_file():
            raise ValueError('Missing required file: ' + name)
        if path.is_symlink() or any(p.is_symlink() for p in path.parents if p.is_relative_to(addon)):
            raise ValueError('Symlinked release input: ' + name)
        if not path.resolve().is_relative_to(addon.resolve()):
            raise ValueError('Release input escapes addon directory: ' + name)
        if name.startswith('Media/Licenses/') and 'CC0' not in path.read_text(encoding='utf-8'):
            raise ValueError('Missing CC0 notice: ' + name)
    return versions[0], sorted(allowed)

def verify_archive(path, payloads):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(payloads) or archive.testzip():
            raise ValueError('Archive member or integrity mismatch')
        for name in names:
            safe_name(name)
            if not name.startswith('FlightpathArcade/') or archive.read(name) != payloads[name]:
                raise ValueError('Archive content mismatch: ' + name)
        with tempfile.TemporaryDirectory(prefix='.verify-', dir=path.parent) as directory:
            target = Path(directory).resolve()
            if not target.is_relative_to(path.parent.resolve()):
                raise ValueError('Verification directory escapes output directory')
            archive.extractall(target)
            actual = {p.relative_to(target).as_posix() for p in target.rglob('*') if p.is_file()}
            if actual != set(payloads) or any((target/n).read_bytes() != d for n,d in payloads.items()):
                raise ValueError('Clean extraction mismatch')

def build(root=ROOT, output_dir=None):
    addon = Path(root) / 'FlightpathArcade'
    version, allowed = inputs(addon)
    output = Path(output_dir) if output_dir is not None else Path(root) / 'dist'
    if output.resolve().is_relative_to(addon.resolve()):
        raise ValueError('Output must be outside the addon directory')
    payloads = {'FlightpathArcade/' + n: (addon/n).read_bytes() for n in allowed}
    output.mkdir(parents=True, exist_ok=True)
    path = output / ('FlightpathArcade-' + version + '.zip')
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in payloads.items():
            info = zipfile.ZipInfo(name, (2026,1,1,0,0,0))
            info.create_system = 3; info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    verify_archive(path, payloads)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    checksum = path.with_suffix('.zip.sha256')
    checksum.write_text(digest + '  ' + path.name + '\n', encoding='utf-8', newline='\n')
    manifest = output / ('FlightpathArcade-' + version + '-manifest.json')
    manifest.write_text(json.dumps({'version':version,'zip':path.name,'sha256':digest,
        'files':[{'path':n,'bytes':len(d),'sha256':hashlib.sha256(d).hexdigest()} for n,d in payloads.items()]},
        indent=2) + '\n', encoding='utf-8', newline='\n')
    return {'version':version,'zip':path,'checksum':checksum,'manifest':manifest,
            'sha256':digest,'file_count':len(payloads)}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--github-output', type=Path)
    args = parser.parse_args()
    try:
        result = build(output_dir=args.output_dir)
    except (ValueError, OSError, zipfile.BadZipFile) as exc:
        parser.exit(1, 'Packaging failed: ' + str(exc) + '\n')
    if args.github_output:
        with args.github_output.open('a', encoding='utf-8', newline='\n') as stream:
            for key in ('version','zip','checksum','manifest'):
                value = result[key].resolve().as_posix() if isinstance(result[key],Path) else result[key]
                stream.write(key + '=' + value + '\n')
    print('PASS: explicit dependencies, safe paths, integrity and clean extraction')
    print(str(result['zip']) + ' (' + str(result['file_count']) + ' addon files)')
    print('SHA256: ' + result['sha256'])

if __name__ == '__main__':
    main()

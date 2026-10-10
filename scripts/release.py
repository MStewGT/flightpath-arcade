"""Publish tested package assets. Only the manual GitHub workflow invokes this.

Existing tags are never moved; existing assets are never replaced or deleted.
An interrupted draft can be resumed when every existing asset matches.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request
import package


class GitHub:
    def __init__(self, repository, token):
        self.repository, self.token = repository, token

    def call(self, method, path, data=None, missing=False, upload=False):
        host = 'uploads.github.com' if upload else 'api.github.com'
        url = 'https://' + host + '/repos/' + self.repository + path
        body = data if upload else (json.dumps(data).encode() if data is not None else None)
        headers = {'Authorization': 'Bearer ' + self.token,
                   'Accept': 'application/vnd.github+json',
                   'X-GitHub-Api-Version': '2022-11-28',
                   'Content-Type': 'application/octet-stream' if upload else 'application/json'}
        try:
            with urllib.request.urlopen(urllib.request.Request(url, body, headers, method=method), timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as exc:
            if missing and exc.code == 404:
                return None
            raise ValueError('GitHub ' + method + ' ' + path + ' failed (HTTP ' + str(exc.code) + '). Rerun after resolving the error; no assets are overwritten.') from None


def tag_commit(api, tag):
    ref = api.call('GET', '/git/ref/tags/' + tag, missing=True)
    if ref is None:
        return None
    obj = ref['object']
    for _ in range(10):
        if obj['type'] == 'commit':
            return obj['sha']
        if obj['type'] != 'tag':
            break
        obj = api.call('GET', '/git/tags/' + obj['sha'])['object']
    raise ValueError('Cannot resolve release tag to a commit')


def validate_assets(directory):
    version, allowed = package.inputs(package.ROOT / 'FlightpathArcade')
    stem = 'FlightpathArcade-' + version
    names = [stem + '.zip', stem + '.zip.sha256', stem + '-manifest.json']
    directory = Path(directory)
    if {p.name for p in directory.iterdir()} != set(names):
        raise ValueError('Expected exactly the ZIP, checksum and manifest in the asset directory')
    payloads = {'FlightpathArcade/' + n: (package.ROOT / 'FlightpathArcade' / n).read_bytes() for n in allowed}
    package.verify_archive(directory / names[0], payloads)
    files = {n: (directory / n).read_bytes() for n in names}
    digest = hashlib.sha256(files[names[0]]).hexdigest()
    expected = {'version': version, 'zip': names[0], 'sha256': digest,
                'files': [{'path': n, 'bytes': len(d), 'sha256': hashlib.sha256(d).hexdigest()} for n, d in payloads.items()]}
    if json.loads(files[names[2]]) != expected or files[names[1]].decode() != digest + '  ' + names[0] + '\n':
        raise ValueError('Package checksum or manifest does not match tested source')
    return version, files


def release_assets(api, release_id):
    result = []
    page = 1
    while True:
        batch = api.call('GET', '/releases/' + str(release_id) + '/assets?per_page=100&page=' + str(page))
        result.extend(batch)
        if len(batch) < 100:
            return result
        page += 1


def check_assets(existing, files):
    found = set()
    for asset in existing:
        name = asset['name']
        if name not in files or name in found:
            raise ValueError('Unexpected or duplicate existing Release asset: ' + name)
        data = files[name]
        if (asset.get('state') != 'uploaded' or asset.get('size') != len(data)
                or asset.get('digest') != 'sha256:' + hashlib.sha256(data).hexdigest()):
            raise ValueError('Existing Release asset differs or lacks a verifiable SHA-256: ' + name + '. Refusing to overwrite it.')
        found.add(name)
    return found


def publish(api, version, sha, files):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('Invalid version or workflow commit SHA')
    tag = 'v' + version
    commit = tag_commit(api, tag)
    if commit is not None and commit != sha:
        raise ValueError('Tag ' + tag + ' targets a different commit. Refusing to move it.')
    release = api.call('GET', '/releases/tags/' + tag, missing=True)
    if release and (commit is None or release.get('prerelease')):
        raise ValueError('Existing Release has no matching tag or is a prerelease')
    # Check every existing asset before any mutation, including partial drafts.
    present = check_assets(release_assets(api, release['id']), files) if release else set()
    if commit is None:
        api.call('POST', '/git/refs', {'ref': 'refs/tags/' + tag, 'sha': sha})
    if tag_commit(api, tag) != sha:
        raise ValueError('Release tag changed during validation')
    if release is None:
        release = api.call('POST', '/releases', {
            'tag_name': tag, 'target_commitish': sha, 'name': 'Flightpath Arcade ' + version,
            'draft': True, 'prerelease': False,
            'body': 'Small games for your WoW Forever flights.\n\n'
                    'Download the install ZIP and extract FlightpathArcade into Interface/AddOns. '
                    'Use /fpa or the minimap button to play and adjust flight settings.\n\n'
                    'Artwork: [Kenney](https://kenney.nl/), CC0. Full credits and license notices are included.'})
    for name, data in files.items():
        if name not in present:
            asset = api.call('POST', '/releases/' + str(release['id']) + '/assets?name=' + urllib.parse.quote(name, safe=''), data, upload=True)
            check_assets([asset], files)
    if check_assets(release_assets(api, release['id']), files) != set(files):
        raise ValueError('Release assets are incomplete')
    if tag_commit(api, tag) != sha:
        raise ValueError('Release tag changed before publication')
    if release['draft']:
        release = api.call('PATCH', '/releases/' + str(release['id']), {'draft': False})
    if release['draft'] or release.get('prerelease'):
        raise ValueError('Release was not published as a full release')
    return release['html_url']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets', required=True, type=Path)
    args = parser.parse_args()
    try:
        if os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch':
            raise ValueError('Release publishing requires the manual GitHub workflow')
        repository = os.environ['GITHUB_REPOSITORY']
        if repository != 'MStewGT/flightpath-arcade':
            raise ValueError('Unexpected release repository')
        version, files = validate_assets(args.assets)
        url = publish(GitHub(repository, os.environ['GH_TOKEN']), version, os.environ['GITHUB_SHA'], files)
        print('Verified public Release: ' + url)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
                stream.write('Published and verified [Flightpath Arcade ' + version + '](' + url + ').\n')
    except (ValueError, KeyError, OSError) as exc:
        parser.exit(1, 'Release failed: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()

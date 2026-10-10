"""Offline Release API mocks; never contacts GitHub or publishes anything."""
from pathlib import Path
import hashlib
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import release

SHA = 'a' * 40
FILES = {'addon.zip': b'zip', 'checksum': b'sha', 'manifest.json': b'json'}


def asset(name, data):
    return {'name': name, 'size': len(data), 'state': 'uploaded',
            'digest': 'sha256:' + hashlib.sha256(data).hexdigest()}


class FakeGitHub:
    def __init__(self, commit=None, existing=False, draft=False):
        self.commit = commit
        self.release = {'id': 1, 'draft': draft, 'prerelease': False, 'html_url': 'https://example.test/release'} if existing else None
        self.assets = []
        self.writes = []
        self.annotated = False
        self.fail_upload = False

    def call(self, method, path, data=None, missing=False, upload=False):
        if method != 'GET':
            self.writes.append((method, path, data))
        if method == 'GET' and path.startswith('/git/ref/tags/'):
            if self.commit is None: return None
            return {'object': {'type': 'tag' if self.annotated else 'commit', 'sha': self.commit}}
        if method == 'GET' and path.startswith('/git/tags/'):
            return {'object': {'type': 'commit', 'sha': self.commit}}
        if method == 'GET' and path.startswith('/releases/tags/'):
            return self.release
        if method == 'GET' and '/assets?' in path:
            return list(self.assets)
        if method == 'POST' and path == '/git/refs':
            if self.commit is not None: raise ValueError('Concurrent tag creation')
            self.commit = data['sha']; return {}
        if method == 'POST' and path == '/releases':
            self.release = dict(data, id=1, html_url='https://example.test/release')
            return self.release
        if upload:
            if self.fail_upload: raise ValueError('Simulated upload failure')
            name = release.urllib.parse.unquote(path.split('name=')[1])
            item = asset(name, data); self.assets.append(item); return item
        if method == 'PATCH':
            self.release.update(data); return self.release
        raise AssertionError((method, path))


class ReleaseTests(unittest.TestCase):
    def test_new_release_exact_commit_and_draft_first(self):
        api = FakeGitHub()
        release.publish(api, '1.3.1', SHA, FILES)
        self.assertEqual(api.commit, SHA)
        self.assertEqual(api.writes[0][2], {'ref': 'refs/tags/v1.3.1', 'sha': SHA})
        self.assertTrue(api.writes[1][2]['draft'])
        self.assertEqual(api.writes[1][2]['target_commitish'], SHA)
        self.assertEqual(api.writes[-1][0], 'PATCH')
        self.assertFalse(api.release['draft'])
        self.assertEqual(release.check_assets(api.assets, FILES), set(FILES))

    def test_identical_rerun_has_no_writes(self):
        api = FakeGitHub(); release.publish(api, '1.3.1', SHA, FILES)
        api.writes.clear(); release.publish(api, '1.3.1', SHA, FILES)
        self.assertEqual(api.writes, [])

    def test_wrong_commit_rejected_without_writes(self):
        api = FakeGitHub('b' * 40, True)
        with self.assertRaisesRegex(ValueError, 'different commit'):
            release.publish(api, '1.3.1', SHA, FILES)
        self.assertEqual(api.writes, [])

    def test_conflicting_or_unverifiable_assets_never_overwritten(self):
        variants = [asset('addon.zip', b'other'), dict(asset('addon.zip', b'zip'), digest=None),
                    dict(asset('addon.zip', b'zip'), state='starter'), asset('extra', b'x')]
        for item in variants:
            with self.subTest(asset=item):
                api = FakeGitHub(SHA, True, True); api.assets = [item]
                with self.assertRaises(ValueError): release.publish(api, '1.3.1', SHA, FILES)
                self.assertEqual(api.writes, [])

    def test_duplicate_asset_rejected(self):
        api = FakeGitHub(SHA, True); api.assets = [asset('addon.zip', b'zip')] * 2
        with self.assertRaises(ValueError): release.publish(api, '1.3.1', SHA, FILES)
        self.assertEqual(api.writes, [])

    def test_partial_draft_resumes_only_missing_assets(self):
        api = FakeGitHub(SHA, True, True); api.assets = [asset('addon.zip', b'zip')]
        release.publish(api, '1.3.1', SHA, FILES)
        self.assertEqual(len([x for x in api.writes if x[0] == 'POST']), 2)
        self.assertFalse(api.release['draft'])

    def test_failure_leaves_draft_and_can_resume(self):
        api = FakeGitHub(); api.fail_upload = True
        with self.assertRaises(ValueError): release.publish(api, '1.3.1', SHA, FILES)
        self.assertTrue(api.release['draft'])
        api.fail_upload = False; release.publish(api, '1.3.1', SHA, FILES)
        self.assertFalse(api.release['draft'])

    def test_annotated_tag_resolves_to_exact_commit(self):
        api = FakeGitHub(SHA); api.annotated = True
        release.publish(api, '1.3.1', SHA, FILES)
        self.assertFalse(any(x[1] == '/git/refs' for x in api.writes))

    def test_release_without_tag_or_prerelease_rejected(self):
        for api in [FakeGitHub(None, True), FakeGitHub(SHA, True)]:
            if api.commit: api.release['prerelease'] = True
            with self.assertRaises(ValueError): release.publish(api, '1.3.1', SHA, FILES)
            self.assertEqual(api.writes, [])

    def test_invalid_version_or_sha_rejected_before_api(self):
        api = FakeGitHub()
        for version, sha in [('bad', SHA), ('1.3.1', 'main')]:
            with self.assertRaises(ValueError): release.publish(api, version, sha, FILES)
        self.assertEqual(api.writes, [])

    def test_actual_package_validation_and_tampering(self):
        root = release.package.ROOT
        with tempfile.TemporaryDirectory(dir=root / 'dist') as directory:
            result = release.package.build(output_dir=directory)
            version, files = release.validate_assets(directory)
            self.assertEqual(version, result['version']); self.assertEqual(len(files), 3)
            checksum = result['checksum']; original = checksum.read_bytes()
            checksum.write_bytes(b'wrong')
            with self.assertRaisesRegex(ValueError, 'checksum or manifest'): release.validate_assets(directory)
            checksum.write_bytes(original)
            (Path(directory) / 'extra.txt').write_text('unexpected')
            with self.assertRaisesRegex(ValueError, 'exactly'): release.validate_assets(directory)


if __name__ == '__main__': unittest.main(verbosity=2)

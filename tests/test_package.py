"""Standard-library packaging regression tests; no WoW or Lua dependency."""
from pathlib import Path
import hashlib, importlib.util, json, shutil, subprocess, sys, tempfile, unittest, zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package', ROOT/'scripts/package.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
VERSION=package.inputs(ROOT/'FlightpathArcade')[0]

class PackagingTests(unittest.TestCase):
    def setUp(self):
        scratch = ROOT/'dist'
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix='.package-test-', dir=scratch)
        self.root = Path(self.temp.name).resolve()
        self.assertTrue(self.root.is_relative_to(scratch.resolve()))
        self.addCleanup(self.temp.cleanup)
        self.addon = self.root/'FlightpathArcade'
        shutil.copytree(ROOT/'FlightpathArcade', self.addon)

    def test_clean_archive_and_excluded_extras(self):
        extras = ['tests/run.lua','docs/screenshot.png','scripts/build.py','.git/config','.env',
                  'FrostRunExperiment/UI.lua','dev-notes.md','Media/private.png']
        for name in extras:
            p=self.addon/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('excluded')
        result=package.build(self.root)
        with zipfile.ZipFile(result['zip']) as archive:
            names=archive.namelist()
            self.assertEqual(len(names),39)
            self.assertTrue(all(n.startswith('FlightpathArcade/') for n in names))
            for name in extras:self.assertNotIn('FlightpathArcade/'+name,names)
        meta=json.loads(result['manifest'].read_text())
        self.assertEqual(meta['version'],VERSION)
        self.assertEqual(len(meta['files']),39)
        self.assertEqual(meta['sha256'],hashlib.sha256(result['zip'].read_bytes()).hexdigest())
        self.assertEqual(result['checksum'].read_text(),meta['sha256']+'  '+result['zip'].name+'\n')
        self.assertFalse(list(result['zip'].parent.glob('.verify-*')))

    def test_every_required_file_fails_when_missing(self):
        _,files=package.inputs(self.addon)
        for name in files:
            with self.subTest(name=name):
                p=self.addon/name;data=p.read_bytes();p.unlink()
                try:
                    with self.assertRaises(ValueError):package.build(self.root)
                finally:p.write_bytes(data)

    def test_repeatable_zip(self):
        first=package.build(self.root)['zip'].read_bytes()
        self.assertEqual(first,package.build(self.root)['zip'].read_bytes())

    def test_version_is_read_from_toc(self):
        p=self.addon/'FlightpathArcade.toc'
        p.write_text(p.read_text().replace('## Version: '+VERSION,'## Version: 9.8.7'))
        result=package.build(self.root)
        self.assertEqual(result['version'],'9.8.7')
        self.assertEqual(result['zip'].name,'FlightpathArcade-9.8.7.zip')

    def test_toc_paths_and_types(self):
        p=self.addon/'FlightpathArcade.toc';original=p.read_text()
        for bad in ['../outside.lua','/absolute.lua','C:/secret.lua','Frost\\UI.lua','.hidden.lua','tests/test.lua','bad.py']:
            with self.subTest(path=bad):
                p.write_text(original+'\n'+bad+'\n')
                with self.assertRaises(ValueError):package.build(self.root)

    def test_toc_dependencies_and_version(self):
        p=self.addon/'FlightpathArcade.toc';original=p.read_text()
        variants=[original+'\nLogic.lua\n',original.replace('Core.lua',''),
                  original.replace('Logic.lua\nAnimation.lua','Animation.lua\nLogic.lua'),
                  original.replace(VERSION,'../bad'),original+'\n## Version: 2.0.0\n',
                  original.replace('16001','99999')]
        for text in variants:
            p.write_text(text)
            with self.assertRaises(ValueError):package.build(self.root)

    def test_missing_cc0_notice(self):
        (self.addon/'Media/Licenses/Tiny Ski.txt').write_text('No license provided')
        with self.assertRaises(ValueError):package.build(self.root)

    def test_output_cannot_be_inside_addon(self):
        with self.assertRaises(ValueError):package.build(self.root,self.addon/'build')

    def test_archive_unexpected_member_rejected(self):
        result=package.build(self.root);path=result['zip']
        with zipfile.ZipFile(path) as z:payloads={n:z.read(n) for n in z.namelist()}
        with zipfile.ZipFile(path,'a') as z:z.writestr('../outside','bad')
        with self.assertRaises(ValueError):package.verify_archive(path,payloads)

    def test_validation_not_disabled_by_python_optimization(self):
        script=ROOT/'scripts/package.py'
        (self.addon/'Core.lua').unlink()
        result=subprocess.run([sys.executable,'-O','-c',
            'import runpy,sys; runpy.run_path(sys.argv[1])["build"](__import__("pathlib").Path(sys.argv[2]))',
            str(script),str(self.root)],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Missing required file: Core.lua',result.stderr)

    def test_cli_and_github_outputs(self):
        output=self.root/'artifacts';step=self.root/'step-output'
        result=subprocess.run([sys.executable,str(ROOT/'scripts/package.py'),
            '--output-dir',str(output),'--github-output',str(step)],cwd=self.root,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        values=dict(line.split('=',1) for line in step.read_text().splitlines())
        self.assertEqual(values['version'],VERSION)
        for key in ('zip','checksum','manifest'):self.assertTrue(Path(values[key]).is_file())

if __name__=='__main__':unittest.main(verbosity=2)

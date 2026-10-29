"""Real local Git integration tests; no network or production files."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('memory', Path(__file__).with_name('ancient_memory.py'))
memory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(memory)


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True, stderr=subprocess.DEVNULL).strip()


class MemoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.remote = root / 'remote.git'
        subprocess.check_call(['git', 'init', '--bare', str(self.remote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.a, self.b = root / 'a', root / 'b'
        subprocess.check_call(['git', 'clone', str(self.remote), str(self.a)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.configure(self.a)
        (self.a / 'README.md').write_text('Game overview', encoding='utf-8')
        git(self.a, 'add', '.'); git(self.a, 'commit', '-m', 'baseline'); git(self.a, 'push', '-u', 'origin', 'HEAD')
        subprocess.check_call(['git', 'clone', str(self.remote), str(self.b)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.configure(self.b)
        memory.ROOT = self.a

    def configure(self, root):
        git(root, 'config', 'user.name', 'Memory test')
        git(root, 'config', 'user.email', 'test@example.invalid')

    def tearDown(self):
        self.temp.cleanup()

    def test_roundtrip_and_unicode(self):
        memory.save('request', 'Menu — larger text')
        memory.publish()
        memory.ROOT = self.b
        memory.refresh()
        self.assertIn('Menu — larger text', memory.brief())
        self.assertNotIn('Menu — larger text', memory.brief('no match'))
        memory.save('completed', 'Updated menu', 'menu.gd; visual test pending')
        memory.publish()
        memory.ROOT = self.a
        memory.refresh()
        self.assertIn('visual test pending', memory.brief())

    def test_completed_requires_evidence(self):
        with self.assertRaises(ValueError): memory.save('completed', 'done')
        with self.assertRaises(ValueError): memory.save('request', ' ')

    def test_staged_work_preserved(self):
        (self.a / 'code.txt').write_text('unfinished')
        git(self.a, 'add', 'code.txt')
        memory.save('bug', 'bad collision')
        with self.assertRaises(RuntimeError): memory.publish()
        self.assertEqual('code.txt', git(self.a, 'diff', '--cached', '--name-only'))

    def test_unstaged_game_not_uploaded(self):
        (self.a / 'README.md').write_text('unfinished changes')
        memory.save('request', 'new idea'); memory.publish()
        self.assertEqual('Game overview', git(self.a, 'show', 'HEAD:README.md'))
        self.assertEqual('unfinished changes', (self.a / 'README.md').read_text())
        with self.assertRaises(RuntimeError): memory.refresh()

    def test_remote_changes_stop_publish_without_losing_notes(self):
        memory.save('request', 'PC A'); memory.publish()
        memory.ROOT = self.b
        path = memory.save('request', 'PC B offline')
        with self.assertRaises(RuntimeError): memory.publish()
        self.assertTrue(path.exists())
        self.assertIn('PC B offline', memory.brief())
        self.assertEqual('', git(self.b, 'diff', '--cached', '--name-only'))

    def test_existing_local_commits_not_uploaded(self):
        (self.a / 'code.txt').write_text('local commit')
        git(self.a, 'add', '.'); git(self.a, 'commit', '-m', 'unfinished feature')
        memory.save('request', 'note')
        with self.assertRaises(RuntimeError): memory.publish()
        self.assertEqual('1', git(self.a, 'rev-list', '--count', '@{upstream}..HEAD'))


if __name__ == '__main__':
    unittest.main()

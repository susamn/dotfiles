#!/usr/bin/env python3
"""Unit tests for the distro-agnostic runner and installer.

Note on mocking: these tests deliberately avoid patching os.path.exists or
builtins.open globally. Blanket patches (return_value=True) make every existence
check succeed, which is how a suite of passing tests coexisted with an installer
that crashed on import and a boot checker that never printed a verdict. Real
temporary directories are used instead -- they are barely more code and they
actually constrain behaviour.
"""
import os
import sys
import unittest
import json
import importlib.util
import shutil
import tempfile
from unittest.mock import patch, MagicMock

# Import the orchestrator and installer modules dynamically since their filenames contain hyphens or clash
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

import types

# Import linux-system-manager.sh (manually compile since importlib doesn't auto-load .sh files as python)
sys_manager = types.ModuleType("sys_manager")
sys_manager.__file__ = os.path.join(SCRIPT_DIR, "linux-system-manager.sh")
with open(sys_manager.__file__, 'r') as f:
    source_code = f.read()
code_obj = compile(source_code, sys_manager.__file__, 'exec')
exec(code_obj, sys_manager.__dict__)
sys.modules["sys_manager"] = sys_manager

# Import install.py
install_spec = importlib.util.spec_from_file_location("install", os.path.join(SCRIPT_DIR, "install.py"))
install = importlib.util.module_from_spec(install_spec)
install_spec.loader.exec_module(install)

def write_os_release(directory, **fields):
    """Write a real os-release file and return its path."""
    path = os.path.join(directory, 'os-release')
    with open(path, 'w') as f:
        for key, value in fields.items():
            f.write(f'{key}="{value}"\n')
    return path


class DistroFixture:
    """A throwaway repo layout: <tmp>/distros/<id>/ plus an os-release file.

    Using real directories means os.path.isdir does real work, so a detection bug
    can actually fail a test -- unlike a blanket os.path.isdir mock.
    """

    def __init__(self, distro_dirs, **os_release):
        self.tmp = tempfile.mkdtemp()
        self.distros_root = os.path.join(self.tmp, 'distros')
        for name in distro_dirs:
            os.makedirs(os.path.join(self.distros_root, name))
        self.os_release = write_os_release(self.tmp, **os_release)

    def cleanup(self):
        shutil.rmtree(self.tmp, ignore_errors=True)


class TestDistroDetection(unittest.TestCase):
    """detect_distro() against real directories and real os-release files."""

    def _detect(self, fixture):
        with patch.object(sys_manager, 'SCRIPT_DIR', fixture.tmp), \
             patch.object(sys_manager, 'OS_RELEASE_PATH', fixture.os_release):
            return sys_manager.detect_distro()

    def test_exact_id_match(self):
        fx = DistroFixture(['arch'], ID='arch', NAME='Arch Linux')
        self.addCleanup(fx.cleanup)
        self.assertEqual(self._detect(fx), ('arch', 'Arch Linux'))

    def test_id_wins_over_id_like(self):
        """A directory matching ID must be preferred over any ID_LIKE fallback."""
        fx = DistroFixture(['arch', 'debian'], ID='arch', NAME='Arch Linux',
                           ID_LIKE='debian')
        self.addCleanup(fx.cleanup)
        distro_id, _ = self._detect(fx)
        self.assertEqual(distro_id, 'arch')

    def test_falls_back_to_id_like(self):
        """Ubuntu has no distros/ubuntu, so it must resolve via ID_LIKE=debian."""
        fx = DistroFixture(['debian'], ID='ubuntu', NAME='Ubuntu', ID_LIKE='debian')
        self.addCleanup(fx.cleanup)
        self.assertEqual(self._detect(fx), ('debian', 'Ubuntu'))

    def test_id_like_respects_declared_order(self):
        fx = DistroFixture(['rhel'], ID='fedora', NAME='Fedora Linux',
                           ID_LIKE='rhel centos')
        self.addCleanup(fx.cleanup)
        distro_id, name = self._detect(fx)
        self.assertEqual(distro_id, 'rhel')
        self.assertEqual(name, 'Fedora Linux')

    def test_unsupported_distro_returns_none(self):
        fx = DistroFixture([], ID='gentoo', NAME='Gentoo')
        self.addCleanup(fx.cleanup)
        distro_id, name = self._detect(fx)
        self.assertIsNone(distro_id)
        self.assertEqual(name, 'Gentoo')

    def test_missing_os_release_raises(self):
        fx = DistroFixture(['arch'], ID='arch', NAME='Arch')
        self.addCleanup(fx.cleanup)
        os.remove(fx.os_release)
        with patch.object(sys_manager, 'SCRIPT_DIR', fx.tmp), \
             patch.object(sys_manager, 'OS_RELEASE_PATH', fx.os_release):
            with self.assertRaises(FileNotFoundError):
                sys_manager.detect_distro()

    def test_quoted_and_unquoted_values_both_parse(self):
        fx = DistroFixture(['arch'])
        self.addCleanup(fx.cleanup)
        with open(fx.os_release, 'w') as f:
            f.write('ID=arch\nNAME="Arch Linux"\nVERSION_ID=rolling\n')
        self.assertEqual(self._detect(fx), ('arch', 'Arch Linux'))


class TestMenuLoading(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.distro_dir = os.path.join(self.tmp, 'distros', 'arch')
        os.makedirs(self.distro_dir)

    def _write_menu(self, data):
        path = os.path.join(self.distro_dir, 'menu.json')
        with open(path, 'w') as f:
            json.dump(data, f)
        return path

    def test_loads_real_menu_file(self):
        self._write_menu({"distro_id": "arch", "sections": []})
        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp):
            data = sys_manager.load_menu('arch')
        self.assertEqual(data['distro_id'], 'arch')
        self.assertEqual(data['sections'], [])

    def test_missing_menu_raises_filenotfound(self):
        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp):
            with self.assertRaises(FileNotFoundError):
                sys_manager.load_menu('does-not-exist')

    def test_malformed_menu_raises_jsondecodeerror(self):
        path = os.path.join(self.distro_dir, 'menu.json')
        with open(path, 'w') as f:
            f.write('{ this is not json')
        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp):
            with self.assertRaises(json.JSONDecodeError):
                sys_manager.load_menu('arch')


class TestMenuRendering(unittest.TestCase):

    MENU = {
        "sections": [
            {"id": "1", "title": "Test Section", "items": [
                {"key": "a", "label": "Test A", "exec": "a.sh"},
                {"key": "b", "label": "Test B", "exec": "b.sh"},
            ]},
            {"id": "2", "title": "Second", "items": [
                {"key": "1", "label": "Test C", "exec": "c.sh"},
            ]},
        ]
    }

    def _render(self):
        # clear_screen shells out to `clear`, which warns when TERM is unset in
        # CI. Stub it rather than letting every render spawn a process.
        with patch.object(sys_manager, 'clear_screen'), \
             patch('builtins.print'):
            return sys_manager.render_menu(self.MENU, "Test Distro")

    def test_action_codes_are_built_from_section_and_key(self):
        action_map = self._render()
        self.assertEqual(sorted(action_map), ['1a', '1b', '21'])

    def test_action_map_points_at_correct_items(self):
        action_map = self._render()
        self.assertEqual(action_map['1a']['label'], 'Test A')
        self.assertEqual(action_map['1b']['exec'], 'b.sh')
        self.assertEqual(action_map['21']['label'], 'Test C')

    def test_lookup_is_case_insensitive(self):
        """main() lowercases input, so the map must be keyed lowercase."""
        action_map = self._render()
        self.assertIn('1a', action_map)
        self.assertNotIn('1A', action_map)

    def test_empty_menu_yields_empty_map(self):
        with patch.object(sys_manager, 'clear_screen'), patch('builtins.print'):
            self.assertEqual(sys_manager.render_menu({"sections": []}, "X"), {})


class TestRunAction(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.distro_dir = os.path.join(self.tmp, 'distros', 'arch')
        os.makedirs(self.distro_dir)

    def _make_script(self, name, body="#!/bin/bash\nexit 0\n", mode=0o755):
        path = os.path.join(self.distro_dir, name)
        with open(path, 'w') as f:
            f.write(body)
        os.chmod(path, mode)
        return path

    def test_invokes_script_with_declared_args(self):
        self._make_script('test.sh')
        item = {"key": "a", "label": "Test A", "exec": "test.sh",
                "args": ["--flag", "value"]}

        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp), \
             patch.object(sys_manager, 'clear_screen'), \
             patch('builtins.print'), patch('builtins.input', return_value=''), \
             patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            sys_manager.run_action('arch', item)

        argv = mock_run.call_args[0][0]
        self.assertTrue(argv[0].endswith('test.sh'))
        self.assertEqual(argv[1:], ['--flag', 'value'])

    def test_runs_from_the_distro_directory(self):
        """Scripts resolve sibling paths relative to cwd, so this is load-bearing."""
        self._make_script('test.sh')
        item = {"key": "a", "label": "T", "exec": "test.sh"}

        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp), \
             patch.object(sys_manager, 'clear_screen'), \
             patch('builtins.print'), patch('builtins.input', return_value=''), \
             patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            sys_manager.run_action('arch', item)

        self.assertEqual(mock_run.call_args[1]['cwd'], self.distro_dir)

    def test_missing_script_does_not_execute_anything(self):
        item = {"key": "a", "label": "Ghost", "exec": "absent.sh"}

        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp), \
             patch.object(sys_manager, 'clear_screen'), \
             patch('builtins.print'), patch('builtins.input', return_value=''), \
             patch('subprocess.run') as mock_run:
            sys_manager.run_action('arch', item)

        mock_run.assert_not_called()

    def test_non_executable_script_is_chmodded(self):
        path = self._make_script('test.sh', mode=0o644)
        item = {"key": "a", "label": "T", "exec": "test.sh"}

        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp), \
             patch.object(sys_manager, 'clear_screen'), \
             patch('builtins.print'), patch('builtins.input', return_value=''), \
             patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            sys_manager.run_action('arch', item)

        self.assertTrue(os.access(path, os.X_OK))

    def test_real_script_failure_is_surfaced(self):
        """End to end with no subprocess mock: a failing script must be reported."""
        self._make_script('fail.sh', body="#!/bin/bash\nexit 3\n")
        item = {"key": "a", "label": "Failing", "exec": "fail.sh"}

        printed = []
        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp), \
             patch.object(sys_manager, 'clear_screen'), \
             patch('builtins.print', side_effect=lambda *a, **k: printed.append(
                 " ".join(str(x) for x in a))), \
             patch('builtins.input', return_value=''):
            sys_manager.run_action('arch', item)

        self.assertTrue(any('3' in line for line in printed),
                        f"exit code 3 was not reported; got: {printed}")


class TestRequiresGating(unittest.TestCase):
    """run_action() must fail closed on an unmet 'requires' prerequisite."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.distro_dir = os.path.join(self.tmp, 'distros', 'arch')
        os.makedirs(self.distro_dir)
        self.marker = os.path.join(self.tmp, 'ran.marker')

    def _make_script(self, name, body, mode=0o755):
        path = os.path.join(self.distro_dir, name)
        with open(path, 'w') as f:
            f.write(body)
        os.chmod(path, mode)
        return path

    def _run(self, item):
        printed = []
        with patch.object(sys_manager, 'SCRIPT_DIR', self.tmp), \
             patch.object(sys_manager, 'clear_screen'), \
             patch('builtins.print', side_effect=lambda *a, **k: printed.append(
                 " ".join(str(x) for x in a))), \
             patch('builtins.input', return_value=''):
            sys_manager.run_action('arch', item)
        return printed

    def test_action_runs_when_requirement_is_met(self):
        self._make_script('prereq_check.sh', "#!/bin/bash\nexit 0\n")
        self._make_script('trace.sh', f"#!/bin/bash\ntouch '{self.marker}'\nexit 0\n")
        item = {"key": "a", "label": "Trace", "exec": "trace.sh", "requires": "prereq"}

        self._run(item)

        self.assertTrue(os.path.exists(self.marker))

    def test_action_is_blocked_when_requirement_fails(self):
        self._make_script('prereq_check.sh', "#!/bin/bash\necho 'missing tool' >&2\nexit 1\n")
        self._make_script('trace.sh', f"#!/bin/bash\ntouch '{self.marker}'\nexit 0\n")
        item = {"key": "a", "label": "Trace", "exec": "trace.sh", "requires": "prereq"}

        printed = self._run(item)

        self.assertFalse(os.path.exists(self.marker),
                          "gated action must not run when the prerequisite check fails")
        self.assertTrue(any('requires' in line.lower() for line in printed),
                         f"no 'requires' message found in output: {printed}")

    def test_action_is_blocked_when_check_script_is_missing(self):
        """Fail closed: an undeclared requirement must not silently pass."""
        self._make_script('trace.sh', f"#!/bin/bash\ntouch '{self.marker}'\nexit 0\n")
        item = {"key": "a", "label": "Trace", "exec": "trace.sh", "requires": "ghost"}

        self._run(item)

        self.assertFalse(os.path.exists(self.marker))

    def test_ungated_action_ignores_absent_requirement(self):
        """Items with no 'requires' key must behave exactly as before."""
        self._make_script('trace.sh', f"#!/bin/bash\ntouch '{self.marker}'\nexit 0\n")
        item = {"key": "a", "label": "Trace", "exec": "trace.sh"}

        self._run(item)

        self.assertTrue(os.path.exists(self.marker))


class TestInstaller(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def test_installs_service_and_timer_files(self):
        services = os.path.join(self.tmp, 'services')
        dest = os.path.join(self.tmp, 'systemd')
        os.makedirs(services)
        os.makedirs(dest)
        for name in ('test.service', 'test.timer', 'ignored.txt'):
            with open(os.path.join(services, name), 'w') as f:
                f.write('[Unit]\n')

        copied = []
        real_copy = shutil.copy2

        def spy(src, dst, *a, **k):
            copied.append(os.path.basename(src))
            return real_copy(src, os.path.join(dest, os.path.basename(dst)))

        with patch.object(install, 'SERVICES_SRC_DIR', services), \
             patch('builtins.print'), \
             patch('shutil.copy2', side_effect=spy), \
             patch('os.chmod'), \
             patch('subprocess.run') as mock_run:
            install.install_systemd_services()

        self.assertIn('test.service', copied)
        self.assertIn('test.timer', copied)
        self.assertNotIn('ignored.txt', copied,
                         "only .service and .timer files should be installed")
        self.assertEqual(mock_run.call_args[0][0], ['systemctl', 'daemon-reload'])

    def test_missing_services_dir_is_not_fatal(self):
        with patch.object(install, 'SERVICES_SRC_DIR',
                          os.path.join(self.tmp, 'nope')), \
             patch('builtins.print'), \
             patch('subprocess.run') as mock_run:
            install.install_systemd_services()
        mock_run.assert_not_called()

    def test_runs_distro_hook_installer(self):
        distro_dir = os.path.join(self.tmp, 'distros', 'arch')
        os.makedirs(distro_dir)
        hook = os.path.join(distro_dir, 'install_hooks.sh')
        with open(hook, 'w') as f:
            f.write('#!/bin/bash\nexit 0\n')
        os.chmod(hook, 0o755)

        with patch.object(install, 'SCRIPT_DIR', self.tmp), \
             patch('builtins.print'), \
             patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            install.run_distro_installer('arch')

        self.assertTrue(mock_run.call_args[0][0][0].endswith('install_hooks.sh'))

    def test_absent_hook_installer_is_skipped_quietly(self):
        with patch.object(install, 'SCRIPT_DIR', self.tmp), \
             patch('builtins.print'), \
             patch('subprocess.run') as mock_run:
            install.run_distro_installer('nonexistent-distro')
        mock_run.assert_not_called()


if __name__ == '__main__':
    unittest.main()

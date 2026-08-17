#!/usr/bin/env python3
"""Regression tests for bugs that actually shipped.

Every test here corresponds to a real defect that was live in main. Each one was
verified to FAIL against the pre-fix code -- a regression test that passes against
the broken version is worse than no test, because it manufactures confidence.

The shell tests drive the real scripts through subprocess against temp fixtures
rather than mocking, because every one of these bugs lived in the interaction
between bash options (`set -euo pipefail`) and command exit codes. Mocks cannot
express that.
"""
import builtins
import contextlib
import importlib.util
import io
import os
import shutil
import subprocess
import symtable
import tempfile
import textwrap
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASH = shutil.which('bash') or '/bin/bash'

# Unit files and engine scripts live in $SERVICES_PATH, not inside the tool.
# Resolved exactly as install.py does, with the same workspace-relative fallback,
# so the suite cannot silently drift from what ships.
SERVICES_DIR = os.environ.get('SERVICES_PATH') or os.path.abspath(
    os.path.join(SCRIPT_DIR, '..', '..', 'services'))


def run_bash(script, *args, env=None, stdin=None, cwd=None):
    """Run a shell script and capture everything, never raising on failure."""
    full_env = dict(os.environ)
    if env:
        full_env.update(env)
    return subprocess.run(
        [BASH, script, *args],
        capture_output=True, text=True, timeout=60,
        env=full_env, input=stdin, cwd=cwd,
    )


class TestInstallerRegressions(unittest.TestCase):
    """install.py aborted with NameError before registering any package hooks."""

    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location(
            "install_under_test", os.path.join(SCRIPT_DIR, "install.py"))
        cls.install = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.install)

    def test_no_unresolved_globals_in_any_function(self):
        """The NameError that shipped: a function reading another's local.

        Static check across the whole module, so this catches the next one too --
        not just the specific name that broke.
        """
        with open(os.path.join(SCRIPT_DIR, "install.py")) as f:
            source = f.read()
        table = symtable.symtable(source, "install.py", "exec")
        # `import builtins`, not `dir(__builtins__)`: the latter is a module when a
        # file runs as __main__ but a dict when imported, so under test discovery it
        # would yield dict methods and flag every builtin as unresolved.
        module_names = set(dir(self.install)) | set(dir(builtins))

        offenders = []
        for func in table.get_children():
            if func.get_type() != 'function':
                continue
            for sym in func.get_symbols():
                name = sym.get_name()
                if (sym.is_global() and not sym.is_assigned()
                        and name not in module_names):
                    offenders.append(f"{func.get_name()}() -> {name}")

        self.assertEqual(
            offenders, [],
            "Functions reference names that do not exist at module scope: "
            + ", ".join(offenders))

    def test_rclone_helper_is_callable(self):
        """Directly exercises the function whose NameError went unnoticed.

        Fully isolated: SUDO_USER/USER are pointed at a throwaway account name so
        the helper resolves an empty profile directory. Without this the test walks
        the developer's real rclone profiles, shells out to the network, and tries
        to write into /etc/systemd/system.
        """
        import unittest.mock as mock

        with tempfile.TemporaryDirectory() as tmp:
            services = os.path.join(tmp, 'services')
            fake_home = os.path.join(tmp, 'home', 'nobody-under-test')
            os.makedirs(services)
            os.makedirs(fake_home)

            original = self.install.SERVICES_SRC_DIR
            env = {k: v for k, v in os.environ.items()
                   if k not in ('SUDO_USER', 'USER')}
            env['USER'] = 'nobody-under-test'

            try:
                self.install.SERVICES_SRC_DIR = services
                with mock.patch.dict(os.environ, env, clear=True), \
                     mock.patch.object(self.install.os.path, 'expanduser',
                                       return_value=fake_home), \
                     mock.patch.object(self.install.subprocess, 'run') as fake_run, \
                     contextlib.redirect_stdout(io.StringIO()):
                    fake_run.return_value = subprocess.CompletedProcess(
                        args=[], returncode=1, stdout='', stderr='')
                    self.install.install_rclone_sync_helper()

                # No profiles exist, so no systemd calls should have been attempted.
                self.assertEqual(
                    fake_run.call_count, 0,
                    "helper shelled out despite there being no profiles")
            except NameError as e:
                self.fail(f"install_rclone_sync_helper raised NameError: {e}")
            finally:
                self.install.SERVICES_SRC_DIR = original

    def test_install_phases_are_independent(self):
        """One failing phase must not skip the others.

        The NameError was only catastrophic because it aborted main() before hook
        registration ran.
        """
        with open(os.path.join(SCRIPT_DIR, "install.py")) as f:
            source = f.read()

        # assertTrue rather than assertIn: assertIn embeds the entire haystack in
        # the failure message, which for a source file is unreadable in CI logs.
        self.assertTrue(
            "phases" in source,
            "main() should iterate independent phases so one failure "
            "cannot skip hook registration")
        self.assertTrue(
            "except Exception" in source,
            "each install phase should be individually guarded")


class TestSetEShellIdioms(unittest.TestCase):
    """`set -euo pipefail` + idioms that return non-zero on success."""

    def test_counter_increment_does_not_abort(self):
        """((VAR++)) exits 1 when VAR is 0, killing the script under set -e.

        This is the bug that stopped check_boot.sh from ever printing its verdict.
        """
        broken = textwrap.dedent("""\
            set -euo pipefail
            N=0
            bump() { N=$((N + 1)); }
            bump; bump
            echo "N=$N"
        """)
        res = subprocess.run([BASH, '-c', broken], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"aborted: {res.stderr}")
        self.assertIn("N=2", res.stdout)

    def test_no_bare_postincrement_in_shipped_scripts(self):
        """Guard the whole tree, not just the two files that were broken."""
        import re
        pattern = re.compile(r'\(\(\s*\w+\+\+\s*\)\)')
        offenders = []
        for root, _dirs, files in os.walk(SCRIPT_DIR):
            if '.git' in root:
                continue
            for name in files:
                if not name.endswith('.sh'):
                    continue
                path = os.path.join(root, name)
                with open(path, encoding='utf-8', errors='replace') as f:
                    for lineno, line in enumerate(f, 1):
                        if pattern.search(line):
                            rel = os.path.relpath(path, SCRIPT_DIR)
                            offenders.append(f"{rel}:{lineno}")
        self.assertEqual(
            offenders, [],
            "((VAR++)) returns 1 when VAR is 0 and aborts under `set -e`; "
            "use VAR=$((VAR + 1)) instead. Found at: " + ", ".join(offenders))

    def test_grep_c_fallback_does_not_double_up(self):
        """`grep -c ... || echo 0` yields "0\\n0" and breaks the comparison.

        This inverted the GRUB safety verdict: a config with no kernel entries was
        reported as passing.
        """
        with tempfile.TemporaryDirectory() as tmp:
            empty = os.path.join(tmp, 'grub.cfg')
            with open(empty, 'w') as f:
                f.write("menuentry 'Broken' {\n}\n")

            good = textwrap.dedent(f"""\
                set -euo pipefail
                c=$(grep -c "vmlinuz-linux" "{empty}" || true)
                if [[ $c -eq 0 ]]; then echo "VERDICT=error"; else echo "VERDICT=ok"; fi
            """)
            res = subprocess.run([BASH, '-c', good], capture_output=True, text=True)
            self.assertIn("VERDICT=error", res.stdout,
                          "a GRUB config with no kernel entries must report an error")
            self.assertNotIn("syntax error", res.stderr)

    def test_no_grep_c_echo_zero_idiom_remains(self):
        import re
        pattern = re.compile(r'grep -c[^|\n]*\|\|\s*echo\s+"?0"?')
        offenders = []
        for root, _dirs, files in os.walk(SCRIPT_DIR):
            if '.git' in root:
                continue
            for name in files:
                if not name.endswith('.sh'):
                    continue
                path = os.path.join(root, name)
                with open(path, encoding='utf-8', errors='replace') as f:
                    for lineno, line in enumerate(f, 1):
                        if pattern.search(line):
                            offenders.append(
                                f"{os.path.relpath(path, SCRIPT_DIR)}:{lineno}")
        self.assertEqual(
            offenders, [],
            'grep -c prints "0" AND exits 1, so `|| echo "0"` appends a second '
            'value. Use `|| true`. Found at: ' + ", ".join(offenders))


class TestCleanupBackupsSafety(unittest.TestCase):
    """The cleanup unit calls rm -rf; its scoping is a safety property."""

    def setUp(self):
        self.script = os.path.join(SERVICES_DIR, 'cleanup-backups.sh')
        if not os.path.isfile(self.script):
            self.skipTest("services/cleanup-backups.sh not present")
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def _make_backup_tree(self, age_parent_days=90):
        home = os.path.join(self.tmp, 'u1')
        backups = os.path.join(home, '.boot-backups')
        old = os.path.join(backups, 'boot-backup-20200101_000000')
        new = os.path.join(backups, 'boot-backup-20991231_000000')
        for d in (old, new):
            os.makedirs(d)

        old_ts = 1000000000  # long past
        os.utime(old, (old_ts, old_ts))
        if age_parent_days:
            os.utime(backups, (old_ts, old_ts))
        return backups, old, new

    def test_aged_parent_directory_is_never_deleted(self):
        """The trap: without -mindepth/-name, an aged .boot-backups matches
        `-type d` and rm -rf takes every backup with it, including today's."""
        backups, old, new = self._make_backup_tree()

        res = run_bash(self.script, '--home-root', self.tmp)
        self.assertEqual(res.returncode, 0, res.stderr)

        self.assertTrue(os.path.isdir(backups),
                        "the .boot-backups parent must survive even when aged")
        self.assertTrue(os.path.isdir(new),
                        "a recent backup must survive")
        self.assertFalse(os.path.isdir(old),
                         "an aged backup should have been pruned")

    def test_dry_run_deletes_nothing(self):
        backups, old, new = self._make_backup_tree()
        res = run_bash(self.script, '--dry-run', '--home-root', self.tmp)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("would remove", res.stdout)
        self.assertTrue(os.path.isdir(old), "--dry-run must not delete anything")
        self.assertTrue(os.path.isdir(new))

    def test_rejects_invalid_retention(self):
        res = run_bash(self.script, '--retention-days', 'abc', '--home-root', self.tmp)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("non-negative integer", res.stderr)

    def test_unknown_option_is_rejected(self):
        res = run_bash(self.script, '--definitely-not-an-option')
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("unknown option", res.stderr)

    def test_service_unit_does_not_rely_on_shell_globbing(self):
        """systemd does not expand globs in ExecStart; the original unit did."""
        unit = os.path.join(SERVICES_DIR, 'sys-manager-cleanup.service')
        if not os.path.isfile(unit):
            self.skipTest("unit file not present")
        with open(unit) as f:
            unit_lines = f.readlines()
        for line in unit_lines:
            if line.startswith('ExecStart='):
                self.assertNotIn(
                    '*', line,
                    "ExecStart contains a glob, which systemd passes through "
                    "literally: " + line.strip())


class TestPrivilegeEscalation(unittest.TestCase):
    """check_boot.sh silently dropped its flags when re-executing under sudo."""

    def test_original_args_captured_before_parse_loop(self):
        for distro in ('arch', 'debian'):
            path = os.path.join(SCRIPT_DIR, 'distros', distro, 'check_boot.sh')
            if not os.path.isfile(path):
                continue
            with open(path) as fh:
                source = fh.read()
            with self.subTest(distro=distro):
                self.assertIn(
                    'ORIGINAL_ARGS=("$@")', source,
                    f"{distro}/check_boot.sh must capture argv before the parse "
                    "loop consumes it")
                self.assertNotIn(
                    'exec sudo "$0" "$@"', source,
                    f'{distro}/check_boot.sh: `"$@"` inside a function refers to '
                    "the function's args, silently dropping --auto-fix")

    def test_flags_survive_reexec_construction(self):
        """Behavioural proof of the argv-replay pattern, without invoking sudo."""
        harness = textwrap.dedent("""\
            set -euo pipefail
            ORIGINAL_ARGS=("$@")
            AUTO_FIX=false
            while [[ $# -gt 0 ]]; do
              case "$1" in
                --auto-fix) AUTO_FIX=true; shift ;;
                --quick-banner) shift ;;
                *) shift ;;
              esac
            done
            echo "replay:${ORIGINAL_ARGS[@]+${ORIGINAL_ARGS[@]}}"
        """)
        res = subprocess.run(
            [BASH, '-c', harness, 'check_boot.sh', '--auto-fix', '--quick-banner'],
            capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("--auto-fix", res.stdout)
        self.assertIn("--quick-banner", res.stdout)

    def test_empty_args_do_not_trip_set_u(self):
        harness = textwrap.dedent("""\
            set -euo pipefail
            ORIGINAL_ARGS=("$@")
            echo "replay:${ORIGINAL_ARGS[@]+${ORIGINAL_ARGS[@]}}"
        """)
        res = subprocess.run([BASH, '-c', harness, 'check_boot.sh'],
                             capture_output=True, text=True)
        self.assertEqual(res.returncode, 0,
                         f"unset array expansion tripped set -u: {res.stderr}")


class TestInstallerDoesNotDestroyState(unittest.TestCase):
    """The installer tore down healthy mounts when a network probe failed.

    install.py validates each rclone profile by probing a remote with a short
    timeout. On failure it ran `systemctl disable --now`, so a momentary blip
    during an unrelated re-install stopped working mounts and removed them from
    boot. Verified against a live system: three healthy mounts went to
    failed+disabled after a routine `sudo ./install.py`.
    """

    def test_no_disable_now_anywhere_in_installer(self):
        with open(os.path.join(SCRIPT_DIR, 'install.py')) as f:
            source = f.read()

        offenders = [
            f"install.py:{lineno}"
            for lineno, line in enumerate(source.splitlines(), 1)
            if 'disable' in line and '--now' in line and not line.strip().startswith('#')
        ]
        self.assertEqual(
            offenders, [],
            "install.py must never stop or disable units: its checks are "
            "network-dependent, so a transient failure would tear down working "
            "sync. Report and skip instead. Found at: " + ", ".join(offenders))

    def test_installer_explains_how_to_enable_manually(self):
        with open(os.path.join(SCRIPT_DIR, 'install.py')) as f:
            source = f.read()
        self.assertIn(
            'systemctl enable --now', source,
            "when a profile is not activated the installer should tell the user "
            "how to enable it themselves")


class TestMountUnitLifecycle(unittest.TestCase):
    """A clean `systemctl stop` was being recorded as a unit failure."""

    UNIT = os.path.join(SERVICES_DIR, 'rclone-mount@.service')

    def setUp(self):
        if not os.path.isfile(self.UNIT):
            self.skipTest("rclone-mount@.service not present")
        with open(self.UNIT) as f:
            self.text = f.read()

    def test_sigterm_exit_is_treated_as_success(self):
        """rclone execs in the foreground, so SIGTERM yields 143 (128+15).

        Without SuccessExitStatus every normal stop leaves the unit red, which
        made healthy mounts show up under "Failed Personal Services".
        """
        self.assertIn(
            'SuccessExitStatus=', self.text,
            "rclone exits 143 on a clean SIGTERM; without SuccessExitStatus "
            "systemd records every ordinary stop as a failure")
        line = next(l for l in self.text.splitlines()
                    if l.startswith('SuccessExitStatus='))
        self.assertTrue(
            '143' in line or 'SIGTERM' in line,
            f"SuccessExitStatus should cover the SIGTERM exit; got: {line}")

    def test_stale_mount_is_cleaned_up(self):
        self.assertIn(
            'ExecStopPost=', self.text,
            "a crashed rclone leaves a stale FUSE mountpoint that blocks the "
            "next mount; clear it on stop")

    def test_unmount_mode_exists_in_runner(self):
        runner = os.path.join(SERVICES_DIR, 'rclone-mount.sh')
        with open(runner) as f:
            self.assertIn('--unmount', f.read(),
                          "the unit's ExecStopPost calls rclone-mount.sh --unmount")

    def test_unmount_mode_is_a_noop_when_nothing_is_mounted(self):
        """ExecStopPost runs on every stop, so the common case must exit 0."""
        runner = os.path.join(SERVICES_DIR, 'rclone-mount.sh')
        with tempfile.TemporaryDirectory() as tmp:
            profiles = os.path.join(tmp, '.config', 'rclone-sync-profiles')
            os.makedirs(profiles)
            target = os.path.join(tmp, 'not-a-mount')
            os.makedirs(target)
            with open(os.path.join(profiles, 'p.conf'), 'w') as f:
                f.write(f'REMOTE="r"\nREMOTE_PATH=""\n'
                        f'LOCAL_PATH="{target}"\nSYNC_TYPE="mount"\n')

            res = run_bash(runner, '--unmount', 'p', env={'HOME': tmp})
            self.assertEqual(res.returncode, 0,
                             f"--unmount must succeed when idle: {res.stderr}")

    def test_unmount_rejects_missing_profile_argument(self):
        runner = os.path.join(SERVICES_DIR, 'rclone-mount.sh')
        res = run_bash(runner)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("Usage:", res.stderr)


class TestSystemctlParsing(unittest.TestCase):
    """systemctl marks units needing attention with a bullet, which was being
    parsed as the unit name -- yielding phantom entries in the listing."""

    def test_unit_name_extraction_survives_status_bullet(self):
        script = os.path.join(SCRIPT_DIR, 'distros', 'arch', 'services_scripts.sh')
        if not os.path.isfile(script):
            script = os.path.join(SCRIPT_DIR, 'distros', 'common',
                                  'services_scripts.sh')
        if not os.path.isfile(script):
            self.skipTest("services_scripts.sh not found")

        with open(script) as f:
            body = f.read()
        self.assertIn('lsm_unit_names', body,
                      "unit-name extraction should go through the shared filter")

        # Exercise the filter itself against output that carries the marker.
        harness = textwrap.dedent("""\
            lsm_unit_names() {
                awk '{
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /\\.(service|timer|socket|mount|target|path)$/) {
                            print $i
                            break
                        }
                    }
                }'
            }
            printf '\\u25cf rclone-mount@a.service loaded failed failed X\\n  rclone-mount@b.service loaded active running X\\n' \\
                | lsm_unit_names
        """)
        res = subprocess.run([BASH, '-c', harness], capture_output=True, text=True)
        self.assertEqual(
            res.stdout.split(),
            ['rclone-mount@a.service', 'rclone-mount@b.service'],
            f"bullet-prefixed lines mis-parsed; got: {res.stdout!r}")

    def test_no_bare_awk_first_field_on_systemctl_output(self):
        import re
        pattern = re.compile(r"systemctl list-unit[^|\n]*\|\s*awk\s*'\{print \$1\}'")
        offenders = []
        for root, dirs, files in os.walk(os.path.join(SCRIPT_DIR, 'distros')):
            dirs[:] = [d for d in dirs if d != '__pycache__']
            for name in files:
                if not name.endswith('.sh'):
                    continue
                path = os.path.join(root, name)
                with open(path, encoding='utf-8', errors='replace') as f:
                    for lineno, line in enumerate(f, 1):
                        if pattern.search(line):
                            offenders.append(
                                f"{os.path.relpath(path, SCRIPT_DIR)}:{lineno}")
        self.assertEqual(
            offenders, [],
            "systemctl prefixes lines with a status marker, so $1 is not always "
            "the unit name. Found at: " + ", ".join(offenders))


class TestPathResolution(unittest.TestCase):
    """No script may assume home directories live under /home/<user>."""

    def test_no_hardcoded_home_paths_in_executable_code(self):
        import re
        # Matches /home/ followed by a variable or name -- but not inside comments.
        pattern = re.compile(r'/home/(?!\*)[\w${]')
        offenders = []
        for root, dirs, files in os.walk(SCRIPT_DIR):
            dirs[:] = [d for d in dirs if d not in ('.git', '__pycache__')]
            for name in files:
                if not name.endswith(('.sh', '.py', '.service', '.timer')):
                    continue
                path = os.path.join(root, name)
                with open(path, encoding='utf-8', errors='replace') as f:
                    for lineno, line in enumerate(f, 1):
                        stripped = line.strip()
                        if stripped.startswith('#') or stripped.startswith('//'):
                            continue
                        if pattern.search(line):
                            offenders.append(
                                f"{os.path.relpath(path, SCRIPT_DIR)}:{lineno}")
        self.assertEqual(
            offenders, [],
            "Home directories must be resolved from passwd (getent), not assumed "
            "to be under /home. Found at: " + ", ".join(offenders))

    def test_timeline_survives_minimal_environment(self):
        """Package-manager hooks run with almost no environment; a bare ${USER}
        is unbound under `set -u` and aborted the hook."""
        for distro in ('arch', 'debian'):
            path = os.path.join(SCRIPT_DIR, 'distros', distro, 'timeline.sh')
            if not os.path.isfile(path):
                continue
            with self.subTest(distro=distro):
                res = subprocess.run(
                    ['env', '-i', BASH, path, '--help'],
                    capture_output=True, text=True, timeout=30)
                self.assertNotIn("unbound variable", res.stderr)
                self.assertEqual(res.returncode, 0, res.stderr)

    def test_backup_dir_identical_with_and_without_sudo(self):
        """Under sudo $HOME is /root, which split backups across two locations."""
        path = os.path.join(SCRIPT_DIR, 'distros', 'arch', 'backup_boot.sh')
        if not os.path.isfile(path):
            self.skipTest("backup_boot.sh not present")

        probe = 'source <(sed -n "9,22p" %s); echo "$BACKUP_DIR"' % path

        plain = subprocess.run([BASH, '-c', probe],
                               capture_output=True, text=True)
        as_sudo = subprocess.run(
            [BASH, '-c', probe], capture_output=True, text=True,
            env={**os.environ, 'HOME': '/root', 'USER': 'root',
                 'SUDO_USER': os.environ.get('USER', 'root')})

        self.assertEqual(
            plain.stdout.strip(), as_sudo.stdout.strip(),
            "BACKUP_DIR must resolve to the invoking user's home whether or not "
            "the script was reached through sudo")


class TestPersonalServicesScope(unittest.TestCase):
    """Section 5 queried only the system manager, so user-scope personal units
    (the common case -- anything needing $HOME or a login session) were invisible
    to it, and toggling one would have been aimed at the wrong systemd instance.

    Verified against the pre-fix tree: every test here fails on it EXCEPT
    test_system_target_is_not_wanted_by_default_target, which guards an
    invariant that already held.

    The user-scope half of this contract is asserted in the user's dotfiles, not
    here: this tool ships the system-scope target and queries both managers, but
    does not own the user-scope unit.
    """

    def setUp(self):
        self.script = os.path.join(SCRIPT_DIR, 'distros', 'arch',
                                   'services_scripts.sh')
        if not os.path.isfile(self.script):
            self.skipTest("services_scripts.sh not found")
        with open(self.script) as f:
            self.body = f.read()

    def test_user_manager_is_queried_for_personal_units(self):
        self.assertIn('systemctl --user', self.body,
                      "personal-services.target exists in both managers; "
                      "querying only the system one hides every user unit")

    def test_collect_emits_scope_with_each_unit(self):
        """A bare unit name is not actionable -- the same name can exist in both
        managers, and the caller has no way to recover which one it came from."""
        harness = textwrap.dedent(f"""\
            source <(sed -n '1,/^case "$action" in/p' {self.script} | head -n -1) 2>/dev/null || true
            collect_personal_units | tr '\\0' '\\n' | head -40
        """)
        res = subprocess.run([BASH, '-c', harness], capture_output=True, text=True)
        emitted = [l for l in res.stdout.splitlines() if l.strip()]
        self.assertTrue(emitted, f"collect_personal_units produced nothing: {res.stderr!r}")
        for line in emitted:
            self.assertRegex(
                line, r'^(system|user)\t\S+$',
                f"record {line!r} is missing its scope prefix")

    def test_state_changes_never_sudo_a_user_unit(self):
        """sudo systemctl --user talks to root's user manager, not the caller's,
        so the unit would be enabled for the wrong account and appear to do
        nothing."""
        self.assertNotIn('sudo systemctl --user', self.body)
        self.assertIn('lsm_systemctl_admin', self.body,
                      "enable/disable must route through the scope-aware wrapper")

    def test_no_unscoped_systemctl_in_personal_sections(self):
        """Every systemctl call reachable from a personal-unit record must carry
        the record's scope."""
        start = self.body.index('--active-personal')
        section = self.body[start:]
        offenders = []
        for lineno, line in enumerate(section.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith('#'):
                continue
            if 'systemctl' in stripped and 'lsm_systemctl' not in stripped:
                offenders.append(stripped)
        self.assertEqual(
            offenders, [],
            "unscoped systemctl calls in the personal sections: " + "; ".join(offenders))

    def test_system_target_is_shipped(self):
        """This tool installs the system-scope target. The user-scope one is
        provided by the user's dotfiles -- Section 5 still queries both, but only
        this half is ours to ship."""
        system_target = os.path.join(SERVICES_DIR, 'personal-services.target')
        self.assertTrue(os.path.isfile(system_target), "system-scope target missing")

    @staticmethod
    def _wanted_by(path):
        """Effective WantedBy= directives, ignoring comments.

        Parsed rather than substring-matched: these files explain the scope
        split in a header comment that necessarily names the wrong target, and a
        naive `in` check reads that prose as configuration.
        """
        values = []
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith(('#', ';')):
                    continue
                if line.startswith('WantedBy='):
                    values.extend(line.split('=', 1)[1].split())
        return values

    def test_system_target_is_not_wanted_by_default_target(self):
        system_target = os.path.join(SERVICES_DIR, 'personal-services.target')
        self.assertIn('multi-user.target', self._wanted_by(system_target))

class TestTemplateInstanceGlob(unittest.TestCase):
    """`${name%.*}` on rclone-sync@.service yields "rclone-sync@", whose glob
    matched the .timer instances too -- so each template listed the other's
    units and every instance appeared twice in Section 5.

    test_glob_does_not_cross_match_unit_types exercises the corrected idiom in
    isolation, so it passes against the pre-fix tree by construction; the guard
    that actually fails there is test_template_glob_carries_the_unit_suffix.
    """

    def test_template_glob_carries_the_unit_suffix(self):
        for distro in ('arch', 'debian'):
            script = os.path.join(SCRIPT_DIR, 'distros', distro,
                                  'services_scripts.sh')
            if not os.path.isfile(script):
                continue
            with open(script) as f:
                body = f.read()
            self.assertNotIn(
                '"${template_base}*"', body,
                f"{distro}: bare template glob matches both .service and .timer")
            self.assertIn('template_suffix', body,
                          f"{distro}: template glob must be suffix-qualified")

    def test_glob_does_not_cross_match_unit_types(self):
        harness = textwrap.dedent("""\
            name="rclone-sync@.service"
            template_base="${name%.*}"
            template_suffix="${name##*.}"
            for u in rclone-sync@a.service rclone-sync@a.timer rclone-sync@b.service; do
                # shellcheck disable=SC2053
                [[ $u == ${template_base}*.${template_suffix} ]] && echo "$u"
            done
        """)
        res = subprocess.run([BASH, '-c', harness], capture_output=True, text=True)
        self.assertEqual(
            res.stdout.split(),
            ['rclone-sync@a.service', 'rclone-sync@b.service'],
            f"timer instance leaked into the .service template match: {res.stdout!r}")

class TestTimerTriggeredServiceNoise(unittest.TestCase):
    """A Type=oneshot service driven by a timer is inactive between runs by
    design. Listing it beside its own timer reported every healthy sync as
    "inactive/stopped", which reads as broken."""

    def setUp(self):
        self.script = os.path.join(SCRIPT_DIR, 'distros', 'arch',
                                   'services_scripts.sh')
        if not os.path.isfile(self.script):
            self.skipTest("services_scripts.sh not found")
        with open(self.script) as f:
            self.body = f.read()

    def test_status_listing_filters_timer_triggered_services(self):
        self.assertIn('lsm_is_timer_triggered', self.body,
                      "the status listing must suppress timer-driven oneshots")

    def test_failed_listing_does_NOT_filter_them(self):
        """A failed oneshot is exactly what --failed-personal exists to surface;
        applying the same filter there would hide real breakage."""
        failed_block = self.body[self.body.index('--failed-personal'):
                                 self.body.index('--manage-personal')]
        self.assertNotIn('lsm_is_timer_triggered', failed_block)

    def test_manage_listing_does_NOT_filter_them(self):
        """You must still be able to trigger a oneshot by hand."""
        manage_block = self.body[self.body.index('--manage-personal'):]
        self.assertNotIn('lsm_is_timer_triggered', manage_block)

    def test_unscheduled_oneshot_is_still_shown(self):
        """The filter keys on TriggeredBy, which is empty when the timer is
        disabled -- so a oneshot nobody schedules stays visible rather than
        silently vanishing from the listing."""
        self.assertIn('TriggeredBy', self.body)
        self.assertIn('[[ -n "$trig" ]]', self.body)

class TestInteractiveInstaller(unittest.TestCase):
    """Installing was a manual step outside the tool, so a new machine silently
    ended up with units present but nothing enabled."""

    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location(
            "installer_ui", os.path.join(SCRIPT_DIR, "install.py"))
        cls.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.mod)

    def test_survey_is_read_only_and_needs_no_root(self):
        """Seeing what is installed must never cost a password."""
        items = self.mod.survey()
        self.assertIsInstance(items, list)
        for it in items:
            self.assertIn(it['kind'], ('unit', 'engine', 'profile'))
            self.assertIn(it['state'],
                          ('current', 'stale', 'missing', 'disabled', 'unknown'))

    def test_status_mode_does_not_escalate(self):
        with open(os.path.join(SCRIPT_DIR, 'install.py')) as f:
            src = f.read()
        status_block = src[src.index("if mode == '--status'"):
                           src.index("check_root()")]
        self.assertNotIn('execvp', status_block)
        self.assertNotIn('check_root', status_block)

    def test_templated_units_compare_after_substitution(self):
        """@USER@ means the raw source never equals the installed file, so a
        naive diff would report those units permanently outdated."""
        self.assertIn('_rendered', dir(self.mod))
        with open(os.path.join(SCRIPT_DIR, 'install.py')) as f:
            src = f.read()
        self.assertIn('TEMPLATED_UNITS', src)

    def test_selection_is_carried_as_kind_id_not_indices(self):
        """Indices would rebind to different items if the survey order shifted
        between the unprivileged prompt and the privileged re-exec."""
        with open(os.path.join(SCRIPT_DIR, 'install.py')) as f:
            src = f.read()
        self.assertIn("f\"{i['kind']}:{i['id']}\"", src)

    def test_parse_selection_forms(self):
        p = self.mod.parse_selection
        self.assertEqual(sorted(p('1 3 5', 10)), [1, 3, 5])
        self.assertEqual(sorted(p('1-4', 10)), [1, 2, 3, 4])
        self.assertEqual(sorted(p('2,4', 10)), [2, 4])
        self.assertEqual(p('a', 3), {1, 2, 3})
        self.assertEqual(p('', 10), set())
        self.assertEqual(p('n', 10), set())

    def test_parse_selection_rejects_out_of_range_and_garbage(self):
        """Silently dropping a bad token beats installing the wrong item."""
        p = self.mod.parse_selection
        self.assertEqual(p('99', 10), set())
        self.assertEqual(p('abc', 10), set())
        self.assertEqual(p('0', 10), set())
        self.assertEqual(sorted(p('1-99', 3)), [1, 2, 3])

class TestProfileCreationLocation(unittest.TestCase):
    """Section 62 wrote new profiles straight to ~/.config/rclone-sync-profiles,
    producing a real file among stow symlinks: it worked on the machine that
    created it and was silently missing on the next one."""

    def setUp(self):
        self.script = os.path.join(SCRIPT_DIR, 'distros', 'arch', 'cloud_sync.sh')
        if not os.path.isfile(self.script):
            self.skipTest("cloud_sync.sh not found")
        with open(self.script) as f:
            self.body = f.read()

    def _resolver(self, home, env=None, source='/nonexistent/distros/arch/x.sh'):
        harness = textwrap.dedent(f"""\
            source <(sed -n '/^lsm_repo_profiles_dir/,/^}}/p' {self.script})
            BASH_SOURCE=("{source}")
            lsm_repo_profiles_dir "{home}" ".config/rclone-sync-profiles"
        """)
        full = {k: v for k, v in os.environ.items() if k != 'DOTFILES_DIR'}
        full.update(env or {})
        res = subprocess.run([BASH, '-c', harness], capture_output=True,
                             text=True, env=full)
        return res.stdout.strip()

    def test_creation_uses_the_resolver_not_a_hardcoded_home_path(self):
        self.assertIn('lsm_repo_profiles_dir', self.body)
        self.assertIn('live_profiles_dir', self.body,
                      "the live and repo locations must be tracked separately")

    def test_dotfiles_dir_env_wins(self):
        with tempfile.TemporaryDirectory() as t:
            repo = os.path.join(t, 'repo')
            os.makedirs(os.path.join(repo, '.config/rclone-sync-profiles'))
            got = self._resolver(os.path.join(t, 'home'), {'DOTFILES_DIR': repo})
            self.assertEqual(got, os.path.join(repo, '.config/rclone-sync-profiles'))

    def test_follows_an_existing_stowed_profile_back_to_its_repo(self):
        with tempfile.TemporaryDirectory() as t:
            live = os.path.join(t, 'home/.config/rclone-sync-profiles')
            repo = os.path.join(t, 'repo/.config/rclone-sync-profiles')
            os.makedirs(live); os.makedirs(repo)
            open(os.path.join(repo, 'x.conf'), 'w').close()
            os.symlink('../../../repo/.config/rclone-sync-profiles/x.conf',
                       os.path.join(live, 'x.conf'))
            self.assertEqual(self._resolver(os.path.join(t, 'home')), repo)

    def test_falls_back_to_home_outside_a_dotfiles_checkout(self):
        """The tool must still work when it is not living inside a repo."""
        with tempfile.TemporaryDirectory() as t:
            home = os.path.join(t, 'home')
            os.makedirs(os.path.join(home, '.config/rclone-sync-profiles'))
            self.assertEqual(self._resolver(home),
                             os.path.join(home, '.config/rclone-sync-profiles'))

    def test_broken_stow_link_does_not_resolve_to_a_missing_dir(self):
        """readlink -f happily returns a path that does not exist; the resolver
        must reject it rather than write into nowhere."""
        with tempfile.TemporaryDirectory() as t:
            home = os.path.join(t, 'home')
            live = os.path.join(home, '.config/rclone-sync-profiles')
            os.makedirs(live)
            os.symlink('../../../gone/x.conf', os.path.join(live, 'x.conf'))
            self.assertEqual(self._resolver(home), live)


class TestTimerActivatedCrossReference(unittest.TestCase):
    """A timer-driven `Type=oneshot` service is hidden from the Section 5 status
    listing because it sits inactive between runs by design. Hiding it entirely
    left no answer to "where is the service?", so the timer's row now carries a
    marker and the unit it activates is detailed below.

    The marker generator increments a global counter. Read back through $( ), that
    increment happens in a subshell and is discarded -- every timer is labelled
    (A) and every row points at the same detail line. This shipped, and was only
    visible because two timers happened to be listed together.
    """

    def _services_script(self):
        path = os.path.join(SCRIPT_DIR, 'distros', 'arch', 'services_scripts.sh')
        if not os.path.isfile(path):
            self.skipTest("services_scripts.sh not found")
        return path

    def _body(self):
        with open(self._services_script()) as f:
            return f.read()

    @staticmethod
    def _extract_function(body, name):
        """The function exactly as shipped: from its definition to the closing
        brace in column 0. Testing a re-typed copy would not catch a drift."""
        start = body.index('%s() {' % name)
        end = body.index('\n}\n', start) + len('\n}\n')
        return body[start:end]

    def test_marker_is_not_read_through_command_substitution(self):
        import re
        self.assertIsNone(
            re.search(r'\$\(\s*lsm_next_marker', self._body()),
            "lsm_next_marker increments a global counter; reading its result "
            "through $( ) runs that increment in a subshell, so every marker "
            "comes back as (A)")

    def test_marker_sequence_is_unique_and_survives_past_z(self):
        harness = self._extract_function(self._body(), 'lsm_next_marker') + textwrap.dedent("""
            set -euo pipefail
            LSM_MARKER_IDX=0
            for _ in {1..30}; do
                lsm_next_marker
                printf '%s\\n' "$LSM_MARKER"
            done
        """)
        res = subprocess.run([BASH, '-c', harness], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stderr)

        markers = res.stdout.split()
        self.assertEqual(markers[:3], ['A', 'B', 'C'])
        self.assertEqual(len(markers), 30)
        self.assertEqual(len(set(markers)), 30,
                         "a reused marker points two timers at one detail line; "
                         "got: %r" % markers)

    def test_hidden_oneshot_is_accounted_for_not_dropped(self):
        body = self._body()
        start = body.index('--active-personal)')
        end = body.index('--failed-personal)')
        self.assertIn(
            'lsm_print_triggered_section', body[start:end],
            "the status view filters out timer-driven oneshots, so it must also "
            "print the section that accounts for them")


class TestDistroParity(unittest.TestCase):
    """Capability scripts are duplicated per distro. Most genuinely differ --
    pacman is not apt -- but the distro-blind ones must stay byte-identical, or a
    fix applied to one copy ships the original bug on the other distro.

    This list is the set that is distro-blind today. Making one of them
    distro-specific is a real decision: remove it here deliberately rather than
    letting the copies drift apart silently.
    """

    DISTRO_BLIND = [
        'boot_help.sh',
        'cloud_sync.sh',
        'install_services.sh',
        'services_scripts.sh',
        'view_grub.sh',
    ]

    def test_distro_blind_scripts_are_identical_across_distros(self):
        import hashlib
        distros_dir = os.path.join(SCRIPT_DIR, 'distros')
        if not os.path.isdir(distros_dir):
            self.skipTest("no distros directory")
        distros = sorted(d for d in os.listdir(distros_dir)
                         if os.path.isdir(os.path.join(distros_dir, d))
                         and d not in ('common', '__pycache__'))
        if len(distros) < 2:
            self.skipTest("only one distro present")

        for script in self.DISTRO_BLIND:
            digests = {}
            for distro in distros:
                path = os.path.join(distros_dir, distro, script)
                if not os.path.isfile(path):
                    continue
                with open(path, 'rb') as f:
                    digests[distro] = hashlib.sha256(f.read()).hexdigest()
            if len(digests) < 2:
                continue
            self.assertEqual(
                len(set(digests.values())), 1,
                "%s has drifted between distros: %s" % (script, digests))


if __name__ == '__main__':
    unittest.main()

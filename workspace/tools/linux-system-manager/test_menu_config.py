#!/usr/bin/env python3
"""Contract tests for every distro's menu.json.

The menu is the entire public surface of this tool: linux-system-manager.sh does
nothing except read these files and exec what they point at. A typo in an "exec"
value is invisible until a user picks that option and gets "Executable script not
found" -- so the wiring is verified here rather than at runtime.
"""
import json
import os
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DISTROS_DIR = os.path.join(SCRIPT_DIR, 'distros')


def discover_distros():
    """Every directory under distros/ that ships a menu.json."""
    if not os.path.isdir(DISTROS_DIR):
        return []
    found = []
    for name in sorted(os.listdir(DISTROS_DIR)):
        menu = os.path.join(DISTROS_DIR, name, 'menu.json')
        if os.path.isfile(menu):
            found.append((name, menu))
    return found


class TestMenuConfig(unittest.TestCase):

    def test_at_least_one_distro_exists(self):
        self.assertTrue(discover_distros(), "No distros/*/menu.json found at all")

    def test_menus_are_valid_json(self):
        for distro, menu_path in discover_distros():
            with self.subTest(distro=distro):
                with open(menu_path) as f:
                    try:
                        json.load(f)
                    except json.JSONDecodeError as e:
                        self.fail(f"{menu_path} is not valid JSON: {e}")

    def test_menu_schema_shape(self):
        for distro, menu_path in discover_distros():
            with self.subTest(distro=distro):
                with open(menu_path) as f:
                    data = json.load(f)

                self.assertIn('sections', data, f"{distro}: missing 'sections'")
                self.assertIsInstance(data['sections'], list)

                for section in data['sections']:
                    self.assertIn('id', section, f"{distro}: section missing 'id'")
                    self.assertIn('title', section, f"{distro}: section missing 'title'")
                    for item in section.get('items', []):
                        for field in ('key', 'label', 'exec'):
                            self.assertIn(
                                field, item,
                                f"{distro}: item {item!r} missing '{field}'")
                        self.assertIsInstance(
                            item.get('args', []), list,
                            f"{distro}: 'args' must be a list in {item!r}")

    def test_action_codes_are_unique(self):
        """Duplicate <section><key> codes make one entry permanently unreachable.

        render_menu() builds a flat dict keyed on section_id + key, so a collision
        silently shadows the earlier item instead of erroring.
        """
        for distro, menu_path in discover_distros():
            with self.subTest(distro=distro):
                with open(menu_path) as f:
                    data = json.load(f)

                seen = {}
                for section in data['sections']:
                    for item in section.get('items', []):
                        code = f"{section['id']}{item['key']}".lower()
                        self.assertNotIn(
                            code, seen,
                            f"{distro}: duplicate action code '{code}' "
                            f"({seen.get(code)!r} shadowed by {item['label']!r})")
                        seen[code] = item['label']

    def test_every_exec_target_exists(self):
        """The bug class this file exists for: a menu entry pointing at nothing."""
        for distro, menu_path in discover_distros():
            distro_dir = os.path.dirname(menu_path)
            with open(menu_path) as f:
                data = json.load(f)

            for section in data['sections']:
                for item in section.get('items', []):
                    target = os.path.join(distro_dir, item['exec'])
                    with self.subTest(distro=distro, label=item['label']):
                        self.assertTrue(
                            os.path.isfile(target),
                            f"{distro}: menu entry {item['label']!r} "
                            f"points at missing file {item['exec']}")

    def test_every_exec_target_is_executable(self):
        """run_action() chmods on demand, but a non-executable file in git means
        the tool relies on that fallback and fails on read-only checkouts."""
        for distro, menu_path in discover_distros():
            distro_dir = os.path.dirname(menu_path)
            with open(menu_path) as f:
                data = json.load(f)

            for section in data['sections']:
                for item in section.get('items', []):
                    target = os.path.join(distro_dir, item['exec'])
                    if not os.path.isfile(target):
                        continue  # already reported by the previous test
                    with self.subTest(distro=distro, label=item['label']):
                        self.assertTrue(
                            os.access(target, os.X_OK),
                            f"{distro}: {item['exec']} is not executable")

    def test_requires_resolves_to_an_existing_check_script(self):
        """A 'requires' value must map to a real, executable <value>_check.sh --
        otherwise the gate in run_action() fails closed for every user,
        permanently, with no hint why.
        """
        for distro, menu_path in discover_distros():
            distro_dir = os.path.dirname(menu_path)
            with open(menu_path) as f:
                data = json.load(f)

            for section in data['sections']:
                for item in section.get('items', []):
                    requires = item.get('requires')
                    if not requires:
                        continue
                    check_script = os.path.join(distro_dir, f'{requires}_check.sh')
                    with self.subTest(distro=distro, label=item['label']):
                        self.assertTrue(
                            os.path.isfile(check_script),
                            f"{distro}: menu entry {item['label']!r} requires "
                            f"{requires!r} but {requires}_check.sh is missing")
                        self.assertTrue(
                            os.access(check_script, os.X_OK),
                            f"{distro}: {requires}_check.sh is not executable")

    def test_declared_distro_id_matches_directory(self):
        for distro, menu_path in discover_distros():
            with self.subTest(distro=distro):
                with open(menu_path) as f:
                    data = json.load(f)
                if 'distro_id' in data:
                    self.assertEqual(
                        data['distro_id'], distro,
                        f"{menu_path} declares distro_id={data['distro_id']!r} "
                        f"but lives in distros/{distro}/")


if __name__ == '__main__':
    unittest.main()

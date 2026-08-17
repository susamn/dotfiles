#!/usr/bin/env python3
import os
import sys
import json
import time
import subprocess

# --- TUI Styling & Palette (TUI-Creator Standard) ---
CLEAR = '\033[H\033[2J'
BOLD = '\033[1m'
DIM = '\033[2m'
ITALIC = '\033[3m'
UNDERLINE = '\033[4m'

# Semantic Color Roles
PRIMARY = '\033[38;5;39m'   # Cyan Blue
SUCCESS = '\033[38;5;82m'   # Vivid Green
WARNING = '\033[38;5;214m'  # Amber / Orange
DANGER = '\033[38;5;196m'   # Bright Red
INFO = '\033[38;5;75m'      # Soft Blue
ACCENT = '\033[38;5;171m'   # Vibrant Purple / Magenta
NC = '\033[0m'              # Reset

BRAILLE_SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
DRY_RUN = False

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OS_RELEASE_PATH = os.environ.get('OS_RELEASE_PATH', '/etc/os-release')

SECTION_ICONS = {
    "1": "🛡️ ",
    "2": "📦",
    "3": "🔍",
    "4": "⚙️ ",
    "5": "⚡",
    "6": "📊",
    "7": "🔧",
    "8": "🔬",
}


def clear_screen():
    sys.stdout.write(CLEAR)
    sys.stdout.flush()


def spinner_animation(message: str, duration: float = 0.25):
    """Renders a smooth cross-platform Braille loading spinner."""
    if not sys.stdout.isatty():
        return
    end_time = time.time() + duration
    idx = 0
    while time.time() < end_time:
        frame = BRAILLE_SPINNER[idx % len(BRAILLE_SPINNER)]
        sys.stdout.write(f"\r  {PRIMARY}{frame}{NC} {DIM}{message}{NC}   ")
        sys.stdout.flush()
        time.sleep(0.05)
        idx += 1
    sys.stdout.write("\r\033[K")
    sys.stdout.flush()


def print_header(title: str):
    width = 62
    padded_title = f" {title} "
    total_padding = width - len(padded_title) - 2
    left_pad = total_padding // 2
    right_pad = total_padding - left_pad

    border_top = f"╭{'─' * (width - 2)}╮"
    border_mid = f"│{' ' * left_pad}{BOLD}{ACCENT}{padded_title}{NC}{' ' * right_pad}│"
    border_bot = f"╰{'─' * (width - 2)}╯"

    print(f"{PRIMARY}{border_top}{NC}")
    print(f"{PRIMARY}{border_mid}{NC}")
    print(f"{PRIMARY}{border_bot}{NC}")
    print()


def print_section_header(title: str):
    clear_screen()
    print_header(title)


def pause():
    print()
    input(f"{DIM}Press ENTER to continue...{NC}")


def detect_distro():
    if not os.path.exists(OS_RELEASE_PATH):
        raise FileNotFoundError(f"Could not find {OS_RELEASE_PATH} to detect distro.")

    info = {}
    with open(OS_RELEASE_PATH) as f:
        for line in f:
            if '=' in line:
                k, v = line.strip().split('=', 1)
                info[k] = v.strip('"')

    distro_id = info.get('ID')
    if distro_id and os.path.isdir(os.path.join(SCRIPT_DIR, 'distros', distro_id)):
        return distro_id, info.get('NAME', distro_id)

    for like in info.get('ID_LIKE', '').split():
        if os.path.isdir(os.path.join(SCRIPT_DIR, 'distros', like)):
            return like, info.get('NAME', like)

    return None, info.get('NAME', 'Unknown')


def load_menu(distro_id: str):
    menu_path = os.path.join(SCRIPT_DIR, 'distros', distro_id, 'menu.json')
    if not os.path.exists(menu_path):
        raise FileNotFoundError(f"Menu capabilities file not found at {menu_path}")

    with open(menu_path) as f:
        return json.load(f)


def render_menu(menu_data: dict, distro_name: str):
    clear_screen()
    print_header(f"🖥️  {distro_name} System Manager")

    sections = menu_data.get("sections", [])
    action_map = {}

    if DRY_RUN:
        print(f"  {WARNING}[DRY-RUN INSPECTION ACTIVE]{NC}\n")

    for section in sections:
        sec_id = str(section.get("id"))
        sec_title = section.get("title")
        icon = SECTION_ICONS.get(sec_id, "⚙️ ")
        print(f"{SUCCESS}{sec_id}{NC})   {INFO}{icon} {BOLD}{sec_title}{NC}")

        items = section.get("items", [])
        for item in items:
            key = str(item.get("key"))
            label = item.get("label")
            action_code = f"{sec_id}{key}"
            action_map[action_code.lower()] = item
            print(f"      {ACCENT}{key}{NC})  {WARNING}{label}{NC}")
        print()

    print(f"  {DANGER}0{NC})   Exit")
    print(f"  {DIM}d{NC})   Toggle Dry-Run Mode {'(ON)' if DRY_RUN else '(OFF)'}")
    print()
    return action_map


def check_requirement(distro_id: str, requirement: str):
    """Runs distros/<distro_id>/<requirement>_check.sh and reports readiness.

    Fails closed: a missing script, a non-zero exit, or a crash all mean
    "not ready" -- an undeclared or broken prerequisite must never silently
    let a gated action through.
    """
    check_script = os.path.join(SCRIPT_DIR, 'distros', distro_id, f'{requirement}_check.sh')

    if not os.path.exists(check_script):
        return False, f"Requirement checker not found: {check_script}"

    if not os.access(check_script, os.X_OK):
        try:
            os.chmod(check_script, 0o755)
        except Exception:
            pass

    try:
        result = subprocess.run([check_script], capture_output=True, text=True, timeout=15)
    except Exception as e:
        return False, f"Requirement check failed to run: {e}"

    if result.returncode == 0:
        return True, ""
    return False, (result.stdout.strip() or result.stderr.strip())


def run_action(distro_id: str, item: dict):
    label = item.get("label")
    exec_file = item.get("exec")
    args = item.get("args", [])
    requires = item.get("requires")

    print_section_header(label)

    if requires:
        ready, detail = check_requirement(distro_id, requires)
        if not ready:
            print(f"{DANGER}✗ Locked:{NC} {BOLD}{label}{NC} requires '{requires}' readiness.")
            if detail:
                print(f"{DIM}{detail}{NC}")
            print()
            print(f"{WARNING}Run the readiness check / setup action in that section first.{NC}")
            pause()
            return

    script_path = os.path.join(SCRIPT_DIR, 'distros', distro_id, exec_file)
    if not os.path.exists(script_path):
        print(f"{DANGER}✗ Executable script not found: {script_path}{NC}")
        pause()
        return

    if not os.access(script_path, os.X_OK):
        try:
            os.chmod(script_path, 0o755)
        except Exception as e:
            print(f"{WARNING}⚠ Warning: Could not set executable permissions: {e}{NC}")

    print(f"{PRIMARY}──────────────────────────────────────────────────────────────{NC}")
    print(f"{WARNING}Target Task:{NC} {BOLD}{label}{NC}")
    print(f"{DIM}Script Path:{NC} {script_path}")
    if args:
        print(f"{DIM}Arguments:{NC}   {' '.join(args)}")
    print(f"{PRIMARY}──────────────────────────────────────────────────────────────{NC}")
    print()

    if DRY_RUN:
        print(f"{WARNING}ℹ DRY-RUN MODE: Command inspection only. No changes executed.{NC}")
        print(f"  {PRIMARY}Command:{NC} {script_path} {' '.join(args)}")
        pause()
        return

    spinner_animation(f"Launching {label}...")

    try:
        result = subprocess.run([script_path] + args, cwd=os.path.join(SCRIPT_DIR, 'distros', distro_id))
        print()
        if result.returncode == 0:
            print(f"{SUCCESS}✓ Task completed successfully.{NC}")
        else:
            print(f"{DANGER}✗ Command exited with code: {result.returncode}{NC}")
    except Exception as e:
        print(f"{DANGER}✗ Execution failed: {e}{NC}")

    pause()


def main():
    global DRY_RUN
    try:
        distro_id, distro_name = detect_distro()
        if not distro_id:
            print(f"{DANGER}Error: Distro '{distro_name}' is not supported yet.{NC}")
            sys.exit(1)

        menu_data = load_menu(distro_id)

        while True:
            action_map = render_menu(menu_data, distro_name)
            choice = input(f"{PRIMARY}Select option (e.g. 1a, 21, d, 0):{NC} ").strip().lower()

            if choice == '0':
                print(f"\n{SUCCESS}Goodbye!{NC}\n")
                break
            elif choice == 'd':
                DRY_RUN = not DRY_RUN
                status_str = "ENABLED" if DRY_RUN else "DISABLED"
                spinner_animation(f"Dry-run mode {status_str}")
            elif choice in action_map:
                run_action(distro_id, action_map[choice])
            else:
                print(f"{DANGER}Invalid option. Please try again.{NC}")
                time.sleep(0.8)

    except KeyboardInterrupt:
        print(f"\n{SUCCESS}Goodbye!{NC}\n")
        sys.exit(0)
    except Exception as e:
        print(f"{DANGER}Error starting System Manager: {e}{NC}")
        sys.exit(1)


if __name__ == '__main__':
    main()

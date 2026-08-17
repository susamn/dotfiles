#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess

# --- Colors ---
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
NC = '\033[0m'

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Units live in $SERVICES_PATH, not inside this tool. The tool installs and
# manages them; the definitions are configuration and belong with the rest of it.
# Falls back to the workspace-relative path so the installer still works when the
# environment variable is not exported (package hooks run with almost no env).
SERVICES_SRC_DIR = os.environ.get('SERVICES_PATH') or os.path.abspath(
    os.path.join(SCRIPT_DIR, '..', '..', 'services'))

def check_root():
    if os.geteuid() != 0:
        print(f"{YELLOW}This installation script requires root privileges to install systemd services and pacman hooks.{NC}")
        print(f"Re-running with sudo...")
        try:
            # Re-execute the script with sudo
            os.execvp('sudo', ['sudo', sys.executable] + sys.argv)
        except Exception as e:
            print(f"{RED}Failed to elevate privileges: {e}{NC}")
            sys.exit(1)

def detect_distro():
    if not os.path.exists('/etc/os-release'):
        print(f"{RED}Error: /etc/os-release not found. Cannot determine distro.{NC}")
        sys.exit(1)
        
    info = {}
    with open('/etc/os-release') as f:
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

def install_systemd_services():
    real_user = os.environ.get('SUDO_USER', os.environ.get('USER', 'root'))
    dest_dir = '/etc/systemd/system'

    if not os.path.isdir(SERVICES_SRC_DIR):
        print(f"{YELLOW}ℹ No 'services' directory found. Skipping systemd service installation.{NC}")
        return

    service_files = [f for f in os.listdir(SERVICES_SRC_DIR)
                     if f.endswith(('.service', '.timer', '.target'))]

    if not service_files:
        print(f"{YELLOW}ℹ No systemd services or timers found in {SERVICES_SRC_DIR}.{NC}")
        return

    print(f"{BLUE}⚙ Installing custom systemd services & timers...{NC}")
    for file in service_files:
        src_path = os.path.join(SERVICES_SRC_DIR, file)
        dest_path = os.path.join(dest_dir, file)
        
        try:
            if file in ['rclone-sync@.service', 'rclone-mount@.service']:
                with open(src_path, 'r') as f:
                    content = f.read()
                content = content.replace('@USER@', real_user)
                with open(dest_path, 'w') as f:
                    f.write(content)
            else:
                shutil.copy2(src_path, dest_path)
            
            # Ensure permissions are correct (644 for systemd services)
            os.chmod(dest_path, 0o644)
            print(f"  {GREEN}✓ Installed: {file} → {dest_path}{NC}")
        except Exception as e:
            print(f"  {RED}✗ Failed to install {file}: {e}{NC}")

            
    print(f"  {BLUE}Reloading systemd daemon...{NC}")
    try:
        subprocess.run(['systemctl', 'daemon-reload'], check=True)
        print(f"  {GREEN}✓ Systemd daemon reloaded successfully.{NC}")
    except Exception as e:
        print(f"  {RED}✗ Failed to reload systemd: {e}{NC}")


def run_distro_installer(distro_id):
    distro_install_script = os.path.join(SCRIPT_DIR, 'distros', distro_id, 'install_hooks.sh')
    
    if not os.path.exists(distro_install_script):
        print(f"{YELLOW}ℹ No hook installer script found for {distro_id} at {distro_install_script}.{NC}")
        return
        
    print(f"{BLUE}⚙ Executing distro-specific hooks installer ({distro_id})...{NC}")
    
    # Ensure it's executable
    if not os.access(distro_install_script, os.X_OK):
        os.chmod(distro_install_script, 0o755)
        
    try:
        result = subprocess.run([distro_install_script], cwd=os.path.dirname(distro_install_script))
        if result.returncode == 0:
            print(f"  {GREEN}✓ Distro-specific installer finished successfully.{NC}")
        else:
            print(f"  {RED}✗ Distro-specific installer failed with code: {result.returncode}{NC}")
    except Exception as e:
        print(f"  {RED}✗ Failed to execute distro installer: {e}{NC}")

def install_rclone_sync_helper():
    
    # 1. Copy sync and mount runner scripts
    runners = [
        ('rclone-sync.sh', '/usr/local/bin/rclone-sync.sh'),
        ('rclone-mount.sh', '/usr/local/bin/rclone-mount.sh'),
        ('cleanup-backups.sh', '/usr/local/bin/sys-manager-cleanup-backups.sh'),
    ]

    print(f"{BLUE}⚙ Installing Rclone Sync and Mount helper utilities...{NC}")
    for src_file, dest_path in runners:
        src_path = os.path.join(SERVICES_SRC_DIR, src_file)
        if os.path.exists(src_path):
            try:
                shutil.copy2(src_path, dest_path)
                os.chmod(dest_path, 0o755)
                print(f"  {GREEN}✓ Installed: {src_file} → {dest_path}{NC}")
            except Exception as e:
                print(f"  {RED}✗ Failed to install {src_file}: {e}{NC}")
        else:
            print(f"  {YELLOW}⚠ Runner script not found at {src_path}. Skipping.{NC}")

    # 2. Scan for user sync profiles to register their timers/services
    real_user = os.environ.get('SUDO_USER', os.environ.get('USER', 'root'))
    user_home = os.path.expanduser(f"~{real_user}")
    profile_dir = os.path.join(user_home, '.config/rclone-sync-profiles')

    print(f"{BLUE}⚙ Scanning for user sync/mount profiles...{NC}")
    import glob
    profile_paths = []
    profile_paths.extend(glob.glob(os.path.join(profile_dir, '*.conf')))
    if real_user != 'root':
        profile_paths.extend(glob.glob('/root/.config/rclone-sync-profiles/*.conf'))
    
    if profile_paths:
        print(f"  Found {len(profile_paths)} profiles. Validating and registering systemd services...")
        for src_path in profile_paths:
            p_file = os.path.basename(src_path)
            profile_name = os.path.splitext(p_file)[0]
            
            # Read profile configuration
            config_vars = {}
            try:
                with open(src_path, 'r') as f:
                    for line in f:
                        if '=' in line and not line.strip().startswith('#'):
                            k, v = line.strip().split('=', 1)
                            config_vars[k.strip()] = v.strip('"\'')
            except Exception as e:
                print(f"  {RED}✗ Failed to read {src_path}: {e}{NC}")
                continue
                
            user = config_vars.get('USER', 'root')
            remote = config_vars.get('REMOTE')
            remote_path = config_vars.get('REMOTE_PATH', '')
            local_path = config_vars.get('LOCAL_PATH')
            sync_type = config_vars.get('SYNC_TYPE', 'one')
            schedule = config_vars.get('SCHEDULE', 'daily')
            
            if not all([remote, local_path]):
                print(f"  {RED}✗ Profile '{profile_name}' is missing required fields (REMOTE, LOCAL_PATH){NC}")
                continue
                
            # Resolve user's rclone config
            user_home = os.path.expanduser(f"~{user}")
            rclone_config = os.path.join(user_home, '.config/rclone/rclone.conf')
            
            # Check 1: Backend Availability
            backend_ok = False
            try:
                remotes_res = subprocess.run(['sudo', '-u', user, '-H', 'rclone', 'listremotes', '--config', rclone_config], capture_output=True, text=True, timeout=5)
                if remotes_res.returncode == 0:
                    remotes = [r.strip(':') for r in remotes_res.stdout.splitlines()]
                    if remote in remotes:
                        backend_ok = True
            except Exception:
                pass
                
            # Check 2: Local Path Availability
            local_ok = True
            if not os.path.isdir(local_path):
                try:
                    subprocess.run(['sudo', '-u', user, '-H', 'mkdir', '-p', local_path], capture_output=True)
                    local_ok = os.path.isdir(local_path)
                except Exception:
                    local_ok = False
            
            # Check 3: Remote Path Availability
            remote_ok = False
            if backend_ok:
                try:
                    remote_res = subprocess.run(['sudo', '-u', user, '-H', 'rclone', 'lsf', '--max-depth', '1', f'{remote}:{remote_path}', '--config', rclone_config], capture_output=True, timeout=10)
                    if remote_res.returncode == 0:
                        remote_ok = True
                except Exception:
                    pass
            
            # Activate only if all checks pass
            if backend_ok and local_ok and remote_ok:
                try:
                    # Pin each instance to the user that owns its profile. The
                    # template's @USER@ was substituted once with the installing
                    # user, so without this every profile runs as that user.
                    unit = (f'rclone-mount@{profile_name}.service' if sync_type == 'mount'
                            else f'rclone-sync@{profile_name}.service')
                    user_override_dir = f'/etc/systemd/system/{unit}.d'
                    os.makedirs(user_override_dir, exist_ok=True)
                    with open(os.path.join(user_override_dir, 'user.conf'), 'w') as f:
                        f.write(f"[Service]\nUser={user}\n")

                    if sync_type == 'mount':
                        # Enable mount service directly (runs continuously, no timer!)
                        subprocess.run(['systemctl', 'enable', f'rclone-mount@{profile_name}.service'], check=True)
                        print(f"  {GREEN}✓ Profile '{profile_name}' (Mount) activated and enabled rclone-mount@{profile_name}.service{NC}")
                    else:
                        # Write timer override
                        override_dir = f"/etc/systemd/system/rclone-sync@{profile_name}.timer.d"
                        if not os.path.exists(override_dir):
                            os.makedirs(override_dir)
                        override_file = os.path.join(override_dir, 'override.conf')
                        with open(override_file, 'w') as f:
                            f.write(f"[Timer]\nOnCalendar=\nOnCalendar={schedule}\n")
                        
                        # Enable timer
                        subprocess.run(['systemctl', 'enable', f'rclone-sync@{profile_name}.timer'], check=True)
                        print(f"  {GREEN}✓ Profile '{profile_name}' (Sync) activated and enabled rclone-sync@{profile_name}.timer ({schedule}){NC}")
                except Exception as e:
                    print(f"  {RED}✗ Failed to setup systemd units for {profile_name}: {e}{NC}")
            else:
                # Deliberately does NOT disable or stop anything.
                #
                # These checks probe a *network* backend with a short timeout. A
                # transient failure previously ran `systemctl disable --now`,
                # which stopped healthy mounts and removed them from boot -- so a
                # momentary blip during an unrelated re-install silently tore down
                # working sync. An installer may add and report; it may not
                # dismantle state it did not create in this run.
                reasons = []
                if not backend_ok: reasons.append("Backend missing")
                if not local_ok: reasons.append("Local directory missing/cannot create")
                if not remote_ok: reasons.append("Remote path inaccessible")

                unit = (f'rclone-mount@{profile_name}.service' if sync_type == 'mount'
                        else f'rclone-sync@{profile_name}.timer')

                currently_active = False
                try:
                    probe = subprocess.run(['systemctl', 'is-active', unit],
                                           capture_output=True, text=True, timeout=5)
                    currently_active = probe.stdout.strip() == 'active'
                except Exception:
                    pass

                print(f"  {YELLOW}⚠ Profile '{profile_name}' not activated "
                      f"(Reasons: {', '.join(reasons)}).{NC}")
                if currently_active:
                    print(f"    {BLUE}ℹ {unit} is already running and was left "
                          f"untouched. These checks are network-dependent, so this "
                          f"is most likely a transient failure.{NC}")
                else:
                    print(f"    Fix the above, then enable manually:")
                    print(f"      sudo systemctl enable --now {unit}")



def main():
    print(f"{CYAN}╔════════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║     sys-manager Global Installation Setup      ║{NC}")
    print(f"{CYAN}╚════════════════════════════════════════════════╝{NC}")
    print()
    
    check_root()
    
    distro_id, distro_name = detect_distro()
    if not distro_id:
        print(f"{RED}Error: Distro '{distro_name}' is not supported yet.{NC}")
        print(f"Aborting installation.")
        sys.exit(1)
        
    print(f"{BLUE}Detected Distribution:{NC} {GREEN}{distro_name} ({distro_id}){NC}")
    print()

    # Each phase is independent: a failure in one must not prevent the others from
    # running, otherwise a single bug silently skips hook registration entirely.
    phases = [
        ("systemd services", install_systemd_services, ()),
        ("rclone helpers", install_rclone_sync_helper, ()),
        ("distro hooks", run_distro_installer, (distro_id,)),
    ]

    failed = []
    for name, func, args in phases:
        try:
            func(*args)
        except Exception as e:
            failed.append(name)
            print(f"  {RED}✗ Phase '{name}' failed: {type(e).__name__}: {e}{NC}")
        print()

    if failed:
        print(f"{RED}✗ Installation completed with errors in: {', '.join(failed)}{NC}")
        print(f"Re-run after fixing, or install the failed phase manually.")
        sys.exit(1)

    print(f"{GREEN}✓ Global Installation Sequence Completed.{NC}")
    print(f"You can now run system manager with: {os.path.join(SCRIPT_DIR, 'linux-system-manager.sh')}")

if __name__ == '__main__':
    main()


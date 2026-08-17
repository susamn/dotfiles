#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import re
import time
import shutil
import socket
import struct
import datetime

# --- Colors ---
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
MAGENTA = '\033[0;35m'
NC = '\033[0m'

# --- Paths setup ---
def get_user_state_dir():
    real_user = os.environ.get('SUDO_USER', os.environ.get('USER', 'root'))
    if real_user == 'root':
        home = os.path.expanduser("~root")
    else:
        home = os.path.expanduser(f"~{real_user}")
    return os.path.join(home, ".local", "state", "linux-system-manager")

STATE_DIR = get_user_state_dir()
SNAPSHOTS_DIR = os.path.join(STATE_DIR, "snapshots")
AUDIT_LOG_FILE = os.path.join(STATE_DIR, "audit.log")

def setup_paths():
    os.makedirs(SNAPSHOTS_DIR, exist_ok=True)

def log_audit(reasoning, command, success, result_summary, confidence_score=None):
    setup_paths()
    entry = {
        "timestamp": datetime.datetime.now().isoformat(),
        "reasoning": reasoning,
        "command": command,
        "success": success,
        "result_summary": result_summary
    }
    if confidence_score is not None:
        entry["confidence_score"] = confidence_score
    try:
        with open(AUDIT_LOG_FILE, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass

def check_tool(cmd):
    return shutil.which(cmd) is not None

def clear_screen():
    os.system('clear')

def print_header(title):
    print(f"{CYAN}╔══════════════════════════════════════════════════════════════╗{NC}")
    # Center the title in the header block
    padding = (60 - len(title)) // 2
    extra = (60 - len(title)) % 2
    print(f"{CYAN}║{' ' * padding}{MAGENTA}{title}{CYAN}{' ' * (padding + extra)}║{NC}")
    print(f"{CYAN}╚══════════════════════════════════════════════════════════════╝{NC}")
    print()

def pause():
    print()
    input("Press ENTER to return to menu...")

# --- Escalation Pattern ---
def escalate_privileges():
    if os.geteuid() != 0:
        print("This toolset requires root privileges to audit sockets, process maps, and firewall rules.")
        print("Re-running with sudo...")
        try:
            os.execvp("sudo", ["sudo", sys.executable] + sys.argv)
        except Exception as e:
            print(f"Failed to elevate privileges: {e}")
            sys.exit(1)

# --- Table Alignment Helpers (ANSI Safe) ---
def ansi_len(s):
    ansi_escape = re.compile(r'\x1b\[[0-9;]*[mG]')
    return len(ansi_escape.sub('', str(s)))

def print_table(headers, rows):
    if not rows:
        print("No data available.")
        return
    # Calculate column widths
    widths = [len(h) for h in headers]
    for row in rows:
        for idx, val in enumerate(row):
            widths[idx] = max(widths[idx], ansi_len(val))
            
    # Print headers
    header_str = "  ".join(f"{h:<{widths[idx]}}" for idx, h in enumerate(headers))
    print(f"{CYAN}{header_str}{NC}")
    print(f"{BLUE}{'-' * (sum(widths) + 2 * (len(headers) - 1))}{NC}")
    
    # Print rows
    for row in rows:
        row_parts = []
        for idx, val in enumerate(row):
            val_str = str(val)
            padding_len = widths[idx] - ansi_len(val_str)
            row_parts.append(val_str + " " * padding_len)
        print("  ".join(row_parts))

# --- Parsers & Data Gatherers ---
def parse_ip_addr_text(text):
    interfaces = []
    current_iface = None
    
    iface_re = re.compile(r'^\d+:\s+([^:]+):\s+<([^>]+)>\s+mtu\s+(\d+).*?state\s+(\w+)')
    inet_re = re.compile(r'^\s+inet\s+([^\s]+)\s+brd\s+([^\s]+)?')
    inet6_re = re.compile(r'^\s+inet6\s+([^\s]+)')
    
    for line in text.splitlines():
        iface_match = iface_re.match(line)
        if iface_match:
            if current_iface:
                interfaces.append(current_iface)
            name = iface_match.group(1)
            flags = iface_match.group(2).split(',')
            mtu = int(iface_match.group(3))
            state = iface_match.group(4)
            current_iface = {
                "ifname": name,
                "flags": flags,
                "mtu": mtu,
                "operstate": state,
                "addr_info": []
            }
        elif current_iface:
            inet_match = inet_re.match(line)
            if inet_match:
                ip_mask = inet_match.group(1)
                ip, _, mask = ip_mask.partition('/')
                current_iface["addr_info"].append({
                    "family": "inet",
                    "local": ip,
                    "prefixlen": int(mask) if mask else 32
                })
            else:
                inet6_match = inet6_re.match(line)
                if inet6_match:
                    ip_mask = inet6_match.group(1)
                    ip, _, mask = ip_mask.partition('/')
                    current_iface["addr_info"].append({
                        "family": "inet6",
                        "local": ip,
                        "prefixlen": int(mask) if mask else 128
                    })
                    
    if current_iface:
        interfaces.append(current_iface)
    return interfaces

def parse_ip_route_text(text):
    routes = []
    for line in text.splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        route = {}
        if parts[0] == "default":
            route["dst"] = "default"
        else:
            route["dst"] = parts[0]
            
        i = 1
        while i < len(parts) - 1:
            key = parts[i]
            val = parts[i+1]
            if key == "via":
                route["gateway"] = val
            elif key == "dev":
                route["dev"] = val
            elif key == "metric":
                try:
                    route["metric"] = int(val)
                except ValueError:
                    route["metric"] = val
            elif key == "src":
                route["prefsrc"] = val
            i += 2
        routes.append(route)
    return routes

def get_interfaces_and_routes_json():
    interfaces = []
    routes = []
    try:
        addr_res = subprocess.run(["ip", "-j", "addr", "show"], capture_output=True, text=True, timeout=3)
        if addr_res.returncode == 0:
            interfaces = json.loads(addr_res.stdout)
    except Exception:
        pass
    try:
        route_res = subprocess.run(["ip", "-j", "route", "show"], capture_output=True, text=True, timeout=3)
        if route_res.returncode == 0:
            routes = json.loads(route_res.stdout)
    except Exception:
        pass
    return interfaces, routes

def get_normalized_network_state():
    interfaces, routes = get_interfaces_and_routes_json()
    if not interfaces:
        try:
            addr_res = subprocess.run(["ip", "addr", "show"], capture_output=True, text=True, timeout=3)
            if addr_res.returncode == 0:
                interfaces = parse_ip_addr_text(addr_res.stdout)
        except Exception:
            pass
    if not routes:
        try:
            route_res = subprocess.run(["ip", "route", "show"], capture_output=True, text=True, timeout=3)
            if route_res.returncode == 0:
                routes = parse_ip_route_text(route_res.stdout)
        except Exception:
            pass
    return {"interfaces": interfaces, "routes": routes}

def parse_ss_output(stdout):
    sockets = []
    lines = stdout.splitlines()
    if not lines:
        return sockets
    for line in lines[1:]:
        parts = line.strip().split()
        if len(parts) < 6:
            continue
        netid = parts[0]
        state = parts[1]
        recv_q = parts[2]
        send_q = parts[3]
        local = parts[4]
        peer = parts[5]
        process_info = " ".join(parts[6:]) if len(parts) > 6 else ""
        
        local_ip, _, local_port = local.rpartition(":")
        peer_ip, _, peer_port = peer.rpartition(":")
        
        local_ip = local_ip.strip("[]")
        peer_ip = peer_ip.strip("[]")
        
        processes = []
        if process_info:
            matches = re.findall(r'"([^"]+)",pid=(\d+),fd=(\d+)', process_info)
            for m in matches:
                processes.append({
                    "name": m[0],
                    "pid": int(m[1]),
                    "fd": int(m[2])
                })
        sockets.append({
            "proto": netid,
            "state": state,
            "recv_q": recv_q,
            "send_q": send_q,
            "local_ip": local_ip,
            "local_port": local_port,
            "peer_ip": peer_ip,
            "peer_port": peer_port,
            "processes": processes
        })
    return sockets

def ip_to_int(ip):
    return struct.unpack("!I", socket.inet_aton(ip))[0]

def int_to_ip(val):
    return socket.inet_ntoa(struct.pack("!I", val))

def calculate_subnet(ip, prefixlen):
    try:
        ip_val = ip_to_int(ip)
        mask = (0xFFFFFFFF << (32 - prefixlen)) & 0xFFFFFFFF
        subnet_val = ip_val & mask
        return f"{int_to_ip(subnet_val)}/{prefixlen}"
    except Exception:
        return None

def parse_nmap_output(stdout):
    hosts = []
    current_host = None
    report_re = re.compile(r'Nmap scan report for (?:([^\s]+)\s+\(([^)]+)\)|([^\s]+))')
    for line in stdout.splitlines():
        match = report_re.match(line)
        if match:
            hostname = match.group(1) or ""
            ip = match.group(2) or match.group(3)
            current_host = {"ip": ip, "hostname": hostname, "status": "down"}
        elif "Host is up" in line and current_host:
            current_host["status"] = "up"
            hosts.append(current_host)
            current_host = None
    return hosts

# --- Menu Action Handlers ---

def show_interfaces_and_routes():
    if not check_tool("ip"):
        print(f"{RED}Error: 'ip' utility is required but not installed.{NC}")
        return
    state = get_normalized_network_state()
    
    print_header("Network Interfaces")
    iface_headers = ["Interface", "Status", "MTU", "IP Addresses"]
    iface_rows = []
    for iface in state.get("interfaces", []):
        name = iface.get("ifname", "unknown")
        status = iface.get("operstate", "unknown")
        mtu = iface.get("mtu", "-")
        ips = [addr.get("local") for addr in iface.get("addr_info", []) if addr.get("local")]
        ip_str = ", ".join(ips) if ips else "none"
        
        status_str = f"{GREEN}UP{NC}" if status.upper() == "UP" else f"{RED}{status.upper()}{NC}"
        iface_rows.append([name, status_str, mtu, ip_str])
    print_table(iface_headers, iface_rows)
    
    print("\n")
    print_header("Routing Table")
    route_headers = ["Destination", "Gateway", "Interface", "Metric"]
    route_rows = []
    for route in state.get("routes", []):
        dst = route.get("dst", "unknown")
        gw = route.get("gateway", "*")
        dev = route.get("dev", "*")
        metric = route.get("metric", "-")
        route_rows.append([dst, gw, dev, metric])
    print_table(route_headers, route_rows)
    log_audit("Viewed interfaces and routes", "ip addr / ip route", True, f"Enumerated {len(iface_rows)} interfaces, {len(route_rows)} routes")

def show_sockets():
    if not check_tool("ss"):
        print(f"{RED}Error: 'ss' utility is required but not installed.{NC}")
        return
    try:
        res = subprocess.run(["ss", "-tupan"], capture_output=True, text=True, timeout=5)
        sockets = parse_ss_output(res.stdout)
    except Exception as e:
        print(f"{RED}Failed to run ss command: {e}{NC}")
        return
        
    print_header("Active & Listening Sockets")
    headers = ["Proto", "State", "Local Address", "Peer Address", "Process (PID)"]
    rows = []
    for sock in sockets:
        proto = sock["proto"].upper()
        state = sock["state"]
        local = f"{sock['local_ip']}:{sock['local_port']}"
        peer = f"{sock['peer_ip']}:{sock['peer_port']}"
        
        proc_list = []
        for proc in sock["processes"]:
            proc_list.append(f"{proc['name']} ({proc['pid']})")
        proc_str = ", ".join(proc_list) if proc_list else "-"
        
        if state.upper() == "LISTEN":
            state_str = f"{GREEN}{state}{NC}"
        elif state.upper() == "ESTAB":
            state_str = f"{CYAN}{state}{NC}"
        else:
            state_str = state
        rows.append([proto, state_str, local, peer, proc_str])
    print_table(headers, rows)
    log_audit("Viewed active sockets", "ss -tupan", True, f"Listed {len(rows)} sockets")

def show_firewall():
    raw_output = ""
    tool_name = ""
    
    if check_tool("nft"):
        tool_name = "nft"
        print_header("Firewall Ruleset (nftables)")
        try:
            res = subprocess.run(["nft", "list", "ruleset"], capture_output=True, text=True, timeout=10)
            if res.returncode == 0:
                raw_output = res.stdout
            else:
                print(f"{RED}Error running nft list ruleset: {res.stderr}{NC}")
        except Exception as e:
            print(f"{RED}Error: {e}{NC}")
    elif check_tool("iptables"):
        tool_name = "iptables"
        print_header("Firewall Ruleset (iptables)")
        try:
            res = subprocess.run(["iptables", "-S"], capture_output=True, text=True, timeout=10)
            if res.returncode == 0:
                raw_output = res.stdout
                if check_tool("ip6tables"):
                    res6 = subprocess.run(["ip6tables", "-S"], capture_output=True, text=True, timeout=10)
                    if res6.returncode == 0:
                        raw_output += "\n# IPv6 Ruleset:\n" + res6.stdout
            else:
                print(f"{RED}Error running iptables -S: {res.stderr}{NC}")
        except Exception as e:
            print(f"{RED}Error: {e}{NC}")
    else:
        print(f"{RED}No firewall management tool (nft/iptables) found.{NC}")
        return

    if raw_output:
        if check_tool("less"):
            try:
                # -R keeps colors, -F exits if fits on screen, -X keeps content visible on exit
                less_proc = subprocess.Popen(["less", "-R", "-F", "-X"], stdin=subprocess.PIPE, text=True)
                less_proc.communicate(input=raw_output)
            except Exception as e:
                print(raw_output)
        else:
            print(raw_output)
        log_audit("Viewed firewall ruleset", f"{tool_name} list ruleset", True, f"Captured ruleset ({len(raw_output.splitlines())} lines)")


def read_proc_net_dev():
    ifaces = {}
    try:
        with open("/proc/net/dev", "r") as f:
            lines = f.readlines()
        for line in lines[2:]:
            if ":" not in line:
                continue
            name, data = line.split(":", 1)
            name = name.strip()
            parts = data.strip().split()
            if len(parts) >= 16:
                ifaces[name] = {
                    "rx_bytes": int(parts[0]),
                    "rx_packets": int(parts[1]),
                    "tx_bytes": int(parts[8]),
                    "tx_packets": int(parts[9])
                }
    except Exception:
        pass
    return ifaces

def show_interface_telemetry():
    t1 = read_proc_net_dev()
    try:
        while True:
            time.sleep(1.0)
            t2 = read_proc_net_dev()
            
            clear_screen()
            print_header("Real-Time Interface Telemetry (Refreshing - Ctrl+C to exit)")
            
            headers = ["Interface", "RX Speed", "TX Speed", "Total RX", "Total TX"]
            rows = []
            for name in t2:
                if name in t1:
                    rx_diff = t2[name]["rx_bytes"] - t1[name]["rx_bytes"]
                    tx_diff = t2[name]["tx_bytes"] - t1[name]["tx_bytes"]
                    
                    rx_speed = f"{rx_diff / 1024.0:.2f} KB/s"
                    tx_speed = f"{tx_diff / 1024.0:.2f} KB/s"
                    total_rx = f"{t2[name]['rx_bytes'] / (1024.0 * 1024.0):.2f} MB"
                    total_tx = f"{t2[name]['tx_bytes'] / (1024.0 * 1024.0):.2f} MB"
                    rows.append([name, rx_speed, tx_speed, total_rx, total_tx])
            print_table(headers, rows)
            t1 = t2
    except KeyboardInterrupt:
        print("\nStopping telemetry...")
    log_audit("Viewed real-time interface telemetry (continuous)", "/proc/net/dev", True, "Monitored interface telemetry continuously")


def get_process_io():
    proc_io = {}
    for pid_dir in os.listdir("/proc"):
        if not pid_dir.isdigit():
            continue
        pid = int(pid_dir)
        io_file = os.path.join("/proc", pid_dir, "io")
        comm_file = os.path.join("/proc", pid_dir, "comm")
        if os.path.exists(io_file) and os.path.exists(comm_file):
            try:
                with open(comm_file, "r") as f:
                    comm = f.read().strip()
                read_bytes = 0
                write_bytes = 0
                with open(io_file, "r") as f:
                    for line in f:
                        if line.startswith("read_bytes:"):
                            read_bytes = int(line.split()[1])
                        elif line.startswith("write_bytes:"):
                            write_bytes = int(line.split()[1])
                proc_io[pid] = {
                    "comm": comm,
                    "read_bytes": read_bytes,
                    "write_bytes": write_bytes
                }
            except Exception:
                pass
    return proc_io

def show_proc_io_fallback():
    t1 = get_process_io()
    try:
        while True:
            time.sleep(1.0)
            t2 = get_process_io()
            
            clear_screen()
            print_header("Process I/O Telemetry Fallback (Refreshing - Ctrl+C to exit)")
            
            rows = []
            for pid in t2:
                if pid in t1:
                    r_diff = t2[pid]["read_bytes"] - t1[pid]["read_bytes"]
                    w_diff = t2[pid]["write_bytes"] - t1[pid]["write_bytes"]
                    if r_diff > 0 or w_diff > 0:
                        rows.append([
                            pid,
                            t2[pid]["comm"],
                            f"{r_diff / 1024.0:.2f} KB/s",
                            f"{w_diff / 1024.0:.2f} KB/s"
                        ])
                        
            def sort_key(row):
                r_val = float(row[2].split()[0])
                w_val = float(row[3].split()[0])
                return r_val + w_val
                
            rows.sort(key=sort_key, reverse=True)
            headers = ["PID", "Process Name", "Read Rate", "Write Rate"]
            print_table(headers, rows[:15])
            t1 = t2
    except KeyboardInterrupt:
        print("\nStopping telemetry...")
    log_audit("Viewed process I/O telemetry fallback (continuous)", "/proc/[pid]/io", True, "Monitored process I/O telemetry continuously")

def show_process_telemetry():
    if check_tool("tcptop"):
        print_header("BCC tcptop Telemetry (Ctrl+C to exit)")
        try:
            subprocess.run(["tcptop", "1"])
            log_audit("Ran tcptop process telemetry (continuous)", "tcptop 1", True, "Successfully executed tcptop")
        except KeyboardInterrupt:
            print("\nStopping telemetry...")
        except Exception as e:
            print(f"{RED}Error running tcptop: {e}{NC}")
    else:
        print(f"{YELLOW}⚠ tcptop (BCC) is not installed.{NC}")
        print("BCC (BPF Compiler Collection) requires kernel headers and LLVM/Clang.")
        print("To install on Arch:")
        print("  sudo pacman -S bcc-tools python-bcc")
        print("To install on Debian:")
        print("  sudo apt install bpfcc-tools python3-bpfcc")
        print("\nWould you like to run the built-in process I/O fallback instead?")
        choice = input("Run fallback? (y/N): ").strip().lower()
        if choice == 'y':
            show_proc_io_fallback()


def get_arp_neighbors():
    neighbors = []
    try:
        res = subprocess.run(["ip", "neigh", "show"], capture_output=True, text=True, timeout=3)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                parts = line.strip().split()
                if len(parts) >= 4:
                    ip = parts[0]
                    mac = "-"
                    dev = "-"
                    state = parts[-1]
                    if "lladdr" in parts:
                        idx = parts.index("lladdr")
                        if idx + 1 < len(parts):
                            mac = parts[idx + 1]
                    if "dev" in parts:
                        idx = parts.index("dev")
                        if idx + 1 < len(parts):
                            dev = parts[idx + 1]
                    if state.upper() not in ["FAILED", "INCOMPLETE"]:
                        neighbors.append([ip, mac, dev, state])
    except Exception:
        pass
    return neighbors

def discover_hosts():
    print_header("Host Discovery (Instant ARP Cache)")
    
    neighbors = get_arp_neighbors()
    if neighbors:
        headers = ["IP Address", "MAC Address", "Interface", "State"]
        print_table(headers, neighbors)
    else:
        print(f"{YELLOW}No active neighbors found in kernel ARP cache.{NC}")
        
    print()
    if not check_tool("nmap"):
        print(f"{YELLOW}ℹ Active ping sweep (Nmap) is disabled because 'nmap' is not installed.{NC}")
        return
        
    choice = input("Would you like to run an active ping sweep scan (Nmap) on the subnet? (y/N): ").strip().lower()
    if choice != 'y':
        return
        
    state = get_normalized_network_state()
    dev = None
    for route in state.get("routes", []):
        if route.get("dst") == "default" or route.get("dst") == "0.0.0.0/0":
            dev = route.get("dev")
            break
    if not dev and state.get("routes"):
        dev = state["routes"][0].get("dev")
    if not dev:
        print(f"{RED}Could not identify network interface for scan.{NC}")
        return
        
    ip = None
    prefix = None
    for iface in state.get("interfaces", []):
        if iface.get("ifname") == dev:
            for addr in iface.get("addr_info", []):
                if addr.get("family") == "inet":
                    ip = addr.get("local")
                    prefix = addr.get("prefixlen")
                    break
            if ip:
                break
                
    if not ip or not prefix:
        print(f"{RED}Could not find active IPv4 assignment on interface {dev}.{NC}")
        return
        
    scan_subnet = calculate_subnet(ip, prefix)
    if prefix < 24:
        print(f"\n{YELLOW}⚠ Warning: The detected subnet {scan_subnet} is very large (/{prefix}).{NC}")
        print(f"Scanning {2**(32-prefix)} addresses will take a long time and likely time out.")
        
        ip_parts = ip.split('.')
        local_24 = f"{ip_parts[0]}.{ip_parts[1]}.{ip_parts[2]}.0/24"
        narrow_choice = input(f"Would you like to narrow the scan to the local /24 segment ({local_24})? (Y/n): ").strip().lower()
        if narrow_choice != 'n':
            scan_subnet = local_24
            print(f"Subnet narrowed to {scan_subnet}")
            
    print(f"\nRunning optimized active sweep on {scan_subnet}...")
    try:
        res = subprocess.run([
            "nmap", "-sn", 
            "--min-parallelism", "100", 
            "--max-rtt-timeout", "100ms", 
            scan_subnet
        ], capture_output=True, text=True, timeout=15)
        
        if res.returncode == 0:
            hosts = parse_nmap_output(res.stdout)
            headers = ["IP Address", "Hostname", "Status"]
            rows = [[h["ip"], h["hostname"] or "-", f"{GREEN}{h['status'].upper()}{NC}"] for h in hosts]
            print("\n")
            print_header(f"Active Hosts found on {scan_subnet}")
            print_table(headers, rows)
            log_audit("Discovered network hosts", f"nmap -sn {scan_subnet}", True, f"Found {len(hosts)} active hosts in subnet {scan_subnet}")
        else:
            print(f"{RED}Nmap failed: {res.stderr}{NC}")
    except subprocess.TimeoutExpired:
        print(f"{RED}Error: Nmap scan timed out. Try narrowing the subnet range.{NC}")
    except Exception as e:
        print(f"{RED}Error running nmap: {e}{NC}")


def take_snapshot():
    interfaces_routes = get_normalized_network_state()
    sockets = []
    if check_tool("ss"):
        try:
            res = subprocess.run(["ss", "-tupan"], capture_output=True, text=True, timeout=5)
            sockets = parse_ss_output(res.stdout)
        except Exception:
            pass
            
    fw_count = 0
    fw_type = "unknown"
    if check_tool("nft"):
        try:
            res = subprocess.run(["nft", "list", "ruleset"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                fw_count = len(res.stdout.splitlines())
                fw_type = "nftables"
        except Exception:
            pass
    elif check_tool("iptables"):
        try:
            res = subprocess.run(["iptables", "-S"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                fw_count = len(res.stdout.splitlines())
                fw_type = "iptables"
        except Exception:
            pass
            
    snapshot = {
        "timestamp": datetime.datetime.now().isoformat(),
        "interfaces": interfaces_routes.get("interfaces", []),
        "routes": interfaces_routes.get("routes", []),
        "sockets": sockets,
        "firewall": {
            "type": fw_type,
            "rule_lines_count": fw_count
        }
    }
    
    snap_id = f"snap_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
    filepath = os.path.join(get_user_state_dir(), "snapshots", f"{snap_id}.json")
    try:
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, "w") as f:
            json.dump(snapshot, f, indent=2)
        print(f"{GREEN}✓ Snapshot successfully saved!{NC}")
        print(f"Snapshot ID: {CYAN}{snap_id}{NC}")
        print(f"Path: {filepath}")
        log_audit("Created network state snapshot", f"Save snapshot to {filepath}", True, f"Saved snapshot {snap_id}")
    except Exception as e:
        print(f"{RED}Error writing snapshot file: {e}{NC}")

def compare_snapshots():
    snap_dir = os.path.join(get_user_state_dir(), "snapshots")
    if not os.path.isdir(snap_dir):
        print(f"{YELLOW}No snapshots available yet. Take a snapshot first.{NC}")
        return
        
    files = sorted([f for f in os.listdir(snap_dir) if f.startswith("snap_") and f.endswith(".json")], reverse=True)
    if not files:
        print(f"{YELLOW}No snapshots available yet. Take a snapshot first.{NC}")
        return
        
    print_header("Available Snapshots")
    for idx, f in enumerate(files):
        time_part = f.replace("snap_", "").replace(".json", "")
        try:
            dt = datetime.datetime.strptime(time_part, "%Y%m%d_%H%M%S")
            time_str = dt.strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            time_str = "unknown date"
        print(f"  {CYAN}{idx + 1}{NC})  {f} ({time_str})")
        
    print()
    choice = input("Select snapshot to compare against (or press ENTER to cancel): ").strip()
    if not choice:
        return
    try:
        sel_idx = int(choice) - 1
        if sel_idx < 0 or sel_idx >= len(files):
            print(f"{RED}Invalid selection.{NC}")
            return
    except ValueError:
        print(f"{RED}Invalid selection.{NC}")
        return
        
    snap_file = os.path.join(snap_dir, files[sel_idx])
    try:
        with open(snap_file, "r") as f:
            old_state = json.load(f)
    except Exception as e:
        print(f"{RED}Error reading snapshot file: {e}{NC}")
        return
        
    print("Gathering current live state...")
    live_interfaces_routes = get_normalized_network_state()
    live_sockets = []
    if check_tool("ss"):
        try:
            res = subprocess.run(["ss", "-tupan"], capture_output=True, text=True, timeout=5)
            live_sockets = parse_ss_output(res.stdout)
        except Exception:
            pass
            
    def get_sock_key(s):
        return (s.get("proto"), s.get("local_ip"), s.get("local_port"), s.get("peer_ip"), s.get("peer_port"))
        
    old_socks = {get_sock_key(s): s for s in old_state.get("sockets", [])}
    live_socks = {get_sock_key(s): s for s in live_sockets}
    
    print_header(f"Differential Analysis vs {files[sel_idx]}")
    
    old_listening = {k: v for k, v in old_socks.items() if v.get("state") == "LISTEN" or v.get("proto") == "udp"}
    live_listening = {k: v for k, v in live_socks.items() if v.get("state") == "LISTEN" or v.get("proto") == "udp"}
    
    new_listening = []
    closed_listening = []
    for k, v in live_listening.items():
        if k not in old_listening:
            new_listening.append(v)
    for k, v in old_listening.items():
        if k not in live_listening:
            closed_listening.append(v)
            
    old_estab = {k: v for k, v in old_socks.items() if v.get("state") == "ESTAB"}
    live_estab = {k: v for k, v in live_socks.items() if v.get("state") == "ESTAB"}
    
    new_estab = []
    closed_estab = []
    for k, v in live_estab.items():
        if k not in old_estab:
            new_estab.append(v)
    for k, v in old_estab.items():
        if k not in live_estab:
            closed_estab.append(v)
            
    print(f"{BLUE}━━━ Socket Port & Connection Changes ━━━{NC}")
    if not any([new_listening, closed_listening, new_estab, closed_estab]):
        print("  No socket or connection changes detected.")
    else:
        if new_listening:
            print(f"  {GREEN}➕ New Listening Ports:{NC}")
            for s in new_listening:
                proc = ", ".join([f"{p['name']}({p['pid']})" for p in s.get("processes", [])]) or "unknown"
                print(f"    • {s.get('proto').upper()} {s.get('local_ip')}:{s.get('local_port')} (Process: {proc})")
        if closed_listening:
            print(f"  {RED}➖ Closed Listening Ports:{NC}")
            for s in closed_listening:
                print(f"    • {s.get('proto').upper()} {s.get('local_ip')}:{s.get('local_port')}")
        if new_estab:
            print(f"  {GREEN}➕ New Active Connections:{NC}")
            for s in new_estab:
                proc = ", ".join([f"{p['name']}({p['pid']})" for p in s.get("processes", [])]) or "unknown"
                print(f"    • {s.get('proto').upper()} {s.get('local_ip')}:{s.get('local_port')} ➔ {s.get('peer_ip')}:{s.get('peer_port')} (Process: {proc})")
        if closed_estab:
            print(f"  {RED}➖ Closed Active Connections:{NC}")
            for s in closed_estab:
                print(f"    • {s.get('proto').upper()} {s.get('local_ip')}:{s.get('local_port')} ➔ {s.get('peer_ip')}:{s.get('peer_port')}")
                
    def get_route_key(r):
        return (r.get("dst"), r.get("gateway"), r.get("dev"))
        
    old_routes = {get_route_key(r): r for r in old_state.get("routes", [])}
    live_routes = {get_route_key(r): r for r in live_interfaces_routes.get("routes", [])}
    
    new_routes = []
    removed_routes = []
    for k, v in live_routes.items():
        if k not in old_routes:
            new_routes.append(v)
    for k, v in old_routes.items():
        if k not in live_routes:
            removed_routes.append(v)
            
    print()
    print(f"{BLUE}━━━ Routing Topology Changes ━━━{NC}")
    if not new_routes and not removed_routes:
        print("  No routing table changes detected.")
    else:
        if new_routes:
            print(f"  {GREEN}➕ Added Routes:{NC}")
            for r in new_routes:
                print(f"    • Dest: {r.get('dst')}, Gateway: {r.get('gateway', '*')}, Dev: {r.get('dev')}")
        if removed_routes:
            print(f"  {RED}➖ Removed Routes:{NC}")
            for r in removed_routes:
                print(f"    • Dest: {r.get('dst')}, Gateway: {r.get('gateway', '*')}, Dev: {r.get('dev')}")
    print()
    log_audit("Performed snapshot comparison", f"Diff current state against {files[sel_idx]}", True, "Analyzed socket and routing diffs")

def run_security_report():
    print_header("Security & Compliance Audit Report")
    
    state = get_normalized_network_state()
    sockets = []
    if check_tool("ss"):
        try:
            res = subprocess.run(["ss", "-tupan"], capture_output=True, text=True, timeout=5)
            sockets = parse_ss_output(res.stdout)
        except Exception:
            pass
            
    risks = []
    score = 100
    
    fw_rules = 0
    fw_type = "None"
    if check_tool("nft"):
        try:
            res = subprocess.run(["nft", "list", "ruleset"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                fw_rules = len(res.stdout.splitlines())
                fw_type = "nftables"
        except Exception:
            pass
    elif check_tool("iptables"):
        try:
            res = subprocess.run(["iptables", "-S"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                fw_rules = len(res.stdout.splitlines())
                fw_type = "iptables"
        except Exception:
            pass
            
    if fw_rules == 0:
        risks.append({
            "severity": "HIGH",
            "desc": "No active firewall rulesets configured on host.",
            "confidence": 95,
            "remediation": "Enable and configure nftables or ufw/firewalld."
        })
        score -= 40
    else:
        print(f"{GREEN}✓ Active firewall rules detected ({fw_type}, {fw_rules} rules).{NC}")
        
    insecure_ports = {
        "21": "FTP (unencrypted credentials and data transfer)",
        "23": "Telnet (unencrypted terminal session, highly obsolete)",
        "80": "HTTP (unencrypted web service, verify if SSL is redirecting)",
        "25": "SMTP (unencrypted mail server, verify STARTTLS)",
        "110": "POP3 (unencrypted mail retrieval)",
        "143": "IMAP (unencrypted mail retrieval)",
        "513": "R-Services rlogin (highly obsolete, no encryption)",
        "514": "R-Services rsh (highly obsolete, no encryption)"
    }
    
    listening_socks = [s for s in sockets if s.get("state") == "LISTEN" or s.get("proto") == "udp"]
    for s in listening_socks:
        port = s.get("local_port")
        if port in insecure_ports:
            proc = ", ".join([f"{p['name']}({p['pid']})" for p in s.get("processes", [])]) or "unknown"
            risks.append({
                "severity": "CRITICAL" if port in ["23", "513", "514"] else "HIGH",
                "desc": f"Insecure service running on port {port}: {insecure_ports[port]}",
                "confidence": 99,
                "remediation": f"Disable the {proc} process or update it to use an encrypted protocol (SFTP, SSH, HTTPS)."
            })
            if port in ["23", "513", "514"]:
                score -= 50
            else:
                score -= 30
                
        if port in ["22", "8022"] and s.get("local_ip") in ["0.0.0.0", "*", "::"]:
            proc = ", ".join([f"{p['name']}({p['pid']})" for p in s.get("processes", [])]) or "sshd"
            risks.append({
                "severity": "MEDIUM",
                "desc": f"Administration interface ({proc}) listening on wildcard address ({s.get('local_ip')}:{port}).",
                "confidence": 90,
                "remediation": "Restrict SSH binding to localhost or a specific management interface IP in sshd_config."
            })
            score -= 15
            
    score = max(0, score)
    if score >= 90:
        rating = f"{GREEN}EXCELLENT ({score}/100){NC}"
    elif score >= 75:
        rating = f"{YELLOW}GOOD ({score}/100){NC}"
    elif score >= 50:
        rating = f"{YELLOW}FAIR ({score}/100){NC}"
    else:
        rating = f"{RED}POOR / CRITICAL ACTION REQUIRED ({score}/100){NC}"
        
    print(f"\nOverall Host Security Rating: {rating}")
    print()
    
    if risks:
        print(f"{RED}━━━ Risks & Compliance Deviations Detected ━━━{NC}")
        print()
        for idx, r in enumerate(risks):
            sev_color = RED if r["severity"] in ["CRITICAL", "HIGH"] else YELLOW
            print(f" {idx + 1}. [{sev_color}{r['severity']}{NC}] {r['desc']}")
            print(f"    Confidence Score: {r['confidence']}%")
            print(f"    Remediation: {r['remediation']}")
            print()
    else:
        print(f"{GREEN}✓ No obvious risk deviations or obsolete services detected on listening ports.{NC}")
    log_audit("Generated Security Compliance Report", "Audit connections & firewall rules", True, f"Calculated host security score: {score}/100", confidence_score=score)

# --- Sub-page Runner Loop ---

def decode_decimal_escapes(s):
    return re.sub(r'\\(\d{3})', lambda m: chr(int(m.group(1))), s)

def parse_avahi_output(stdout):
    services = []
    for line in stdout.splitlines():
        if line.startswith("="):
            parts = line.strip().split(";")
            if len(parts) >= 9:
                services.append({
                    "interface": parts[1],
                    "family": parts[2],
                    "name": decode_decimal_escapes(parts[3]),
                    "type": decode_decimal_escapes(parts[4]),
                    "hostname": decode_decimal_escapes(parts[6]),
                    "ip": parts[7],
                    "port": parts[8]
                })
    return services

def show_avahi_discovery():
    if not check_tool("avahi-browse"):
        print(f"{RED}Error: 'avahi-browse' is not installed.{NC}")
        print("To install:")
        print("  sudo pacman -S avahi")
        return
        
    print_header("mDNS / Avahi Service Topology")
    print("Browsing for active services on the local network (avahi-browse)...")
    
    try:
        # Run avahi-browse in parsable mode, resolving all services, terminating after dump
        res = subprocess.run(["avahi-browse", "-d", "local", "-a", "-r", "-t", "-p"], capture_output=True, text=True, timeout=15)
        if res.returncode == 0:
            services = parse_avahi_output(res.stdout)
            if services:
                # Group by (hostname, ip, interface)
                hosts_map = {}
                for s in services:
                    key = (s["hostname"], s["ip"], s["interface"])
                    if key not in hosts_map:
                        hosts_map[key] = []
                    hosts_map[key].append(s)
                
                # Build tree lines
                tree_lines = []
                for key, items in hosts_map.items():
                    hostname, ip, interface = key
                    tree_lines.append(f"🖥️  {GREEN}{hostname}{NC} ({CYAN}{ip}{NC}) via interface {BLUE}{interface}{NC}")
                    
                    seen_services = set()
                    unique_items = []
                    for s in items:
                        svc_key = (s["name"], s["type"], s["port"])
                        if svc_key not in seen_services:
                            seen_services.add(svc_key)
                            unique_items.append(s)
                    
                    # Sort services by name
                    unique_items.sort(key=lambda x: x["name"])
                    
                    for idx, s in enumerate(unique_items):
                        is_last = (idx == len(unique_items) - 1)
                        connector = "└──" if is_last else "├──"
                        tree_lines.append(f"   {connector} {YELLOW}{s['name']}{NC} ({s['type']}) on Port {MAGENTA}{s['port']}{NC}")
                    tree_lines.append("")
                
                # Pipe into less if available, else fallback
                if check_tool("less"):
                    try:
                        # -R keeps colors, -F exits if fits on screen, -X keeps content visible on exit
                        less_proc = subprocess.Popen(
                            ["less", "-R", "-F", "-X"],
                            stdin=subprocess.PIPE,
                            text=True
                        )
                        fzf_input = "\n".join(tree_lines)
                        less_proc.communicate(input=fzf_input)
                    except Exception as e:
                        print(f"{RED}Failed to run less: {e}. Printing tree instead:{NC}\n")
                        for line in tree_lines:
                            print(line)
                else:
                    print("\n")
                    for line in tree_lines:
                        print(line)
                
                log_audit("Ran Avahi service discovery topology", "avahi-browse -d local -a -r -t -p", True, f"Mapped services for {len(hosts_map)} hosts")
            else:
                print(f"{YELLOW}No mDNS/Avahi services discovered on local network.{NC}")
        else:
            print(f"{RED}Avahi-browse failed: {res.stderr}{NC}")
    except subprocess.TimeoutExpired:
        print(f"{RED}Error: Avahi-browse scan timed out.{NC}")
    except Exception as e:
        print(f"{RED}Error running avahi-browse: {e}{NC}")

def get_default_gateway():
    try:
        res = subprocess.run(["ip", "route", "show", "default"], capture_output=True, text=True, timeout=3)
        if res.returncode == 0 and res.stdout:
            parts = res.stdout.strip().split()
            if "via" in parts:
                idx = parts.index("via")
                return parts[idx + 1]
    except:
        pass
    return None

def get_local_ip_and_interface():
    try:
        res = subprocess.run(["ip", "route", "get", "1.1.1.1"], capture_output=True, text=True, timeout=3)
        if res.returncode == 0 and res.stdout:
            parts = res.stdout.strip().split()
            if "src" in parts:
                src_idx = parts.index("src")
                dev_idx = parts.index("dev")
                return parts[src_idx + 1], parts[dev_idx + 1]
    except:
        pass
    return "127.0.0.1", "lo"

def show_network_graph():
    print_header("Terminal Network Topology Graph")
    print("Gathering network topology...")
    
    local_ip, iface = get_local_ip_and_interface()
    gateway_ip = get_default_gateway()
    
    # Get active hosts from ARP neighbor cache
    arp_neighs = []
    try:
        res = subprocess.run(["ip", "neigh", "show", "dev", iface], capture_output=True, text=True, timeout=3)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                parts = line.strip().split()
                if len(parts) >= 5 and "FAILED" not in line:
                    ip = parts[0]
                    arp_neighs.append(ip)
    except:
        pass
        
    # Get local subnet info
    subnet_range = "Unknown Subnet"
    try:
        res = subprocess.run(["ip", "route", "show", "dev", iface], capture_output=True, text=True, timeout=3)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                if "proto kernel" in line or "scope link" in line:
                    parts = line.split()
                    if parts:
                        subnet_range = parts[0]
                        break
    except:
        pass
        
    # Retrieve mDNS names via avahi if available
    names_map = {}
    services_map = {}
    if check_tool("avahi-browse"):
        try:
            res = subprocess.run(["avahi-browse", "-d", "local", "-a", "-r", "-t", "-p"], capture_output=True, text=True, timeout=10)
            if res.returncode == 0:
                services = parse_avahi_output(res.stdout)
                for s in services:
                    ip = s["ip"]
                    names_map[ip] = s["hostname"]
                    if ip not in services_map:
                        services_map[ip] = []
                    svc_info = f"{s['name']} (Port {s['port']})"
                    if svc_info not in services_map[ip]:
                        services_map[ip].append(svc_info)
        except:
            pass

    # Unique list of other nodes
    nodes = set(arp_neighs)
    if gateway_ip:
        nodes.discard(gateway_ip)
    nodes.discard(local_ip)
    
    # Render topology graph
    graph_lines = []
    graph_lines.append(f"\n   {CYAN}[ Internet ]{NC}")
    graph_lines.append("        │")
    
    if gateway_ip:
        gateway_name = names_map.get(gateway_ip, "default-gateway")
        graph_lines.append(f"  {RED}[ Gateway ]{NC} ─────── {YELLOW}{gateway_ip}{NC} ({gateway_name})")
    else:
        graph_lines.append(f"  {RED}[ Gateway ]{NC} ─────── Unknown Gateway")
        
    graph_lines.append("        │")
    graph_lines.append(f"  ──────┴─────────────────────────── {GREEN}Subnet: {subnet_range} ({iface}){NC}")
    graph_lines.append("        │                         │")
    graph_lines.append(f"  {GREEN}[ Local Host ]{NC}                  {CYAN}[ Active Subnet Nodes ]{NC}")
    graph_lines.append(f"  ({local_ip})")
    
    sorted_nodes = sorted(list(nodes))
    if not sorted_nodes:
        graph_lines.append("                                  (No other active nodes detected)")
    else:
        for idx, node in enumerate(sorted_nodes):
            is_last = (idx == len(sorted_nodes) - 1)
            connector = "└─" if is_last else "├─"
            node_name = names_map.get(node, "unknown")
            graph_lines.append(f"                                  {connector} {YELLOW}{node}{NC} ({node_name})")
            
            if node in services_map:
                services_list = services_map[node]
                for s_idx, svc in enumerate(services_list):
                    indent = " " if is_last else "│"
                    sub_connector = "└──" if (s_idx == len(services_list) - 1) else "├──"
                    graph_lines.append(f"                                  {indent}   {sub_connector} {MAGENTA}{svc}{NC}")
    graph_lines.append("\n")
    
    if check_tool("less"):
        try:
            less_proc = subprocess.Popen(
                ["less", "-R", "-F", "-X"],
                stdin=subprocess.PIPE,
                text=True
            )
            less_proc.communicate(input="\n".join(graph_lines))
        except Exception as e:
            print(f"{RED}Failed to run less: {e}. Printing graph directly:{NC}\n")
            for line in graph_lines:
                print(line)
    else:
        for line in graph_lines:
            print(line)
            
    log_audit("Displayed network topology graph", "ip neigh & avahi-browse graph", True, f"Mapped {len(nodes)} active nodes")

def main():
    escalate_privileges()
    setup_paths()
    
    while True:
        clear_screen()
        print_header("Network Discovery & Mapping Auditor")
        
        # Tool status mapping
        ip_ok = check_tool("ip")
        ss_ok = check_tool("ss")
        fw_ok = check_tool("nft") or check_tool("iptables")
        telemetry_ok = True  # fallback always available via /proc
        bcc_ok = check_tool("tcptop")
        nmap_ok = check_tool("nmap")
        avahi_ok = check_tool("avahi-browse")
        
        # Build menu strings
        opt1 = f"Enumerate Interfaces & Routing" if ip_ok else f"Enumerate Interfaces & Routing {RED}[DISABLED: 'ip' missing]{NC}"
        opt2 = f"Active Sockets & Process Map" if ss_ok else f"Active Sockets & Process Map {RED}[DISABLED: 'ss' missing]{NC}"
        opt3 = f"Audit Firewall / ACL Ruleset" if fw_ok else f"Audit Firewall / ACL Ruleset {RED}[DISABLED: 'nft'/'iptables' missing]{NC}"
        opt4 = f"Real-Time Interface Telemetry" if telemetry_ok else f"Real-Time Interface Telemetry {RED}[DISABLED: /proc missing]{NC}"
        opt5 = f"Real-Time Process Telemetry (BCC)" if bcc_ok else f"Real-Time Process Telemetry (BCC) {YELLOW}[DISABLED: 'tcptop' missing (fallback available)]{NC}"
        opt6 = f"Subnet Host Discovery (Nmap)" if nmap_ok else f"Subnet Host Discovery (Nmap) {RED}[DISABLED: 'nmap' missing]{NC}"
        opt7 = f"mDNS / Avahi Service Topology" if avahi_ok else f"mDNS / Avahi Service Topology {RED}[DISABLED: 'avahi-browse' missing]{NC}"
        opt8 = f"Terminal Network Topology Graph" if ip_ok else f"Terminal Network Topology Graph {RED}[DISABLED: 'ip' missing]{NC}"
        opt9 = f"Take Atomic Snapshot of Network State"
        opt10 = f"Compare Slices / Differential Analysis"
        opt11 = f"Generate Security Audit Report"
        
        print(f"  {MAGENTA}1{NC})  {opt1}")
        print(f"  {MAGENTA}2{NC})  {opt2}")
        print(f"  {MAGENTA}3{NC})  {opt3}")
        print(f"  {MAGENTA}4{NC})  {opt4}")
        print(f"  {MAGENTA}5{NC})  {opt5}")
        print(f"  {MAGENTA}6{NC})  {opt6}")
        print(f"  {MAGENTA}7{NC})  {opt7}")
        print(f"  {MAGENTA}8{NC})  {opt8}")
        print(f"  {MAGENTA}9{NC})  {opt9}")
        print(f"  {MAGENTA}10{NC}) {opt10}")
        print(f"  {MAGENTA}11{NC}) {opt11}")
        print(f"  {RED}0{NC})  Return to Main Menu")
        print()
        
        choice = input(f"{CYAN}Select option (0-11):{NC} ").strip()
        
        if choice == '0':
            break
        elif choice == '1':
            if not ip_ok:
                print(f"{RED}Error: Option disabled because 'ip' is missing.{NC}")
                pause()
                continue
            clear_screen()
            show_interfaces_and_routes()
            pause()
        elif choice == '2':
            if not ss_ok:
                print(f"{RED}Error: Option disabled because 'ss' is missing.{NC}")
                pause()
                continue
            clear_screen()
            show_sockets()
            pause()
        elif choice == '3':
            if not fw_ok:
                print(f"{RED}Error: Option disabled because 'nft' and 'iptables' are missing.{NC}")
                pause()
                continue
            clear_screen()
            show_firewall()
            pause()
        elif choice == '4':
            clear_screen()
            show_interface_telemetry()
            pause()
        elif choice == '5':
            clear_screen()
            show_process_telemetry()
            pause()
        elif choice == '6':
            if not nmap_ok:
                print(f"{RED}Error: Option disabled because 'nmap' is missing.{NC}")
                pause()
                continue
            clear_screen()
            discover_hosts()
            pause()
        elif choice == '7':
            if not avahi_ok:
                print(f"{RED}Error: Option disabled because 'avahi-browse' is missing.{NC}")
                pause()
                continue
            clear_screen()
            show_avahi_discovery()
            pause()
        elif choice == '8':
            if not ip_ok:
                print(f"{RED}Error: Option disabled because 'ip' is missing.{NC}")
                pause()
                continue
            clear_screen()
            show_network_graph()
            pause()
        elif choice == '9':
            clear_screen()
            take_snapshot()
            pause()
        elif choice == '10':
            clear_screen()
            compare_snapshots()
            pause()
        elif choice == '11':
            clear_screen()
            run_security_report()
            pause()
        else:
            print(f"{RED}Invalid option.{NC}")
            time.sleep(1)

if __name__ == '__main__':
    main()


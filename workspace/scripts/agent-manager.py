#!/usr/bin/env python3
"""
Agent & MCP Manager CLI tool for Dotfiles.
Manages AI agents, skill symlinks, and central MCP server configuration across all agents.
"""

import sys
import os
import json
import shlex
import argparse
from pathlib import Path

# Paths resolution following physical symlinks
def get_dotfiles_dir() -> Path:
    if "DOTFILES_DIR" in os.environ:
        env_p = Path(os.environ["DOTFILES_DIR"]).resolve()
        if (env_p / "skills").exists():
            return env_p
    # Resolve script location following physical symlinks
    script_p = Path(__file__).resolve()
    candidate = script_p.parents[2]
    if (candidate / "skills").exists():
        return candidate
    # Fallback to ~/dotfiles
    home_p = Path.home() / "dotfiles"
    if (home_p / "skills").exists():
        return home_p
    return candidate

DOTFILES_DIR = get_dotfiles_dir()
SKILLS_DIR = DOTFILES_DIR / "skills"
AGENTS_FILE = SKILLS_DIR / ".agents"
MCP_DIR = DOTFILES_DIR / "mcp"
CANONICAL_MCP_FILE = MCP_DIR / "mcp-servers.json"
MCP_PROMPTS_DIR = MCP_DIR / "prompts"

# ANSI Colors for clean UI formatting
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
BLUE = "\033[34m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"
DIM = "\033[2m"

def expand_path(p: str) -> Path:
    return Path(os.path.expanduser(p)).resolve()

def parse_agents_file():
    agents = []
    if not AGENTS_FILE.exists():
        return agents
    
    with open(AGENTS_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            name = parts[0]
            skills_path = parts[1] if len(parts) > 1 else "-"
            instruction_link = parts[2] if len(parts) > 2 else "-"
            mcp_config_path = parts[3] if len(parts) > 3 else "-"
            
            agents.append({
                "name": name,
                "skills_path": skills_path,
                "instruction_link": instruction_link,
                "mcp_config_path": mcp_config_path
            })
    return agents

def load_canonical_mcp():
    if not CANONICAL_MCP_FILE.exists():
        return {}
    try:
        with open(CANONICAL_MCP_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"{RED}Error reading {CANONICAL_MCP_FILE}: {e}{RESET}")
        return {}

def save_canonical_mcp(mcp_dict):
    MCP_DIR.mkdir(parents=True, exist_ok=True)
    with open(CANONICAL_MCP_FILE, "w", encoding="utf-8") as f:
        json.dump(mcp_dict, f, indent=2)

def get_skills():
    active = []
    disabled = []
    if SKILLS_DIR.exists():
        for item in SKILLS_DIR.iterdir():
            if item.is_dir():
                if item.name.endswith(".disabled"):
                    disabled.append(item.name[:-9])
                elif not item.name.startswith("."):
                    active.append(item.name)
    return sorted(active), sorted(disabled)

def sync_mcp_to_agents():
    canonical = load_canonical_mcp()
    agents = parse_agents_file()
    
    # Filter active MCP servers (not disabled)
    active_mcp = {}
    for name, config in canonical.items():
        if not config.get("disabled", False):
            # Clean copy without dotfile-specific meta keys if any
            clean_config = {k: v for k, v in config.items() if k != "disabled"}
            active_mcp[name] = clean_config

    synced_count = 0
    for agent in agents:
        mcp_path_str = agent["mcp_config_path"]
        if mcp_path_str == "-" or not mcp_path_str:
            continue
            
        target_path = expand_path(mcp_path_str)
        target_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Load existing config to preserve top-level non-MCP properties
        existing_data = {}
        if target_path.exists():
            try:
                with open(target_path, "r", encoding="utf-8") as f:
                    existing_data = json.load(f)
            except Exception:
                existing_data = {}

        # Set or replace the mcpServers block
        existing_data["mcpServers"] = active_mcp
        
        with open(target_path, "w", encoding="utf-8") as f:
            json.dump(existing_data, f, indent=2)
            
        print(f"  {GREEN}✓{RESET} Synced MCP servers to {BOLD}{agent['name']}{RESET} ({CYAN}{mcp_path_str}{RESET})")
        synced_count += 1
        
    return synced_count

def cmd_status(args):
    print(f"\n{BOLD}{CYAN}=== Agent & Skill & MCP Status ==={RESET}\n")
    
    # 1. Agents
    agents = parse_agents_file()
    print(f"{BOLD}Configured Agents ({len(agents)}):{RESET}")
    for a in agents:
        mcp_info = f"{CYAN}{a['mcp_config_path']}{RESET}" if a['mcp_config_path'] != "-" else f"{DIM}None{RESET}"
        skills_info = f"{CYAN}{a['skills_path']}{RESET}"
        print(f"  • {BOLD}{a['name']:<10}{RESET} | Skills: {skills_info} | MCP Config: {mcp_info}")
    
    # 2. Skills
    active_skills, disabled_skills = get_skills()
    print(f"\n{BOLD}Skills ({len(active_skills)} Active, {len(disabled_skills)} Disabled):{RESET}")
    print(f"  • {GREEN}Active:{RESET}   {', '.join(active_skills) if active_skills else 'None'}")
    if disabled_skills:
        print(f"  • {YELLOW}Disabled:{RESET} {', '.join(disabled_skills)}")
        
    # 3. MCP Servers
    mcp_dict = load_canonical_mcp()
    print(f"\n{BOLD}Canonical MCP Servers ({len(mcp_dict)} total):{RESET}")
    if not mcp_dict:
        print(f"  {DIM}No MCP servers configured yet in {CANONICAL_MCP_FILE}{RESET}")
    else:
        for name, cfg in mcp_dict.items():
            is_disabled = cfg.get("disabled", False)
            status_str = f"{YELLOW}[Disabled]{RESET}" if is_disabled else f"{GREEN}[Active]{RESET}"
            cmd = cfg.get("command", "")
            args_str = " ".join(cfg.get("args", []))
            print(f"  • {BOLD}{name:<15}{RESET} {status_str} -> {CYAN}{cmd} {args_str}{RESET}")
            if cfg.get("env"):
                env_keys = ", ".join(cfg["env"].keys())
                print(f"    {DIM}Env vars: {env_keys}{RESET}")
    print()

def save_mcp_prompt(name: str, prompt_text: str):
    if not prompt_text:
        return
    MCP_PROMPTS_DIR.mkdir(parents=True, exist_ok=True)
    prompt_file = MCP_PROMPTS_DIR / f"{name}.md"
    content = prompt_text if prompt_text.startswith("#") else f"# {name.capitalize()} MCP Example Prompts\n\n- \"{prompt_text}\"\n"
    with open(prompt_file, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  {GREEN}✓{RESET} Saved prompts to {CYAN}{prompt_file.relative_to(DOTFILES_DIR)}{RESET}")

def remove_mcp_prompt(name: str):
    prompt_file = MCP_PROMPTS_DIR / f"{name}.md"
    if prompt_file.exists():
        try:
            prompt_file.unlink()
            print(f"  {GREEN}✓{RESET} Removed prompt file {CYAN}{prompt_file.relative_to(DOTFILES_DIR)}{RESET}")
        except Exception as e:
            print(f"  {RED}Warning: Could not remove prompt file: {e}{RESET}")

def cmd_sync(args):
    print(f"\n{BOLD}Syncing MCP configurations from canonical storage...{RESET}")
    count = sync_mcp_to_agents()
    print(f"{GREEN}{BOLD}Successfully synced MCP config to {count} agent targets.{RESET}\n")

def cmd_add_mcp(args):
    mcp_dict = load_canonical_mcp()
    name = args.name
    
    if not name and not args.interactive:
        name = input("MCP Server Name: ").strip()
    
    if not name:
        print(f"{RED}Error: Server name is required.{RESET}")
        sys.exit(1)
        
    command = args.command
    if not command and not args.interactive:
        command = input(f"Command (e.g. npx, python, node): ").strip()
        
    args_list = []
    if args.args:
        args_list = shlex.split(args.args)
    elif not args.interactive:
        args_raw = input("Args (space separated, e.g. -y @modelcontextprotocol/server-github): ").strip()
        args_list = shlex.split(args_raw) if args_raw else []
        
    env_dict = {}
    if args.env:
        for kv in args.env:
            if "=" in kv:
                k, v = kv.split("=", 1)
                env_dict[k] = v
                
    mcp_dict[name] = {
        "command": command or "npx",
        "args": args_list or [],
        "env": env_dict,
        "disabled": False
    }
    
    save_canonical_mcp(mcp_dict)
    print(f"\n{GREEN}✓ Added/updated MCP server '{BOLD}{name}{GREEN}' in canonical config.{RESET}")
    
    if hasattr(args, "prompt") and args.prompt:
        save_mcp_prompt(name, args.prompt)
    elif args.interactive:
        p = input(f"Example prompt for {name} (optional): ").strip()
        if p:
            save_mcp_prompt(name, p)

    if not args.no_sync:
        sync_mcp_to_agents()

def cmd_remove_mcp(args):
    mcp_dict = load_canonical_mcp()
    name = args.name
    if name not in mcp_dict:
        print(f"{RED}Error: MCP server '{name}' not found in canonical config.{RESET}")
        sys.exit(1)
        
    del mcp_dict[name]
    save_canonical_mcp(mcp_dict)
    print(f"\n{GREEN}✓ Removed MCP server '{BOLD}{name}{GREEN}' from canonical config.{RESET}")
    remove_mcp_prompt(name)
    sync_mcp_to_agents()

def cmd_toggle_mcp(args, disable: bool):
    mcp_dict = load_canonical_mcp()
    name = args.name
    if name not in mcp_dict:
        print(f"{RED}Error: MCP server '{name}' not found in canonical config.{RESET}")
        sys.exit(1)
        
    mcp_dict[name]["disabled"] = disable
    save_canonical_mcp(mcp_dict)
    state = "Disabled" if disable else "Enabled"
    print(f"\n{GREEN}✓ {state} MCP server '{BOLD}{name}{GREEN}'.{RESET}")
    sync_mcp_to_agents()

def cmd_prompts(args):
    name = getattr(args, "name", None)
    print(f"\n{BOLD}{CYAN}=== MCP Example Prompts ==={RESET}\n")
    
    if name:
        prompt_file = MCP_PROMPTS_DIR / f"{name}.md"
        if not prompt_file.exists():
            print(f"{YELLOW}No prompt file found for '{name}' ({prompt_file}).{RESET}")
            print(f"{DIM}Use `agm add-mcp -n {name} --prompt \"...\"` to set example prompts.{RESET}\n")
            return
        print(f"{BOLD}Prompts for {CYAN}{name}{RESET} ({DIM}{prompt_file.relative_to(DOTFILES_DIR)}{RESET}):\n")
        with open(prompt_file, "r", encoding="utf-8") as f:
            print(f.read())
        print()
    else:
        if not MCP_PROMPTS_DIR.exists() or not list(MCP_PROMPTS_DIR.glob("*.md")):
            print(f"{DIM}No MCP prompts saved in {MCP_PROMPTS_DIR.relative_to(DOTFILES_DIR)}{RESET}\n")
            return
        
        for pfile in sorted(MCP_PROMPTS_DIR.glob("*.md")):
            srv_name = pfile.stem
            print(f"{BOLD}• MCP Server:{RESET} {CYAN}{BOLD}{srv_name}{RESET} ({DIM}{pfile.relative_to(DOTFILES_DIR)}{RESET})")
            with open(pfile, "r", encoding="utf-8") as f:
                for line in f:
                    line_s = line.strip()
                    if line_s.startswith("-") or line_s.startswith("*"):
                        print(f"    {GREEN}{line_s}{RESET}")
            print()

def main():
    parser = argparse.ArgumentParser(description="Agent & MCP Manager CLI for Dotfiles")
    subparsers = parser.add_subparsers(dest="subcommand")
    
    # status / ls
    parser_status = subparsers.add_parser("status", aliases=["ls", "list"], help="List agents, skills, and MCP servers")
    
    # sync
    parser_sync = subparsers.add_parser("sync", help="Sync canonical MCP config to all target agent configs")
    
    # add-mcp
    parser_add = subparsers.add_parser("add-mcp", aliases=["add"], help="Add or update an MCP server configuration")
    parser_add.add_argument("--name", "-n", help="Name of the MCP server")
    parser_add.add_argument("--command", "-c", help="Command (e.g., npx, python)")
    parser_add.add_argument("--args", "-a", type=str, default="", help="Arguments string (e.g., '-y @modelcontextprotocol/server-fetch')")
    parser_add.add_argument("--env", "-e", action="append", help="Environment variables as KEY=VALUE")
    parser_add.add_argument("--prompt", "-p", help="Example prompt / usage instructions for this MCP server")
    parser_add.add_argument("--no-sync", action="store_true", help="Do not auto-sync after adding")
    parser_add.add_argument("-i", "--interactive", action="store_true", help="Interactive prompt mode")
    
    # rm-mcp / remove-mcp / rm / delete
    parser_rm = subparsers.add_parser("rm-mcp", aliases=["rm", "remove", "delete"], help="Remove an MCP server and its prompts")
    parser_rm.add_argument("name", help="Name of the MCP server to remove")

    # prompts / prompt / examples
    parser_prompts = subparsers.add_parser("prompts", aliases=["prompt", "examples"], help="View example prompts for MCP servers")
    parser_prompts.add_argument("name", nargs="?", default=None, help="Optional MCP server name")

    # enable / disable
    parser_enable = subparsers.add_parser("enable-mcp", help="Enable an MCP server")
    parser_enable.add_argument("name", help="Name of the MCP server")
    
    parser_disable = subparsers.add_parser("disable-mcp", help="Disable an MCP server")
    parser_disable.add_argument("name", help="Name of the MCP server")
    
    args = parser.parse_args()
    
    if args.subcommand in (None, "status", "ls", "list"):
        cmd_status(args)
    elif args.subcommand == "sync":
        cmd_sync(args)
    elif args.subcommand in ("add-mcp", "add"):
        cmd_add_mcp(args)
    elif args.subcommand in ("rm-mcp", "rm", "remove", "delete"):
        cmd_remove_mcp(args)
    elif args.subcommand in ("prompts", "prompt", "examples"):
        cmd_prompts(args)
    elif args.subcommand == "enable-mcp":
        cmd_toggle_mcp(args, disable=False)
    elif args.subcommand == "disable-mcp":
        cmd_toggle_mcp(args, disable=True)

if __name__ == "__main__":
    main()


#!/bin/bash
# Prune boot backups older than RETENTION_DAYS across all user home directories.
#
# This exists as a script rather than an inline ExecStart because systemd does NOT
# perform shell glob expansion in ExecStart -- `find /home/*/.boot-backups` there is
# passed to find literally and always fails.
#
# Safety: the find below is deliberately scoped with -mindepth 1 and -name so that
# it can only ever match individual `boot-backup-<stamp>` directories, never the
# `.boot-backups` parent itself. Without those guards an aged parent directory
# matches -type d and `rm -rf` wipes every backup, including today's.

set -euo pipefail

RETENTION_DAYS="${RETENTION_DAYS:-30}"
BACKUP_DIR_NAME=".boot-backups"
BACKUP_GLOB="boot-backup-*"
DRY_RUN=false
HOME_ROOTS=()

usage() {
    cat <<EOF
Usage: $0 [--dry-run] [--retention-days N] [--home-root DIR]

Options:
  --dry-run             Print what would be removed without deleting anything
  --retention-days N    Remove backups older than N days (default: ${RETENTION_DAYS})
  --home-root DIR       Search DIR for */${BACKUP_DIR_NAME} (repeatable; default: /home and /root)
  --help, -h            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --retention-days)
            if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --retention-days requires a non-negative integer" >&2
                exit 2
            fi
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --home-root)
            if [[ $# -lt 2 ]]; then
                echo "Error: --home-root requires a directory" >&2
                exit 2
            fi
            HOME_ROOTS+=("$2")
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# Enumerate real home directories from passwd rather than assuming they live under
# /home. root is at /root, and LDAP/AD or non-default installs put users anywhere.
# Only interactive accounts are considered: system accounts (UID < UID_MIN) share
# placeholder homes like /nonexistent or /var/empty that must never be scanned.
enumerate_home_dirs() {
    local uid_min=1000
    if [[ -r /etc/login.defs ]]; then
        local configured
        configured="$(awk '$1 == "UID_MIN" { print $2; exit }' /etc/login.defs 2>/dev/null || true)"
        [[ "$configured" =~ ^[0-9]+$ ]] && uid_min="$configured"
    fi

    # `nobody` typically sits above UID_MIN with "/" as its home; scanning / is both
    # pointless and the widest possible blast radius for a script that calls rm -rf.
    getent passwd 2>/dev/null | awk -F: -v min="$uid_min" '
        ($3 >= min || $3 == 0) && $6 != "" && $6 != "/" { print $6 }
    ' | sort -u
}

if [[ ${#HOME_ROOTS[@]} -eq 0 ]]; then
    while IFS= read -r h; do
        [[ -n "$h" && -d "$h" ]] && HOME_ROOTS+=("$h")
    done < <(enumerate_home_dirs)
    HOME_DIRS_ARE_HOMES=true
else
    # --home-root was given: treat each argument as a container of home directories
    # (the testable shape), not as a home directory itself.
    HOME_DIRS_ARE_HOMES=false
fi

if [[ ${#HOME_ROOTS[@]} -eq 0 ]]; then
    echo "No home directories found to scan." >&2
    exit 0
fi

removed=0
scanned=0

for home_root in "${HOME_ROOTS[@]}"; do
    [[ -d "$home_root" ]] || continue

    backup_dirs=()
    if [[ "$HOME_DIRS_ARE_HOMES" == true ]]; then
        # home_root IS a home directory
        [[ -d "$home_root/$BACKUP_DIR_NAME" ]] && backup_dirs=("$home_root/$BACKUP_DIR_NAME")
    else
        # home_root CONTAINS home directories
        if [[ -d "$home_root/$BACKUP_DIR_NAME" ]]; then
            backup_dirs=("$home_root/$BACKUP_DIR_NAME")
        else
            while IFS= read -r -d '' d; do
                backup_dirs+=("$d")
            done < <(find "$home_root" -mindepth 2 -maxdepth 2 -type d -name "$BACKUP_DIR_NAME" -print0 2>/dev/null)
        fi
    fi

    for backup_dir in ${backup_dirs[@]+"${backup_dirs[@]}"}; do
        scanned=$((scanned + 1))
        while IFS= read -r -d '' old_backup; do
            if $DRY_RUN; then
                echo "would remove: $old_backup"
            else
                rm -rf -- "$old_backup"
                echo "removed: $old_backup"
            fi
            removed=$((removed + 1))
        done < <(find "$backup_dir" \
                      -mindepth 1 -maxdepth 1 \
                      -type d \
                      -name "$BACKUP_GLOB" \
                      -mtime "+${RETENTION_DAYS}" \
                      -print0 2>/dev/null)
    done
done

if $DRY_RUN; then
    echo "Scanned ${scanned} backup director(ies); ${removed} would be removed (retention ${RETENTION_DAYS}d)."
else
    echo "Scanned ${scanned} backup director(ies); removed ${removed} (retention ${RETENTION_DAYS}d)."
fi

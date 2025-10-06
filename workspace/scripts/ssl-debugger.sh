#!/bin/bash

# ssl-debugger.sh: A tool to diagnose SSL certificate issues for Java and Python.

# --- Color Definitions ---
C_RESET='\e[0m'
C_RED='\e[31m'
C_GREEN='\e[32m'
C_YELLOW='\e[33m'
C_BLUE='\e[34m'
C_CYAN='\e[36m'

# --- Helper Functions ---
function print_separator() {
    printf -- "-%.0s" {1..80}; echo
}

function print_header() {
    clear
    print_separator
    echo -e "${C_CYAN}SSL Certificate Debugger${C_RESET}"
    print_separator
}

function print_boxed_title() {
    local title="$1"
    print_separator
    echo -e "${C_YELLOW}${title}${C_RESET}"
    print_separator
}

function print_info() {
    echo -e "${C_BLUE}[INFO]${C_RESET} $1"
}

function print_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2
}

function print_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

# --- Java Functions ---
function find_java_installations() {
    # Find Java installations in common directories and from JAVA_HOME
    local java_dirs
    java_dirs=$(find /usr/lib/jvm -maxdepth 1 -type d -name "*java*" 2>/dev/null)
    if [[ -n "$JAVA_HOME" && -d "$JAVA_HOME" ]]; then
        java_dirs="$JAVA_HOME
$java_dirs"
    fi
    echo "$java_dirs"
}

function handle_java_ssl() {
    print_boxed_title "Java SSL Diagnosis"
    local java_home
    java_home=$(find_java_installations | fzf --prompt="Select Java installation: ")

    if [[ -z "$java_home" ]]; then
        read -rp "Enter Java installation path (JAVA_HOME): " java_home
    fi

    if [[ ! -d "$java_home" ]]; then
        print_error "Java installation path not found: $java_home"
        exit 1
    fi

    print_info "Using Java installation: $java_home"
    local cacerts_path
    # Look for cacerts in the standard locations
    if [[ -f "$java_home/lib/security/cacerts" ]]; then
        cacerts_path="$java_home/lib/security/cacerts"
    elif [[ -f "$java_home/jre/lib/security/cacerts" ]]; then
        cacerts_path="$java_home/jre/lib/security/cacerts"
    else
        # Fallback to a broader search if not in the standard locations
        cacerts_path=$(find "$java_home" -name cacerts -type f 2>/dev/null | head -n 1)
    fi

    if [[ -z "$cacerts_path" ]]; then
        print_error "cacerts file not found in $java_home"
        exit 1
    fi

    print_info "Found cacerts file: $cacerts_path"

    print_separator
    read -rp "Enter hostname (e.g., google.com): " hostname
    read -rp "Enter port (e.g., 443): " port
    print_separator

    if [[ -z "$hostname" || -z "$port" ]]; then
        print_error "Hostname and port are required."
        exit 1
    fi

    print_info "Testing SSL connection to $hostname:$port..."

    if openssl s_client -connect "$hostname:$port" -CAfile "$cacerts_path" < /dev/null 2>&1 | grep -q "Verify return code: 0 (ok)"; then
        print_success "SSL connection successful!"
    else
        print_error "SSL connection failed. This could be due to a missing certificate in the trust store."
        print_info "To add a certificate, you can use 'keytool' for Java or manually append the certificate to the .pem file for Python."
        print_info "Below is the detailed output from openssl:"
        openssl s_client -connect "$hostname:$port" -CAfile "$cacerts_path" < /dev/null
    fi
}

# --- Python Functions ---
function find_python_installations() {
    # Find python and python3 executables in the PATH
    which -a python python3 2>/dev/null
}

function handle_python_ssl() {
    print_boxed_title "Python SSL Diagnosis"
    local python_path
    python_path=$(find_python_installations | fzf --prompt="Select Python installation: ")

    if [[ -z "$python_path" ]]; then
        read -rp "Enter Python executable path: " python_path
    fi

    if [[ ! -x "$python_path" ]]; then
        print_error "Python executable not found: $python_path"
        exit 1
    fi

    print_info "Using Python installation: $python_path"
    local python_cacert_path
    python_cacert_path=$($python_path -c "try: import certifi; print(certifi.where())" 2>/dev/null)

    if [[ -z "$python_cacert_path" ]]; then
        print_info "'certifi' package not found. Using system default certificates."
        # Attempt to find a reasonable default
        if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
            python_cacert_path=/etc/ssl/certs/ca-certificates.crt
        elif [[ -f /etc/pki/tls/certs/ca-bundle.crt ]]; then
            python_cacert_path=/etc/pki/tls/certs/ca-bundle.crt
        else
            print_error "Could not find a default CA bundle."
            exit 1
        fi
    fi

    print_info "Using CA bundle: $python_cacert_path"

    print_separator
    read -rp "Enter hostname (e.g., google.com): " hostname
    read -rp "Enter port (e.g., 443): " port
    print_separator

    if [[ -z "$hostname" || -z "$port" ]]; then
        print_error "Hostname and port are required."
        exit 1
    fi

    print_info "Testing SSL connection to $hostname:$port..."

    if openssl s_client -connect "$hostname:$port" -CAfile "$python_cacert_path" < /dev/null 2>&1 | grep -q "Verify return code: 0 (ok)"; then
        print_success "SSL connection successful!"
    else
        print_error "SSL connection failed. This could be due to a missing certificate in the trust store."
        print_info "To add a certificate, you can manually append the certificate to the .pem file."
        print_info "Below is the detailed output from openssl:"
        openssl s_client -connect "$hostname:$port" -CAfile "$python_cacert_path" < /dev/null
    fi
}


# --- Main Menu ---
function main_menu() {
    print_header
    echo "Select the environment to debug:"
    PS3=$'\nSelect an option: '
    options=("Java" "Python" "Exit")
    select opt in "${options[@]}"; do
        case $opt in
            "Java")
                handle_java_ssl
                break
                ;;
            "Python")
                handle_python_ssl
                break
                ;;
            "Exit")
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

function main() {
    main_menu
}

main
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[1;36m'
NC='\033[0m'

# Installation settings
INSTALL_DIR="$HOME/kali_tools"
VENV_DIR="$HOME/kali_tools_venv"
PYTHON_MIN_VERSION="3.8"
PYTHON_BIN="/opt/homebrew/bin/python3"
LOG_DIR="$INSTALL_DIR/logs"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
MENU_SCRIPT="$INSTALL_DIR/kali_tools_menu.sh"

# List of Python-based tools to install in virtual environment via pip
PYTHON_TOOLS=(
    "dnsrecon>=0.10.0"
    "sublist3r>=1.0"
    "mitmproxy>=10.0.0"
    "requests>=2.31.0"
)

# List of tools to install via Homebrew
HOMEBREW_TOOLS=(
    "wireshark"  # Installs tshark
    "ngrep"
    "whois"
    "bind"       # Installs dig
    "amass"
    "nmap"
    "fping"
    "bettercap"
    "socat"
    "tcpflow"
)

# List of pre-installed tools (no installation needed)
PREINSTALLED_TOOLS=(
    "tcpdump"
    "nslookup"
    "netcat"
)

# Function to log messages to file and console
log_message() {
    local level=$1
    local message=$2
    echo -e "${CYAN}$message${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
}

# Function to check Python version and architecture
check_python_version() {
    if ! command -v "$PYTHON_BIN" &> /dev/null; then
        log_message "ERROR" "Python 3 not found at $PYTHON_BIN."
        return 1
    fi
    PYTHON_VERSION=$("$PYTHON_BIN" --version 2>&1 | awk '{print $2}')
    PYTHON_ARCH=$("$PYTHON_BIN" -c "import platform; print(platform.machine())")
    if [[ "$(printf '%s\n' "$PYTHON_MIN_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$PYTHON_MIN_VERSION" ]]; then
        log_message "ERROR" "Python $PYTHON_MIN_VERSION or higher required. Found: $PYTHON_VERSION"
        return 1
    fi
    if [[ "$PYTHON_ARCH" != "arm64" ]]; then
        log_message "ERROR" "ARM64 Python required for M1/M2 Macs. Found: $PYTHON_ARCH"
        return 1
    fi
    log_message "INFO" "Python $PYTHON_VERSION ($PYTHON_ARCH) found at $PYTHON_BIN"
    return 0
}

# Function to check if pip is installed in virtual environment
check_pip() {
    "$VENV_DIR/bin/python" -m pip --version &> /dev/null
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Function to install pip in virtual environment
install_pip() {
    log_message "INFO" "pip not found in virtual environment. Attempting to install pip..."
    if "$VENV_DIR/bin/python" -m ensurepip --upgrade --default-pip 2>/dev/null; then
        log_message "INFO" "pip installed successfully using ensurepip."
        "$VENV_DIR/bin/python" -m pip install --upgrade pip
        return 0
    else
        log_message "INFO" "ensurepip failed. Attempting to install pip using get-pip.py..."
        curl -sSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        if [ $? -ne 0 ]; then
            log_message "ERROR" "Failed to download get-pip.py"
            return 1
        fi
        "$VENV_DIR/bin/python" get-pip.py
        if [ $? -ne 0 ]; then
            log_message "ERROR" "Failed to install pip using get-pip.py"
            rm -f get-pip.py
            return 1
        fi
        rm -f get-pip.py
        log_message "INFO" "pip installed successfully."
        "$VENV_DIR/bin/python" -m pip install --upgrade pip
        return 0
    fi
}

# Function to check if a Python tool is installed
check_python_tool() {
    local tool=$1
    "$VENV_DIR/bin/python" -c "import ${tool//-/_}" 2>/dev/null
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a CLI tool is installed
check_tool() {
    local tool=$1
    if [ "$tool" == "netcat" ]; then
        tool="nc"
    fi
    command -v "$tool" &> /dev/null
    return $?
}

# Function to create and activate virtual environment
setup_venv() {
    log_message "INFO" "Setting up virtual environment in $VENV_DIR..."
    if [ -d "$VENV_DIR" ]; then
        log_message "INFO" "Existing virtual environment found. Checking integrity..."
        if [ ! -f "$VENV_DIR/bin/activate" ]; then
            log_message "INFO" "Virtual environment corrupted. Removing and recreating..."
            rm -rf "$VENV_DIR"
        fi
    fi
    if [ ! -d "$VENV_DIR" ]; then
        "$PYTHON_BIN" -m venv "$VENV_DIR"
        if [ $? -ne 0 ]; then
            log_message "ERROR" "Failed to create virtual environment"
            exit 1
        fi
        log_message "INFO" "Virtual environment created."
    fi
    source "$VENV_DIR/bin/activate"
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Failed to activate virtual environment"
        exit 1
    fi
}

# Create log directory
mkdir -p "$LOG_DIR"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    log_message "INFO" "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    if ! command -v brew &> /dev/null; then
        log_message "ERROR" "Failed to install Homebrew"
        exit 1
    fi
    log_message "INFO" "Homebrew installed successfully."
fi

# Install Python 3 if not present or version/architecture is incorrect
if ! check_python_version; then
    log_message "INFO" "Installing Python 3 via Homebrew..."
    brew install python
    PYTHON_BIN="/opt/homebrew/bin/python3"
    if ! check_python_version; then
        log_message "ERROR" "Failed to install compatible ARM64 Python 3"
        exit 1
    fi
fi

# Create installation directory
log_message "INFO" "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$LOG_DIR"
chmod -R 755 "$INSTALL_DIR"
chown -R $(whoami) "$INSTALL_DIR"

# Set up virtual environment
setup_venv

# Check and install pip in virtual environment
if ! check_pip; then
    if ! install_pip; then
        log_message "ERROR" "Failed to install pip in virtual environment. Please install it manually."
        exit 1
    fi
fi

# Upgrade pip in virtual environment
log_message "INFO" "Upgrading pip in virtual environment..."
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools
if [ $? -ne 0 ]; then
    log_message "ERROR" "Failed to upgrade pip in virtual environment"
    exit 1
fi

# Install system dependencies for Python tools (macOS M1/M2 compatibility)
log_message "INFO" "Installing system dependencies for Python tools..."
brew install libffi openssl
export LDFLAGS="-L$(brew --prefix openssl)/lib"
export CFLAGS="-I$(brew --prefix openssl)/include"

# Install Python-based tools in virtual environment
log_message "INFO" "Installing Python-based tools in virtual environment..."
for tool in "${PYTHON_TOOLS[@]}"; do
    tool_name=$(echo "$tool" | cut -d'>' -f1)
    log_message "INFO" "Installing $tool..."
    "$VENV_DIR/bin/python" -m pip install --no-binary :all: "$tool"
    if [ $? -ne 0 ]; then
        log_message "WARNING" "Failed to install $tool via pip. Attempting alternative installation..."
        if [ "$tool_name" == "sublist3r" ]; then
            "$VENV_DIR/bin/python" -m pip install git+https://github.com/aboul3la/Sublist3r.git
        else
            "$VENV_DIR/bin/python" -m pip install "$tool" --no-cache-dir --index-url https://pypi.org/simple
        fi
        if [ $? -ne 0 ]; then
            log_message "ERROR" "Failed to install $tool. Please install it manually using: $VENV_DIR/bin/pip install $tool"
            exit 1
        fi
    fi
    if ! check_python_tool "${tool_name//-/_}"; then
        log_message "ERROR" "$tool installed but not importable. Please check for compatibility or install manually."
        log_message "ERROR" "Try: $VENV_DIR/bin/pip install $tool"
        exit 1
    fi
    log_message "INFO" "$tool installed successfully."
done

# Install Homebrew tools
log_message "INFO" "Installing macOS-compatible network analysis tools via Homebrew..."
for tool in "${HOMEBREW_TOOLS[@]}"; do
    log_message "INFO" "Installing $tool..."
    brew install "$tool" || {
        log_message "WARNING" "Failed to install $tool via Homebrew. It may already be installed or require manual installation."
        continue
    }
done

# Fix permissions for tshark (Wireshark's dumpcap)
if command -v tshark &> /dev/null; then
    log_message "INFO" "Fixing permissions for tshark (dumpcap)..."
    DUMPCAP_PATH=$(brew --prefix wireshark)/bin/dumpcap
    if [ -f "$DUMPCAP_PATH" ]; then
        sudo chmod 755 "$DUMPCAP_PATH"
        sudo chown root:wheel "$DUMPCAP_PATH"
        log_message "INFO" "Permissions fixed for $DUMPCAP_PATH"
    else
        log_message "WARNING" "dumpcap not found at $DUMPCAP_PATH. tshark may require manual permission setup."
    fi
fi

# Verify pre-installed tools
log_message "INFO" "Verifying pre-installed tools..."
for tool in "${PREINSTALLED_TOOLS[@]}"; do
    if check_tool "$tool"; then
        log_message "INFO" "$tool is available."
    else
        log_message "WARNING" "$tool is not available. It should be pre-installed on macOS. Please check your system."
    fi
done

# Copy kali_tools_menu.sh to installation directory
if [ -f "kali_tools_menu.sh" ]; then
    cp "kali_tools_menu.sh" "$MENU_SCRIPT"
    chmod +x "$MENU_SCRIPT"
    log_message "INFO" "Copied kali_tools_menu.sh to $MENU_SCRIPT"
else
    log_message "ERROR" "kali_tools_menu.sh not found in current directory"
    exit 1
fi

# Create wrapper script
log_message "INFO" "Creating wrapper script for virtual environment..."
cat > "$INSTALL_DIR/kali_tools_wrapper.sh" << EOF
#!/bin/bash
VENV_DIR="$VENV_DIR"
MENU_SCRIPT="$MENU_SCRIPT"

# Check if virtual environment exists
if [ ! -d "\$VENV_DIR" ] || [ ! -f "\$VENV_DIR/bin/activate" ]; then
    echo -e "${RED}Error: Virtual environment not found at \$VENV_DIR. Please run install.sh to set it up.${NC}"
    exit 1
fi

# Check Python architecture
PYTHON_ARCH="\$("\$VENV_DIR/bin/python" -c "import platform; print(platform.machine())")"
if [ "\$PYTHON_ARCH" != "arm64" ]; then
    echo -e "${RED}Error: Virtual environment uses \$PYTHON_ARCH Python. ARM64 Python required for M1/M2 Macs.${NC}"
    echo -e "${RED}Please recreate the virtual environment using /opt/homebrew/bin/python3.${NC}"
    exit 1
fi

# Check if Python tools are installed
for tool in dnsrecon sublist3r mitmproxy requests; do
    if ! "\$VENV_DIR/bin/python" -c "import \$tool" 2>/dev/null; then
        echo -e "${RED}Error: \$tool module not found in virtual environment.${NC}"
        echo -e "${RED}Please run: \$VENV_DIR/bin/pip install \$tool${NC}"
        exit 1
    fi
done

# Check if menu script exists
if [ ! -f "\$MENU_SCRIPT" ]; then
    echo -e "${RED}Error: kali_tools_menu.sh not found at \$MENU_SCRIPT${NC}"
    exit 1
fi

# Activate virtual environment
source "\$VENV_DIR/bin/activate"
if [ \$? -ne 0 ]; then
    echo -e "${RED}Error: Failed to activate virtual environment at \$VENV_DIR${NC}"
    exit 1
fi

# Run menu script
"\$MENU_SCRIPT" "\$@"
if [ \$? -ne 0 ]; then
    echo -e "${RED}Error: Failed to run kali_tools_menu.sh${NC}"
    deactivate
    exit 1
fi

# Deactivate virtual environment
deactivate
EOF
chmod +x "$INSTALL_DIR/kali_tools_wrapper.sh"
log_message "INFO" "Wrapper script created at $INSTALL_DIR/kali_tools_wrapper.sh"

# Create symbolic link
log_message "INFO" "Creating symbolic link..."
sudo rm -f "/usr/local/bin/kali_tools"
sudo ln -sf "$INSTALL_DIR/kali_tools_wrapper.sh" "/usr/local/bin/kali_tools"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Failed to create symbolic link for kali_tools"
    exit 1
fi

# Verify installation
if command -v kali_tools &> /dev/null; then
    log_message "INFO" "Kali Tools for macOS installed successfully!"
    echo -e "${GREEN}Run 'kali_tools' to start the menu.${NC}"
    echo -e "${GREEN}Use 'sudo kali_tools' for tools requiring elevated privileges (e.g., tshark, tcpdump, ngrep, bettercap, tcpflow).${NC}"
    echo -e "${GREEN}Installation log: $LOG_FILE${NC}"
else
    log_message "ERROR" "Failed to create symbolic link for kali_tools"
    exit 1
fi
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
NC='\033[0m' # white

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

INVOKED_AS="$(basename "$0")"
if [[ "$INVOKED_AS" == "vynx" ]]; then
    _SOURCE="${BASH_SOURCE[0]}"
    while [ -L "$_SOURCE" ]; do
        _DIR="$(cd -P "$(dirname "$_SOURCE")" && pwd)"
        _SOURCE="$(readlink "$_SOURCE")"
        [[ "$_SOURCE" != /* ]] && _SOURCE="$_DIR/$_SOURCE"
    done
    SCRIPT_DIR="$(cd -P "$(dirname "$_SOURCE")" && pwd)"

    LIB_DIR="$SCRIPT_DIR/sdata/cli/lib"
    BASE_DIR="$SCRIPT_DIR"
    VERBOSE=false
    TEMP_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose) VERBOSE=true; shift ;;
            *) TEMP_ARGS+=("$1"); shift ;;
        esac
    done
    set -- "${TEMP_ARGS[@]}"

    COMMAND="$1"; shift
    case "$COMMAND" in
        run|restart|update|remove-cli|hyprset)
            if [ -f "$LIB_DIR/${COMMAND}.sh" ]; then
                source "$LIB_DIR/${COMMAND}.sh" "$@"
                exit $?
            else
                echo -e "${RED}Error: $COMMAND not found${NC}"; exit 1
            fi
            ;;
        "")
            echo "Usage: vynx [-v] {run|restart|update|remove-cli|hyprset}"; exit 1 ;;
        *)
            echo -e "${RED}Invalid command: $COMMAND${NC}"; exit 1 ;;
    esac
fi

DO_PULL=true
VERBOSE=false
FORCE_INSTALL=false
BACKUP=true
FULL_INSTALL=false
NO_CONFIRM=false

for arg in "$@"; do
    case $arg in
        --no-pull)
            DO_PULL=false
            ;;
        --no-backup)
            BACKUP=false
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        --force-install)
            FORCE_INSTALL=true
            ;;
        --full-install)
            FULL_INSTALL=true
            ;;
        --no-confirm)
            NO_CONFIRM=true
            FORCE_INSTALL=true
            ;;
        *)
            echo -e "${RED}Unknown flag: $arg${NC}"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-pull          Skip git pull operation"
            echo "  --no-backup        Skip backup of existing config"
            echo "  --force-install    Skip illogical-impulse check"
            echo "  --full-install     Install original dots first, then ii-vynx"
            echo "  --no-confirm       Skip all confirmations and checks"
            echo "  -v, --verbose      Enable verbose output"
            exit 1
            ;;
    esac
done

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE] $1${NC}"
    fi
}

setup_hyprland_overrides() {
    local OVERRIDES_DIR="$HOME/.config/hypr/hyprland/shellOverrides"
    local OVERRIDES_FILE="$OVERRIDES_DIR/main.lua"
    local REPO_DEFAULTS="$SCRIPT_DIR/dots/.config/hypr/hyprland/shellOverrides/repo-defaults.lua"
    local HYPRSET="$SCRIPT_DIR/sdata/cli/lib/hyprset.lua"

    echo -e "${NC}• Setting up Hyprland Lua overrides...${NC}"

    if [ ! -d "$OVERRIDES_DIR" ]; then
        mkdir -p "$OVERRIDES_DIR"
    fi

    if [ ! -f "$REPO_DEFAULTS" ]; then
        echo -e "${RED}⚠ Error: Couldn't find repo defaults ($REPO_DEFAULTS), please report this bug!${NC}"
        return 1
    fi

    if [ ! -f "$OVERRIDES_FILE" ]; then
        cp "$REPO_DEFAULTS" "$OVERRIDES_FILE"
        echo -e "${GREEN}✓ Fresh install: copied repo defaults to shellOverrides${NC}"
    else
        echo -e "${BLUE}• Merging repo defaults (preserving local changes)...${NC}"
        if [ -f "$HYPRSET" ]; then
            lua "$HYPRSET" merge "$REPO_DEFAULTS"
            echo -e "${GREEN}✓ Merge complete${NC}"
        else
            echo -e "${YELLOW}⚠ hyprset.lua not found, falling back to cp${NC}"
            cp "$REPO_DEFAULTS" "$OVERRIDES_FILE"
        fi
    fi
}


install_original_dots() {
    echo -e "${RED}Original dots are not installed! Do you want to install them? (y/n): ${NC}"
    read -r setup_response
    
    if [[ ! "$setup_response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}✗ Setup cancelled. Try installing the dots manually.${NC}"
        exit 1
    fi

    printf "${GREEN}
Subcommands:
    install        (Re)Install/Update illogical-impulse.
                    Note: To update to the latest, manually run \"git stash && git pull\" first.
    install-deps   Run the install step \"1. Install dependencies\"
    install-setups Run the install step \"2. Setup for permissions/services etc\"
    install-files  Run the install step \"3. Copying config files\"

    exp-update     (Experimental) Update illogical-impulse without fully reinstall.
    exp-merge      (Experimental) Merge upstream changes with local configs using git rebase.
${NC}"
    echo ""
    echo -e "${RED}Enter the subcommand: ${NC}"
    read -r setup_subcommand
    
    if [[ "$setup_subcommand" == "help" || "$setup_subcommand" == "virtmon" || "$setup_subcommand" == "checkdeps" || "$setup_subcommand" == "uninstall" || "$setup_subcommand" == "resetfirstrun" ]]; then
        echo ""
        echo -e "${RED}✗ Setup cancelled, please don't use dev-only subcommands. Or use it with the original script.${NC}"
        exit 1
    fi

    bash "$SCRIPT_DIR/setup" "$setup_subcommand"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Setup completed successfully!${NC}"
        echo -e "${BLUE}Continuing with ii-vynx installation...${NC}"
        echo ""
    else
        echo -e "${RED}✗ Setup failed! Try installing the dots manually.${NC}"
        exit 1
    fi
}

install_cli() {
    local BIN_PATH="$HOME/.local/bin"
    local CLI_NAME="vynx"
    local TARGET="$BIN_PATH/$CLI_NAME"

    echo -e "${BLUE}• Installing Vynx CLI tool (user mode)...${NC}"

    if [ ! -d "$BIN_PATH" ]; then
        mkdir -p "$BIN_PATH"
        echo -e "${GREEN}✓ Created $BIN_PATH${NC}"
    fi

    if [[ ":$PATH:" != *":$BIN_PATH:"* ]]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}    ⚠ CLI is not in your PATH!${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${RED}You won't be able to use CLI globally. But shell integration is still available.${NC}"
        echo -e "${RED}Add this line to your shell config (~/.bashrc, ~/.zshrc, refer to wiki for fish shell):${NC}"
        echo -e "${GREEN}   export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo ""
        echo -e "${CYAN}Continuing...${NC}"
        if [ "$NO_CONFIRM" = false ]; then
            sleep 3.0
        fi
        echo ""
    fi

    chmod +x "$SCRIPT_DIR/setup-ii-vynx.sh"
    if [ -d "$SCRIPT_DIR/sdata/cli/lib" ]; then
        chmod +x "$SCRIPT_DIR/sdata/cli/lib/"*.sh "$SCRIPT_DIR/sdata/cli/lib/"*.lua 2>/dev/null || true
    fi

    ln -sf "$SCRIPT_DIR/setup-ii-vynx.sh" "$TARGET"

    echo -e "${GREEN}✓ Symlinked $CLI_NAME → $TARGET${NC}"
}

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}          ii-vynx setup     ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$NO_CONFIRM" = false ]; then
    echo -e "${NC}Welcome to the ii-vynx setup script!${NC}"
    echo -e "${NC}This script will install ii-vynx on your system.${NC}"
    echo ""
fi

log_verbose "Verbose mode enabled"
log_verbose "DO_PULL=$DO_PULL"
log_verbose "FORCE_INSTALL=$FORCE_INSTALL"
log_verbose "BACKUP=$BACKUP"
log_verbose "FULL_INSTALL=$FULL_INSTALL"
log_verbose "NO_CONFIRM=$NO_CONFIRM"

if [ "$NO_CONFIRM" = true ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}    ⚠ No-confirm mode enabled${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Skipping all confirmations...${NC}"
    echo -e "${RED}WARNING: This may cause issues!${NC}"
    echo ""
    sleep 4.0
fi

if [ "$FULL_INSTALL" = true ]; then
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Full installation mode enabled${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Installing original dots first...${NC}"
    
    install_original_dots
fi

if [ "$NO_CONFIRM" = false ]; then
    if [ "$DO_PULL" = false ]; then
        echo -e "${YELLOW}--no-pull flag used, skipping git pull.${NC}"
    fi

    echo -e "${BLUE}Your current Quickshell configuration will be backed up and overwritten.${NC}"
    if [ "$BACKUP" = false ]; then
        echo ""
        echo -e "${RED}WARNING: You've used --no-backup flag, skipping the backup process.${NC}"
    fi
    echo -e "${RED}Do you want to continue? (y/n): ${NC}"
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operation cancelled.${NC}"
        exit 0
    fi
    echo ""
fi

CONFIG_DIR="$HOME/.config"
CHECK_DIR="$CONFIG_DIR/illogical-impulse"
TARGET_DIR="$CONFIG_DIR/quickshell/ii"
SOURCE_DIR="$SCRIPT_DIR/dots/.config/quickshell/ii"

log_verbose "CONFIG_DIR=$CONFIG_DIR"
log_verbose "CHECK_DIR=$CHECK_DIR"
log_verbose "TARGET_DIR=$TARGET_DIR"
log_verbose "SCRIPT_DIR=$SCRIPT_DIR"
log_verbose "SOURCE_DIR=$SOURCE_DIR"

if [ "$DO_PULL" = true ]; then
    echo -e "${NC}• Checking for updates...${NC}"
    
    if [ -d "$SCRIPT_DIR/.git" ]; then
        log_verbose "Git repository found at $SCRIPT_DIR/.git"
        cd "$SCRIPT_DIR"
        git pull
        if [ $? -ne 0 ]; then
            echo -e "${RED}An error occurred while running git pull!${NC}"
            exit 1
        fi
        git submodule update --init --recursive
        if [ $? -ne 0 ]; then
            echo -e "${RED}An error occurred while updating git submodules!${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Repository updated${NC}"
        echo ""
    else
        log_verbose "Git repository not found"
        echo -e "${YELLOW}WARNING: Couldn't find the repository, you may have to run git pull manually or clone the repository again.${NC}"
        echo ""
    fi
else
    echo -e "${YELLOW}Skipping git pull (--no-pull flag used)${NC}"
    echo ""
fi

if [ "$FORCE_INSTALL" = false ] && [ "$FULL_INSTALL" = false ]; then
    log_verbose "Checking for illogical-impulse directory"
    if [ ! -d "$CHECK_DIR" ]; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}  ERROR: Couldn't find illogical-impulse!${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        install_original_dots
    fi
    log_verbose "illogical-impulse directory found"
else
    log_verbose "Skipping illogical-impulse check (--force-install or --full-install used)"
fi

log_verbose "Checking source directory"
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}ERROR: Source directory not found, please run git pull manually or clone the repository again: $SOURCE_DIR${NC}"
    exit 1
fi
log_verbose "Source directory found"

log_verbose "Creating parent directory: $(dirname "$TARGET_DIR")"
mkdir -p "$(dirname "$TARGET_DIR")"

if [ "$BACKUP" = true ]; then
    log_verbose "Checking for existing directory"
    if [ -d "$TARGET_DIR" ]; then
        BACKUP_DIR="${TARGET_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        log_verbose "Existing directory found, creating backup: $BACKUP_DIR"
        echo -e "${YELLOW}Backing up the current Quickshell configuration: $BACKUP_DIR${NC}"
        mv "$TARGET_DIR" "$BACKUP_DIR"
    else
        log_verbose "No existing directory found, skipping backup"
    fi
else 
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}      ⚠ No backup flag used${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Skipping the backup process...${NC}"
fi

if command -v vynx &> /dev/null; then
    install_cli
else
    if [ "$NO_CONFIRM" = true ]; then
        install_cli
    else
        echo ""
        echo -e "${BLUE}• Vynx CLI is not installed or not in your PATH. CLI is required for some features yet still optional. ${NC}"
        echo -e "${BLUE}• Do you want to install it? (y/n): ${NC}"
        read -r cli_response
        if [[ "$cli_response" =~ ^[Yy]$ ]]; then
            install_cli
        else
            echo -e "${YELLOW}⚠ Skipping CLI installation.${NC}"
        fi
    fi
fi

echo ""
echo -e "${NC}• Copying...${NC}"
log_verbose "Copying from $SOURCE_DIR to $TARGET_DIR"
cp -r "$SOURCE_DIR/." "$TARGET_DIR/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully copied: $TARGET_DIR${NC}"
    sleep 1.0
    setup_hyprland_overrides
else
    echo -e "${RED}✗ An error occurred while copying!${NC}"
    exit 1
fi

echo ""
echo -e "${NC}• Restarting Hyprland & Quickshell...${NC}"
sleep 0.5

log_verbose "Killing Quickshell process"
pkill -x qs

log_verbose "Reloading Hyprland"
hyprctl reload

sleep 1.0

log_verbose "Starting Quickshell with config: ii"
nohup qs -c ii > /dev/null 2>&1 &

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Quickshell started${NC}"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}         Setup completed!    ${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Press SUPER+CTRL+R if your shell does not starts.${NC}"
    echo ""
    log_verbose "Script completed successfully"
    echo -e "${BLUE}Please star this project on GitHub: ${NC}https://github.com/vaguesyntax/ii-vynx"
    echo -e "${BLUE}And report any issues: ${NC}https://github.com/vaguesyntax/ii-vynx/issues"
    echo ""
else
    echo -e "${RED}✗ An error occurred while starting Quickshell!${NC}"
    exit 1
fi

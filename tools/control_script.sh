#!/bin/bash

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find project root directory by .git folder
find_project_root() {
    local current_dir="$PWD"

    # Сначала ищем .git в родительских директориях
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
    done

    # Если .git не найден, проверяем наличие директории tools/
    if [[ "${PWD##*/}" == "tools" ]]; then
        echo "$(dirname "$PWD")"
    else
        echo "$PWD"
    fi
}


# Create Python virtual environment
create_venv() {
    if [[ -d "$PWD/.venv" ]]; then
        echo -e "${YELLOW}Virtual environment already exists at: $PWD/.venv${NC}"
        return 1
    fi

    echo -e "${GREEN}Creating virtual environment at: $PWD/.venv${NC}"
    python3 -m venv "$PWD/.venv" || {
        echo -e "${RED}Failed to create virtual environment${NC}"
        return 1
    }
}

# Activate virtual environment
activate_venv() {
    if [[ ! -d "$PWD/.venv" ]]; then
        echo -e "${RED}Virtual environment not found at $PWD${NC}"
        return 1
    fi

    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo -e "${YELLOW}Already in virtual environment: $VIRTUAL_ENV${NC}"
        return 0
    fi

    source "$PWD/.venv/bin/activate" || {
        echo -e "${RED}Failed to activate virtual environment${NC}"
        exit 1
    }
    echo -e "${GREEN}Activated virtual environment at $PWD${NC}"
}

# Install base dependencies
install_dependencies() {
    echo -e "${GREEN}Installing system dependencies...${NC}"

    python3 -m pip install truststore || {
        echo -e "${RED}Failed to install truststore${NC}"
        return 1
    }

    pip install --upgrade pip || {
        echo -e "${RED}Failed to upgrade pip${NC}"
        return 1
    }

    if [[ -f "requirements.txt" ]]; then
        pip install --upgrade -r requirements.txt || {
            echo -e "${RED}Failed to install requirements${NC}"
            return 1
        }
    else
        echo -e "${YELLOW}requirements.txt not found${NC}"
    fi

    pip install build stdeb || {
        echo -e "${RED}Failed to install build tools${NC}"
        return 1
    }

    echo -e "${GREEN}Base dependencies installed${NC}"
}

# Build DEB package
build_deb_package() {
    echo -e "${GREEN}Building DEB package...${NC}"

    if ! command -v dpkg-deb >/dev/null 2>&1; then
        echo -e "${RED}dpkg-deb not found. Install dpkg: sudo apt-get install dpkg-dev${NC}"
        return 1
    fi

    python3 setup.py --command-packages=stdeb.command bdist_deb || {
        echo -e "${RED}DEB package build failed${NC}"
        return 1
    }

    echo -e "${GREEN}DEB package built successfully${NC}"
}

# Build Python package
build_python_package() {
    echo -e "${GREEN}Building Python package...${NC}"

    python3 -m build || {
        echo -e "${RED}Python package build failed${NC}"
        return 1
    }

    echo -e "${GREEN}Python package built successfully${NC}"
}

# Install package locally
install_local_package() {
    echo -e "${GREEN}Installing local package...${NC}"

    pip install . || {
        echo -e "${RED}Local package installation failed${NC}"
        return 1
    }

    echo -e "${GREEN}Package installed in development mode${NC}"
}

# Display help information
show_help() {
    echo -e "${GREEN}Project management script${NC}"
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --venv           Create and activate virtual environment"
    echo "  --build_deb      Build DEB package"
    echo "  --build_python   Build Python package"
    echo "  --install_local  Install package locally (requires activated venv)"
    echo "  --all            Full build process: venv + dependencies + all packages"
    echo "  --help           Show this help"
    echo
    echo "Examples:"
    echo "  $0 --venv --build_python  # Setup environment and build Python package"
    echo "  $0 --all                  # Complete rebuild process"
}

# Main control flow
main() {
    local project_root
    project_root=$(find_project_root)

    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --venv)
                cd $project_root
                create_venv
                activate_venv
                install_dependencies
                ;;
            --build_deb)
                cd $project_root
                activate_venv
                build_deb_package
                ;;
            --build_python)
                cd $project_root
                activate_venv
                build_python_package
                ;;
            --install_local)
                cd $project_root
                activate_venv
                install_local_package
                ;;
            --activate_venv)
                cd $project_root
                activate_venv
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Entry point
main "$@"
#!/bin/bash

# Ensure pyenv is available
if ! command -v pyenv &> /dev/null; then
    echo "pyenv is not installed or not in your PATH."
    echo "Please install pyenv to continue: https://github.com/pyenv/pyenv#installation"
    exit 1
fi

# Initialize pyenv
eval "$(pyenv init -)"

VENV_NAME="snowsql-otp"
VENV_PATH="$(pyenv root)/versions/${VENV_NAME}"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Check if the virtual environment exists
if [ ! -d "${VENV_PATH}" ]; then
    echo "Creating pyenv virtual environment '${VENV_NAME}'..."
    
    # Find a suitable python version managed by pyenv
    PYTHON_VERSION=$(pyenv versions --bare | grep -E '^3\.[0-9]+\.[0-9]+$' | tail -n 1)
    
    if [ -z "$PYTHON_VERSION" ]; then
        echo "Could not find a Python 3 version managed by pyenv."
        echo "Please install a version (e.g., 'pyenv install 3.10.4') and try again."
        exit 1
    fi
    
    echo "Using Python version ${PYTHON_VERSION} to create virtualenv."
    # Use the specific python version to create the venv
    if ! PYENV_VERSION=$PYTHON_VERSION pyenv exec python3 -m venv "${VENV_PATH}"; then
        echo "Failed to create virtualenv '${VENV_NAME}'."
        exit 1
    fi
    
    echo "Installing 'pyotp' package from public PyPI..."
    if ! "${VENV_PATH}/bin/pip" install --index-url https://pypi.org/simple pyotp; then
        echo "Failed to install 'pyotp' package."
        exit 1
    fi
fi

# Run snowsql with the OTP from the pyenv virtual environment
MFA_PASSCODE=$("${VENV_PATH}/bin/python" "${SCRIPT_DIR}/snowflake-otp.py")

if [ -z "$MFA_PASSCODE" ]; then
    echo "Failed to generate MFA passcode from snowflake-otp.py"
    exit 1
fi

echo "Virtual environment is ready. Starting snowsql..."

snowsql --mfa-passcode "${MFA_PASSCODE}" "$@"

#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Source this file instead:"
  echo "  source scripts/env.sh"
  exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOL_ROOT="${WORKSPACE_ROOT}/.tooling"

path_prepend() {
  local candidate="$1"
  [[ -d "${candidate}" ]] || return 0
  case ":${PATH}:" in
    *":${candidate}:"*) ;;
    *) export PATH="${candidate}:${PATH}" ;;
  esac
}

path_remove() {
  local candidate="$1"
  local filtered_path=""
  local path_entry=""
  local path_ifs="${IFS}"

  IFS=':'
  for path_entry in ${PATH}; do
    [[ -n "${path_entry}" ]] || continue
    [[ "${path_entry}" == "${candidate}" ]] && continue
    if [[ -z "${filtered_path}" ]]; then
      filtered_path="${path_entry}"
    else
      filtered_path="${filtered_path}:${path_entry}"
    fi
  done
  IFS="${path_ifs}"

  export PATH="${filtered_path}"
}

export EM3555_CODEX_WORKSPACE="${WORKSPACE_ROOT}"
export GSDK_DIR="${GSDK_DIR:-${WORKSPACE_ROOT}/gecko-sdk/v3.0}"
export GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-${TOOL_ROOT}/opt/ghidra/current/libexec}"
export GHIDRA_PROJECT_DIR="${GHIDRA_PROJECT_DIR:-${WORKSPACE_ROOT}/.ghidra}"

is_studio_python_root() {
  local candidate="$1"
  [[ -d "${candidate}" ]] || return 1
  compgen -G "${candidate}/bin/python3*" >/dev/null || return 1
  if ! compgen -G "${candidate}/bin/libpython3*.so*" >/dev/null \
    && ! compgen -G "${candidate}/bin/libpython3*.dylib" >/dev/null \
    && ! compgen -G "${candidate}/lib/libpython3*.so*" >/dev/null \
    && ! compgen -G "${candidate}/lib/libpython3*.dylib" >/dev/null; then
    return 1
  fi
  compgen -G "${candidate}/lib/python3.*" >/dev/null || return 1
}

find_studio_python_root() {
  local candidate
  for candidate in \
    "${TOOL_ROOT}/opt/slc-python/current" \
    "${HOME}/.silabs/slt/installs/archive/python-v"*/python \
    "${HOME}/.silabs/slt/installs/"*/python-v*/python \
    "/Applications/Simplicity Studio.app/Contents/Eclipse/developer/adapter_packs/python" \
    "${HOME}/.silabs/legacy/apps/Simplicity Studio 5.app/Contents/Eclipse/developer/adapter_packs/python"; do
    if is_studio_python_root "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

if [[ -z "${STUDIO_PYTHON3_PATH:-}" ]]; then
  if studio_python_root="$(find_studio_python_root)"; then
    export STUDIO_PYTHON3_PATH="${studio_python_root}"
  fi
fi

export WORKSPACE_VENV_DIR="${WORKSPACE_ROOT}/.venv"
export WORKSPACE_VENV_PYTHON="${WORKSPACE_VENV_DIR}/bin/python3"
path_remove "${WORKSPACE_VENV_DIR}/bin"
path_remove "${TOOL_ROOT}/opt/slc-java/current/bin"
path_remove "${TOOL_ROOT}/opt/slc-python/current/bin"
if [[ -n "${STUDIO_PYTHON3_PATH:-}" ]]; then
  path_remove "${STUDIO_PYTHON3_PATH}/bin"
fi
path_prepend "${TOOL_ROOT}/bin"
path_prepend "${TOOL_ROOT}/opt/arm-gnu-toolchain/current/bin"
path_prepend "${TOOL_ROOT}/opt/jlink/current/bin"
path_prepend "${TOOL_ROOT}/opt/ghidra/current/bin"

if command -v java >/dev/null 2>&1; then
  java_home="$(
    java -XshowSettings:properties -version 2>&1 \
      | awk -F'= ' '/^[[:space:]]*java.home = / {print $2; exit}'
  )"
  if [[ -n "${java_home}" ]]; then
    export JAVA_HOME="${java_home}"
  fi
fi

unset -f is_studio_python_root
unset -f find_studio_python_root
unset -f path_remove
unset -f path_prepend

#!/usr/bin/env bash

em3555_env_return_or_exit() {
  local status="$1"
  return "${status}" 2>/dev/null || exit "${status}"
}

em3555_env_is_sourced() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    case "${ZSH_EVAL_CONTEXT:-}" in
      *:file|*:file:*) return 0 ;;
    esac
    return 1
  fi

  if [[ -n "${BASH_VERSION:-}" ]]; then
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    return
  fi

  return 1
}

em3555_env_script_path() {
  if [[ -n "${BASH_VERSION:-}" ]]; then
    printf '%s\n' "${BASH_SOURCE[0]}"
    return
  fi

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    eval 'printf "%s\n" "${(%):-%x}"'
    return
  fi

  return 1
}

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

  filtered_path="$(
    printf '%s' "${PATH}" \
      | awk -v RS=':' -v ORS=':' -v candidate="${candidate}" '
          length($0) && $0 != candidate { print }
        '
  )"
  filtered_path="${filtered_path%:}"

  export PATH="${filtered_path}"
}

find_first_match() {
  local search_root="$1"
  local name_pattern="$2"
  local match=""

  [[ -d "${search_root}" ]] || return 1

  match="$(find "${search_root}" -name "${name_pattern}" -print -quit 2>/dev/null)"
  [[ -n "${match}" ]]
}

print_glob_matches() {
  local pattern="$1"
  local old_nullglob=""
  local -a matches=()

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    eval 'matches=( ${~pattern}(N) )'
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    old_nullglob="$(shopt -p nullglob 2>/dev/null || true)"
    shopt -s nullglob
    matches=( $pattern )
    if [[ -n "${old_nullglob}" ]]; then
      eval "${old_nullglob}"
    else
      shopt -u nullglob
    fi
  else
    return 1
  fi

  (( ${#matches[@]} == 0 )) && return 0
  printf '%s\n' "${matches[@]}"
}

is_studio_python_root() {
  local candidate="$1"

  [[ -d "${candidate}" ]] || return 1
  find_first_match "${candidate}/bin" 'python3*' || return 1
  if ! find_first_match "${candidate}/bin" 'libpython3*.so*' \
    && ! find_first_match "${candidate}/bin" 'libpython3*.dylib' \
    && ! find_first_match "${candidate}/lib" 'libpython3*.so*' \
    && ! find_first_match "${candidate}/lib" 'libpython3*.dylib'; then
    return 1
  fi
  find_first_match "${candidate}/lib" 'python3.*'
}

find_studio_python_root() {
  local candidate=""
  local pattern=""

  for candidate in \
    "${TOOL_ROOT}/opt/slc-python/current" \
    "/Applications/Simplicity Studio.app/Contents/Eclipse/developer/adapter_packs/python" \
    "${HOME}/.silabs/legacy/apps/Simplicity Studio 5.app/Contents/Eclipse/developer/adapter_packs/python"; do
    if is_studio_python_root "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  for pattern in \
    "${HOME}/.silabs/slt/installs/archive/python-v*/python" \
    "${HOME}/.silabs/slt/installs/*/python-v*/python"; do
    while IFS= read -r candidate; do
      [[ -n "${candidate}" ]] || continue
      if is_studio_python_root "${candidate}"; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    done < <(print_glob_matches "${pattern}")
  done

  return 1
}

if ! em3555_env_is_sourced; then
  echo "Source this file instead:"
  echo "  source scripts/env.sh"
  exit 1
fi

script_path="$(em3555_env_script_path)" || {
  echo "Unable to resolve scripts/env.sh path for this shell." >&2
  em3555_env_return_or_exit 1
}
SCRIPT_DIR="$(cd "$(dirname "${script_path}")" && pwd)" || {
  echo "Unable to resolve the scripts directory." >&2
  em3555_env_return_or_exit 1
}
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)" || {
  echo "Unable to resolve the workspace root." >&2
  em3555_env_return_or_exit 1
}
TOOL_ROOT="${WORKSPACE_ROOT}/.tooling"
export WORKSPACE_ROOT
export EM3555_CODEX_WORKSPACE="${WORKSPACE_ROOT}"
export GSDK_DIR="${GSDK_DIR:-${WORKSPACE_ROOT}/gecko-sdk/v3.0}"
export GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-${TOOL_ROOT}/opt/ghidra/current/libexec}"
export GHIDRA_PROJECT_DIR="${GHIDRA_PROJECT_DIR:-${WORKSPACE_ROOT}/.ghidra}"

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

unset script_path
unset studio_python_root
unset java_home

unset -f is_studio_python_root
unset -f find_studio_python_root
unset -f print_glob_matches
unset -f find_first_match
unset -f path_remove
unset -f path_prepend
unset -f em3555_env_script_path
unset -f em3555_env_is_sourced
unset -f em3555_env_return_or_exit

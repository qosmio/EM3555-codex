#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${WORKSPACE_ROOT}/EM3555-osram-rgbw-flex"
SDK_V30_DIR="${WORKSPACE_ROOT}/gecko-sdk-v3.0"
SDK_COMPAT_ROOT="${WORKSPACE_ROOT}/gecko-sdk"
TOOL_ROOT="${WORKSPACE_ROOT}/.tooling"
BIN_ROOT="${TOOL_ROOT}/bin"
OPT_ROOT="${TOOL_ROOT}/opt"
DOWNLOAD_ROOT="${TOOL_ROOT}/downloads"
VENV_DIR="${WORKSPACE_ROOT}/.venv"
USER_BIN_DIR="${HOME}/.local/bin"
PROFILE_SNIPPET_DIR="${HOME}/.config/profile.d"
PROFILE_SNIPPET="${PROFILE_SNIPPET_DIR}/EM3555-codex.sh"
GHIDRA_PROJECT_DIR="${WORKSPACE_ROOT}/.ghidra"

DEFAULT_ARM_GNU_TOOLCHAIN_X64_URL="https://developer.arm.com/-/media/Files/downloads/gnu/15.2.rel1/binrel/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi.tar.xz"
DEFAULT_ARM_GNU_TOOLCHAIN_ARM64_URL="https://developer.arm.com/-/media/Files/downloads/gnu/15.2.rel1/binrel/arm-gnu-toolchain-15.2.rel1-aarch64-arm-none-eabi.tar.xz"
DEFAULT_COMMANDER_URL="https://www.silabs.com/documents/public/software/SimplicityCommander-Linux.zip"
DEFAULT_UV_INSTALLER_URL="https://astral.sh/uv/install.sh"
DEFAULT_SLT_VERSION="1.1.0"
DEFAULT_SLT_X64_URL="https://www.silabs.com/documents/public/software/slt-cli-${DEFAULT_SLT_VERSION}-linux-x64.zip"
DEFAULT_GHIDRA_RELEASE_API_URL="https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest"
DEFAULT_GITHUB_HOST="github.com"
DEFAULT_WORKSPACE_REPO_SLUG="qosmio/EM3555-codex"

APT_PACKAGES=(
  aria2
  binutils
  bsdextrautils
  build-essential
  ca-certificates
  ccache
  cmake
  curl
  elfutils
  fd-find
  file
  gdb-multiarch
  git
  graphviz
  jq
  libffi-dev
  libglib2.0-0
  libssl-dev
  libusb-1.0-0
  ltrace
  make
  minicom
  mold
  ninja-build
  openocd
  patchelf
  picocom
  pkg-config
  qemu-system-arm
  qemu-user-static
  ripgrep
  rsync
  shellcheck
  socat
  srecord
  strace
  tar
  tmux
  unzip
  universal-ctags
  usbutils
  wget
  xxd
  xz-utils
  zip
  antiword
  bear
  catdoc
  cppcheck
  dos2unix
  gcovr
  lcov
  pandoc
  poppler-utils
  valgrind
  xmlstarlet
  xsltproc
  yq
)

LLVM20_PACKAGES=(
  clang-20
  clang-format-20
  clang-tidy-20
  clang-tools-20
  clangd-20
  lld-20
  lldb-20
  libclang-rt-20-dev
  llvm-20
  llvm-20-dev
  llvm-20-linker-tools
  llvm-20-runtime
  llvm-20-tools
)

JAVA_FALLBACK_PACKAGES=(
  default-jre-headless
)

RE_PYTHON_PACKAGES=(
  binwalk
  capstone
  cmsis-svd
  construct
  hexdump
  intelhex
  ipython
  jinja2
  keystone-engine
  lief
  pwntools
  pyelftools
  pyghidra
  rich
  unicorn
)

SLC_PYTHON_PACKAGES=(
  jinja2
  PyYAML
)

usage() {
  cat <<'EOF'
Usage:
  ./scripts/setup-ubuntu-universal.sh

Optional env vars:
  GITHUB_TOKEN=ghp_...                 # preferred for private GitHub submodules over HTTPS
  GH_TOKEN=ghp_...                     # accepted alias for GITHUB_TOKEN
  GITHUB_API_TOKEN=ghp_...             # accepted alias for GITHUB_TOKEN
  GITHUB_USER=your-github-login        # optional; defaults to x-access-token for token auth
  GITHUB_HOST=github.com               # override only for GitHub Enterprise
  WORKSPACE_REPO_SLUG=owner/repo       # optional; defaults to qosmio/EM3555-codex
  ARM_GNU_TOOLCHAIN_ARCHIVE=/abs/path/to/arm-gnu-toolchain.tar.xz
  ARM_GNU_TOOLCHAIN_URL=https://developer.arm.com/...tar.xz
  COMMANDER_ARCHIVE=/abs/path/to/SimplicityCommander-Linux.zip
  COMMANDER_URL=https://www.silabs.com/documents/public/software/SimplicityCommander-Linux.zip
  GHIDRA_ARCHIVE=/abs/path/to/ghidra_<ver>_PUBLIC_<date>.zip
  GHIDRA_URL=https://github.com/NationalSecurityAgency/ghidra/releases/download/...
  GHIDRA_RELEASE_API_URL=https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest
  SLT_ARCHIVE=/abs/path/to/slt-cli-<ver>-linux-x64.zip
  SLT_URL=https://www.silabs.com/documents/public/software/slt-cli-<ver>-linux-x64.zip
  SLC_ARCHIVE=/abs/path/to/slc-cli-linux.zip   # optional direct override; bypasses SLT
  SLC_URL=https://...
  JLINK_ARCHIVE=/abs/path/to/JLink_Linux_*.tgz # optional; cloud images usually skip this
  JLINK_URL=https://...

Optional env vars for install locations:
  TOOL_ROOT_OVERRIDE=/custom/path
  VENV_DIR_OVERRIDE=/custom/path

Behavior:
  - installs Ubuntu/Debian dependencies with apt
  - initializes private GitHub submodules using the current clone transport, or a GitHub token if provided
  - creates gecko-sdk/v3.0 compatibility links for existing build scripts
  - creates a Python virtualenv and installs the app MCP requirements
  - installs a reverse-engineering Python toolkit into the same virtualenv
  - installs the official Arm GNU toolchain into .tooling from Arm's public tarballs
  - installs Simplicity Commander from Silicon Labs' public Linux ZIP
  - installs Ghidra headless tooling for offline reverse engineering
  - installs slc-cli either directly from an archive/URL or via Silicon Labs SLT
  - optionally installs SEGGER J-Link tools if an archive or URL is provided
  - publishes the installed tools into ~/.local/bin and writes a shell profile snippet
EOF
}

log() {
  printf '[setup] %s\n' "$*"
}

warn() {
  printf '[setup] WARN: %s\n' "$*" >&2
}

die() {
  printf '[setup] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

run_privileged() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "Need root or sudo to run: $*"
  fi
}

register_versioned_alternatives() {
  local suffix="${1:?missing suffix}"
  local candidate=""
  local base=""
  local registered=0

  command -v update-alternatives >/dev/null 2>&1 || {
    warn "update-alternatives not found; skipping registration for *-${suffix} tools"
    return 0
  }

  while IFS= read -r candidate; do
    base="$(basename "${candidate}")"
    base="${base%-${suffix}}"
    [[ -n "${base}" ]] || continue
    run_privileged update-alternatives --install "/usr/bin/${base}" "${base}" "${candidate}" 200
    registered=1
  done < <(find /usr/bin -maxdepth 1 \( -type f -o -type l \) -perm -u+x -name "*-${suffix}" | sort)

  if [[ "${registered}" -eq 1 ]]; then
    log "Registered update-alternatives for *-${suffix} toolchain binaries"
  else
    warn "No executable *-${suffix} binaries found under /usr/bin"
  fi
}

ensure_ubuntu() {
  [[ -r /etc/os-release ]] || die "/etc/os-release not found"
  # shellcheck disable=SC1091
  source /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
    ubuntu:* | *:ubuntu* | *:debian* | debian:*)
      ;;
    *)
      die "This setup script is intended for Ubuntu/Debian images. Detected: ${PRETTY_NAME:-unknown}"
      ;;
  esac
}

detect_host_arch() {
  case "$(uname -m)" in
    x86_64 | amd64)
      printf 'x86_64\n'
      ;;
    aarch64 | arm64)
      printf 'aarch64\n'
      ;;
    *)
      die "Unsupported host architecture: $(uname -m)"
      ;;
  esac
}

get_origin_url() {
  git -C "${WORKSPACE_ROOT}" config --get remote.origin.url 2>/dev/null || true
}

extract_github_repo_slug() {
  local url="$1"
  local github_host="${GITHUB_HOST:-${DEFAULT_GITHUB_HOST}}"
  local slug=""

  case "${url}" in
    "git@${github_host}:"*)
      slug="${url#git@${github_host}:}"
      ;;
    "ssh://git@${github_host}/"*)
      slug="${url#ssh://git@${github_host}/}"
      ;;
    "https://${github_host}/"*)
      slug="${url#https://${github_host}/}"
      ;;
    "http://${github_host}/"*)
      slug="${url#http://${github_host}/}"
      ;;
    *)
      return 1
      ;;
  esac

  slug="${slug%.git}"
  [[ "${slug}" == */* ]] || return 1
  printf '%s\n' "${slug}"
}

get_workspace_repo_slug() {
  local configured_slug="${WORKSPACE_REPO_SLUG:-${GITHUB_REPOSITORY:-}}"
  local origin_url=""
  local origin_slug=""

  if [[ -n "${configured_slug}" ]]; then
    printf '%s\n' "${configured_slug}"
    return 0
  fi

  origin_url="$(get_origin_url)"
  if [[ -n "${origin_url}" ]]; then
    origin_slug="$(extract_github_repo_slug "${origin_url}" || true)"
    if [[ -n "${origin_slug}" ]]; then
      printf '%s\n' "${origin_slug}"
      return 0
    fi
  fi

  printf '%s\n' "${DEFAULT_WORKSPACE_REPO_SLUG}"
}

normalize_submodule_urls() {
  local gitmodules_path="${WORKSPACE_ROOT}/.gitmodules"
  local github_host="${GITHUB_HOST:-${DEFAULT_GITHUB_HOST}}"
  local github_token="${GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_API_TOKEN:-}}}"
  local origin_url=""
  local workspace_slug=""
  local workspace_owner=""
  local use_ssh=0
  local changed=0
  local key=""

  [[ -f "${gitmodules_path}" ]] || return 0

  origin_url="$(get_origin_url)"
  workspace_slug="$(get_workspace_repo_slug)"
  workspace_owner="${workspace_slug%%/*}"

  if [[ -z "${github_token}" ]] && [[ "${origin_url}" =~ ^git@|^ssh:// ]]; then
    use_ssh=1
  fi

  while IFS= read -r key; do
    local submodule_name="${key#submodule.}"
    local current_url=""
    local repo_name=""
    local resolved_url=""

    submodule_name="${submodule_name%.url}"
    current_url="$(git -C "${WORKSPACE_ROOT}" config --file .gitmodules --get "${key}")"

    case "${current_url}" in
      ../*)
        repo_name="${current_url#../}"
        repo_name="${repo_name%.git}"
        if [[ "${use_ssh}" -eq 1 ]]; then
          resolved_url="git@${github_host}:${workspace_owner}/${repo_name}.git"
        else
          resolved_url="https://${github_host}/${workspace_owner}/${repo_name}.git"
        fi
        git -C "${WORKSPACE_ROOT}" config --file .gitmodules "submodule.${submodule_name}.url" "${resolved_url}"
        changed=1
        ;;
    esac
  done < <(git -C "${WORKSPACE_ROOT}" config --file .gitmodules --name-only --get-regexp '^submodule\..*\.url$')

  if [[ "${changed}" -eq 1 ]]; then
    log "Normalized relative submodule URLs for ${workspace_slug}"
  fi
}

mark_workspace_git_safe() {
  local path=""
  local key=""
  local submodule_path=""

  add_safe_dir() {
    local candidate="$1"
    [[ -n "${candidate}" ]] || return 0
    git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "${candidate}" && return 0
    git config --global --add safe.directory "${candidate}"
  }

  add_safe_dir "${WORKSPACE_ROOT}"

  if [[ -f "${WORKSPACE_ROOT}/.gitmodules" ]]; then
    while IFS= read -r key; do
      submodule_path="$(git -C "${WORKSPACE_ROOT}" config --file .gitmodules --get "${key}")"
      [[ -n "${submodule_path}" ]] || continue
      path="${WORKSPACE_ROOT}/${submodule_path}"
      [[ -d "${path}" ]] || continue
      add_safe_dir "${path}"
    done < <(git -C "${WORKSPACE_ROOT}" config --file .gitmodules --name-only --get-regexp '^submodule\..*\.path$')
  fi
}

setup_dirs() {
  TOOL_ROOT="${TOOL_ROOT_OVERRIDE:-${TOOL_ROOT}}"
  VENV_DIR="${VENV_DIR_OVERRIDE:-${VENV_DIR}}"
  BIN_ROOT="${TOOL_ROOT}/bin"
  OPT_ROOT="${TOOL_ROOT}/opt"
  DOWNLOAD_ROOT="${TOOL_ROOT}/downloads"
  USER_BIN_DIR="${HOME}/.local/bin"
  PROFILE_SNIPPET_DIR="${HOME}/.config/profile.d"
  PROFILE_SNIPPET="${PROFILE_SNIPPET_DIR}/EM3555-codex.sh"
  mkdir -p "${BIN_ROOT}" "${OPT_ROOT}" "${DOWNLOAD_ROOT}" "${USER_BIN_DIR}" "${PROFILE_SNIPPET_DIR}" "${GHIDRA_PROJECT_DIR}"
}

configure_private_github_access() {
  local github_host="${GITHUB_HOST:-${DEFAULT_GITHUB_HOST}}"
  local github_token="${GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_API_TOKEN:-}}}"
  local github_user="${GITHUB_USER:-x-access-token}"
  local origin_url=""

  if [[ -n "${github_token}" ]]; then
    log "Configuring GitHub HTTPS access for private submodules on ${github_host}"
    git config --global --unset-all url."https://${github_user}:${github_token}@${github_host}/".insteadOf >/dev/null 2>&1 || true
    git config --global --add url."https://${github_user}:${github_token}@${github_host}/".insteadOf "https://${github_host}/"
    git config --global --add url."https://${github_user}:${github_token}@${github_host}/".insteadOf "git@${github_host}:"
    return 0
  fi

  origin_url="$(get_origin_url)"
  if [[ "${origin_url}" =~ ^git@|^ssh:// ]]; then
    log "Origin uses SSH; reusing existing Git transport for private submodules"
    return 0
  fi

  warn "No GITHUB_TOKEN/GH_TOKEN/GITHUB_API_TOKEN provided. Private submodule init will rely on existing Git credentials for ${github_host}."
}

install_apt_packages() {
  log "Installing Ubuntu packages"
  export DEBIAN_FRONTEND=noninteractive
  local packages_to_install=("${APT_PACKAGES[@]}" "${LLVM20_PACKAGES[@]}")

  if ! command -v java >/dev/null 2>&1; then
    packages_to_install+=("${JAVA_FALLBACK_PACKAGES[@]}")
  fi

  run_privileged apt-get update
  run_privileged apt-get install -y --no-install-recommends "${packages_to_install[@]}"

  register_versioned_alternatives "20"
}

init_submodules() {
  log "Initializing submodules"
  mark_workspace_git_safe
  configure_private_github_access
  normalize_submodule_urls
  git -C "${WORKSPACE_ROOT}" submodule sync --recursive
  git -C "${WORKSPACE_ROOT}" submodule update --init --recursive
}

setup_sdk_layout() {
  [[ -d "${SDK_V30_DIR}" ]] || die "Expected SDK submodule missing: ${SDK_V30_DIR}"
  log "Creating gecko-sdk/v3.0 compatibility layout"
  mkdir -p "${SDK_COMPAT_ROOT}"
  ln -sfn "../gecko-sdk-v3.0" "${SDK_COMPAT_ROOT}/v3.0"
  ln -sfn "v3.0" "${SDK_COMPAT_ROOT}/3.0"
}

create_python_venv() {
  local workspace_python=""
  local requested_version=""
  local existing_version=""

  install_uv
  workspace_python="$(command -v python3)"

  if [[ -x "${workspace_python}" ]]; then
    export WORKSPACE_PYTHON_BIN="${workspace_python}"
  fi

  requested_version="$("${workspace_python}" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')"

  if [[ -x "${VENV_DIR}/bin/python" ]]; then
    existing_version="$("${VENV_DIR}/bin/python" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')"
    if [[ "${existing_version}" != "${requested_version}" ]]; then
      log "Recreating Python virtualenv for Python ${requested_version} (was ${existing_version})"
      rm -rf "${VENV_DIR}"
    else
      log "Python virtualenv already exists: ${VENV_DIR}"
    fi
  fi

  if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
    log "Creating Python virtualenv with ${workspace_python}"
    "${BIN_ROOT}/uv" venv --python "${workspace_python}" "${VENV_DIR}"
  fi
  if [[ -f "${APP_DIR}/tools/mcp/requirements.txt" ]]; then
    UV_LINK_MODE=copy "${BIN_ROOT}/uv" pip install --python "${VENV_DIR}/bin/python" -r "${APP_DIR}/tools/mcp/requirements.txt"
  fi
}

install_reverse_engineering_python_packages() {
  install_uv
  log "Installing reverse-engineering Python packages into virtualenv"
  UV_LINK_MODE=copy "${BIN_ROOT}/uv" pip install --python "${VENV_DIR}/bin/python" "${RE_PYTHON_PACKAGES[@]}"
}

archive_ext_from_name() {
  local name="$1"
  case "${name}" in
    *.tar.bz2) printf '.tar.bz2\n' ;;
    *.tar.bz) printf '.tar.bz\n' ;;
    *.tbz2) printf '.tbz2\n' ;;
    *.tar.gz) printf '.tar.gz\n' ;;
    *.tgz) printf '.tgz\n' ;;
    *.tar.xz) printf '.tar.xz\n' ;;
    *.tar) printf '.tar\n' ;;
    *.zip) printf '.zip\n' ;;
    *) return 1 ;;
  esac
}

url_basename() {
  local url="$1"
  local path_part="${url%%\?*}"
  basename "${path_part}"
}

copy_or_download_archive() {
  local archive_var_name="$1"
  local url_var_name="$2"
  local output_stem="$3"
  local refresh_mode="${4:-auto}"
  local archive_path="${!archive_var_name:-}"
  local archive_url="${!url_var_name:-}"
  local archive_name=""
  local archive_ext=""
  local output_path=""

  if [[ -n "${archive_path}" ]]; then
    [[ -f "${archive_path}" ]] || die "Archive not found: ${archive_path}"
    archive_name="$(basename "${archive_path}")"
    archive_ext="$(archive_ext_from_name "${archive_name}" || true)"
    [[ -n "${archive_ext}" ]] || die "Unsupported archive format for ${archive_path}"
    output_path="${DOWNLOAD_ROOT}/${output_stem}${archive_ext}"
    if [[ "${refresh_mode}" != "force" && -f "${output_path}" ]] && cmp -s "${archive_path}" "${output_path}"; then
      log "Reusing cached archive ${output_stem}${archive_ext}"
      printf '%s\n' "${output_path}"
      return 0
    fi
    cp -f "${archive_path}" "${output_path}"
    printf '%s\n' "${output_path}"
    return 0
  fi

  if [[ -n "${archive_url}" ]]; then
    archive_name="$(url_basename "${archive_url}")"
    archive_ext="$(archive_ext_from_name "${archive_name}" || true)"
    [[ -n "${archive_ext}" ]] || die "Could not infer archive extension from URL: ${archive_url}"
    output_path="${DOWNLOAD_ROOT}/${output_stem}${archive_ext}"
    if [[ "${refresh_mode}" != "force" && -f "${output_path}" ]]; then
      log "Reusing cached archive ${output_stem}${archive_ext}"
      printf '%s\n' "${output_path}"
      return 0
    fi
    download_large_archive "${archive_url}" "${output_path}"
    printf '%s\n' "${output_path}"
    return 0
  fi

  return 1
}

download_large_archive() {
  local archive_url="$1"
  local output_path="$2"

  mkdir -p "$(dirname "${output_path}")"

  if command -v aria2c >/dev/null 2>&1; then
    aria2c \
      -s16 \
      -x16 \
      -k1M \
      -j8 \
      -c \
      --file-allocation=none \
      --dir="$(dirname "${output_path}")" \
      --out="$(basename "${output_path}")" \
      "${archive_url}" >&2
    return 0
  fi

  warn "aria2c not found; falling back to curl for ${archive_url}"
  need_cmd curl
  curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "${output_path}" "${archive_url}"
}

install_uv() {
  local existing_uv="${BIN_ROOT}/uv"
  local existing_uvx="${BIN_ROOT}/uvx"
  local installer_url="${UV_INSTALLER_URL:-${DEFAULT_UV_INSTALLER_URL}}"

  if [[ -x "${existing_uv}" ]]; then
    log "uv already installed: $(${existing_uv} --version)"
    publish_user_bin_links uv uvx
    return 0
  fi

  need_cmd curl
  log "Installing uv"
  curl -LsSf "${installer_url}" | env UV_UNMANAGED_INSTALL="${BIN_ROOT}" UV_NO_MODIFY_PATH=1 sh

  [[ -x "${existing_uv}" ]] || die "uv not found after installation"
  if [[ -x "${existing_uvx}" ]]; then
    publish_user_bin_links uv uvx
  else
    publish_user_bin_links uv
  fi
}

resolve_and_extract_archive() {
  local label="$1"
  local archive_var_name="$2"
  local url_var_name="$3"
  local output_stem="$4"
  local dest_dir="$5"
  local archive_path=""

  archive_path="$(copy_or_download_archive "${archive_var_name}" "${url_var_name}" "${output_stem}")" || return 1

  if extract_archive "${archive_path}" "${dest_dir}"; then
    printf '%s\n' "${archive_path}"
    return 0
  fi

  warn "Failed to extract cached ${label} archive; forcing a fresh download/copy and retrying"
  rm -f "${archive_path}"
  archive_path="$(copy_or_download_archive "${archive_var_name}" "${url_var_name}" "${output_stem}" "force")" || \
    die "Failed to refresh ${label} archive"
  extract_archive "${archive_path}" "${dest_dir}" || die "Failed to extract refreshed ${label} archive: ${archive_path}"
  printf '%s\n' "${archive_path}"
}

extract_archive() {
  local archive_path="$1"
  local dest_dir="$2"
  rm -rf "${dest_dir}"
  mkdir -p "${dest_dir}"

  case "${archive_path}" in
    *.tar.bz2 | *.tar.bz | *.tbz2)
      tar -xjf "${archive_path}" -C "${dest_dir}"
      ;;
    *.tar.gz | *.tgz)
      tar -xzf "${archive_path}" -C "${dest_dir}"
      ;;
    *.tar.xz)
      tar -xJf "${archive_path}" -C "${dest_dir}"
      ;;
    *.tar)
      tar -xf "${archive_path}" -C "${dest_dir}"
      ;;
    *.zip)
      unzip -q "${archive_path}" -d "${dest_dir}"
      ;;
    *)
      die "Unsupported archive format: ${archive_path}"
      ;;
  esac
}

find_executable_path() {
  local search_root="$1"
  shift
  local pattern
  local found=""
  for pattern in "$@"; do
    found="$(find "${search_root}" -type f -name "${pattern}" -perm -u+x | head -n 1)"
    if [[ -n "${found}" ]]; then
      printf '%s\n' "${found}"
      return 0
    fi
  done
  return 1
}

find_named_file_path() {
  local search_root="$1"
  shift
  local pattern
  local found=""
  for pattern in "$@"; do
    found="$(find "${search_root}" -type f -name "${pattern}" | head -n 1)"
    if [[ -n "${found}" ]]; then
      printf '%s\n' "${found}"
      return 0
    fi
  done
  return 1
}

install_current_bin_link() {
  local tool_root="$1"
  local bin_dir="$2"
  rm -rf "${tool_root}/current"
  mkdir -p "${tool_root}/current"
  ln -sfn "${bin_dir}" "${tool_root}/current/bin"
}

symlink_bin_contents() {
  local bin_dir="$1"
  shift
  local tool
  for tool in "$@"; do
    if [[ -x "${bin_dir}/${tool}" ]]; then
      ln -sfn "${bin_dir}/${tool}" "${BIN_ROOT}/${tool}"
    fi
  done
}

publish_user_bin_links() {
  local tool
  for tool in "$@"; do
    if [[ -L "${BIN_ROOT}/${tool}" || -x "${BIN_ROOT}/${tool}" ]]; then
      ln -sfn "${BIN_ROOT}/${tool}" "${USER_BIN_DIR}/${tool}"
    fi
  done
}

install_exec_wrapper() {
  local link_path="$1"
  local target_path="$2"
  cat > "${link_path}" <<EOF
#!/usr/bin/env bash
exec "${target_path}" "\$@"
EOF
  chmod +x "${link_path}"
}

remove_published_java_links() {
  local tool
  for tool in java keytool jarsigner; do
    rm -f "${BIN_ROOT}/${tool}" "${USER_BIN_DIR}/${tool}"
  done
}

write_shell_profile_snippet() {
  cat > "${PROFILE_SNIPPET}" <<EOF
export EM3555_CODEX_WORKSPACE="${WORKSPACE_ROOT}"
export GSDK_DIR="\${GSDK_DIR:-${WORKSPACE_ROOT}/gecko-sdk/v3.0}"
export GHIDRA_INSTALL_DIR="\${GHIDRA_INSTALL_DIR:-${OPT_ROOT}/ghidra/current/libexec}"
export GHIDRA_PROJECT_DIR="\${GHIDRA_PROJECT_DIR:-${GHIDRA_PROJECT_DIR}}"
export WORKSPACE_VENV_DIR="${WORKSPACE_ROOT}/.venv"
export WORKSPACE_VENV_PYTHON="${WORKSPACE_ROOT}/.venv/bin/python3"
if [[ -z "\${STUDIO_PYTHON3_PATH:-}" ]] && [[ -d "${OPT_ROOT}/slc-python/current" ]]; then
  export STUDIO_PYTHON3_PATH="${OPT_ROOT}/slc-python/current"
fi
path_remove_exact() {
  local candidate="\$1"
  local filtered_path=""
  local path_entry=""
  local path_ifs="\${IFS}"

  IFS=':'
  for path_entry in \${PATH}; do
    [[ -n "\${path_entry}" ]] || continue
    [[ "\${path_entry}" == "\${candidate}" ]] && continue
    if [[ -z "\${filtered_path}" ]]; then
      filtered_path="\${path_entry}"
    else
      filtered_path="\${filtered_path}:\${path_entry}"
    fi
  done
  IFS="\${path_ifs}"

  export PATH="\${filtered_path}"
}
path_prepend_exact() {
  local candidate="\$1"
  [[ -d "\${candidate}" ]] || return 0
  case ":\${PATH}:" in
    *:"\${candidate}":*) ;;
    *) export PATH="\${candidate}:\${PATH}" ;;
  esac
}
path_remove_exact "${WORKSPACE_ROOT}/.venv/bin"
path_remove_exact "${OPT_ROOT}/slc-java/current/bin"
path_remove_exact "${OPT_ROOT}/slc-python/current/bin"
if [[ -n "\${STUDIO_PYTHON3_PATH:-}" ]]; then
  path_remove_exact "\${STUDIO_PYTHON3_PATH}/bin"
fi
path_prepend_exact "${BIN_ROOT}"
path_prepend_exact "${OPT_ROOT}/arm-gnu-toolchain/current/bin"
path_prepend_exact "${OPT_ROOT}/jlink/current/bin"
path_prepend_exact "${OPT_ROOT}/ghidra/current/bin"
unset -f path_prepend_exact
unset -f path_remove_exact
if command -v java >/dev/null 2>&1; then
  export JAVA_HOME="\$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/^[[:space:]]*java.home = / {print \$2; exit}')"
fi
EOF

  local shell_rc
  for shell_rc in "${HOME}/.bashrc" "${HOME}/.profile"; do
    touch "${shell_rc}"
    if ! grep -Fq "${PROFILE_SNIPPET}" "${shell_rc}"; then
      printf '\n[ -f "%s" ] && source "%s"\n' "${PROFILE_SNIPPET}" "${PROFILE_SNIPPET}" >> "${shell_rc}"
    fi
  done
}

resolve_latest_ghidra_url() {
  local api_url="${GHIDRA_RELEASE_API_URL:-${DEFAULT_GHIDRA_RELEASE_API_URL}}"

  python3 - "${api_url}" <<'PY'
import json
import sys
import urllib.request

api_url = sys.argv[1]
request = urllib.request.Request(
    api_url,
    headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "EM3555-codex-setup",
    },
)

with urllib.request.urlopen(request, timeout=30) as response:
    payload = json.load(response)

for asset in payload.get("assets", []):
    name = asset.get("name", "")
    if name.startswith("ghidra_") and name.endswith(".zip") and "_PUBLIC_" in name:
        print(asset["browser_download_url"])
        break
else:
    raise SystemExit("No public Ghidra zip asset found in latest release metadata")
PY
}

default_arm_toolchain_url() {
  case "${HOST_ARCH}" in
    x86_64)
      printf '%s\n' "${DEFAULT_ARM_GNU_TOOLCHAIN_X64_URL}"
      ;;
    aarch64)
      printf '%s\n' "${DEFAULT_ARM_GNU_TOOLCHAIN_ARM64_URL}"
      ;;
    *)
      die "No default Arm GNU toolchain URL for host architecture: ${HOST_ARCH}"
      ;;
  esac
}

install_arm_gnu_toolchain() {
  local existing_bin="${OPT_ROOT}/arm-gnu-toolchain/current/bin"
  if [[ -x "${existing_bin}/arm-none-eabi-gcc" ]]; then
    log "ARM GNU toolchain already installed: $(${existing_bin}/arm-none-eabi-gcc --version | head -n 1)"
    symlink_bin_contents "${existing_bin}" \
      arm-none-eabi-gcc \
      arm-none-eabi-g++ \
      arm-none-eabi-gdb \
      arm-none-eabi-nm \
      arm-none-eabi-objcopy \
      arm-none-eabi-objdump \
      arm-none-eabi-ranlib \
      arm-none-eabi-readelf \
      arm-none-eabi-size \
      arm-none-eabi-strip
    return 0
  fi

  : "${ARM_GNU_TOOLCHAIN_URL:=$(default_arm_toolchain_url)}"

  local archive_path
  archive_path="$(resolve_and_extract_archive "ARM GNU toolchain" ARM_GNU_TOOLCHAIN_ARCHIVE ARM_GNU_TOOLCHAIN_URL arm-gnu-toolchain-archive "${OPT_ROOT}/arm-gnu-toolchain")" || \
    die "Failed to resolve ARM GNU toolchain archive"

  log "Installing ARM GNU toolchain from official Arm archive"
  local dest="${OPT_ROOT}/arm-gnu-toolchain"
  local toolchain_bin
  toolchain_bin="$(find "${dest}" -type d -path '*/bin' | while read -r candidate; do
    [[ -x "${candidate}/arm-none-eabi-gcc" ]] && printf '%s\n' "${candidate}" && break
  done)"
  [[ -n "${toolchain_bin}" ]] || die "arm-none-eabi-gcc not found in extracted toolchain archive"
  install_current_bin_link "${dest}" "${toolchain_bin}"
  symlink_bin_contents "${toolchain_bin}" \
    arm-none-eabi-gcc \
    arm-none-eabi-g++ \
    arm-none-eabi-gdb \
    arm-none-eabi-nm \
    arm-none-eabi-objcopy \
    arm-none-eabi-objdump \
    arm-none-eabi-ranlib \
    arm-none-eabi-readelf \
    arm-none-eabi-size \
    arm-none-eabi-strip
  publish_user_bin_links \
    arm-none-eabi-gcc \
    arm-none-eabi-g++ \
    arm-none-eabi-gdb \
    arm-none-eabi-nm \
    arm-none-eabi-objcopy \
    arm-none-eabi-objdump \
    arm-none-eabi-ranlib \
    arm-none-eabi-readelf \
    arm-none-eabi-size \
    arm-none-eabi-strip
}

install_tool_from_archive() {
  local tool_name="$1"
  local archive_var_name="$2"
  local url_var_name="$3"
  local link_name="$4"
  shift 4
  local dest_dir="${OPT_ROOT}/${tool_name}"
  local archive_path

  archive_path="$(resolve_and_extract_archive "${tool_name}" "${archive_var_name}" "${url_var_name}" "${tool_name}-archive" "${dest_dir}")" || return 1

  log "Installing ${tool_name} from archive"
  local executable_path
  executable_path="$(find_executable_path "${dest_dir}" "$@" || true)"
  if [[ -z "${executable_path}" ]]; then
    executable_path="$(find_named_file_path "${dest_dir}" "$@" || true)"
    if [[ -n "${executable_path}" ]]; then
      chmod +x "${executable_path}" || true
    fi
  fi
  [[ -n "${executable_path}" ]] || die "Executable for ${tool_name} not found under ${dest_dir}"
  local executable_dir
  executable_dir="$(dirname "${executable_path}")"
  install_current_bin_link "${dest_dir}" "${executable_dir}"
  ln -sfn "${executable_path}" "${BIN_ROOT}/${link_name}"
}

find_commander_payload_archive() {
  local search_root="$1"
  local pattern=""
  local found=""
  local patterns=()

  case "${HOST_ARCH}" in
    x86_64)
      patterns=(
        "Commander-cli_linux_x86_64_*.tar.bz"
        "Commander_linux_x86_64_*.tar.bz"
      )
      ;;
    aarch64)
      patterns=(
        "Commander-cli_linux_aarch64_*.tar.bz"
        "Commander_linux_aarch64_*.tar.bz"
      )
      ;;
    *)
      die "No Commander payload pattern configured for host architecture: ${HOST_ARCH}"
      ;;
  esac

  for pattern in "${patterns[@]}"; do
    found="$(find "${search_root}" -type f -name "${pattern}" | head -n 1)"
    if [[ -n "${found}" ]]; then
      printf '%s\n' "${found}"
      return 0
    fi
  done

  return 1
}

expand_commander_bundle_if_needed() {
  local dest_dir="$1"
  local existing=""
  local payload_archive=""
  local payload_dir="${dest_dir}/_payload"

  existing="$(find_executable_path "${dest_dir}" "commander" "commander-cli" || true)"
  if [[ -n "${existing}" ]]; then
    return 0
  fi

  payload_archive="$(find_commander_payload_archive "${dest_dir}" || true)"
  if [[ -z "${payload_archive}" ]]; then
    return 0
  fi

  log "Expanding Commander payload $(basename "${payload_archive}")"
  extract_archive "${payload_archive}" "${payload_dir}"
}

link_commander_bins() {
  local executable_path="$1"
  local executable_dir="$2"
  local actual_name
  actual_name="$(basename "${executable_path}")"

  case "${actual_name}" in
    commander-cli)
      ln -sfn "${executable_path}" "${BIN_ROOT}/commander-cli"
      ln -sfn "${executable_path}" "${BIN_ROOT}/commander"
      ;;
    commander)
      ln -sfn "${executable_path}" "${BIN_ROOT}/commander"
      if [[ -x "${executable_dir}/commander-cli" ]]; then
        ln -sfn "${executable_dir}/commander-cli" "${BIN_ROOT}/commander-cli"
      else
        ln -sfn "${executable_path}" "${BIN_ROOT}/commander-cli"
      fi
      ;;
    *)
      die "Unsupported Commander executable name: ${actual_name}"
      ;;
  esac
}

install_commander() {
  local existing="${OPT_ROOT}/commander/current/bin/commander"
  local existing_cli="${OPT_ROOT}/commander/current/bin/commander-cli"
  if [[ -x "${existing}" || -x "${existing_cli}" ]]; then
    if [[ ! -x "${existing}" ]]; then
      existing="${existing_cli}"
    fi
    log "Commander already installed: $(${existing} --version | head -n 1)"
    link_commander_bins "${existing}" "$(dirname "${existing}")"
    publish_user_bin_links commander commander-cli
    return 0
  fi

  : "${COMMANDER_URL:=${DEFAULT_COMMANDER_URL}}"
  local dest_dir="${OPT_ROOT}/commander"
  local archive_path=""
  local executable_path=""
  local executable_dir=""

  archive_path="$(resolve_and_extract_archive "commander" "COMMANDER_ARCHIVE" "COMMANDER_URL" "commander-archive" "${dest_dir}")" || return 1

  log "Installing commander from archive"
  if ! expand_commander_bundle_if_needed "${dest_dir}"; then
    warn "Failed to expand cached Commander payload; forcing a fresh archive and retrying"
    archive_path="$(copy_or_download_archive "COMMANDER_ARCHIVE" "COMMANDER_URL" "commander-archive" "force")" || \
      die "Failed to refresh commander archive"
    extract_archive "${archive_path}" "${dest_dir}" || die "Failed to extract refreshed commander archive: ${archive_path}"
    expand_commander_bundle_if_needed "${dest_dir}" || die "Failed to expand refreshed Commander payload"
  fi

  executable_path="$(find_executable_path "${dest_dir}" "commander" "commander-cli" || true)"
  if [[ -z "${executable_path}" ]]; then
    executable_path="$(find_named_file_path "${dest_dir}" "commander" "commander-cli" || true)"
    if [[ -n "${executable_path}" ]]; then
      chmod +x "${executable_path}" || true
    fi
  fi

  [[ -n "${executable_path}" ]] || die "Executable for commander not found under ${dest_dir}"

  executable_dir="$(dirname "${executable_path}")"
  install_current_bin_link "${dest_dir}" "${executable_dir}"
  link_commander_bins "${executable_path}" "${executable_dir}"
  publish_user_bin_links commander commander-cli
}

install_slt() {
  local existing="${OPT_ROOT}/slt/current/bin/slt"
  if [[ -x "${existing}" ]]; then
    log "SLT already installed: $(${existing} --version | head -n 1)"
    ln -sfn "${existing}" "${BIN_ROOT}/slt"
    publish_user_bin_links slt
    return 0
  fi

  if [[ -z "${SLT_ARCHIVE:-}" && -z "${SLT_URL:-}" ]]; then
    case "${HOST_ARCH}" in
      x86_64)
        SLT_URL="${DEFAULT_SLT_X64_URL}"
        ;;
      aarch64)
        die "No published Silicon Labs SLT Linux arm64 archive was found. Set SLT_ARCHIVE or SLT_URL explicitly if you have one, or provide SLC_ARCHIVE/SLC_URL directly."
        ;;
      *)
        die "No default SLT archive is configured for host architecture: ${HOST_ARCH}"
        ;;
    esac
  fi

  install_tool_from_archive "slt" "SLT_ARCHIVE" "SLT_URL" "slt" "slt"
  publish_user_bin_links slt
}

link_slc_java() {
  local java_bin=""
  java_bin="$(find "${HOME}/.silabs/slt/installs" -type d -path '*/jre/bin' | head -n 1 || true)"
  if [[ -n "${java_bin}" && -x "${java_bin}/java" ]]; then
    local java_root="${OPT_ROOT}/slc-java"
    install_current_bin_link "${java_root}" "${java_bin}"
    remove_published_java_links
  else
    warn "Could not locate SLT-provided Java runtime; falling back to system java in PATH"
  fi
}

link_slc_python() {
  local python_root=""
  python_root="$(find "${HOME}/.silabs/slt/installs" -type d -path '*/python-v*/python' | head -n 1 || true)"
  if [[ -n "${python_root}" && -x "${python_root}/bin/python3" ]]; then
    local python_link_root="${OPT_ROOT}/slc-python"
    rm -rf "${python_link_root}/current"
    mkdir -p "${python_link_root}"
    ln -sfn "${python_root}" "${python_link_root}/current"
    export STUDIO_PYTHON3_PATH="${python_root}"
  else
    warn "Could not locate SLT-provided Python runtime; STUDIO_PYTHON3_PATH will rely on direct install discovery"
  fi
}

resolve_slc_python_interpreter() {
  if [[ -n "${STUDIO_PYTHON3_PATH:-}" && -x "${STUDIO_PYTHON3_PATH}/bin/python3" ]]; then
    printf '%s\n' "${STUDIO_PYTHON3_PATH}/bin/python3"
    return 0
  fi

  if [[ -x "${OPT_ROOT}/slc-python/current/bin/python3" ]]; then
    printf '%s\n' "${OPT_ROOT}/slc-python/current/bin/python3"
    return 0
  fi

  return 1
}

install_slc_python_support_packages() {
  local slc_python=""
  slc_python="$(resolve_slc_python_interpreter || true)"
  if [[ -z "${slc_python}" ]]; then
    warn "No SLC Python runtime detected; skipping SLC Python support package install"
    return 0
  fi

  if "${slc_python}" -c "import jinja2, yaml" >/dev/null 2>&1; then
    log "SLC Python already has template dependencies"
    return 0
  fi

  install_uv
  log "Installing SLC Python support packages"
  UV_LINK_MODE=copy "${BIN_ROOT}/uv" pip install --python "${slc_python}" "${SLC_PYTHON_PACKAGES[@]}"

  "${slc_python}" -c "import jinja2, yaml" >/dev/null 2>&1 || \
    die "SLC Python support packages are still missing from ${slc_python}"
}

trust_sdk_for_slc() {
  local slc_bin="${BIN_ROOT}/slc"
  [[ -x "${slc_bin}" ]] || return 0

  log "Trusting SDK for SLC: ${SDK_V30_DIR}"
  "${slc_bin}" signature trust --sdk "${SDK_V30_DIR}" >/dev/null

  if [[ -L "${SDK_COMPAT_ROOT}/v3.0" || -d "${SDK_COMPAT_ROOT}/v3.0" ]]; then
    "${slc_bin}" signature trust --sdk "${SDK_COMPAT_ROOT}/v3.0" >/dev/null 2>&1 || true
  fi
}
install_slc_direct() {
  if install_tool_from_archive "slc" "SLC_ARCHIVE" "SLC_URL" "slc" "slc" "slc-cli"; then
    local slc_bin="${OPT_ROOT}/slc/current/bin"
    if [[ -x "${slc_bin}/slc-cli" ]]; then
      ln -sfn "${slc_bin}/slc-cli" "${BIN_ROOT}/slc-cli"
    elif [[ -x "${slc_bin}/slc" ]]; then
      ln -sfn "${slc_bin}/slc" "${BIN_ROOT}/slc-cli"
    fi
    if [[ -x "${slc_bin}/slc" ]]; then
      install_exec_wrapper "${BIN_ROOT}/slc" "${slc_bin}/slc"
    fi
    publish_user_bin_links slc slc-cli
    return 0
  fi
  return 1
}

install_slc_via_slt() {
  local slt_bin="${BIN_ROOT}/slt"
  [[ -x "${slt_bin}" ]] || die "slt not found after installation"

  local recipe="${TOOL_ROOT}/pkg.slt"
  cat > "${recipe}" <<'EOF'
version = "0"

[dependency]
slc-cli = "~"
EOF

  log "Installing slc-cli via Silicon Labs SLT"
  "${slt_bin}" install -f "${recipe}"

  local slc_path=""
  slc_path="$(find_executable_path "${HOME}/.silabs/slt/installs" "slc" "slc-cli")" || \
    die "slc-cli was installed via SLT but the executable could not be located under ${HOME}/.silabs/slt/installs"
  local slc_dir
  slc_dir="$(dirname "${slc_path}")"
  install_current_bin_link "${OPT_ROOT}/slc" "${slc_dir}"

  if [[ -x "${slc_dir}/slc" ]]; then
    install_exec_wrapper "${BIN_ROOT}/slc" "${slc_dir}/slc"
  else
    ln -sfn "${slc_path}" "${BIN_ROOT}/slc"
  fi

  if [[ -x "${slc_dir}/slc-cli" ]]; then
    ln -sfn "${slc_dir}/slc-cli" "${BIN_ROOT}/slc-cli"
  else
    ln -sfn "${slc_path}" "${BIN_ROOT}/slc-cli"
  fi

  link_slc_java
  link_slc_python
  remove_published_java_links
  publish_user_bin_links slc slc-cli
}

install_slc() {
  local existing_slc="${BIN_ROOT}/slc"
  if [[ -x "${existing_slc}" ]]; then
    log "slc already installed: $(${existing_slc} --version | head -n 1)"
    link_slc_java
    link_slc_python
    remove_published_java_links
  elif ! install_slc_direct; then
    install_slt
    install_slc_via_slt
  fi

  trust_sdk_for_slc
  install_slc_python_support_packages
}

install_ghidra() {
  local current_root="${OPT_ROOT}/ghidra/current/libexec"
  local current_bin="${OPT_ROOT}/ghidra/current/bin"
  if [[ -x "${current_root}/ghidraRun" && -x "${current_root}/support/analyzeHeadless" ]]; then
    log "Ghidra already installed: ${current_root}"
    symlink_bin_contents "${current_bin}" \
      ghidraRun \
      analyzeHeadless \
      ghidraSvr \
      svrAdmin \
      generateSvrKeyStore
    publish_user_bin_links \
      ghidraRun \
      analyzeHeadless \
      ghidraSvr \
      svrAdmin \
      generateSvrKeyStore
    return 0
  fi

  if [[ -z "${GHIDRA_ARCHIVE:-}" && -z "${GHIDRA_URL:-}" ]]; then
    GHIDRA_URL="$(resolve_latest_ghidra_url)" || die "Failed to resolve latest Ghidra release URL"
  fi

  local archive_path
  archive_path="$(resolve_and_extract_archive "Ghidra" GHIDRA_ARCHIVE GHIDRA_URL ghidra-archive "${OPT_ROOT}/ghidra")" || \
    die "Failed to resolve Ghidra archive"

  log "Installing Ghidra for offline reverse engineering"
  local dest_dir="${OPT_ROOT}/ghidra"

  local ghidra_run
  ghidra_run="$(find_executable_path "${dest_dir}" "ghidraRun" || true)"
  if [[ -z "${ghidra_run}" ]]; then
    ghidra_run="$(find_named_file_path "${dest_dir}" "ghidraRun" || true)"
    if [[ -n "${ghidra_run}" ]]; then
      chmod +x "${ghidra_run}" || true
    fi
  fi
  [[ -n "${ghidra_run}" ]] || die "ghidraRun not found in extracted Ghidra archive"

  local ghidra_root
  ghidra_root="$(dirname "${ghidra_run}")"
  local current_dir="${dest_dir}/current"
  rm -rf "${current_dir}"
  mkdir -p "${current_dir}/bin"
  ln -sfn "${ghidra_root}" "${current_dir}/libexec"

  if [[ -x "${ghidra_root}/ghidraRun" ]]; then
    ln -sfn "${ghidra_root}/ghidraRun" "${current_dir}/bin/ghidraRun"
  fi

  local tool
  for tool in analyzeHeadless ghidraSvr svrAdmin generateSvrKeyStore; do
    if [[ -x "${ghidra_root}/support/${tool}" ]]; then
      ln -sfn "${ghidra_root}/support/${tool}" "${current_dir}/bin/${tool}"
    fi
  done

  symlink_bin_contents "${current_dir}/bin" \
    ghidraRun \
    analyzeHeadless \
    ghidraSvr \
    svrAdmin \
    generateSvrKeyStore
  publish_user_bin_links \
    ghidraRun \
    analyzeHeadless \
    ghidraSvr \
    svrAdmin \
    generateSvrKeyStore
}

install_jlink_from_archive() {
  local archive_path
  if [[ -x "${OPT_ROOT}/jlink/current/bin/JLinkExe" ]]; then
    log "J-Link tools already installed: ${OPT_ROOT}/jlink/current/bin/JLinkExe"
    symlink_bin_contents "${OPT_ROOT}/jlink/current/bin" \
      JLinkExe \
      JLinkRTTClient \
      JLinkGDBServerCLExe \
      JLinkRTTLogger \
      JFlashLiteExe
    publish_user_bin_links \
      JLinkExe \
      JLinkRTTClient \
      JLinkGDBServerCLExe \
      JLinkRTTLogger \
      JFlashLiteExe
    return 0
  fi

  if ! archive_path="$(resolve_and_extract_archive "J-Link" JLINK_ARCHIVE JLINK_URL jlink-archive "${OPT_ROOT}/jlink")"; then
    warn "J-Link archive not provided; skipping install"
    return 0
  fi

  log "Installing J-Link tools from archive"
  local dest_dir="${OPT_ROOT}/jlink"
  local jlink_exe=""
  local jlink_dir=""
  jlink_exe="$(find_executable_path "${dest_dir}" "JLinkExe" || true)"
  if [[ -z "${jlink_exe}" ]]; then
    jlink_exe="$(find_named_file_path "${dest_dir}" "JLinkExe" || true)"
    if [[ -n "${jlink_exe}" ]]; then
      chmod +x "${jlink_exe}" || true
    fi
  fi
  if [[ -n "${jlink_exe}" ]]; then
    jlink_dir="$(dirname "${jlink_exe}")"
  fi
  [[ -n "${jlink_dir}" ]] || die "JLinkExe not found in extracted J-Link archive"
  install_current_bin_link "${dest_dir}" "${jlink_dir}"
  symlink_bin_contents "${jlink_dir}" \
    JLinkExe \
    JLinkRTTClient \
    JLinkGDBServerCLExe \
    JLinkRTTLogger \
    JFlashLiteExe
  publish_user_bin_links \
    JLinkExe \
    JLinkRTTClient \
    JLinkGDBServerCLExe \
    JLinkRTTLogger \
    JFlashLiteExe
}

write_summary() {
  local arm_gnu_summary_url="${ARM_GNU_TOOLCHAIN_URL:-}"
  local commander_summary_url="${COMMANDER_URL:-${DEFAULT_COMMANDER_URL}}"
  local ghidra_summary_url="${GHIDRA_URL:-latest GitHub release}"

  if [[ -z "${arm_gnu_summary_url}" ]]; then
    case "${HOST_ARCH:-$(detect_host_arch)}" in
      x86_64)
        arm_gnu_summary_url="${DEFAULT_ARM_GNU_TOOLCHAIN_X64_URL}"
        ;;
      aarch64)
        arm_gnu_summary_url="${DEFAULT_ARM_GNU_TOOLCHAIN_ARM64_URL}"
        ;;
      *)
        arm_gnu_summary_url="unsupported host architecture"
        ;;
    esac
  fi

  cat <<EOF

Setup complete.

Workspace root:
  ${WORKSPACE_ROOT}

Submodules:
  ${APP_DIR}
  ${SDK_V30_DIR}

Compatibility SDK path:
  ${WORKSPACE_ROOT}/gecko-sdk/v3.0

Installed tool defaults:
  Arm GNU Toolchain: ${arm_gnu_summary_url}
  Simplicity Commander: ${commander_summary_url}
  Ghidra: ${ghidra_summary_url}
  SLT: ${SLT_URL:-manual/direct override}

Shell environment:
  source "${WORKSPACE_ROOT}/scripts/env.sh"

Tool locations:
  ${BIN_ROOT}
  ${VENV_DIR}
  ${OPT_ROOT}/ghidra/current/libexec

Quick checks:
  source scripts/env.sh
  arm-none-eabi-gcc --version
  slc --help
  commander --version
  ghidraRun
  analyzeHeadless /tmp/ghidra-check smoke -import /bin/ls -readOnly -deleteProject
  "\${WORKSPACE_VENV_PYTHON}" -c "import capstone, pyghidra, elftools, unicorn"
  "\${STUDIO_PYTHON3_PATH}/bin/python3" -c "import jinja2"

Example build:
  source scripts/env.sh
  cd EM3555-osram-rgbw-flex
  PROFILE=all USE_IAR=0 RUN_FLASH=0 SKIP_GENERATE=0 BUILD_OTA_AHEAD=1 bash ./tools/build_iar.sh
EOF
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  HOST_ARCH="$(detect_host_arch)"
  ensure_ubuntu
  need_cmd git
  need_cmd python3
  setup_dirs
  install_apt_packages
  init_submodules
  setup_sdk_layout
  create_python_venv
  install_reverse_engineering_python_packages
  install_arm_gnu_toolchain
  install_commander
  install_slc
  # install_jlink_from_archive
  install_ghidra
  write_shell_profile_snippet
  write_summary
}

main "$@"

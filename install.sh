#!/usr/bin/env bash
set -euo pipefail

CLI="git-checkpoints"
RAW_BASE="https://raw.githubusercontent.com/moussa-m/git-checkpoints/main"
INSTALL_DIRS=( "$HOME/.local/bin" "$HOME/bin" "/usr/local/bin" )

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

_print(){ local c=$1 e=$2; shift 2; echo -e "${c}${e} $*${NC}"; }
print_info()    { _print "$BLUE"  "ℹ️" "$@"; }
print_success() { _print "$GREEN" "✅" "$@"; }
print_warning() { _print "$YELLOW" "⚠️" "$@"; }
print_error()   { _print "$RED"   "❌" "$@"; }

check_deps(){
  local miss=()
  for cmd in git curl; do
    command -v "$cmd" &>/dev/null || miss+=("$cmd")
  done
  [ ${#miss[@]} -gt 0 ] && { print_error "Missing: ${miss[*]}"; exit 1; }
  command -v crontab &>/dev/null \
    || print_warning "cron not found; auto-checkpoint disabled"
}

find_dir(){
  for d in "${INSTALL_DIRS[@]}"; do
    [ -d "$d" -a -w "$d" ] && { echo "$d"; return; }
  done
  mkdir -p "$HOME/.local/bin"
  echo "$HOME/.local/bin"
}

install_cli(){
  local dir dst
  dir="$(find_dir)"; dst="$dir/$CLI"
  
  # Use local file if available, otherwise download
  if [ -f "./$CLI" ]; then
    print_info "Installing local $CLI → $dst"
    cp "./$CLI" "$dst"
  else
    print_info "Downloading $CLI → $dst"
    curl -fsSL "$RAW_BASE/$CLI" -o "$dst"
  fi
  
  chmod +x "$dst"
  print_success "Installed $CLI"
  [[ ":$PATH:" == *":$dir:"* ]] \
    || print_warning "Add '$dir' to your PATH"
}

setup_aliases(){
  print_info "Adding Git aliases in $(pwd)"
  git config --local alias.checkpoint '!f(){ git-checkpoints create "$@"; }; f'
  git config --local alias.checkpoints '!f(){
    if [ $# -eq 0 ]; then git-checkpoints list;
    else case $1 in
      create) shift; git-checkpoints create "$@";;
      list)   git-checkpoints list;;
      delete) shift; git-checkpoints delete "$@";;
      load)   shift; git-checkpoints load "$@";;
      *)      echo "Usage: git checkpoints [create|list|delete|load]";;
    esac; fi
  }; f'
  print_success "Aliases set"
}

setup_cron(){
  command -v crontab &>/dev/null || return
  # Get configured interval or use default
  local interval=$(git config --local checkpoints.interval 2>/dev/null || echo "5")
  print_info "Re-installing cron entry every ${interval}m"
  local tmp
  tmp="$(mktemp)"
  crontab -l 2>/dev/null | grep -v "$(pwd)" >"$tmp" || true
  echo "*/$interval * * * * cd \"$(pwd)\" && git-checkpoints auto >/dev/null 2>&1" \
    >>"$tmp"
  crontab "$tmp"; rm -f "$tmp"
  # Set status to running
  git config --local checkpoints.paused "false"
  print_success "Cron installed and status set to running"
}

main(){
  print_info "Starting Git-Checkpoints install"
  check_deps
  install_cli
  setup_aliases
  setup_cron
  print_success "Installation complete!"
}
main

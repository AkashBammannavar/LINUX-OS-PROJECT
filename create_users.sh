#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Configuration
PASSWORD_FILE="/var/secure/user_passwords.txt"
LOG_FILE="/var/log/user_management.log"
SECURE_DIR="/var/secure"
HOME_BASE="/home"
DEFAULT_SHELL="/bin/bash"
PW_LENGTH=12

log() {
  local level="$1"
  local msg="$2"
  local ts
  ts="$(date --iso-8601=seconds)"
  printf "%s [%s] %s\n" "$ts" "$level" "$msg" >> "$LOG_FILE"
}

error_exit() {
  local msg="$1"
  log "ERROR" "$msg"
  echo "ERROR: $msg" >&2
  exit 1
}

generate_password() {
  tr -dc 'A-Za-z0-9@%_-+=' </dev/urandom | head -c "$PW_LENGTH" || true
}

trim() {
  local var="$*"
  echo "$var" | sed -e 's/^\s*//' -e 's/\s*$//'
}

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Use sudo." >&2
  exit 2
fi

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <users-file>" >&2
  echo "Each line: username; group1,group2" >&2
  exit 3
fi

INPUT_FILE="$1"
if [ ! -f "$INPUT_FILE" ] || [ ! -r "$INPUT_FILE" ]; then
  error_exit "Input file '$INPUT_FILE' not found or not readable."
fi

mkdir -p "$SECURE_DIR"
chmod 700 "$SECURE_DIR"

if [ ! -f "$PASSWORD_FILE" ]; then
  touch "$PASSWORD_FILE"
fi
chmod 600 "$PASSWORD_FILE"

if [ ! -f "$LOG_FILE" ]; then
  touch "$LOG_FILE"
fi
chmod 600 "$LOG_FILE"

log "INFO" "Starting user creation from file: $INPUT_FILE"

while IFS= read -r rawline || [ -n "$rawline" ]; do
  line="$(echo "$rawline" | sed 's/\xEF\xBB\xBF//g')"
  line="$(trim "$line")"

  case "$line" in
    ""|\#*)
      continue
      ;;
  esac

  if ! echo "$line" | grep -q ";"; then
    log "WARN" "Skipping malformed line (no semicolon): $line"
    echo "Skipping malformed line (no semicolon): $line"
    continue
  fi

  username_raw="$(echo "$line" | cut -d';' -f1)"
  groups_raw="$(echo "$line" | cut -d';' -f2-)"
  username="$(trim "$username_raw")"
  groups_raw="$(trim "$groups_raw")"

  if [ -z "$username" ]; then
    log "WARN" "Empty username found in line: $rawline"
    continue
  fi

  extra_groups=""
  if [ -n "$groups_raw" ]; then
    groups_clean="$(echo "$groups_raw" | sed 's/\s*,\s*/,/g')"
    groups_space="$(echo "$groups_clean" | tr ',' ' ')"
    first=1
    for g in $groups_space; do
      g_trimmed="$(trim "$g")"
      if [ -z "$g_trimmed" ]; then continue; fi
      if ! getent group "$g_trimmed" >/dev/null; then
        if groupadd "$g_trimmed"; then
          log "INFO" "Group '$g_trimmed' created."
        else
          log "ERROR" "Failed to create group '$g_trimmed' for user '$username'."
        fi
      fi
      if [ $first -eq 1 ]; then
        extra_groups="$g_trimmed"; first=0
      else
        extra_groups+=","$g_trimmed
      fi
    done
  fi

  if id -u "$username" >/dev/null 2>&1; then
    if [ -n "$extra_groups" ]; then
      usermod -a -G "$extra_groups" "$username" && log "INFO" "Existing user '$username' updated with groups: $extra_groups"
    fi
  else
    if [ -n "$extra_groups" ]; then
      useradd -m -d "$HOME_BASE/$username" -s "$DEFAULT_SHELL" -G "$extra_groups" "$username"
    else
      useradd -m -d "$HOME_BASE/$username" -s "$DEFAULT_SHELL" "$username"
    fi
  fi

  user_home="$HOME_BASE/$username"
  [ ! -d "$user_home" ] && mkdir -p "$user_home"
  chown -R "$username":"$username" "$user_home"
  chmod 700 "$user_home"

  password="$(generate_password)"
  if [ -z "$password" ]; then
    if command -v openssl >/dev/null 2>&1; then
      password="$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9@%_-+=' | head -c "$PW_LENGTH")"
    else
      password="ChangeMe123!"
    fi
  fi

  echo "$username:$password" | chpasswd && log "INFO" "Password set for user '$username'"
  printf "%s:%s\n" "$username" "$password" >> "$PASSWORD_FILE"

done < "$INPUT_FILE"

log "INFO" "User creation run complete for input file: $INPUT_FILE"
echo "User creation complete. See $LOG_FILE for details and $PASSWORD_FILE for credentials (mode 600)."
exit 0

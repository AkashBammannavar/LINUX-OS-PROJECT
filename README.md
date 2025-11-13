:- Project Overview

This project automates user account creation and group assignment in Linux systems using a Bash script.
The script reads data from a text file (users.txt), where each line defines a username and their group memberships.

It simplifies the process of adding multiple users, setting passwords, and ensuring proper permissions — ideal for system administrators or DevOps engineers.
1. Script Configuration

PASSWORD_FILE="/var/secure/user_passwords.txt"
   
Sets important file paths for passwords, logs, and user home directories.
Also defines constants like default shell and password length.

2. Logging and Error Functions

   log() { printf "%s [%s] %s\n" "$(date --iso-8601=seconds)" "$1" "$2" >> "$LOG_FILE"; }

log() records every action or error in a log file with timestamps.
error_exit() safely stops the script and logs the error message.

3. Password Generator

 tr -dc 'A-Za-z0-9@%_-+=' </dev/urandom | head -c "$PW_LENGTH"

generate_password() creates a random 12-character secure password using /dev/urandom.
If it fails, a fallback password method is used for reliability.

4. Trim Function

echo "$var" | sed -e 's/^\s*//' -e 's/\s*$//'

Removes extra spaces from usernames or group names.
Ensures clean data when processing each line from the file.

5. Root Permission Check

if [ "$(id -u)" -ne 0 ]; then echo "Run as root."; exit 2; fi
 
Ensures only the root or sudo user can run the script.
This prevents permission errors during user creation.

6. Input File Validation

[ ! -f "$1" ] && error_exit "Input file not found."

Checks that a valid file path is given and that it’s readable.
If the file doesn’t exist, it logs an error and exits.

7. Setup Secure Directories

mkdir -p "$SECURE_DIR" && chmod 700 "$SECURE_DIR"

Creates directories /var/secure and log files if missing.
Sets strict permissions (600/700) for security.

8. Process Each Line

while IFS= read -r line; do ... done < "$INPUT_FILE"

Reads each line of users.txt and skips empty or commented ones.
Splits lines into username and group data using ; as the separator.

9. Group Creation

if ! getent group "$g_trimmed" >/dev/null; then groupadd "$g_trimmed"; fi

Checks if each group exists; if not, it creates it automatically.
Ensures all groups in the file are ready before adding users.

10. User Creation

useradd -m -d "$HOME_BASE/$username" -s "$DEFAULT_SHELL" -G "$extra_groups" "$username"

If the user already exists, adds them to new groups.
If not, creates the user with a home directory and shell.

11. Home Directory Setup
 
 chown -R "$username":"$username" "$HOME_BASE/$username"

Creates /home/username if missing and sets correct permissions.
Ensures ownership belongs to the correct user.

12. Password Setup

echo "$username:$password" | chpasswd

Generates and assigns a random password for each new user.
If generation fails, a default password is used as a fallback.

13. Save Credentials

printf "%s:%s\n" "$username" "$password" >> "$PASSWORD_FILE"

Stores usernames and passwords securely in /var/secure/user_passwords.txt.
This helps admins retrieve login details safely later.

14. Logging Completion

Records that the user creation process is finished.
Displays a message showing where to find logs and password files.

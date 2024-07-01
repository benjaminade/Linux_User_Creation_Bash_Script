#!/bin/bash

# Check if script is executed with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check if input file is provided as argument
if [ $# -ne 1 ]; then
    echo "This is how you run this script: $0 <input-file>"
    exit 1
fi

INPUT_FILE=$1


# Check if input file exists and is readable
if [ ! -f "$INPUT_FILE" ] || [ ! -r "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE does not exist or is not readable"
    exit 1
fi

# Log file path
LOG_FILE="/var/log/user_management.log"


# Function to generate random password
generate_password() {
    # Generate a 12-character random alphanumeric password
    openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 12
}


# Read input file and create users
while IFS=';' read -r username groups; do
    # Trim whitespace from username and groups
    username=$(echo "$username" | tr -d '[:space:]')
    groups=$(echo "$groups" | tr -d '[:space:]')

     # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "$(date) - User $username already exists, skipping." >> "$LOG_FILE"
        continue
    fi


    # Create user with home directory
    useradd -m -s /bin/bash "$username"


    # Create personal group for the user if not exists
    if ! grep -q "^$username:" /etc/group; then
        groupadd "$username"
    fi


    # Add user to their personal group
    usermod -aG "$username" "$username"

        # Add user to additional groups
    IFS=',' read -ra user_groups <<< "$groups"
    for group in "${user_groups[@]}"; do
        if ! grep -q "^$group:" /etc/group; then
            groupadd "$group"
        fi
        usermod -aG "$group" "$username"
    done


    # Generate random password for the user
    password=$(generate_password)


    # Set password for the user
    echo "$username:$password" | chpasswd


    # Log user creation details
    echo "$(date) - Created user $username with groups: $groups" >> "$LOG_FILE"


    # Store password securely
        # Check if /var/secure directory exists
        if [ ! -d /var/secure ]; then
        mkdir -p /var/secure
        fi

        #Append username and password to the file
        echo "$username,$password" >> /var/secure/user_passwords.csv

done < "$INPUT_FILE"

# Secure permissions for password file
chmod 600 /var/secure/user_passwords.csv


# Completion message
echo "$(date) - User creation process completed." >> "$LOG_FILE"


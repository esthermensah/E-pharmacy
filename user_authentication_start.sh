#!/bin/bash

credentials_file="credentials.txt"
logged_in_file=".logged_in"

# Function to check if a username exists in the credentials file
username_exists() {
    local username="$1"
    grep -q "^$username:" "$credentials_file"
}

# Function to generate a random salt
generate_salt() {
    openssl rand -hex 8
}

# Function to generate salted hash
generate_hash() {
    local data="$1"
    local salt="$2"
    echo -n "$data$salt" | openssl dgst -sha256 | awk '{print $2}'
}

# Function to check if a role is valid
is_valid_role() {
    local role="$1"
    case "$role" in
        normal|salesperson|admin)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to add new credentials to the file
add_credentials() {
    local username="$1"
    local password="$2"
    local role="${3:-normal}"  # Use "normal" as the default value if the third argument is not provided

    # Check if the role is valid
    if ! is_valid_role "$role"; then
        echo "Invalid role. Role should be either normal, salesperson, or admin."
        return 1
    fi

    # Check if the username already exists
    if username_exists "$username"; then
        echo "Username '$username' already exists. Credentials not added."
        return 1
    fi

    # Generate salt and hash the password with the salt
    local salt=$(generate_salt)
    local hashed_password=$(generate_hash "$password" "$salt")

    # Append the line in the specified format to the credentials file
    echo "$username:$hashed_password:$salt:$role:0" >> "$credentials_file"
    echo "New credentials added to $credentials_file"
    return 0
}

# Function to verify credentials and update the login status
verify_credentials() {
    local username="$1"
    local password="$2"

    # Check if the username exists in the credentials file and get stored hash and salt
    local stored_hash_and_salt
    stored_hash_and_salt=$(get_stored_hash_and_salt "$username")

    if [ -z "$stored_hash_and_salt" ]; then
        echo "Invalid username"
        return 1
    fi

    # Extract stored hash and salt
    local stored_hash
    local stored_salt
    IFS=':' read -r stored_hash stored_salt <<< "$stored_hash_and_salt"

    # Compute hash based on the provided password and stored salt
    local input_hash=$(echo -n "$password$stored_salt" | openssl dgst -sha256 | awk '{print $2}')

    # Compare the generated hash with the stored hash
    if [ "$input_hash" = "$stored_hash" ]; then
        echo "Authentication successful! Welcome, $username."

        # Update credentials file with the new login status
        sed -i "s/^$username:.*$/$username:$stored_hash:$stored_salt/" "$credentials_file"

        # Create .logged_in file with the username of the logged-in user
        echo "$username" > "$logged_in_file"

        return 0
    else
        echo "Invalid password. Authentication failed."
        return 1
    fi
}

# Function to logout
logout() {
    if [ -s "$logged_in_file" ]; then
        # Read the username of the currently logged-in user
        local logged_in_user
        logged_in_user=$(<"$logged_in_file")

        # Delete the .logged_in file
        rm "$logged_in_file"

        # Update the credentials file to change the last field to 0
        sed -i "s/^$logged_in_user:.*$/\0:0/" "$credentials_file"

        echo "Logout successful. Goodbye, $logged_in_user."
    else
        echo "No user is currently logged in."
    fi
}

# Function to display the main menu
main_menu() {
    PS3="Select an option: "
    options=("Login" "Self-Register" "Exit")

    select opt in "${options[@]}"; do
        case $REPLY in
            1)  # Login
                read -p "Username: " input_username
                read -s -p "Password: " input_password
                echo
                verify_credentials "$input_username" "$input_password"
                ;;
            2)  # Self-Register
                read -p "Username: " new_username
                read -s -p "Password: " new_password
                echo
                read -p "Fullname: " new_fullname
                read -p "Role (normal/salesperson/admin): " new_role
                add_credentials "$new_username" "$new_password" "$new_fullname" "$new_role"
                ;;
            3)  # Exit
                echo "Exiting the application."
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Start the main menu
main_menu

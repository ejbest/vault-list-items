#!/bin/bash

# Enable error handling
set -e

# Login to Vault (ensure $VAULT_TOKEN and $VAULT_ADDR are set)
vault login $VAULT_TOKEN

# Function to retrieve and list all secrets engines
function list_secrets_engines() {
    echo "Retrieving all secrets engines..."
    local engines

    # Get all enabled secrets engines
    engines=$(vault secrets list -format=json | jq -r 'keys[]')

    if [ $? -ne 0 ]; then
        echo "Error: Unable to retrieve secrets engines."
        exit 1
    fi

    echo "Secrets Engines Found:"
    echo "${engines}"

    # Iterate over each secrets engine
    for engine in ${engines}; do
        echo "Processing Secrets Engine: ${engine}"

        # Check the type of secrets engine
        engine_type=$(vault secrets list -format=json | jq -r ".[\"${engine}\"].type")

        if [[ ${engine_type} == "kv" ]]; then
            # If it's a KV engine, list its secrets
            echo "  Listing secrets in KV engine ${engine}:"
            list_vault_paths "${engine}"
        else
            echo "  Engine ${engine} is of type ${engine_type}, skipping."
        fi
    done
}

# Function to recursively list all paths in a KV secrets engine
function list_vault_paths() {
    local base_path=$1
    local secrets

    # List paths at the current level
    secrets=$(vault kv list -format=json "${base_path}" 2>/dev/null | jq -r '.[]')

    if [ $? -ne 0 ]; then
        echo "  Error: Unable to list paths for ${base_path}"
        return
    fi

    for secret in ${secrets}; do
        if [[ ${secret} == */ ]]; then
            # Recursively list sub-paths if it's a directory
            list_vault_paths "${base_path}${secret}"
        else
            # Print full path of the secret
            echo "  Found secret: ${base_path}${secret}"
        fi
    done
}

# Function to list access authentication methods
function list_and_expand_auth_methods() {
    echo "Retrieving all authentication methods..."
    local auth_methods

    # List all auth methods
    auth_methods=$(vault auth list -format=json | jq -r 'keys[]')

    if [ $? -ne 0 ]; then
        echo "Error: Unable to retrieve authentication methods."
        exit 1
    fi

    echo "Authentication Methods Found:"
    echo "${auth_methods}"

    for method in ${auth_methods}; do
        echo ""
        echo "Processing Authentication Method: ${method}"

        # Dynamically explore sub-paths for each method
        # Possible subpaths under auth methods include 'users', 'roles', 'groups', etc.
        subpaths=("users" "roles" "groups")

        for subpath in "${subpaths[@]}"; do
            full_path="auth/${method}${subpath}/"
            echo "  Exploring ${full_path}..."

            # Check if the path exists
            items=$(vault list -format=json "${full_path}" 2>/dev/null | jq -r '.[]')
            if [ $? -eq 0 ]; then
                if [ -z "$items" ]; then
                    echo "    No items found under ${full_path}."
                else
                    echo "  Items under ${full_path}:"
                    for item in ${items}; do
                        echo "    - ${item}"
                    done
                fi
            else
                echo "  Error retrieving items from ${full_path}"
            fi
        done
    done
}

# Main script execution
echo "Starting Vault Discovery..."
echo ""
echo "Step 1: Listing all KV secrets..."
list_secrets_engines

echo "Starting Vault Authentication Method Discovery..."
list_and_expand_auth_methods
echo ""
echo "Vault Authentication Method Discovery Complete!"

echo ""
echo "Vault Discovery Complete!"

#!/bin/bash

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] $message${NC}"
}

# Function to check if a container is running
check_running() {
    container=$1
    max_attempts=30
    attempt=1

    log "${BLUE}" "Waiting for $container to be running..."
    while [ $attempt -le $max_attempts ]; do
        status=$(docker inspect --format='{{.State.Status}}' $container 2>/dev/null)
        
        if [ "$status" == "running" ]; then
            log "${GREEN}" "$container is running!"
            return 0
        fi
        log "${YELLOW}" "Attempt $attempt: $container status: $status. Waiting..."
        sleep 5
        ((attempt++))
    done

    log "${RED}" "Error: $container did not start within the expected time."
    exit 1
}

# Function to execute Vault commands
vault_exec() {
    docker-compose exec -T vault vault "$@"
}

# Function to execute Consul commands
consul_exec() {
    docker-compose exec -T consul consul "$@"
}

# Start the containers
log "${BLUE}" "Starting containers..."
docker-compose up -d --build

# Wait for Consul to be running
check_running vault-consul-consul-1

# Wait for Vault to be running
check_running vault-consul-vault-1

# Sleep for a bit to allow services to fully start
sleep 10

# Configure Consul ACLs
log "${BLUE}" "Configuring Consul ACLs..."
consul_token=$(consul_exec acl bootstrap | grep "SecretID:" | awk '{print $2}')
if [ -z "$consul_token" ]; then
    log "${RED}" "Failed to bootstrap Consul ACLs."
    exit 1
fi
log "${GREEN}" "Consul ACL Bootstrap Token: $consul_token"

# Apply the read-only policy
log "${BLUE}" "Applying read-only policy to Consul..."
policy_result=$(consul_exec acl policy create -token="$consul_token" -name "global-read" -description "Global read access" -rules @/consul/policies/consul-acl-policy.json)
if [[ $policy_result == *"ID:"* ]]; then
    log "${GREEN}" "Policy created successfully."
    policy_id=$(echo "$policy_result" | grep "ID:" | awk '{print $2}')
    log "${GREEN}" "Policy ID: $policy_id"
else
    log "${RED}" "Failed to create policy. Error: $policy_result"
    exit 1
fi

# Create a token with the policy
log "${BLUE}" "Creating a token with the read-only policy..."
read_token=$(consul_exec acl token create -token="$consul_token" -description "Global read token" -policy-name "global-read" -format json | jq -r .SecretID)
if [ -z "$read_token" ]; then
    log "${RED}" "Failed to create read token."
    exit 1
fi
log "${GREEN}" "Consul Read Token: $read_token"

# Check Vault status
log "${BLUE}" "Checking Vault status..."
if vault_exec status; then
    log "${GREEN}" "Vault is already initialized and unsealed."
else
    # Initialize Vault
    log "${BLUE}" "Initializing Vault..."
    init_output=$(vault_exec operator init -key-shares=1 -key-threshold=1)
    root_token=$(echo "$init_output" | grep "Initial Root Token:" | awk '{print $NF}')
    unseal_key=$(echo "$init_output" | grep "Unseal Key 1:" | awk '{print $NF}')

    log "${YELLOW}" "Root Token: $root_token"
    log "${YELLOW}" "Unseal Key: $unseal_key"

    # Unseal Vault
    log "${BLUE}" "Unsealing Vault..."
    vault_exec operator unseal $unseal_key
fi

# Log in to Vault
log "${BLUE}" "Logging in to Vault..."
vault_exec login $root_token

# Enable the KV secrets engine
log "${BLUE}" "Enabling KV secrets engine..."
vault_exec secrets enable -path=secret kv-v2 || log "${YELLOW}" "KV secrets engine might already be enabled. Continuing..."

# Create a sample secret
log "${BLUE}" "Creating a sample secret..."
vault_exec kv put secret/apps/librarium api_key=supersecret

# Create a policy from the mounted JSON file
log "${BLUE}" "Creating a policy..."
if vault_exec policy write app-policy /vault/policies/app-policy.json; then
    log "${GREEN}" "Policy created successfully."
else
    log "${RED}" "Failed to create policy. Check if app-policy.json exists in ./vault/policies/"
    exit 1
fi

# Create a token with the policy
log "${BLUE}" "Creating a token with the new policy..."
app_token=$(vault_exec token create -policy=app-policy -format=json | jq -r .auth.client_token)
if [ -z "$app_token" ]; then
    log "${RED}" "Failed to create app token."
    exit 1
fi
log "${GREEN}" "Application Token: $app_token"

# Verify Vault is registered with Consul
log "${BLUE}" "Verifying Vault registration with Consul..."
consul_services=$(curl -s -H "X-Consul-Token: $consul_token" http://localhost:8500/v1/catalog/services)
if echo "$consul_services" | jq -e '.vault' > /dev/null; then
    log "${GREEN}" "Vault is successfully registered with Consul."
else
    log "${YELLOW}" "Warning: Vault does not appear to be registered with Consul. Check Vault and Consul logs for more information."
fi

log "${GREEN}" "Setup complete!"
log "${YELLOW}" "Consul ACL Bootstrap Token: $consul_token"
log "${YELLOW}" "Consul Read Token: $read_token"
log "${YELLOW}" "Vault Root Token: $root_token"
log "${YELLOW}" "Vault Unseal Key: $unseal_key"
log "${YELLOW}" "Vault Application Token: $app_token"
log "${BLUE}" "You can now use these tokens to interact with Consul and Vault."
log "${BLUE}" "Access the Consul UI at http://localhost:8500 and use the Bootstrap Token to log in."
log "${BLUE}" "Access the Vault UI at http://localhost:8200 and use the Root Token to log in."

# Save tokens to a file
log "${BLUE}" "Saving tokens to tokens.txt..."
cat << EOF > tokens.txt
Consul ACL Bootstrap Token: $consul_token
Consul Read Token: $read_token
Vault Root Token: $root_token
Vault Unseal Key: $unseal_key
Vault Application Token: $app_token
EOF
log "${GREEN}" "Tokens saved to tokens.txt"

log "${YELLOW}" "WARNING: tokens.txt contains sensitive information. Secure or delete this file in production environments."

# ==============================================================================
# AI CLI TOOLS: fix | ask | tell
# Architecture: Remote LLM Offloading (Tailscale, Local Network, or Cloud)
# ==============================================================================

# --- Infrastructure Configuration ---
# OWASP Decoupling: Set these variables in your environment (e.g., .bashrc / .zshrc)
# Example: export LM_STUDIO_URL="http://<YOUR_TAILSCALE_IP_OR_LOCALHOST>:<PORT>/v1/chat/completions"
# Example: export AI_MODEL="<YOUR_MODEL_NAME_HERE>"

tell() {
  # 0. NIST Zero-Trust: Verify infrastructure configuration exists
  if [[ -z "$LM_STUDIO_URL" || -z "$AI_MODEL" ]]; then
    echo "ERROR: LM_STUDIO_URL or AI_MODEL environment variables are missing." >&2
    echo "Please configure them in your shell profile before running." >&2
    return 1
  fi

  local input
  if [[ -n "$*" ]]; then
    input="$*"
  else
    input=$(cat)
  fi
  
  if [[ -z "$input" ]]; then return; fi

  # 1. Hostile Input Assumption: Safely construct JSON
  local json_payload
  if ! json_payload=$(jq -n --arg msg "$input" --arg model "$AI_MODEL" \
    '{"model": $model, "messages": [{"role": "user", "content": $msg}]}'); then
      echo "ERROR: Failed to construct JSON payload. Check input formatting." >&2
      return 1
  fi

  # 2. Deterministic Execution: 5s connection timeout, 60s max execution
  local curl_output
  if ! curl_output=$(curl -sS --connect-timeout 5 -m 60 "$LM_STUDIO_URL" \
    -H "Content-Type: application/json" \
    -d "$json_payload" 2>&1); then
      echo "ERROR: Network failure reaching LLM server at $LM_STUDIO_URL" >&2
      echo "cURL stderr: $curl_output" >&2
      return 1
  fi

  # 3. Explicit Error Handling: Validate JSON response
  local response
  response=$(echo "$curl_output" | jq -r '.choices[0].message.content' 2>/dev/null)
  
  if [[ -z "$response" || "$response" == "null" ]]; then
      echo "ERROR: Invalid or empty response from LLM server." >&2
      echo "Raw Output: $curl_output" >&2
      return 1
  fi

  # 4. The Aesthetic Filter: Strip markdown formatting blocks
  echo "$response" | sed '/^```/d'
}

ask() {
  local stdin_content=""
  if [[ ! -t 0 ]]; then
      stdin_content=$(cat -)
  fi

  if [[ -n "$stdin_content" ]]; then
      local prompt="INSTRUCTION: $*\n\nCONTEXT/CODE:\n$stdin_content"
      echo -e "$prompt" | tell
  else
      tell "$*"
  fi
}

fix() {
  # 1. NIST Zero-Trust: Verify dependencies
  if ! type tell > /dev/null 2>&1; then
    echo "ERROR: 'tell' function is missing from the environment." >&2
    return 1
  fi

  # 2. Bash-Specific History Target: Grab the command BEFORE 'fix'
  local last_cmd
  last_cmd=$(fc -ln -2 -2 | sed 's/^[ \t]*//')

  # 3. Hostile Input Assumption: Prevent infinite loops
  if [[ -z "$last_cmd" || "$last_cmd" == "fix" ]]; then
    # Fallback in case of weird HISTCONTROL configurations
    last_cmd=$(fc -ln -1 -1 | sed 's/^[ \t]*//')
    if [[ -z "$last_cmd" || "$last_cmd" == "fix" ]]; then
      echo "ERROR: Could not isolate the previous command from history." >&2
      return 1
    fi
  fi

  echo "Executing and analyzing: $last_cmd" >&2

  # 4. Capture output and status
  local cmd_output
  cmd_output=$(eval "$last_cmd" 2>&1)
  local exit_status=$?

  # 5. Determinism: Validate failure before API call
  if [[ $exit_status -eq 0 ]]; then
    echo "Diagnostic: Command returned exit code 0 (Success). No fix required." >&2
    echo "$cmd_output"
    return 0
  fi

  # 6. Construct payload and route
  local prompt="INSTRUCTION: You are a senior Linux engineer. The following command failed. Provide the exact, step-by-step terminal command to resolve this issue. Be concise.\n\nCOMMAND:\n$last_cmd\n\nEXIT STATUS:\n$exit_status\n\nOUTPUT/ERROR:\n$cmd_output"
  
  echo -e "$prompt" | tell
}

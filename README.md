# AI CLI Suite (fix | ask | tell)

A cross-platform Bash CLI suite designed to intercept terminal errors and route AI queries via a mesh network to a privately hosted Large Language Model (LLM). 

Built with a strict focus on systems architecture and high-reliability operational constraints, this suite allows offloading of AI inference from edge devices (Ubuntu bare-metal, iOS via iSH) to a central localized node (e.g., an M1 Mac running LM Studio) over a secure Tailscale VPN mesh.

## Architecture & Operational Constraints

This tool was engineered strictly adhering to enterprise and high-reliability deployment standards:

* Explicit Error Handling (DoD JSF Standard): Zero silent failures. The suite actively traps `jq` parsing errors, API rejections, and network timeouts, returning actionable `stderr` logs to the terminal.
* Deterministic Execution: Bounded network interactions. Utilizes strict 5-second connection timeouts and 60-second execution maximums to prevent indefinite terminal hanging.
* NIST Zero-Trust Validation: The script validates the existence of required dependencies (`jq`, `curl`, core functions) and environment variables before attempting any execution.
* OWASP Decoupling: Absolutely no hardcoded credentials, IPs, or secrets in the source code. Target URLs and model names are strictly injected at runtime via environment variables.
* State Containment: Zero mutable global variables within the functions to prevent state corruption across sequential commands.

## The Tools

### 1. fix (Automated Diagnostic Routing)
Captures the exact `stderr` and exit status of your previously failed terminal command and routes it to the LLM for a precise, step-by-step resolution.
* Mechanism: Uses `fc -ln` to isolate the prior command, re-evaluates it capturing standard error (`2>&1`), validates non-zero exit status, and constructs a secure JSON payload for the AI.

### 2. ask (Direct Terminal Interface)
A conversational interface to query the LLM directly from the command line, with support for stdin piping.
* Example: `ask "Write a strict .gitignore file for a Python project"`

### 3. tell (The Routing Engine)
The core transport function. Handles the JSON construction, `cURL` payload delivery over the network, HTTP response validation, and markdown parsing.

## Deployment & Configuration

### Prerequisites
* `curl` and `jq` installed on the host machine.
* A running LLM API endpoint (e.g., LM Studio, Ollama, or a cloud provider).
* (Optional but recommended) Tailscale or equivalent overlay network for secure, remote routing.

### Installation
1. Source the `cli-suite.sh` file in your `~/.bashrc`, `~/.zshrc`, or `~/.profile`:
   bash
   source /path/to/ai-cli-suite/cli-suite.sh
2. Add your target routing variables to your environment profile:
   Bash
   export LM_STUDIO_URL="http://<YOUR_TAILSCALE_IP>:<PORT>/v1/chat/completions"
   export AI_MODEL="<YOUR_MODEL_NAME>"
3. Enjoy it:)

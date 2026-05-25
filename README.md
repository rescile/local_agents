# Local Agentic Infrastructure Workspace

This repository provides a fully localized, declarative development and execution environment for agentic infrastructure automation. It tightly integrates **Loki** (the agent execution engine), a local **Ollama** instance leveraging hardware acceleration, and **Rescile-CE** (Community Edition) via the Model Context Protocol (MCP).

The entire workspace is managed declaratively using **NixOS / Nix Flakes** and orchestrated seamlessly via **direnv**, ensuring reproducible dependencies across identical environments without polluting global system paths.

## Architecture Overview

The workspace establishes a secure, local loop for translates high-level infrastructure requirements into deterministic execution sequences (Python, Pulumi, Terraform, Ansible, and Zsh).

* **Loki (Agent Core):** Processes localized reasoning prompts and orchestrates tool calling.
* **Ollama (Local LLM Server):** Handles on-device inference using optimized models (e.g., `qwen2.5-coder`, `gemma3`) accelerated directly via Intel GPU runtimes (`xe` kernel module / Level Zero).
* **Rescile-CE:** Acts as the NextGen Automation Server, exposing environment dependencies, multi-cloud topologies, and state validation to the agent via an HTTP MCP endpoint.

---

## Prerequisites

To utilize this workspace, the following components must be installed on the host system:

* [Nix Package Manager](https://nixos.org/) with Flakes enabled.
* [direnv](https://direnv.net/) integrated with the host shell (`zsh`, `bash`, etc.).

---

## Quickstart

### 1. Initialize the Environment

Navigate into the repository directory. `direnv` will automatically evaluate the `flake.nix`, build the specific version of Loki from source, inject all necessary platform tools (Ansible, Terraform, Pulumi), and configure the environment variables:

```bash
cd local_agents
direnv allow

```

### 2. Launch the Local Model Server

Due to isolation constraints within `direnv` and GPU driver bindings, the local Ollama daemon is decoupled from the automated shell hook to prevent terminal blocking. Start the model server in a separate terminal split or window within this directory:

```bash
start-ollama

```

### 3. Synchronize Models

In the terminal session running the workspace environment, download the preferred model into the localized workspace storage (`.ollama/models`):

```bash
ollama pull qwen2.5-coder:7b

```

### 4. Run the Agent

Ensure that the **Rescile-CE** server is active and listening on port `7600`. Then, initialize the agent interface:

```bash
loki

```

---

## Directory Structure & Configurations

The flake enforces a strict local state layout to keep the host system clean and comply with strict data sovereignty standards:

* `flake.nix`: Defines the deterministic build for `loki-ai`, injects the Intel Compute Runtime, and structures environment exports.
* `.ollama/`: Localized directory holding all downloaded LLM weights. Excluded from version control via `.gitignore`.
* `~/.config/loki/config.yaml`: Automatically generated on shell initialization. Configures the OpenAI-compatible client endpoint pointing to the local Ollama instance.
* `~/.config/loki/functions/mcp.json`: Declaratively provisioned to bind the `rescile-automation` MCP HTTP server into Loki's capabilities.

### Links
* based on https://github.com/Dark-Alex-17/loki

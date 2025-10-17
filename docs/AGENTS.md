# Codex Agents Configuration

## Execution
agent:
mode: fully_automatic
approvals:
  require_approval: false
  ask_to_proceed: "never"
  human_in_the_loop: "none"
  auto_confirm: true
safety:
  confirm_shell: false
  confirm_file_write: false
  confirm_commit: false

tasks:
  source: "docs/CODEX_TASKS.md"
  format: "checklist"
  code_block_lang: "bash"
  stop_on_failure: false
  one_commit_per_task: true
  respect_depends: true
  idempotent_steps: true

git:
  enabled: true
  branch: "codex"
  push: true
  commit_strategy: "one_commit_per_task"
  commit_message_template: "Codex: {{task_id}} {{task_title}}"

repo_policy:
  protected_branch: true
  default_branch: "main"
  allow_direct_push: false
  require_pull_request: true
  pull_request:
    base: "main"
    head: "codex"
    title: "Codex Auto PR"
    body: "Automated changes from Codex tasks."
    labels: ["automerge", "codex"]
    draft: false

auto_merge:
  enabled: true
  strategy: "merge"    # merge | squash | rebase
  require_status_checks: true
  required_labels: ["automerge"]
  block_on_change_requests: true

ci:
  expect:
    - ".github/workflows/ci.yml"

telemetry:
  log_commits: true
  log_failures: true
sandbox:
    allow_exec:
      - "codex"
      - "bash"
      - "git"
      - "node"
      - "pnpm"
    no_tty: true


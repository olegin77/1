---
agent:
  name: codex
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
  execution:
    max_iterations: 800
    stop_on_test_failure: true
    continue_on_error: false
    retry_attempts: 1
  tasks:
    source: "docs/CODEX_TASKS.md"
    format: "checklist"
    autoadvance: true
    dependency_key: "depends"
    code_block_lang: "bash"
    done_markers: ["[x]", "[X]"]
  git:
    enabled: true
    branch: "codex"                      # агент коммитит сюда
    commit_strategy: "one_commit_per_task"
    sign_commits: false
    push: true
  schedule:
    on_file_change:
      - "docs/CODEX_TASKS.md"
      - "docs/TECH_SPEC.md"
    cron: "*/10 * * * *"
repo_policy:
  protected_branch: false
  require_pull_request: false
  required_approvals: 0
  allow_direct_push: true
auto_merge:
  enabled: false
---


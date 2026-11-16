#!/bin/sh
# Install the triage-insights Agent Skill for Claude Code, OpenAI Codex,
# and/or GitHub Copilot CLI.
#
# POSIX sh — avoids arrays, [[ ]], and other bash-4+-only syntax so this
# also runs under bash 3.2 (macOS's default /bin/bash) and dash. Safe to
# re-run: each install is a full copy of the current skill directory, never
# a merge.
#
# Usage:
#   install.sh [--tool claude|codex|copilot|all] [--project <dir>]
#
# Without --project, installs into the tool's user-level skills directory
# (~/.claude/skills, ~/.codex/skills, ~/.copilot/skills). With --project
# <dir>, installs into that directory's per-tool project skills directory
# instead (.claude/skills, .agents/skills, .github/skills) — no user-level
# write. Default --tool is "all".
#
# Adding this repository as a plugin marketplace (README.md at the root) is the
# preferred install path for Claude Code, Codex, and Copilot CLI alike —
# it is versioned and updates in place. This script is the fallback for a
# plain file copy: a project-level install, or a tool with no marketplace
# concept of its own.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_SRC="$SCRIPT_DIR/skills/triage-insights"
SKILL_NAME="triage-insights"

tool="all"
project_dir=""
project_given=""
tool_given=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tool)
      [ $# -ge 2 ] || { echo "install.sh: --tool needs a value" >&2; exit 1; }
      tool="$2"
      tool_given=1
      shift 2
      ;;
    --tool=*)
      tool="${1#--tool=}"
      tool_given=1
      shift
      ;;
    --project)
      [ $# -ge 2 ] || { echo "install.sh: --project needs a directory" >&2; exit 1; }
      project_dir="$2"
      project_given=1
      shift 2
      ;;
    --project=*)
      project_dir="${1#--project=}"
      project_given=1
      shift
      ;;
    -h|--help)
      echo "Usage: install.sh [--tool claude|codex|copilot|all] [--project <dir>]"
      exit 0
      ;;
    *)
      echo "install.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -n "$project_given" ] && [ -z "$project_dir" ]; then
  echo "install.sh: --project needs a non-empty directory" >&2
  exit 1
fi

case "$tool" in
  claude|codex|copilot|all) ;;
  *)
    echo "install.sh: --tool must be one of claude, codex, copilot, all (got: $tool)" >&2
    exit 1
    ;;
esac

if [ ! -f "$SKILL_SRC/SKILL.md" ]; then
  echo "install.sh: cannot find $SKILL_SRC/SKILL.md — run this from a checkout of triageagent-dev/skills" >&2
  exit 1
fi

install_one() {
  dest_parent="$1"
  # With the default --tool all, skip a user-level tool directory that does not exist.
  if [ -z "$tool_given" ] && [ -z "$project_dir" ] && [ ! -d "$(dirname "$dest_parent")" ]; then
    echo "skipped: $(dirname "$dest_parent") does not exist (use --tool to force)"
    return 0
  fi
  mkdir -p "$dest_parent"
  rm -rf "${dest_parent:?}/$SKILL_NAME"
  cp -R "$SKILL_SRC" "$dest_parent/$SKILL_NAME"
  echo "installed: $dest_parent/$SKILL_NAME/SKILL.md"
}

if [ -n "$project_dir" ]; then
  case "$tool" in claude|all) install_one "$project_dir/.claude/skills" ;; esac
  case "$tool" in codex|all) install_one "$project_dir/.agents/skills" ;; esac
  case "$tool" in copilot|all) install_one "$project_dir/.github/skills" ;; esac
else
  case "$tool" in claude|all) install_one "$HOME/.claude/skills" ;; esac
  case "$tool" in codex|all) install_one "$HOME/.codex/skills" ;; esac
  case "$tool" in copilot|all) install_one "$HOME/.copilot/skills" ;; esac
fi

echo "done."

#!/usr/bin/env bash
set -eu

# ─── Configuration ───────────────────────────────────────────────────────────
DEFAULT_IGNORE="venv|__pycache__|\.git|\.nova|\.DS_Store|\.pytest_cache|node_modules|\.next|archive|archives|\.cache|scratch|target|\.venv|\.mypy_cache|\.tox|\.hypothesis|\.pylint.d|\.bundle|\.cargo|\.gradle|\.settings|\.eslintcache|\.parcel-cache|\.turbo|\.circleci|package-lock\.json|\.vscode|build|dist|bin|pkg|out|tmp|log|\.tsbuildinfo|\.swp|\.swo|\.bak|\.tmp|\.lock$|.*~|\.nvmrc|\.tool-versions|\.editorconfig|\.gitattributes|.*\.(png|jpg|jpeg|svg|ico|mp4|mov|webm|wav|mp3|ogg|ttf|woff|woff2)$"
DIR="."
OUT="content.txt"
EXTENSIONS="*"
APPEND_IGNORE=""
MAX_MB=5   # max file size in MB

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Generate a file-tree & concatenate text files, skipping:
 • .gitignore entries
 • built-in ignore patterns (+ any -a PATTERN)
 • binaries
 • files > MAX size
 • the output file itself

Redacts values in:
 • .env* files
 • Any file with "secrets" in the name (case-insensitive)

Options:
  -d DIR         Directory to scan (default: .)
  -e EXT1,EXT2   Comma-sep extensions (no dot). Default: all.
  -o FILE        Output file (default: content.txt)
  -a PATTERN     Append regex to default ignore list
  -s SIZE_MB     Skip files larger than SIZE_MB MB (default: ${MAX_MB})
  -h             Show this help and exit
EOF
}

# ─── Parse CLI ────────────────────────────────────────────────────────────────
if [[ $# -gt 0 && "$1" == "--help" ]]; then
  print_help
  exit 0
fi

while getopts "d:e:o:a:s:h" opt; do
  case $opt in
    d) DIR="$OPTARG"        ;;
    e) EXTENSIONS="$OPTARG" ;;
    o) OUT="$OPTARG"        ;;
    a) APPEND_IGNORE="$OPTARG" ;;
    s) MAX_MB="$OPTARG"     ;;
    h) print_help; exit 0   ;;
    *) print_help; exit 1   ;;
  esac
done
shift $((OPTIND-1))

[[ -d "$DIR" ]] || { echo "Directory not found: $DIR" >&2; exit 1; }

# ─── Friendly name & build ignore regex ──────────────────────────────────────
DIR_NAME=${DIR##*/}; [[ "$DIR" == "." ]] && DIR_NAME=${PWD##*/}
if [[ -n "$APPEND_IGNORE" ]]; then
  IGNORE_PATTERN="${DEFAULT_IGNORE}|${APPEND_IGNORE}"
else
  IGNORE_PATTERN="$DEFAULT_IGNORE"
fi

# ─── stat compatibility & gitignore support ─────────────────────────────────
if stat --version &>/dev/null; then
  stat_size(){ stat -c%s "$1"; }
else
  stat_size(){ stat -f%z "$1"; }
fi

USE_GIT_IGNORE=false
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
  USE_GIT_IGNORE=true
fi
MAX_BYTES=$(( MAX_MB * 1024 * 1024 ))

# ─── Figure out display name for extensions ─────────────────────────────────
if [[ "$EXTENSIONS" == "*" ]]; then
  INC_EXTS="all"
else
  INC_EXTS="$EXTENSIONS"
fi

# ─── Redact Function ─────────────────────────────────────────────────────────
redact_env() {
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      echo "${key}=REDACTED"
    else
      echo "$line"
    fi
  done < "$1"
}

# ─── Header & FileTree ───────────────────────────────────────────────────────
{
  echo "Filetree & Content"
  echo "This file contains a filetree & the associated content of the ${DIR_NAME} directory."
  echo "Included file types : ${INC_EXTS}"
  echo "Ignored patterns    : ${IGNORE_PATTERN}"
  echo
  echo "======= FileTree ========"
  if command -v tree &>/dev/null; then
    tree -a -I "$IGNORE_PATTERN" "$DIR"
  else
    find "$DIR" -type f | sed 's#^#  #'
  fi
  echo
  echo "======== Files ========"
} > "$OUT"

# ─── Gather & filter ─────────────────────────────────────────────────────────
files=()
while IFS= read -r f; do
  rel=${f#"$DIR"/}

  [[ "$rel" == "$(basename "$OUT")" ]] && continue
  [[ "$rel" =~ (^|/)?($IGNORE_PATTERN)(/|$)? ]] && continue
  $USE_GIT_IGNORE && git check-ignore -q "$f" 2>/dev/null && continue

  # extension filter
  if [[ "$EXTENSIONS" != "*" ]]; then
    keep=false
    for ext in ${EXTENSIONS//,/ }; do
      [[ "$f" == *.$ext ]] && { keep=true; break; }
    done
    [[ "$keep" == false ]] && continue
  fi

  (( $(stat_size "$f") > MAX_BYTES )) && continue
  grep -Iq . "$f" || continue

  files+=("$f")
done < <(find "$DIR" -type f)

count=${#files[@]}
(( count > 100 )) && echo "Warning: found $count files (>100)" >&2

# ─── Concatenate with dividers & redaction ──────────────────────────────────
for f in "${files[@]}"; do
  rel=${f#"$DIR"/}
  {
    echo
    echo "=====   BEGIN: $rel   ====="
    base="$(basename "$f" | tr '[:upper:]' '[:lower:]')"
    if [[ "$base" =~ ^\.env ]] || [[ "$base" == *secrets* ]]; then
      redact_env "$f"
    else
      cat "$f"
    fi
    echo
    echo "=====     END: $rel     ====="
  } >> "$OUT"
done

echo "Wrote $count file(s) to $OUT"

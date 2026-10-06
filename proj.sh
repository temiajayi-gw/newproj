#!/usr/bin/env bash
set -euo pipefail

name="${1:?Usage: proj <name>}"

# ---------- language-specific setup ----------

setup_ts() {
  # Safety settings first, so they apply to the install below
  cat > pnpm-workspace.yaml << 'EOF'
minimumReleaseAge: 4320 # minutes so 3 days
allowBuilds:
  esbuild: true
  lefthook: true
EOF

  echo "save-exact=true" > .npmrc

  pnpm init

  cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "types": ["node"]
  }
}
EOF

  cat > lefthook.yml << 'EOF'
pre-commit:
  commands:
    format:
      glob: "*.{js,ts,jsx,tsx,json,jsonc}"
      run: pnpm biome format --write --no-errors-on-unmatched {staged_files}
      stage_fixed: true
EOF

  echo "node_modules" >> .gitignore

  pnpm add -D typescript @types/node @biomejs/biome tsx vitest lefthook
  pnpm biome init
  pnpm lefthook install
}

setup_python() {
  # Windows Git Bash often has "python", Mac/Linux "python3"
  # "command -v" only checks a command exists. On Windows, python3 can be a
  # Microsoft Store stub that exists but doesn't run, so we try running each one.
  local py=""
  for candidate in python3 python; do
    if "$candidate" --version > /dev/null 2>&1; then
      py="$candidate"
      break
    fi
  done

  if [[ -z "$py" ]]; then
    echo "No working Python found" >&2
    exit 1
  fi

  "$py" -m venv .venv

  # Windows puts the activate script in Scripts/, Mac/Linux in bin/
  local venv_bin=".venv/bin"
  [[ -d .venv/bin ]] || venv_bin=".venv/Scripts"

  # check the venv was actually created
  if [[ ! -d "$venv_bin" ]]; then
    echo "venv failed to create" >&2
    exit 1
  fi

  # No activation needed: calling the venv's own pip installs into the venv
  "$venv_bin/pip" install lefthook ruff
  "$venv_bin/pip" freeze > requirements.txt

  # Points at the venv directly, so commits work even if the venv
  # isn't activated in the terminal you commit from.
  # (No quotes on EOF here, so $venv_bin gets filled in.)
  cat > lefthook.yml << EOF
pre-commit:
  commands:
    format:
      glob: "*.py"
      run: $venv_bin/ruff format {staged_files}
      stage_fixed: true
EOF

  "$venv_bin/lefthook" install

  printf ".venv\n__pycache__\n" >> .gitignore
}

setup_go() {
  go mod init "$name"

  # Needs Go 1.24+. Records lefthook in go.mod and creates go.sum.
  go get -tool github.com/evilmartians/lefthook@latest

  cat > lefthook.yml << 'EOF'
pre-commit:
  commands:
    format:
      glob: "*.go"
      run: gofmt -w {staged_files}
      stage_fixed: true
EOF

  go tool lefthook install

  echo "bin" >> .gitignore
}

# ---------- common setup ----------

mkdir "$name" && cd "$name"
git init
touch README.md
echo ".env" > .gitignore

# ---------- menu ----------

PS3="Pick a language (number): "
select lang in "TypeScript" "Python" "Go"; do
  case "$lang" in
    TypeScript) setup_ts; break ;;
    Python)     setup_python; break ;;
    Go)         setup_go; break ;;
    *)          echo "Pick 1, 2 or 3" ;;
  esac
done

echo "Done. cd $name to get started."
if [[ "$lang" == "Python" ]]; then
  echo "Then activate your venv: source .venv/bin/activate (Windows: source .venv/Scripts/activate)"
fi
echo "Review your lockfile / requirements.txt / go.sum before your first commit."
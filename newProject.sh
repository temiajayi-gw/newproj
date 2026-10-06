#!/usr/bin/env bash
set -euo pipefail

name="${1:?Usage: newproj <name>}"
mkdir "$name" && cd "$name"

git init
pnpm init

# safety first!
cat > pnpm-workspace.yaml << 'EOF'
minimumReleaseAge: 4320 # minutes so 3 days
allowBuilds:
  esbuild: true
  lefthook: true
EOF

cat > .npmrc << 'EOF'
save-exact=true
EOF


touch README.md

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

cat > .gitignore << 'EOF'
.env
node_modules
EOF

pnpm add -D typescript @types/node @biomejs/biome tsx vitest lefthook
pnpm biome init

pnpm lefthook install

echo "Done. Review pnpm-lock.yaml before your first commit."
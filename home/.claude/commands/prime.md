# Prime

## Quickly understand this repository structure

1. Check if this is a git repo with `git rev-parse --is-inside-work-tree 2>/dev/null`
2. For git repos: Run `git ls-files | grep -v "node_modules\|.git"` for tracked files
   For non-git repos: Run `find . -type f -not -path "*/node_modules/*" -not -path "*/.git/*" | sort`
3. Identify project type through key files (package.json, Cargo.toml, requirements.txt, etc.)
4. Read README.md, and other documentation files
5. Examine project structure and important directories
6. Check for configuration files (.env.example, .gitignore, etc.)
7. Summarize project purpose, structure, and technologies used

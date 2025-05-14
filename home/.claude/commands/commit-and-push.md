# Commit And Push

## Follow instructions to commit changes and push to remote
- Run `eval "$(pyenv init -)" && pyenv activate black-env && black --line-length 79` to stay PEP-8 compliant for any python files
- Check changes with `git status` and `git diff`
- Show what files would be included with `git add -n .` 
- Check if README.md files need updating
- Get confirmation before committing 
- Add and commit changes, with brief message (without claude), with arg `--no-gpg-sign`
- Push change to remote

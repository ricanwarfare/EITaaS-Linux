#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_ref=${1:-HEAD}
output_dir=${2:-"$project_root/dist"}

if [ -d "$project_root/.git" ] && command -v git >/dev/null 2>&1; then
    version=$(
        git -c safe.directory="$project_root" -C "$project_root" \
            show "$source_ref:pyproject.toml" |
            sed -n 's/^version = "\([^"]*\)"$/\1/p'
    )
else
    version=$(sed -n 's/^version = "\([^"]*\)"$/\1/p' "$project_root/pyproject.toml")
fi

if [ -z "$version" ]; then
    echo "could not determine project version at $source_ref" >&2
    exit 1
fi

archive_name="eitaas-linux-$version.tar.gz"
mkdir -p "$output_dir"

if [ -d "$project_root/.git" ] && command -v git >/dev/null 2>&1; then
    git -c safe.directory="$project_root" -C "$project_root" \
        archive --format=tar --prefix="eitaas-linux-$version/" "$source_ref" |
        gzip -n > "$output_dir/$archive_name"
else
    python3 -c "
import tarfile, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve()
dest = Path(sys.argv[2])
prefix = sys.argv[3]
ignored = {'.build', 'dist', '.git', '__pycache__', '.pytest_cache'}
with tarfile.open(dest, 'w:gz') as tar:
    for p in sorted(root.rglob('*')):
        if any(part in ignored for part in p.parts):
            continue
        rel = p.relative_to(root)
        tar.add(p, arcname=f'{prefix}/{rel}', recursive=False)
" "$project_root" "$output_dir/$archive_name" "eitaas-linux-$version"
fi

printf '%s\n' "$output_dir/$archive_name"

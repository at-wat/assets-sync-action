#!/bin/bash

cd "${GITHUB_WORKSPACE}" \
  || (echo "Workspace is unavailable" >&2; exit 1)

set -eu

root_dir=${INPUT_ROOT_DIR:-root}

if [ ! -d ${root_dir} ]
then
  echo "Must have ${root_dir} directory" >&2
  exit 1
fi

version=$(basename ${GITHUB_REF})
message_template=${INPUT_COMMIT_MESSAGE:-"Update assets to %v"}
push_prefix=
exclude_files=$(cd ${root_dir} && echo ${INPUT_EXCLUDE_PATHS} | xargs -n1 ls -1; true)

# Take a snapshot
git push -k -u -a

# Remove excluded files
for excluded in ${exclude_files}
do
  echo "Excluding ${excluded}"
  rm -rf ${excluded}
done

case "${INPUT_DRYRUN:-false}" in
  "true" )
    echo "Dryrun"
    push_prefix="echo ";;
  "false" )
    ;;
  * )
    echo "dryrun option must be 'true' or 'false'" >&2
    exit 1;;
esac

git config --global user.name ${INPUT_GIT_USER}
git config --global user.email ${INPUT_GIT_EMAIL}

# Set GITHUB_USER to workaround hub command auth error
# https://github.com/github/hub/issues/2149#issuecomment-513214342
export GITHUB_USER="${GITHUB_ACTOR}"
export GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}

for repo in ${INPUT_REPOS}
do
  echo "Syncing ${repo}"
  tmpdir=$(mktemp -d)
  git clone --depth=1 https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${repo} ${tmpdir}
  base_branch=$(git -C ${tmpdir} symbolic-ref --short HEAD)
  git -C ${tmpdir} checkout -b sync-assets-${version}

  # Copy files with directory structure
  for file in $(cd ${root_dir}; find . -type f)
  do
    echo "- Copying ${file}"
    mkdir -p $(dirname ${tmpdir}/${file})
    cp ${root_dir}/${file} ${tmpdir}/${file}
  done
  git -C ${tmpdir} add .

  if git -C ${tmpdir} diff --cached --exit-code
  then
    echo "- ${repo} is up-to-date"
    rm -rf ${tmpdir}
    continue
  fi

  message=${message_template//%v/${version}}
  git -C ${tmpdir} commit -m "${message}"
  ${push_prefix} git -C ${tmpdir} push origin sync-assets-${version}

  # Open PR
  echo "- Opening PR"
  (cd ${tmpdir}; ${push_prefix} hub pull-request \
    -b ${base_branch} \
    -h sync-assets-${version} \
    --no-edit \
    "Update assets to ${version}")

  rm -rf ${tmpdir}
done

# Revert excluded files
git stash pop

#!/bin/bash

cd "${GITHUB_WORKSPACE}" \
  || (echo "Workspace is unavailable" >&2; exit 1)

set -eu

if [ ! -d root ]
then
  echo "Must have ./root directory" >&2
  exit 1
fi

version=$(basename ${GITHUB_REF})
message_template=${INPUT_COMMIT_MESSAGE:-"Update assets to %v"}

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
  for file in $(cd root; find . -type f)
  do
    echo "- Copying ${file}"
    mkdir -p $(dirname ${tmpdir}/${file})
    cp ./root/${file} ${tmpdir}/${file}
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
  git -C ${tmpdir} push origin sync-assets-${version}

  # Open PR
  echo "- Opening PR"
  (cd ${tmpdir}; hub pull-request \
    -b ${base_branch} \
    -h sync-assets-${version} \
    --no-edit \
    "Update assets to ${version}")

  rm -rf ${tmpdir}
done

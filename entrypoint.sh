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
head_branch_template=${INPUT_BRANCH:-"sync-assets-%v"}
head_branch=${head_branch_template//%v/${version}}
push_prefix=
force_push=

if ! [[ "${INPUT_PUSH_INTERVAL:-1}" =~ ^[0-9]+$ ]]
then
  echo "push_interval must be a number" >&2
  exit 1
fi

# Remove excluded files
tmproot=$(mktemp -d)
cp -r ${root_dir}/. ${tmproot}/
root_dir=${tmproot}
exclude_files=$(cd ${root_dir} && echo ${INPUT_EXCLUDE_PATHS} | xargs -n1 -r bash -c 'ls -1 $0'; true)
for excluded in ${exclude_files}
do
  echo "Excluding ${excluded}"
  (cd ${root_dir} && rm -rf ${excluded})
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

case "${INPUT_FORCE_PUSH:-false}" in
  "true" )
    echo "Force push"
    force_push=-f;;
  "false" )
    ;;
  * )
    echo "force_push option must be 'true' or 'false'" >&2
    exit 1;;
esac

git config --global user.name ${INPUT_GIT_USER}
git config --global user.email ${INPUT_GIT_EMAIL}

for repo in ${INPUT_REPOS}
do
  echo "Syncing ${repo}"
  tmpdir=$(mktemp -d)
  git clone --depth=1 https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${repo} ${tmpdir}
  base_branch=$(git -C ${tmpdir} symbolic-ref --short HEAD)
  git -C ${tmpdir} checkout -b ${head_branch}

  # Copy files with directory structure
  for file in $(cd ${root_dir}; find . -type f)
  do
    echo "- Copying ${file}"
    mkdir -p $(dirname ${tmpdir}/${file})
    cp ${root_dir}/${file} ${tmpdir}/${file}
  done

  # Remove files
  for file in ${INPUT_RM}
  do
    echo "- Removing ${file}"
    rm -f ${tmpdir}/${file}
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

  if ! ${push_prefix} git -C ${tmpdir} push ${force_push} origin ${head_branch}
  then
    # Allow to fetch existing PR branch
    git -C ${tmpdir} config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'

    if ! git -C ${tmpdir} fetch origin ${head_branch}
    then
      echo "- Push failed and can't fetch the branch" >&2
      exit 1
    fi
    if ! git -C ${tmpdir} diff --exit-code ${head_branch} origin/${head_branch}
    then
      echo "- Branch already exists but has diff" >&2
      exit 1
    fi
    echo "- Reusing existing branch"
  fi

  if [ $(cd ${tmpdir}; gh pr list --head ${head_branch} | wc -l) -gt 0 ]
  then
    echo "- PR is already open"
    rm -rf ${tmpdir}
    continue
  fi

  # Open PR
  echo "- Opening PR"
  (
    cd ${tmpdir}
    ${push_prefix} gh pr create \
      --base ${base_branch} \
      --head ${head_branch} \
      --fill
  )

  rm -rf ${tmpdir}

  sleep ${INPUT_PUSH_INTERVAL:-1}
done
rm -rf ${tmproot}

# assets-sync-action

GitHub Action to deploy asset files to multiple repositories.

## Inputs
<dl>
  <dt>repos</dt> <dd>Space separated list of target repository slugs. (required)</dd>
  <dt>github_token</dt> <dd>GitHub personal access token <b>with write permission to the repos</b>. Use <a href="https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets">encrypted secrets</a>. (required)</dd>
  <dt>git_user</dt> <dd>User name of commit author. (required)</dd>
  <dt>git_email</dt> <dd>E-mail address of commit author. (required)</dd>
  <dt>commit_message</dt> <dd>Commit message of generated commits. Defaults to <code>Update assets to %v</code>. (<code>%v</code>: version tag string)</dd>
  <dt>root_dir</dt> <dd>Root directory of the assets for this job. Defaults to <code>root</code>.</dd>
  <dt>dryrun</dt> <dd>Set true to run the job without pushing.</dd>
</dl>

## Directory structure

The repository using assets-sync-action must have `./root` directory.
Files in the `./root` will be deployed to the target repositories keeping its directory structure.

```
.
├── .github
│   └── workflows
│       └── assets-sync.yml (see example section)
└── root
    ├── dir
    │   └── another-file-to-be-deployed
    └── file-to-be-deployed
```

## Example

Deploy the files by adding `v0.0.0` style tag.

```yaml
name: assets-sync
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: checkout
        uses: actions/checkout@v2
      - name: sync
        uses: at-wat/assets-sync-action@v0
        with:
          repos: @@owner/repo1@@ @@owner/repo2@@
          git_user: @@MAINTAINER_NAME@@
          git_email: @@MAINTAINER_EMAIL_ADDRESS@@
          github_token: ${{ secrets.GITHUB_TOKEN_REPO }}
```

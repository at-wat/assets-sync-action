# assets-sync-action

GitHub Action to deploy asset files to multiple repositories.

## Inputs
<dl>
  <dt>repos</dt> <dd>Space separated list of target repository slugs. (required)</dd>
  <dt>github_token</dt> <dd>GitHub personal access token with write permission to the repos. (required)</dd>
  <dt>git_user</dt> <dd>User name of commit author. (required)</dd>
  <dt>git_email</dt> <dd>E-mail address of commit author. (required)</dd>
</dl>

## Example

```yaml
name: assets-sync
on:
  push:
    tags:
      - '[0-9]+.[0-9]+.[0-9]+'

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: checkout
        uses: actions/checkout@v2
      - name: sync
        uses: at-wat/assets-sync-action@v1
        with:
          repos: @@owner@@/@@repo1@@ @@owner@@/@@repo2@@
          git_user: @@MAINTAINER_NAME@@
          git_email: @@MAINTAINER_EMAIL_ADDRESS@@
          github_token: ${{ secrets.GITHUB_TOKEN_REPO }}
```

# DSAI-07 lab: CI gate, plan on PR, fail on policy

GitHub Actions runs fmt, validate, plan, and the DSAI-06 Conftest policies on every pull request, posts the result as a PR comment, and fails the check when policy fails. A second job runs Semgrep, gitleaks, and OSV-Scanner on the application code. Branch protection makes the plan check required.

## One-time setup (off camera in the lesson)

1. Push this folder to a new private GitHub repository on Ahmed's personal GitHub (`main` branch).
2. In the AWS sandbox, create an IAM OIDC provider for `token.actions.githubusercontent.com` and a role the workflow can assume from this repository's pull requests. Give it read-only permissions: plan needs to read, never write.
3. In the repository settings, add an Actions variable `AWS_PLAN_ROLE_ARN` with that role's ARN.
4. Branch protection on `main`: require the `plan` status check before merging.

## Steps

1. `git switch -c ai/app-logs`, copy `change/logs.tf` to the repo root, commit, push.
2. `gh pr create --fill`. Watch the `plan` check fail and read the PR comment.
3. Fix with Claude in Cursor: block public access on the logs bucket and scope the logs policy actions.
4. Commit, push, watch the check pass and the merge button unlock.

State: this lab plans against empty local state in CI, so every resource shows as create. Course repos that use a remote state backend pass `-backend-config` in the init step instead.

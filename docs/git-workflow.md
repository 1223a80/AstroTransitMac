# Git Workflow

This repository has already seen confusion caused by mixing multiple tasks in one worktree and by treating local commits as if they were already on GitHub. Use this checklist before and after every non-trivial change.

## 1. Confirm starting state

```bash
git status --short --branch
git log origin/main..HEAD --oneline
```

- `git status --short --branch` tells you whether the current branch is dirty and whether it is ahead / behind the tracked remote.
- `git log origin/main..HEAD --oneline` shows commits that exist only locally.
- If the worktree is dirty before you start, identify which files belong to which task before editing anything.

## 2. Keep task boundaries clean

- One user request or one technical objective per commit sequence.
- If unrelated work is already present locally, do not extend the mess. Separate it into distinct commits first.
- `PLANS.md` should describe the intended task boundary.
- `git diff` should prove the actual code changes.
- `CHANGELOG.md` should summarize the result after the code change exists.

## 3. Before review or handoff

Run the validation appropriate for the touched area, then inspect:

```bash
git diff --stat
git diff
```

If `PLANS.md` still has an older task marked `in progress` but that task is already done or superseded, close it before adding a new plan entry.

## 4. Before pushing

Check:

```bash
git status --short --branch
git log --oneline origin/main..HEAD
```

- Make sure each logical task has its own commit.
- Make sure commit messages match the actual task boundaries.
- Make sure `PLANS.md` and `CHANGELOG.md` align with those same boundaries.

## 5. After pushing

Verify that the branch is no longer ahead of the tracked remote:

```bash
git status --short --branch
```

Do not report "already on GitHub" unless that command confirms the branch is synchronized.

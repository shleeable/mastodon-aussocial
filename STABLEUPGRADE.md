# Stable Branch Upgrade Guide

This repo tracks upstream [mastodon/mastodon](https://github.com/mastodon/mastodon)
stable releases on the `stable` branch. Our custom work lives on `main` / `aus.social`.

The `stable` branch holds our own local changes (docs, tweaks) **on top of** a
given upstream release **tag** (for example `v4.6.3`). When a new release comes
out we **merge** the new tag into `stable` so that both the upstream changes and
our local commits are preserved. Conflicts are resolved by hand, keeping both
sides.

## One-time setup

Add the upstream remote if you don't already have it:

```bash
git remote add upstream https://github.com/mastodon/mastodon.git
# verify
git remote -v
```

## Upgrading `stable` to a new release (e.g. v4.6.4)

Replace `v4.6.4` below with the tag you're upgrading to. This uses a merge so
your local commits on `stable` are kept.

```bash
# 1. Fetch just the release tag from upstream (no other tags)
git fetch upstream tag v4.6.4 --no-tags

# 2. Confirm the tag points where you expect
git log -1 --format="%H %ci %s" v4.6.4

# 3. Switch to the stable branch and make sure it's current
git switch stable
git pull origin stable

# 4. Merge the release tag into stable (keeps upstream + your local commits)
git merge v4.6.4
```

### Resolving conflicts (keep both upstream and local)

Non-conflicting upstream changes merge automatically. Where the same lines were
touched by both upstream and your local commits, git pauses and marks conflicts:

```bash
# See which files conflict
git status

# For each conflicted file, open it and combine BOTH sides:
#   <<<<<<< HEAD            -> your local (stable) changes
#   =======
#   >>>>>>> v4.6.4          -> upstream release changes
# Edit to keep what you want from each, then remove the marker lines.

# If you want to take one whole side for a specific file instead of hand-editing:
git checkout --ours   path/to/file    # keep your local version
git checkout --theirs path/to/file    # keep the upstream version

# Stage each resolved file
git add path/to/file

# Once everything is resolved, finish the merge
git commit            # accept/edit the default merge message
```

If a merge goes sideways and you want to start over:

```bash
git merge --abort
```

### Publish

```bash
# 5. Push the merged result (normal push, no force needed)
git push origin stable

# 6. Verify
git log --oneline -5 stable
```

## Bringing the update into your custom branch

Once `stable` is updated, merge it into your working branch:

```bash
git switch aus.social        # or main
git merge stable             # resolve any conflicts with your custom tweaks
```

Or via GitHub CLI, from the `stable` branch:

```bash
gh pr create --base aus.social --head stable \
  --title "Merge upstream v4.6.4 into aus.social" \
  --body "Syncs custom branch with upstream Mastodon v4.6.4 stable release."
```

## Quick reference

| Step               | Command                                              |
| ------------------ | ---------------------------------------------------- |
| Fetch tag          | `git fetch upstream tag vX.Y.Z --no-tags`            |
| Update stable      | `git switch stable && git pull origin stable`        |
| Merge release      | `git merge vX.Y.Z`                                   |
| Keep local file    | `git checkout --ours <file> && git add <file>`       |
| Keep upstream file | `git checkout --theirs <file> && git add <file>`     |
| Finish merge       | `git commit`                                         |
| Publish            | `git push origin stable`                             |
| Merge to custom    | `git switch aus.social && git merge stable`          |

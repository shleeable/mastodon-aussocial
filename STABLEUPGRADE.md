# Stable Branch Upgrade Guide

This repo tracks upstream [mastodon/mastodon](https://github.com/mastodon/mastodon)
stable releases on the `stable` branch. Our custom work lives on `main` / `aus.social`.

The `stable` branch is kept in sync with a specific upstream release **tag**
(for example `v4.6.3`). This guide covers bumping it to the next tag.

## One-time setup

Add the upstream remote if you don't already have it:

```bash
git remote add upstream https://github.com/mastodon/mastodon.git
# verify
git remote -v
```

## Upgrading `stable` to a new release (e.g. v4.6.4)

Replace `v4.6.4` below with the tag you're upgrading to.

```bash
# 1. Fetch just the release tag from upstream (no other tags)
git fetch upstream tag v4.6.4 --no-tags

# 2. Confirm the tag points where you expect
git log -1 --format="%H %ci %s" v4.6.4

# 3. Switch to the stable branch
git switch stable

# 4. Reset stable to exactly match the release tag
git reset --hard v4.6.4

# 5. Push. Because step 4 rewrites history, this needs a force push.
#    --force-with-lease refuses to overwrite unexpected remote changes.
git push --force-with-lease origin stable

# 6. Verify the remote now points at the release commit
git ls-remote origin stable
```

> Note: `git reset --hard` and `git push --force-with-lease` are destructive to the
> `stable` branch history. That's intentional here, `stable` is meant to mirror the
> upstream tag exactly and hold no local commits.

## Bringing the update into your custom branch

Once `stable` matches the new release, open a PR to merge it into your working branch:

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

| Step            | Command                                             |
| --------------- | --------------------------------------------------- |
| Fetch tag       | `git fetch upstream tag vX.Y.Z --no-tags`           |
| Move stable     | `git switch stable && git reset --hard vX.Y.Z`      |
| Publish         | `git push --force-with-lease origin stable`         |
| Verify remote   | `git ls-remote origin stable`                       |
| Merge to custom | `git switch aus.social && git merge stable`         |

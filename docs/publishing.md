# Publishing PDtoMSstats on GitHub

This is a maintainer guide. It separates publishing the source repository from
publishing a ready-made Docker image.

## Before publishing

1. Confirm that `git status --short` is empty or contains only intentional
   changes.
2. Confirm that no project data, sample identifiers, results, reports,
   workbooks, credentials, or institutional certificates are tracked.
3. Run the repository checks and the de-identified example.
4. Decide whether the repository will be private or public.
5. Obtain owner approval for a distribution license before making the
   repository public. The current `LICENSE` is only a placeholder.

A private repository is the safest first publication when ownership or license
approval is still being decided.

## 1. Create an empty GitHub repository

On GitHub:

1. Select **New repository**.
2. Name it `PDtoMSstats`.
3. Select the owner or organization.
4. Choose **Private** or **Public**.
5. Do not add a README, `.gitignore`, or license because they already exist in
   the local repository.
6. Select **Create repository**.

GitHub will display the new repository URL, for example:

```text
https://github.com/OWNER/PDtoMSstats.git
```

## 2. Connect and push the existing local repository

From the local `PDtoMSstats` folder, replace `OWNER` and run:

```bash
git remote add origin https://github.com/OWNER/PDtoMSstats.git
git remote -v
git push -u origin main
```

If the organization requires SSH, use the SSH URL GitHub provides instead.
Do not paste access tokens into repository files or configuration files.

## 3. Add collaborators

For a personal repository, open **Settings > Collaborators** and invite the
required GitHub accounts. For an organization repository, grant access through
the appropriate team whenever possible.

Collaborators can then clone the repository:

```bash
git clone https://github.com/OWNER/PDtoMSstats.git
```

Direct them to [Getting started without R programming](getting-started.md).

## 4. Confirm GitHub Actions

The repository contains checks for repository structure, the de-identified
example, and Docker builds. Open the **Actions** tab after the first push and
confirm that the checks pass.

Organization policy may initially disable Actions or package publishing. If
so, an organization administrator must allow the workflows. The container
publishing workflow requests only `contents: read` and `packages: write`.

## 5. Create a release and publish the Docker image

Before tagging, make sure the same release version is recorded in
`DESCRIPTION`, `CITATION.cff`, and `CHANGELOG.md`. Move the relevant
`Unreleased` notes into that version's changelog section and commit those
changes.

The `Publish Docker image` workflow runs when a version tag beginning with `v`
is pushed. For version 0.1.1:

```bash
git tag -a v0.1.1 -m "PDtoMSstats 0.1.1"
git push origin v0.1.1
```

The workflow publishes Linux AMD64 and ARM64 images to GitHub Container
Registry with tags similar to:

```text
ghcr.io/owner/pdtomsstats:0.1.1
ghcr.io/owner/pdtomsstats:0.1
ghcr.io/owner/pdtomsstats:latest
```

Container names are lowercase. The first multi-platform build can take a long
time because the scientific R packages are compiled for both architectures.

After the workflow succeeds:

1. Open the package from the repository's right sidebar or the owner's
   **Packages** page.
2. Open **Package settings**.
3. Confirm that the package is linked to the repository.
4. Set package visibility and access to match the intended collaborators.

A public package is easiest for collaborators because it can be pulled without
signing in. A private package requires each collaborator to authenticate Docker
to `ghcr.io` with permission to read packages.

## 6. Test the published image

Replace `owner` with the lowercase GitHub owner:

```bash
docker pull ghcr.io/owner/pdtomsstats:0.1.1
docker run --rm ghcr.io/owner/pdtomsstats:0.1.1
```

The second command should end with a successful environment check.

The normal beginner instructions use `docker compose build`, which works even
when no prebuilt package is available. After the final GitHub owner and package
visibility are known, the getting-started guide can also advertise the exact
prebuilt image name.

## 7. Publish a GitHub release page

Open **Releases > Draft a new release**, select the version tag, and summarize:

- major workflow changes;
- changes that can affect numerical results;
- supported inputs and operating systems;
- known limitations;
- the Docker image tag.

Use `CHANGELOG.md` as the source for release notes. Do not attach private input
or output files.

## 8. Enable the documentation website

The repository contains a Quarto documentation website under `docs` and a
`Deploy documentation to GitHub Pages` workflow. One repository administrator
must complete the initial GitHub Pages setup:

1. Open **Settings > Pages**.
2. Under **Build and deployment**, select **GitHub Actions** as the source.
3. Open the **Actions** tab and run **Deploy documentation to GitHub Pages**, or
   push a documentation change to `main`.
4. Confirm the deployment at
   `https://openomics.github.io/PDtoMSstats/`.

The workflow renders the Markdown files with Quarto and deploys only the
generated static site. `docs/_site` is ignored by Git.

GitHub Pages availability and access controls for a private organization
repository depend on the organization's GitHub plan and policy. Treat the
website as potentially public: never place project data, sample identifiers,
credentials, unpublished results, or internal-only instructions under `docs`.

## Updating the repository

For later changes:

```bash
git add <intended-files>
git commit -m "Describe the change"
git push origin main
```

Create and push a new version tag only for a reviewed release. Never reuse or
move a published version tag to different code.

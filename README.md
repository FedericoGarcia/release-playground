# release-playground

Throwaway repository for rehearsing a pnpm monorepo release pipeline: release-please opens the release pull request, and merging it publishes to npm through trusted publishing (OIDC) with provenance. The packages are dummies and get unpublished once the rehearsal is over.

## Layout

| Path | Role |
| --- | --- |
| `packages/a` | Standalone package |
| `packages/b` | Peers on `a` through `workspace:*` |
| `config/typescript` | Private workspace package used as a `workspace:*` dev dependency; must never be published |
| `.github/workflows/release.yml` | release-please, then publish when a release is created or when dispatched with `force_publish` |
| `.github/workflows/ci.yml` | One build check on pull requests, to see whether the release pull request triggers it |
| `scripts/publish-with-npm.sh` | Alternative publish path: `pnpm pack` plus `npm publish <tarball>` |

The repository variable `PUBLISH_METHOD` picks the publish step: unset or `pnpm` runs `pnpm -r publish`, `npm` runs the script.

## Scenarios

Each scenario answers one question. Record the answer next to it.

1. **Bootstrap.** npm only lets you add a trusted publisher to a package that already exists. Does a local `--tag bootstrap` publish of `0.0.0` leave `latest` unset, or does npm point `latest` at it anyway?
   Answer: npm points `latest` at it anyway (`{"latest":"0.0.0","bootstrap":"0.0.0"}`), so the bootstrap version is what `npm install` gets until the first real release. The publish returned `202` ("being processed and may take a few minutes") and the package became readable 4 to 5 minutes later. `npm trust` succeeded for both packages right after their publishes were accepted.
2. **Release through OIDC.** After a `feat(a): …` commit, the release pull request, and its merge, does the publish job succeed with no token and show provenance on npmjs.com?
3. **pnpm or npm.** Does `pnpm -r publish` perform the OIDC exchange by itself? If not, does `PUBLISH_METHOD=npm` succeed after a `force_publish` dispatch?
4. **Peer range.** What range does the published `b` declare for `a`?
   Local `pnpm pack`: `workspace:*` is published as the exact version (`"0.0.0"`). Whether that hurts consumers depends on scenario 5: if every release of `a` also releases `b` with the new pin, the latest versions always match. `workspace:^` publishes a caret range, but a caret on `0.0.x` is still exact.
5. **Dependency cascade.** When only `a` changes, does `updatePeerDependencies` bump `b` too, to which version, and what does the source `package.json` of `b` say afterwards?
6. **New package.** Adding a package `c` with `0.0.0` in the manifest: does a `feat` commit release it as `0.0.1` (because of `bump-patch-for-minor-pre-major`), and does a `Release-As: 0.1.0` footer make it debut at `0.1.0`?
7. **Private package.** Is `config/typescript` skipped without failing the job?
   Local `pnpm -r publish --dry-run`: only `a` and `b` are selected; the private packages are skipped silently.
8. **Rerun.** Does a `force_publish` dispatch after a successful publish pass without publishing anything? Because npm processes a publish for a few minutes before the version becomes readable, also try a rerun inside that window: the "already published" check reads 404 there and may try to publish the same version again.
9. **Tarball contents.** Does each tarball hold only `dist`, `README.md`, `LICENSE` and `package.json`?
   Local `pnpm pack`: only those four entries ship. The published manifest keeps `"@playground/source": "./src/index.ts"` pointing at a file that is not in the tarball, and publint 0.3.25 reports "All good!" anyway. A `publishConfig.exports` without that condition removes it from the published manifest while development keeps resolving `src`. `devDependencies` ship with the private `@config/typescript` rewritten to `0.0.0`, and `dist/index.d.ts.map` points at `../src/index.ts`, which is not shipped either.
10. **Checks on the release pull request.** release-please opens its pull request with `GITHUB_TOKEN`, and events created with that token start no workflows. Does `CI` run on the release pull request? If a ruleset requires the `build` check, can the pull request be merged?
11. **Publish only from `main`.** With the trusted publisher bound to the `npm` environment and the environment limited to `main`, does a publish job started from another branch fail?

## Runbook

1. Install dependencies with `pnpm install`.
2. Create the public repository and push `main`.
3. Let Actions open pull requests, which a new repository does not allow by default:
   `gh api -X PUT repos/FedericoGarcia/release-playground/actions/permissions/workflow -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true`
4. Create the `npm` environment with a deployment branch policy that only allows `main` (Settings → Environments).
5. Bootstrap each package from an interactive terminal, since npm's web 2FA waits for the browser approval and fails with `EOTP` when it cannot: `nvm use && pnpm build && npm login`, then `nvm use && NPM_DIST_TAG=bootstrap bash scripts/publish-with-npm.sh`. Keep `nvm use` in the same command line, or the script runs without `node` on its `PATH`. `DRY_RUN=1` shows what would be published without publishing.
6. For each package: `npm trust github <package> --file release.yml --repo FedericoGarcia/release-playground --env npm --allow-publish`.
7. Push a `feat(a): …` commit, merge the release pull request, and watch the publish job.
8. If a publish fails, fix the cause and run the `Release` workflow manually with `force_publish`. Re-running the failed job also works, but a new push does not: release-please finds nothing to release and skips the publish job.
9. The repository and packages stay up as a reference for later questions. To clean up: `npm unpublish <package> --force`, `b` before `a`, since npm refuses to unpublish a package that others depend on. Within 72 hours of the first publish that is the only condition; after that, npm also requires fewer than 300 downloads in the last week and a single maintainer, and `npm deprecate` is the fallback. A version number can never be reused, and unpublishing every version blocks new versions of that name for 24 hours. Then archive the repository.

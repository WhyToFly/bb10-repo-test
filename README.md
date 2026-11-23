# bb10-repo-test

Test repository for Rubus / apk on BlackBerry 10. It holds one harmless demo package,
`hello-bb10-github` 1.0-r0, which installs a single text file
(`share/hello-bb10-github/hello.txt` under the apk root) and runs no scripts. It is signed with a
throwaway key made for this test (`keys/my-bb10-repo.rsa.pub`), not with the main repository's key.

Phones need bb10-apk-tools 20260927-r1 or newer for HTTPS.

## Addresses to add on a phone

| Route | Repository address | Signing key the phone needs |
|---|---|---|
| GitHub Pages (Settings -> Pages: branch `main`, folder `/` root) | `https://whytofly.github.io/bb10-repo-test/docs/repo` | `https://whytofly.github.io/bb10-repo-test/docs/keys/my-bb10-repo.rsa.pub` |
| GitHub Pages if set to folder `/docs` instead | `https://whytofly.github.io/bb10-repo-test/repo` | `https://whytofly.github.io/bb10-repo-test/keys/my-bb10-repo.rsa.pub` |
| raw.githubusercontent.com (no Pages needed) | `https://raw.githubusercontent.com/WhyToFly/bb10-repo-test/main/docs/repo` | `https://raw.githubusercontent.com/WhyToFly/bb10-repo-test/main/docs/keys/my-bb10-repo.rsa.pub` |
| Release `v1` (see below) | `https://github.com/WhyToFly/bb10-repo-test/releases/download/v1/APKINDEX.tar.gz` | `https://github.com/WhyToFly/bb10-repo-test/releases/download/v1/my-bb10-repo.rsa.pub` |

Key location convention (what Rubus looks for): the index's signature names the key file
(`.SIGN.RSA.<keyname>` inside `APKINDEX.tar.gz`); the key is fetched from `keys/<keyname>` next to
`repo-info.json`, or from `<keyname>` directly next to it (flat layouts such as releases).
`repo-info.json` sits one level above a folder repository's address, or next to the index file
when the address is the index itself.

Key fingerprint (SHA-256 of the DER public key):
`59:A2:2E:1E:85:AE:77:24:F7:80:5C:E8:23:C4:65:A6:1E:AE:00:DC:AB:A6:14:0E:17:49:FB:65:FE:2B:56:CA`

## Release-asset test (web UI)

1. Releases -> "Draft a new release" -> "Choose a tag": type `v1`, "Create new tag: v1 on publish",
   target `main`. Title: `v1`.
2. Attach exactly these four files from `release-assets/` (flat, keep the names):
   - `APKINDEX.tar.gz`
   - `hello-bb10-github-1.0-r0.apk`
   - `my-bb10-repo.rsa.pub`
   - `repo-info.json`
3. Publish release (not pre-release, not draft).
4. Check from a computer: `curl -sIL https://github.com/WhyToFly/bb10-repo-test/releases/download/v1/APKINDEX.tar.gz`
   should end in `HTTP/2 200` after one redirect.

## Rebuilding

`docker run --rm -v "$PWD":/r -w /r alpine:3.24 sh build.sh` (needs the private key in
`keys/my-bb10-repo.rsa`, which is not in git). Never rebuild a published version; raise `pkgrel`.

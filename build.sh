#!/bin/sh
# build.sh - build, sign and index the packages in packages/ for a GitHub-hosted repository.
#
# Run from this directory on a computer with Docker:
#     docker run --rm -v "$PWD":/r -w /r alpine:3.24 sh build.sh
#
# Output (both are the same signed packages, laid out for the two hosting styles):
#   docs/                     GitHub Pages ("Deploy from a branch", folder /docs)
#     .nojekyll
#     repo-info.json          name/description Rubus shows for the source
#     repo/armhf/APKINDEX.tar.gz   index (apk asks for <repo>/<phone arch>/APKINDEX.tar.gz)
#     repo/noarch/*.apk             packages (apk asks for <repo>/<package arch>/<file>)
#     keys/<name>.rsa.pub     public key for people who want to check signatures
#   release/                  GitHub release assets (flat: upload every file in it)
#     APKINDEX.tar.gz, *.apk, repo-info.json, <name>.rsa.pub
#
# Keys: on the first run a new RSA key pair is created in keys/. keys/*.rsa is the PRIVATE key:
# never commit or upload it (.gitignore excludes it). Back it up; a lost key means every phone
# has to be told about a new one.
set -eu

KEYNAME=${KEYNAME:-my-bb10-repo}   # file name of the key; phones store the public key under this name
REPO_NAME=${REPO_NAME:-"My BlackBerry 10 repository"}
REPO_DESC=${REPO_DESC:-"Packages for BlackBerry 10, installable with Rubus or apk."}

apk add --no-cache alpine-sdk openssl >/dev/null
adduser -D builder 2>/dev/null || true
addgroup builder abuild 2>/dev/null || true

mkdir -p keys
if [ ! -f "keys/$KEYNAME.rsa" ]; then
    echo "==> creating signing key keys/$KEYNAME.rsa (keep it private)"
    openssl genrsa -out "keys/$KEYNAME.rsa" 2048 2>/dev/null
    openssl rsa -in "keys/$KEYNAME.rsa" -pubout -out "keys/$KEYNAME.rsa.pub" 2>/dev/null
fi
H=/home/builder/.abuild
mkdir -p "$H" /etc/apk/keys
cp "keys/$KEYNAME.rsa" "keys/$KEYNAME.rsa.pub" "$H/"
cp "keys/$KEYNAME.rsa.pub" /etc/apk/keys/
echo "PACKAGER_PRIVKEY=\"$H/$KEYNAME.rsa\"" > "$H/abuild.conf"
chown -R builder:builder "$H"; chmod 600 "$H/$KEYNAME.rsa"

OUT=/home/builder/out
rm -rf "$OUT"; mkdir -p "$OUT"; chown builder:builder "$OUT"
for d in packages/*/; do
    [ -f "$d/APKBUILD" ] || continue
    b=/home/builder/build/$(basename "$d")
    rm -rf "$b"; mkdir -p "$b"; cp -R "$d". "$b/"; chown -R builder:builder "$b"
    echo "==> building $(basename "$d")"
    # REPODEST: abuild writes $REPODEST/<repo>/<arch>/; noarch packages land under the build arch.
    su builder -c "cd $b && REPODEST=$OUT abuild -F -d -P $OUT" 2>&1 | tail -2
done

rm -rf docs release
mkdir -p docs/repo/armhf docs/repo/noarch docs/keys release
# Collect every built .apk regardless of abuild's directory naming.
find "$OUT" -name '*.apk' -exec cp {} docs/repo/noarch/ \;
n=$(ls docs/repo/noarch/*.apk 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "no packages were built" >&2; exit 1; }

# The phones are armhf and the packages noarch: apk reads <repo>/armhf/APKINDEX.tar.gz and then
# downloads <repo>/noarch/<name>-<version>.apk (measured on a Classic). GitHub Pages does not
# serve symlinks reliably, so the index is a real file in armhf/ (with a copy in noarch/).
# Only noarch packages are supported by this layout; armhf packages would go in armhf/.
apk index --allow-untrusted -o docs/repo/armhf/APKINDEX.tar.gz docs/repo/noarch/*.apk
chown builder docs/repo/armhf/APKINDEX.tar.gz
su builder -c "abuild-sign -k $H/$KEYNAME.rsa $PWD/docs/repo/armhf/APKINDEX.tar.gz"
cp docs/repo/armhf/APKINDEX.tar.gz docs/repo/noarch/

cat > docs/repo-info.json <<EOF
{ "name": "$REPO_NAME", "description": "$REPO_DESC" }
EOF
: > docs/.nojekyll
cp "keys/$KEYNAME.rsa.pub" docs/keys/

cp docs/repo/armhf/APKINDEX.tar.gz docs/repo/noarch/*.apk release/
cp docs/repo-info.json "keys/$KEYNAME.rsa.pub" release/

# Self-check: the index must verify with the public key alone.
mkdir -p /tmp/vk && cp "keys/$KEYNAME.rsa.pub" /tmp/vk/
apk --keys-dir /tmp/vk verify docs/repo/noarch/*.apk
echo "==> $n package(s). docs/ is ready for GitHub Pages, release/ for release assets."

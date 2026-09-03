#! /bin/bash

set -eoux pipefail

rm -rf dist

# build
civet build.civet

# adjust .d.ts files: point .civet imports at .js and drop the .civet infix.
# find + a redirect rather than globstar + `sed -i`: macOS ships bash 3.2 and
# BSD sed, which have neither.
find dist -name '*.civet.d.ts' | while read -r f; do
  sed 's/\.civet"/.js"/g' "$f" > "${f%.civet.d.ts}.d.ts"
  rm "$f"
done

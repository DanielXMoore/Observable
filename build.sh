#! /bin/bash

set -eoux pipefail
shopt -s globstar

rm -rf dist

# build
civet build.civet

# adjust .d.ts files
for f in dist/**/*.civet.d.ts; do
  # replace all .civet imports with .js
  sed -i 's/\.civet"/.js"/g' "$f"
  mv "$f" "${f%.civet.d.ts}.d.ts"
done

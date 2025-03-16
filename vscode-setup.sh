#!/bin/env bash

FMTK_VERSION=2.0.5
FACTORIO_VERSION=2.0.41
FLIB_VERSION=v0.16.2

FACTORIO_ROOT="$1"
FMTK_BIN="$HOME/.vscode/extensions/justarandomgeek.factoriomod-debug-$FMTK_VERSION/bin/fmtk"

code --install-extension justarandomgeek.factoriomod-debug

rm -R ".vscode/factorio"
if [ -n "$FACTORIO_ROOT" ]; then
  $FMTK_BIN luals-addon -d "$FACTORIO_ROOT/doc-html/runtime-api.json" -p "$FACTORIO_ROOT/doc-html/prototype-api.json" ".vscode"
else
  $FMTK_BIN luals-addon -o "$FACTORIO_VERSION"
fi

rm -R ".vscode/factorio-data"
git clone --depth 1 --branch "$FACTORIO_VERSION" "https://github.com/wube/factorio-data.git" ".vscode/factorio-data"
rm -Rf ".vscode/factorio-data/.git"

rm -R ".vscode/flib"
git clone --depth 1 --branch "$FLIB_VERSION" "https://github.com/factoriolib/flib.git" ".vscode/flib"
rm -Rf ".vscode/flib/.git"

#!/bin/bash
# Correr a partir da raiz do repositório (onde está este script)
set -e
NAME=pg65363_pg65420
SRC_DIR="$(pwd)/$NAME"
PDF="${1:-}"

# Sem argumento: usa o único PDF que estiver dentro de pg65363_pg65420/
if [ -z "$PDF" ]; then
  PDFS=("$SRC_DIR"/*.pdf)
  if [ ${#PDFS[@]} -ne 1 ] || [ ! -f "${PDFS[0]}" ]; then
    echo "Indica o PDF: bash make_zip.sh caminho/do/relatorio.pdf"; exit 1
  fi
  PDF="${PDFS[0]}"
fi
[ -f "$PDF" ] || { echo "PDF nao encontrado: $PDF"; exit 1; }
for f in Makefile inputdata.txt src/MD.cpp; do
  [ -f "$SRC_DIR/$f" ] || { echo "Falta $NAME/$f"; exit 1; }
done

OUT="$(pwd)/$NAME.zip"
BUILD=$(mktemp -d)
rm -f "$OUT"

mkdir -p "$BUILD/$NAME/src"
cp "$SRC_DIR/Makefile" "$SRC_DIR/inputdata.txt" "$BUILD/$NAME/"
cp "$SRC_DIR/src/MD.cpp" "$BUILD/$NAME/src/"
cp "$PDF" "$BUILD/$NAME/relatorio.pdf"

find "$BUILD/$NAME" -type d -exec chmod 755 {} +
find "$BUILD/$NAME" -type f -exec chmod 644 {} +

(cd "$BUILD" && zip -rqX "$OUT" "$NAME")
rm -rf "$BUILD"

unzip -Z "$OUT"
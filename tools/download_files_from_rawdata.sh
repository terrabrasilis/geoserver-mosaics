#!/bin/bash
#
# Adjust the destination location for the files and the source URL for the download.
LOCAL_PATH="/pve8/storage/mosaic_process_data/pampa/2024"
URL="https://terrabrasilis.dpi.inpe.br/rawdata/BIOMAS_BR/PAMPA/ARQUIVOS_EQUIPE/Prodes_Pampa_2024/Imagens_Pampa_2024_mosaico/"
# The expected files have a TIFF or ZIP extension.
FILTRO=".*\.(zip|tif)$"

[ -z "$URL" ] && { echo "Uso: $0 URL [regex]"; exit 1; }

FILE_LIST=$(curl -fsSL "$URL" \
| grep -Eoi '<a [^>]*href="[^"]+"' \
| sed -E 's/.*href="([^"]+)".*/\1/' \
| grep -E "$FILTRO" \
| sed -E "s|^/|$(echo "$URL" | sed -E 's|(https?://[^/]+).*|\1|')/|" \
| awk -v base="$URL" '
  BEGIN {
    if (base !~ /\/$/) base = base"/"
    split(base, b, "/")
    base_no_file = base
  }
  {
    u=$0
    if (u ~ /^https?:\/\//) { print u; next }
    if (u ~ /^\//)                 { print b[1]"//"b[3] u; next }
    print base u
  }
' \
| sed 's|/\./|/|g' | sed 's|[^/]+/\.\./||g' \
| sort -u)

for FILE_URL in $FILE_LIST
do
  file_name=$(basename ${FILE_URL})
  if [[ ! -f "${LOCAL_PATH}/${file_name}" ]]; then
    echo "Download file: ${file_name}"
    wget --output-document="${LOCAL_PATH}/${file_name}" "${FILE_URL}"
  fi;
done

ls -lth ${LOCAL_PATH}
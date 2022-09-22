#!/bin/bash

mydir=$(pwd)

exec > ${mydir}/output_unzip_unrar_files.log 2>&1
echo "Inicio: `date +%d-%m-%y_%H:%M:%S`"

# unzip all zip files
for z in *.zip; do 
    unzip -o "$z" -d imagens/; 
done 

echo "Fim: `date +%d-%m-%y_%H:%M:%S`"


# unrar all zip files
for f in *.rar; do 
    unrar x -o+ "$f" imagens/; 
done

echo "Fim: `date +%d-%m-%y_%H:%M:%S`"


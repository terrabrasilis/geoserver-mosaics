#!/bin/bash
# remove the oldest file when has more than one with the same pathrow

GET_INDEX(){

  value="$1"

  for i in "${!PATHROWS[@]}"; do
     [[ "${PATHROWS[$i]}" = "${value}" ]] && break
  done

  echo $i
}

OLDER_DATE(){
  # convert to unix-timestamps and so compare the result numbers to return the oldest
  DT1=$(date -d "${1}" +%s)
  DT2=$(date -d "${2}" +%s)

  if [ $DT1 -ge $DT2 ];
  then
    echo "${2}"
  else
    echo "${1}"
  fi
}

BASE_DIR=$(pwd)
PATHROWS=()
FDATES=()
D_PATHROWS=()
D_FDATES=()

# first remove the unused cenes taged with "NAO_USOU_" in cerrado dataset
rm ./NAO_USOU_*.tif

for fullfile in `ls ${BASE_DIR}/*.tif | awk {'print $1'}`
do
    # split filename and extension
    filename=$(basename -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    PATHROW=$(echo ${filename} | cut -d'_' -f3)
    FDATE=$(echo ${filename} | cut -d'_' -f4)
    if [[ " ${PATHROWS[@]} " =~ " ${PATHROW} " ]]; then
      D_PATHROWS+=(${PATHROW})
      D_FDATES+=(${FDATE})
    else
      PATHROWS+=(${PATHROW})
      FDATES+=(${FDATE})
    fi;
done

RMVAL=()
length=${#D_PATHROWS[@]}
for ((i=0; i<$length; ++i));
do

  idx=$(GET_INDEX "${D_PATHROWS[$i]}")

  ODATE=$(OLDER_DATE "${D_FDATES[$i]}" "${FDATES[$idx]}")

  RMVAL+=("${D_PATHROWS[$i]}_${ODATE}_")
done

length=${#RMVAL[@]}
for ((i=0; i<$length; ++i));
do
  rm ./*${RMVAL[$i]}*.tif
done

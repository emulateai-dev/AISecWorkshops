#!/bin/bash 

dtxHome="/home/dtx"

if [[ "$EUID" != "0" ]]; then
    echo "Please run as root"
    exit 1
fi

git=$(find / -name 'AISecWorkshops' 2>/dev/null)

if [[ -d $git ]]; then
        echo "Repo here" 
else
        echo "Repo not found cloning"
        git -C $dtxHome clone https://github.com/emulateai-dev/AISecWorkshops.git 
fi

if [[ -f /etc/apt/sources.list ]]; then
    echo "Confirming broken package not in sources.list"
    deadsnakes=$(ls /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-*.sources | grep -o "plucky")
    if [[ -n "$deadsnakes" ]]; then
        echo "Broken package found in sources.list"
        sed -i 's/plucky/noble/g' /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-*.sources
        apt update -y 
    else
        echo "Broken package not found in sources.list"
        add-apt-repository ppa:deadsnakes/ppa -y
        sed -i 's/plucky/noble/g' /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-*.sources
        apt update -y  
    fi
fi
deadsnakeADD=$(grep -iE "^add-apt-repository ppa:deadsnakes/ppa -y |^add-apt-repository -y ppa:deadsnakes/ppa" $dtxHome/AISecWorkshops/labs/setup/vm/Pre_Installation.sh)
replace="#add-apt-repository -y ppa:deadsnakes/ppa"
if [[ "$deadsnakeADD" != "$replace" ]]; then
    sed -i 's_add-apt-repository -y ppa:deadsnakes/ppa_#add-apt-repository -y ppa:deadsnakes/ppa_g' $dtxHome/AISecWorkshops/labs/setup/vm/Pre_Installation.sh
    bash $dtxHome/AISecWorkshops/labs/setup/vm/Pre_Installation.sh
else 
    bash $dtxHome/AISecWorkshops/labs/setup/vm/Pre_Installation.sh
fi



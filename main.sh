#!/bin/bash

# Check if the domain argument is provided
if [ -z $1 ]; then
    echo "Please provide a domain name as an argument."
    exit 1
fi

# Set variables for output files and domain
export domain=$1
export merged_out="subdomains.txt"

# Create a blank subdomains.txt file
touch $merged_out

# Define functions for each tool
run_amass() {
    local amass_out="amass.txt"
    if amass enum -brute -active -d $domain -o $merged_out -silent; then
        echo "Error running Amass."
        exit 1
    fi
    echo "**********Amass successful**********"
}

run_chaos() {
    local chaos_out="chaos.txt"
    if [[ -z "${CHAOS_KEY}" ]];then
        echo "The chaos token doesnt exported"
        exit 1
    fi
    if chaos -d $domain -o $chaos_out;then
        sort -u $chaos_out $merged_out -o $merged_out
        rm $chaos_out
    else
        echo "Error running chaos"
        exit 1
    fi
    echo "**********Chaos successful**********"
}

run_crtsh() {
    local crtsh_out="crtsh.txt"
    if curl -s "https://crt.sh/?q=$domain&output=json" | jq -r ".[].name_value" | sed 's/\*//g' > $crtsh_out;then # grep -Po '(\w+\.\w+\.\w+)$'
        sort -u $crtsh_out $merged_out -o $merged_out
        rm $crtsh_out
    else
        echo "Error calling crt.sh"
        exit 1
    fi
    echo "**********crtsh successful**********"
}

run_securitytrails() {
    local securitytrails_out="securitytrails.txt"
    if curl -s "https://api.securitytrails.com/v1/domain/$domain/subdomains?children_only=true&include_inactive=true" -H 'apikey: stL85OmLX3fw9DXGNmfYLFEiZhbNYTZ4' > /dev/null | jq '.subdomains[]' | sed "s/\"//g" | sed "s/.*/&.$domain/" > $securitytrails_out;then
        sort -u $securitytrails_out $merged_out -o $merged_out
        rm $securitytrails_out
    else
        echo "Error calling securitytrails api"
        exit 1
    fi
    echo "**********securitytrails successful**********"
}

run_subfinder() {
    local subfinder_out="subfinder.txt"
    if subfinder -d $domain -o $subfinder_out -all -silent; then
        sort -u $subfinder_out $merged_out -o $merged_out
        rm $subfinder_out
        # comm -23 $subfinder_out $merged_out >> $merged_out
    else
        echo "Error running Subfinder."
        exit 1
    fi
    echo "**********Subfinder successful**********"
}

run_findomain() {
    local findomain_out="findomain.txt"
    if [[ -z "${findomain_fb_token}" ]] && [[ -z "${findomain_securitytrails_token}" ]]&& [[ -z "${findomain_virustotal_token}" ]];then
        echo "Tokens of findomain doesnt exported"
        exit 1
    fi
    if findomain -q -t $domain -u $findomain_out; then
        sort -u $findomain_out $merged_out -o $merged_out
        rm $findomain_out
        # comm -23 $findomain_out $merged_out >> $merged_out
    else
        echo "Error running Findomain."
        exit 1
    fi
    echo "**********Findomain successful**********"
}


export -f run_amass run_subfinder run_findomain run_crtsh run_chaos run_securitytrails


# Check the requirements is installed or not
echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing curl and ..."
echo "#########################################################################"
if [ -x "$(command -v curl)" ]; then
  tput setaf 2; echo "CURL already installed, skipping."
else
  sudo apt update && sudo apt install curl -y
  tput setaf 2; echo "CURL installed!!!"
fi
echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing unzip  ..."
echo "#########################################################################"
if [ -x "$(command -v unzip)" ]; then
  tput setaf 2; echo "unzip already installed, skipping."
else
  sudo apt update && sudo apt install unzip -y
  tput setaf 2; echo "unzip installed!!!"
fi
echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing amass..."
echo "#########################################################################"
if [ -x "$(command -v amass)" ]; then
  tput setaf 2; echo "amass already installed, skipping."
else
  go install -v github.com/owasp-amass/amass/v4/...@master
  tput setaf 2; echo "amass installed!!!"
fi
echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing subfinder..."
echo "#########################################################################"
if [ -x "$(command -v subfinder)" ]; then
  tput setaf 2; echo "subfinder already installed, skipping."
else
  go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
  if $? == 0;then
        tput setaf 2; echo "subfinder installed!!!"
  else
    tput setaf 1; echo "Cant install subfinder, try install it manually "
  fi
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing chaos..."
echo "#########################################################################"
if [ -x "$(command -v chaos)" ]; then
  tput setaf 2; echo "rapidapi already installed, skipping."
else
  go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest
  tput setaf 2; echo "chaos installed!!!"
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing findomain..."
echo "#########################################################################"
if [ -x "$(command -v findomain)" ]; then
  tput setaf 2; echo "findomain already installed, skipping."
else
  curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-linux.zip;unzip findomain-linux.zip;chmod +x findomain;sudo mv findomain /usr/bin/findomain
  tput setaf 2; echo "findomain installed!!!"
fi
echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing parallel..."
echo "#########################################################################"
if [ -x "$(command -v parallel)" ]; then
  tput setaf 2; echo "parallel already installed, skipping."
else
  sudo apt update && sudo apt install parallel -y
  tput setaf 2; echo "parallel installed!!!"
fi

tput setaf 6;
read -p "Everything is ready. start enumerating subdomains ??? " answer
case ${answer:0:1} in
    y|Y|yes|YES|Yes )
      echo "Starting !!!"
    ;;
    * )
      exit 0
    ;;
esac

# Run all tools in parallel
parallel --jobs 6 ::: run_amass run_subfinder run_findomain run_crtsh run_chaos run_securitytrails

#!/bin/bash
alias subbrute="python3.10 ~/Documents/subbrute/subbrute.py"
# Check if the domain argument is provided
if [ -z $1 ]; then
    echo "Please provide a domain name as an argument."
    exit 1
fi

cat subdomains.txt | sed 's/\.[^.]*\.[^.]*$//'| tr '.' '\n' |sort -u -o wordlist.txt
# Define functions for each tool
export domain=$1
run_shuffledns() {
    local shuffledns_out="shuffledns.txt"
    if shuffledns -d $domain -w ~/Documents/Recon/2m-subdomains.txt -r ~/Documents/Recon/resolvers.txt -o $shuffledns_out -silent; then
        sort -u $shuffledns_out subdomains.txt -o subdomains.txt
        rm $shuffledns_out
    else
        echo "Error running ShuffleDNS."
        exit 1
    fi
    echo "***************Shuffledns ran successful***************"
}

run_subbrute() {
    local subbrute_out="subbrute.txt"
    if subbrute -p $domain -r /home/thm/Documents/Recon/resolvers.txt -o $subbrute_out;then
        sort -u $subbrute_out subdomains.txt -o subdomains.txt
        rm $subbrute_out
    else
        echo "Error running subbrute"
        exit 1
    fi
    echo "***************Subbrute ran successful***************"
}

run_dnsgen() {
    local dnsgen_out="dnsgen.txt"
    # if ! cat "subdomains.txt" | dnsgen - | massdns -r ~/Documents/Recon/resolvers.txt -q -t A -o J --flush 2>/dev/null;then
    if cat "subdomains.txt" | dnsgen - > $dnsgen_out ;then
        sort -u $dnsgen_out subdomains.txt -o subdomains.txt
        rm $dnsgen_out
    else
        echo "Error running dnsgen"
        exit 1
    fi
    echo "***************DNSGen ran successful***************"
}

run_ripgen() {
    local ripgen_out="ripgen.txt"
    if cat subdomains.txt | ripgen > $ripgen_out;then
        sort -u $ripgen_out subdomains.txt -o subdomains.txt
        rm $ripgen_out
    else
        echo "Error running ripgen"
        exit 1
    fi
    echo "***************RIPGen ran successful***************"
}

# run_dnsrecon(){
#     if ! dnsrecon -d $domain -D
# }

# Export functions to use in parallel
export -f  run_shuffledns  run_dnsgen run_ripgen run_subbrute

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing shuffledns..."
echo "#########################################################################"
if [ -x "$(command -v shuffledns)" ]; then
  tput setaf 2; echo "shuffledns already installed, skipping."
else
  go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
  if $? == 0;then
        tput setaf 2; echo "shuffledns installed!!!"
  else
    tput setaf 1; echo "Cant install shuffledns, try install it manually "
  fi
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing dnsgen..."
echo "#########################################################################"
if [ -x "$(command -v dnsgen)" ]; then
  tput setaf 2; echo "dnsgen already installed, skipping."
else
  git clone https://github.com/ProjectAnte/dnsgen ~/Documents && cd ~/Documents/dnsgen && pip3 install -r requirements.txt && sudo python3 setup.py install
  if $? == 0;then
        tput setaf 2; echo "dnsgen installed!!!"
  else
    tput setaf 1; echo "Cant install dnsgen, try install it manually "
  fi
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing ripgen..."
echo "#########################################################################"
if [ -x "$(command -v ripgen)" ]; then
  tput setaf 2; echo "ripgen already installed, skipping."
else
  cargo install ripgen && export $PATH=PATH:/home/kali/.cargo/bin
  if $? == 0;then
        tput setaf 2; echo "ripgen installed!!!"
  else
    tput setaf 1; echo "Cant install ripgen, try install it manually "
  fi
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing subbrute..."
echo "#########################################################################"
if [ -x "$(command -v subbrute)" ]; then
  tput setaf 2; echo "subbrute already installed, skipping."
elif [ "$(type -t subbrute)" = 'alias' ]; then
  tput setaf 2; echo "subbrute already installed, skipping."
else
  git clone https://github.com/TheRook/subbrute.git ~/Documents && echo 'alias subbrute="python3.10 ~/Documents/subbrute/subbrute.py"' > ~/.zshrc
  if $? == 0;then
        tput setaf 2; echo "subbrute installed!!!"
  else
    tput setaf 1; echo "Cant install subbrute, try install it manually "
  fi
fi

tput setaf 6;
read -p "Everything is ready. start dnsBruteforcing ??? " answer
case ${answer:0:1} in
    y|Y|yes|YES|Yes )
      echo "Starting !!!"
    ;;
    * )
      exit 0
    ;;
esac
# Run all tools in parallel
parallel --jobs 4 ::: run_shuffledns run_dnsgen run_ripgen run_subbrute

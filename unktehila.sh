#!/bin/bash

# Check if running with root privileges
if [ "$EUID" -ne 0 ]
then
    echo "You need to run this script with administrative privileges to scan ports."
    exit 1
fi

# Create output directory with current date and time
output_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(date +%Y-%m-%d-%H-%m)"
mkdir -p "$output_dir"

# Define dependencies and their installation commands
dependencies=("masscan:masscan" "holehe:holehe" "sherlock:sherlock" "whatsmyname:whatsmyname")
install_commands=("apt-get install masscan" "pip3 install holehe" "git clone https://github.com/sherlock-project/sherlock.git /usr/local/sherlock; cd /usr/local/sherlock; python3 -m pip install -r requirements.txt" "git clone https://github.com/webbreacher/whatsmyname.git /usr/local/whatsmyname")

# Install dependencies if they are not already installed
for i in "${!dependencies[@]}"
do
    IFS=':' read -ra dep <<< "${dependencies[$i]}"
    if ! command -v "${dep[0]}" &> /dev/null
    then
        if [ "${dep[0]}" = "sherlock" ]; then
            # Check if sherlock directory exists before cloning
            if [ ! -d "/usr/local/sherlock" ]; then
                git clone https://github.com/sherlock-project/sherlock.git /usr/local/sherlock
                if [ -d "/usr/local/sherlock" ]; then
                    (cd /usr/local/sherlock && python3 -m pip install -r requirements.txt)
                fi
            fi
        elif [ "${dep[0]}" = "whatsmyname" ]; then
            # Check if whatsmyname directory exists before cloning
            if [ ! -d "/usr/local/whatsmyname" ]; then
                git clone https://github.com/webbreacher/whatsmyname.git /usr/local/whatsmyname
            fi
        else
            eval "${install_commands[$i]} > /dev/null 2>&1"
        fi
    fi
done


# Read user input
read -r -p "IP: " ip
read -r -p "Domain: " domain
read -r -p "Email: " email
read -r -p "Username: " username

echo "This could take a while. You should grab a coffee"
cat coffee.txt

# IPs
if [ -n "$ip" ]
then
    sudo masscan --range "$ip" -p0-65535U:0-65535 --banners --rate 1200000 | sudo tee "$output_dir/masscan.txt"
    curl http://ipwho.is/"$ip" > "$output_dir/ipwhois.txt"
    wget -rSnd -np -l inf --spider -o "$output_dir/wget.txt" "http://$ip"
fi

# Domain
if [ -n "$domain" ]
then
    wget -rSnd -np -l inf --spider -o "$output_dir/domain.txt" "$domain"
    curl "https://urlscan.io/api/v1/search/?q=domain:$domain"
fi

# Email
if [ -n "$email" ]
then
    holehe "$email" --only-used > "$output_dir/holehe.txt"
fi

# Username
if [ -n "$username" ]
then
    if [ ! -d "/usr/local/sherlock" ]; then
        echo "Sherlock is not installed or cannot be found"
    else
        cd /usr/local/sherlock/ && python3 sherlock "$username" > "$output_dir/sherlock.txt"
    fi
    if [ -n "$username" ]; then
        if [ ! -d "/usr/local/whatsmyname" ]; then
            echo "whatsmyname is not installed or cannot be found"
        else
            cd /usr/local/whatsmyname/ && python3 whats_my_name.py -u "$username" > "$output_dir/whatsmyname.txt"
        fi
    fi
fi

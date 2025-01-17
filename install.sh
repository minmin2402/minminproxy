#!/bin/bash

# Đường dẫn file cấu hình và thư mục 3proxy
WORKDIR="/home/proxy-installer"
mkdir $WORKDIR && cd $_
CONFIG_PATH="/usr/local/etc/3proxy/3proxy.cfg"
SERVICE_PATH="/etc/systemd/system/3proxy.service"
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

# Menu
show_menu() {
  echo "=============================="
  echo " MinMinProxy Management Script tele: @minmin24203"
  echo "=============================="
  echo "1. Install and setup 3proxy"
  echo "2. Generate proxy (no auth)"
  echo "3. Generate proxy (with auth)"
  echo "4. Remove all proxies"
  echo "5. Exit"
  echo "=============================="
  read -p "Choose an option [1-5]: " choice
}

# Kiểm tra và cấu hình IPv6
setup_ipv6() {
  echo "Checking IPv6 configuration..."
  local interface=$(ip -6 route | grep default | awk '{print $5}')
  if [ -z "$interface" ]; then
    echo "No IPv6 default route found. Configuring IPv6..."
    interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E 'eth|ens' | head -n 1)

    if [ -z "$interface" ]; then
      echo "No valid network interface found. Exiting."
      exit 1
    fi

    sudo tee /etc/netplan/99-custom-ipv6.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    $interface:
      addresses:
        - ${IP6}::7bc8:4000/64
      gateway6: ${IP6}::1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

    sudo netplan apply
    echo "IPv6 configured successfully."
  else
    echo "IPv6 is already configured."
  fi
}

# Cài đặt và cấu hình 3proxy
install_3proxy() {
  # Kiểm tra và xóa file cấu hình nếu tồn tại
  if [ -f "$CONFIG_PATH" ]; then
    echo "Config file exists. Removing it..."
    sudo rm -f $CONFIG_PATH
  fi

  echo "Installing 3proxy..."
  sudo apt update && sudo apt install -y git build-essential nano iptables
  cd $WORKDIR
  git clone https://github.com/z3apa3a/3proxy.git
  cd 3proxy
  make -f Makefile.Linux
  mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
  cp bin/3proxy /usr/local/etc/3proxy/bin/
  cp scripts/init.d/proxy.sh /etc/init.d/3proxy
  chmod +x /etc/init.d/3proxy
  echo "3proxy installed successfully."
  # Tạo file dịch vụ systemd
  echo "Setting up 3proxy service..."
  cat <<EOF | sudo tee $SERVICE_PATH
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/etc/3proxy/bin/3proxy $CONFIG_PATH
ExecStop=/bin/kill -s TERM $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  echo "nserver 8.8.8.8" >> $CONFIG_PATH
  echo "nserver 8.8.4.4" >> $CONFIG_PATH
  echo "timeouts 1 5 30" >> $CONFIG_PATH
  echo "log /var/log/3proxy.log D" >> $CONFIG_PATH
  echo "daemon" >> $CONFIG_PATH

  sudo systemctl daemon-reload
  sudo systemctl enable 3proxy
  echo "3proxy service setup completed."
  cd $WORKDIR
}

# Mở cổng bằng iptables
open_ports() {
  local start_port=$1
  local end_port=$2
  echo "Opening ports $start_port to $end_port..."
  sudo iptables -I INPUT -p tcp --dport $start_port:$end_port -j ACCEPT
  sudo ip6tables -I INPUT -p tcp --dport $start_port:$end_port -j ACCEPT
  sudo iptables-save > /etc/iptables/rules.v4
  sudo ip6tables-save > /etc/iptables/rules.v6
  echo "Ports $start_port to $end_port opened."
}

# Tạo proxy không yêu cầu xác thực
generate_no_auth_proxy() {
  read -p "Enter the number of proxies to create: " num_proxies
  read -p "Enter the starting port: " start_port

  end_port=$((start_port + num_proxies - 1))
  open_ports $start_port $end_port

  for ((i=0; i<num_proxies; i++)); do
    port=$((start_port + i))
    echo "proxy -n -p$port -i$IP4 -e$IP6::7bc8:400$i" >> $CONFIG_PATH
  done

  echo "Generated $num_proxies no-auth proxies starting from port $start_port."
  sudo systemctl daemon-reload
  sudo systemctl restart 3proxy
}

# Tạo proxy có xác thực
generate_auth_proxy() {
  read -p "Enter the username: " username
  read -p "Enter the password: " password
  read -p "Enter the number of proxies to create: " num_proxies
  read -p "Enter the starting port: " start_port

  end_port=$((start_port + num_proxies - 1))
  open_ports $start_port $end_port

  echo "users $username:CL:$password" >> $CONFIG_PATH

  for ((i=0; i<num_proxies; i++)); do
    port=$((start_port + i))
    echo "proxy -n -p$port -i$IP4 -e$IP6::7bc8:400$i" >> $CONFIG_PATH
  done

  echo "Generated $num_proxies auth proxies starting from port $start_port."
  sudo systemctl daemon-reload
  sudo systemctl restart 3proxy
}

# Xóa tất cả proxy
remove_all_proxies() {
  echo "Removing all proxies..."
  sudo rm -f $CONFIG_PATH
  sudo touch $CONFIG_PATH
  echo "Removed all proxies. Please reconfigure 3proxy if needed."
  sudo systemctl restart 3proxy
}

# Chạy script
while true; do
  show_menu
  case $choice in
    1) setup_ipv6; install_3proxy ;;
    2) setup_ipv6; generate_no_auth_proxy ;;
    3) setup_ipv6; generate_auth_proxy ;;
    4) remove_all_proxies ;;
    5) echo "Exiting..."; exit ;;
    *) echo "Invalid option. Please try again." ;;
  esac
done

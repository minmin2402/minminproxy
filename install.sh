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

# Cài đặt và cấu hình 3proxy
install_3proxy() {
  # Kiểm tra và xóa file cấu hình nếu tồn tại
  if [ -f "$CONFIG_PATH" ]; then
    echo "Config file exists. Removing it..."
    sudo rm -f $CONFIG_PATH
  fi

  echo "Installing 3proxy..."
  sudo apt update && sudo apt install -y git build-essential nano iptables
  git clone https://github.com/z3apa3a/3proxy.git
  cd 3proxy
  make -f Makefile.Linux
  mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
  cp 3proxy /usr/local/etc/3proxy/bin/
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

# Tạo proxy không yêu cầu xác thực
generate_no_auth_proxy() {
  read -p "Enter the number of proxies to create: " num_proxies
  read -p "Enter the starting port: " start_port

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
    1) install_3proxy ;;
    2) generate_no_auth_proxy ;;
    3) generate_auth_proxy ;;
    4) remove_all_proxies ;;
    5) echo "Exiting..."; exit ;;
    *) echo "Invalid option. Please try again." ;;
  esac
done

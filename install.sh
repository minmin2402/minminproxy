#!/bin/sh

# Cập nhật và cài đặt các gói cần thiết
sudo apt update
sudo apt install git build-essential make gcc g++ net-tools -y

# Tải và cài đặt 3proxy
git clone "https://github.com/z3APA3A/3proxy.git"
cd 3proxy
make -f Makefile.Linux || true
sudo make install

# Kiểm tra cài đặt 3proxy
if [ ! -d /usr/local/3proxy ]; then
    echo "Cài đặt 3proxy thất bại."
    exit 1
fi

# Tạo tệp script kiểm tra và xóa proxy hết hạn
cat <<'EOF' > /root/check_and_remove_expired_proxies.sh
#!/bin/bash

# Đường dẫn tệp dữ liệu proxy
DATA_FILE="/root/data.txt"
CONFIG_FILE="/usr/local/3proxy/conf/3proxy.cfg"
TEMP_FILE="/usr/local/3proxy/conf/3proxy_new.cfg"
TODAY=$(date +%Y-%m-%d)

# Tạo tệp cấu hình tạm thời
echo "" > "$TEMP_FILE"

# Đọc từng dòng trong tệp /root/data.txt
while IFS=/ read -r USER PASS IP PORT IPV6 EXPIRATION_DATE; do
    # Chuyển định dạng ngày từ DD-MM-YYYY sang YYYY-MM-DD để so sánh
    EXPIRATION_DATE_FORMATTED=$(date -d "$EXPIRATION_DATE" +%Y-%m-%d 2>/dev/null)
    
    # Kiểm tra ngày hết hạn
    if [[ "$TODAY" > "$EXPIRATION_DATE_FORMATTED" ]]; then
        echo "Xóa proxy cho user $USER (hết hạn vào $EXPIRATION_DATE_FORMATTED)"
        # Xóa cấu hình proxy hết hạn từ 3proxy.cfg
        sed -i "/allow $USER/,/flush/d" "$CONFIG_FILE"
    else
        echo "Proxy $USER vẫn còn hạn sử dụng."
        # Giữ cấu hình proxy chưa hết hạn
        grep -A5 "allow $USER" "$CONFIG_FILE" >> "$TEMP_FILE"
    fi
done < "$DATA_FILE"

# Ghi lại các phần cấu hình không liên quan đến proxy
grep -Ev "allow .*" "$CONFIG_FILE" >> "$TEMP_FILE"

# Thay thế cấu hình cũ
mv "$TEMP_FILE" "$CONFIG_FILE"

# Khởi động lại 3proxy để áp dụng cấu hình mới
systemctl restart 3proxy
EOF

# Cấp quyền thực thi cho script
chmod +x /root/check_and_remove_expired_proxies.sh

# Kiểm tra script trước khi thêm cronjob
if [ -f /root/check_and_remove_expired_proxies.sh ]; then
    (crontab -l 2>/dev/null; echo "0 0 * * * /bin/bash /root/check_and_remove_expired_proxies.sh") | crontab -
else
    echo "Script kiểm tra proxy không tồn tại. Hủy thêm cronjob."
fi

# Khởi động lại 3proxy để áp dụng cấu hình
systemctl restart 3proxy
systemctl status 3proxy || echo "Dịch vụ 3proxy không khởi động được."

echo "Cài đặt hoàn tất!"

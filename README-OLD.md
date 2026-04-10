```
chmod +x MDNS_Toolkit.sh
```

یک فایل به نام MasterDNS_tool.cfg کنار اسکریپت بسازید:
```
OUTPUT_DIR="./output"

RESOLV_FILE="sorted_ip.txt"
CLIENT_FILE="client_resolvers.txt"

EXECUTABLE="./MDV"

TEST_URL="https://speed.cloudflare.com/__down?bytes=1000000"

AUTH="user:pass"
SOCKS_HOST="127.0.0.1"
SOCKS_PORT="10800"
```

نمایش راهنما
```
bash MDNS_Toolkit.sh help
```

### 1. مرتب‌سازی IPها
##### مرتب‌سازی همه فایل‌های log:
```
bash MDNS_Toolkit.sh sa
```

##### مرتب‌سازی یک فایل خاص:
```
bash MDNS_Toolkit.sh s file.log
```
------------

### 2. تست سرعت (Speed Test)

```
bash MDNS_Toolkit.sh st
```

##### تست روی یک IP خاص:
```
bash MDNS_Toolkit.sh st 1.2.3.4
```

----

#####  تمام خروجی‌ها داخل فولدر زیر ذخیره می‌شوند:
```
./output/
```
----
## نحوه کار ابزار
### مرحله 1: انتخاب IP

از فایل sorted_ip.txt یا ورودی مستقیم

### مرحله 2: اجرای MDV

برای هر IP، اسکریپت MDV اجرا می‌شود تا SOCKS5 بالا بیاید

### مرحله 3: تست اتصال

با درخواست به:

```
myip.wtf/json
```

### مرحله 4: تست سرعت

دانلود فایل تست از:

```
https://speed.cloudflare.com/__down?bytes=1000000
```

-----

### نکات مهم عملکرد

برای بهترین نتیجه در MDV Client تنظیمات زیر پیشنهاد می‌شود:

```
SAVE_MTU_SERVERS_TO_FILE = false

DOWNLOAD_COMPRESSION_TYPE = 1

MIN_UPLOAD_MTU = 40
MAX_UPLOAD_MTU = 130

MIN_DOWNLOAD_MTU = 500
MAX_DOWNLOAD_MTU = 900
```

### نکات مهم
قبل از انجام تست فایل اجرایی را متوقف کنید

```
sudo systemctl stop masterdnsvpn
```

اگر MDV بالا نیاید، تست انجام نمی‌شود
SOCKS5 باید روی 127.0.0.1:8080 فعال باشد
بهتر است سیستم حداقل 1GB RAM داشته باشد
اجرای طولانی ممکن است باعث فشار CPU شود

----

### ساختار پروژه
```
MDNS_Toolkit.sh
MasterDNS_tool.cfg
MDV
sorted_ip.txt
client_resolvers.txt
output/
```


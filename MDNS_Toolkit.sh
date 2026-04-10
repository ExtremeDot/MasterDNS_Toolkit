#!/usr/bin/env bash
set -u

# ================= COLORS =================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ================= LOGO =================
echo -e "${CYAN}"
echo "███╗   ███╗██████╗ ███╗   ██╗███████╗"
echo "████╗ ████║██╔══██╗████╗  ██║██╔════╝"
echo "██╔████╔██║██║  ██║██╔██╗ ██║███████╗"
echo "██║╚██╔╝██║██║  ██║██║╚██╗██║╚════██║"
echo "██║ ╚═╝ ██║██████╔╝██║ ╚████║███████║"
echo "╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═══╝╚══════╝"
echo -e "${GREEN}MasterDNS Toolkit${NC}\n"

CONFIG_FILE="./MasterDNS_tool.cfg"

# ================= CREATE CONFIG IF NOT EXISTS =================
if [[ ! -f "$CONFIG_FILE" ]]; then
cat <<EOF > "$CONFIG_FILE"
OUTPUT_DIR="./output"
RESOLV_FILE="sorted_ip.txt"
CLIENT_FILE="client_resolvers.txt"
EXECUTABLE="./MDV"
TEST_URL="https://speed.cloudflare.com/__down?bytes=1000000"

AUTH="master_dns_vpn:master_dns_vpn"
SOCKS_HOST="127.0.0.1"
SOCKS_PORT="10800"
EOF

echo -e "${YELLOW}Sample config created: $CONFIG_FILE${NC}"
fi

source "$CONFIG_FILE"
mkdir -p "$OUTPUT_DIR"

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$OUTPUT_DIR/speed_$DATE.log"

# ================= SORT =================
sort_ips() {
  grep -Eho '([0-9]{1,3}\.){3}[0-9]{1,3}' "$@" \
  | awk -F. '$1<=255 && $2<=255 && $3<=255 && $4<=255' \
  | sort -u -t. -k1,1n -k2,2n -k3,3n -k4,4n \
  > "$RESOLV_FILE"

  cp "$RESOLV_FILE" "$OUTPUT_DIR/sorted_ip_$DATE.txt"

  echo -e "${GREEN}Sorted -> $RESOLV_FILE${NC}"
}

# ================= TXT → LOG =================
convert_txt_to_log() {
  for f in *.txt; do
    [[ "$f" == "client_resolvers.txt" ]] && continue
    [[ "$f" == "sorted_ip.txt" ]] && continue
    mv -- "$f" "${f%.txt}.log"
  done
  echo -e "${GREEN}TXT → LOG done${NC}"
}

# ================= PREPARE CLIENT CONFIG =================
prepare_client() {

  FILE="client_config.toml"

  [[ ! -f "$FILE" ]] && echo -e "${RED}client_config.toml not found${NC}" && exit 1

  cp "$FILE" client_config.original

  sed -i 's|SAVE_MTU_SERVERS_TO_FILE *=.*|SAVE_MTU_SERVERS_TO_FILE = false|' "$FILE"
  sed -i 's|MIN_UPLOAD_MTU *=.*|MIN_UPLOAD_MTU = 40|' "$FILE"
  sed -i 's|MIN_DOWNLOAD_MTU *=.*|MIN_DOWNLOAD_MTU = 500|' "$FILE"
  sed -i 's|MAX_UPLOAD_MTU *=.*|MAX_UPLOAD_MTU = 120|' "$FILE"
  sed -i 's|MAX_DOWNLOAD_MTU *=.*|MAX_DOWNLOAD_MTU = 900|' "$FILE"

  sed -i 's|LISTEN_IP *=.*|LISTEN_IP = "127.0.0.1"|' "$FILE"
  sed -i 's|LISTEN_PORT *=.*|LISTEN_PORT = 55555|' "$FILE"

  sed -i 's|SOCKS5_AUTH *=.*|SOCKS5_AUTH = true|' "$FILE"
  sed -i 's|SOCKS5_USER *=.*|SOCKS5_USER = "ab1"|' "$FILE"
  sed -i 's|SOCKS5_PASS *=.*|SOCKS5_PASS = "ab2"|' "$FILE"

  echo -e "${GREEN}client_config prepared + backup created${NC}"
}

# ================= SYNC CONFIG =================
sync_cfg() {

  FILE="client_config.toml"

  USER=$(grep SOCKS5_USER "$FILE" | cut -d '"' -f2)
  PASS=$(grep SOCKS5_PASS "$FILE" | cut -d '"' -f2)
  HOST=$(grep LISTEN_IP "$FILE" | cut -d '"' -f2)
  PORT=$(grep LISTEN_PORT "$FILE" | grep -o '[0-9]*')

  sed -i "s|AUTH=.*|AUTH=\"$USER:$PASS\"|" "$CONFIG_FILE"
  sed -i "s|SOCKS_HOST=.*|SOCKS_HOST=\"$HOST\"|" "$CONFIG_FILE"
  sed -i "s|SOCKS_PORT=.*|SOCKS_PORT=\"$PORT\"|" "$CONFIG_FILE"

  echo -e "${GREEN}Config synced with client_config.toml${NC}"
}
# ================= SPEED TEST =================
speedtest_loop() {

while true; do

    if [ ! -s "$RESOLV_FILE" ]; then
        echo "tamam shod"
        break
    fi

    IP=$(head -n 1 "$RESOLV_FILE")
    echo "Processing IP: $IP"

    echo "$IP" > "$CLIENT_FILE"
    sed -i '1d' "$RESOLV_FILE"

    chmod +x "$EXECUTABLE"
    "$EXECUTABLE" > /dev/null 2>&1 &
    MDV_PID=$!

    echo "Waiting for SOCKS5..."
    for i in {1..30}; do
        if nc -z $SOCKS_HOST $SOCKS_PORT 2>/dev/null; then
            break
        fi
        sleep 2
    done

    RESULT1="FAIL"
    RESULT2="FAIL"
    RESULT3="FAIL"

    for i in 1 2 3; do
        RESPONSE=$(curl -s --max-time 10 \
            --socks5 $SOCKS_HOST:$SOCKS_PORT \
            --proxy-user $AUTH \
            myip.wtf/json)

        COUNTRY=$(echo "$RESPONSE" | grep -o '"YourFuckingCountry": *"[^"]*"' | cut -d '"' -f4)

        if [ -n "$COUNTRY" ]; then
            STATUS="OK"
        else
            STATUS="FAIL"
        fi

        case $i in
            1) RESULT1=$STATUS ;;
            2) RESULT2=$STATUS ;;
            3) RESULT3=$STATUS ;;
        esac

        sleep 2
    done

    if [[ "$RESULT1" == "OK" || "$RESULT2" == "OK" || "$RESULT3" == "OK" ]]; then

        START=$(date +%s%N)

        SPEED=$(curl -o /dev/null -s \
            --max-time 20 \
            --socks5 $SOCKS_HOST:$SOCKS_PORT \
            --proxy-user $AUTH \
            -w "%{speed_download}" \
            "$TEST_URL")

        END=$(date +%s%N)

        DURATION=$(echo "scale=2; ($END - $START)/1000000000" | bc)
        SPEED_KB=$(echo "scale=2; $SPEED/1024" | bc)

        echo "$(date) | $IP $RESULT1 $RESULT2 $RESULT3 - Speed: ${SPEED_KB} KB/s | Time: ${DURATION}s" | tee -a "$LOG_FILE"

    else
        echo "$(date) | IP $IP skipped (all FAIL)" | tee -a "$LOG_FILE"
    fi

    # kill MDV (very important fix)
    kill $MDV_PID 2>/dev/null
    sleep 2

    if ps -p $MDV_PID > /dev/null 2>&1; then
        kill -9 $MDV_PID
    fi

    echo "--------------------------------------"

    # IMPORTANT: prevent script crash
    sleep 1

done
}


# ================= HELP =================
show_help() {

echo -e "${CYAN}================ MasterDNS Toolkit =================${NC}"

echo -e "${YELLOW}General Commands:${NC}"
echo -e "${GREEN}sa${NC}        → extract IPs from all logs"
echo -e "${GREEN}s file${NC}    → sort IPs from file"
echo -e "${GREEN}st [IP]${NC}   → speed test"

echo ""
echo -e "${YELLOW}Utility:${NC}"
echo -e "${GREEN}conv${NC}      → convert txt → log"
echo -e "${GREEN}prep${NC}      → prepare client_config.toml"
echo -e "${GREEN}sync${NC}      → sync cfg from client_config"

echo ""
echo -e "${YELLOW}Notes:${NC}"
echo "Stop service before run:"
echo "sudo systemctl stop masterdnsvpn"

echo -e "${CYAN}====================================================${NC}"
}

# ================= MAIN =================
case "${1:-help}" in

  sa)
    sort_ips *.log
    ;;

  s)
    sort_ips "$2"
    ;;

  st)
    echo "Run speedtest..."
    if [[ -n "${2:-}" ]]; then
      speedtest_single "$2"
    else
      speedtest_loop
    fi
    ;;

  conv)
    convert_txt_to_log
    ;;

  prep)
    prepare_client
    ;;

  sync)
    sync_cfg
    ;;

  help)
    show_help
    ;;

  *)
    show_help
    ;;

esac

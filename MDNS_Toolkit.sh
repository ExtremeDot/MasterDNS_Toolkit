#!/usr/bin/env bash
set -u

CONFIG_FILE="./MasterDNS_tool.cfg"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "config peyda nashod"
  exit 1
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

  echo "done -> $RESOLV_FILE"
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

# ================= SINGLE IP =================
speedtest_single() {
    echo "$1" > "$CLIENT_FILE"
    echo "$1" > "$RESOLV_FILE"
    speedtest_loop
}

# ================= MAIN =================
case "${1:-h}" in

  sa)
    shopt -s nullglob
    files=( *.log )
    sort_ips "${files[@]}"
    ;;

  s)
    sort_ips "$2"
    ;;

  st)
    if [[ -n "${2:-}" ]]; then
      speedtest_single "$2"
    else
      speedtest_loop
    fi
    ;;

  help)
  echo "----------------------------------------------------------------------------------------------------"
  echo "Ghabl az ejraye script, Service Master DNS ro ghire faal konid, sudo systemctl stop masterdnsvpn"
  echo "MasterDNS_tool.cfg ro berooz resani konid , nano MasterDNS_tool.cfg"
  echo "IP haye vorodi baraye test tooye file sorted_ip.txt gharar migireh"
  echo ""
  echo " Dastoorat --------------"
  echo "MDNS_Toolkit.sh sa , IP ha ro az tamami file haye log biroon miare va mirizeh tooye sorted_ip.txt"
  echo "MDNS_Toolkit.sh s file.txt , IP haye daroon file.txt ro moratab mikoneh va mifrest to sorted_ip.txt"
  echo "MDNS_Toolkit.sh st 1.2.3.4 , IP 1.2.3.4 ro copy mikoneh to client_resolvers.txt va azash test migireh"
  echo "----------------------------------------------------------------------------------------------------"
  echo "Tanzimat zire ro dar client_config.toml anjam bedid."
  echo "az client_resolver.txt copy backupd begirid. cp client_resolver.txt client_resolver.txt.backup"
  echo "client_config.toml ro injori tanzim konid ghabl az ejra"
  echo " 1- log ro khamoosh konid, SAVE_MTU_SERVERS_TO_FILE = false "
  echo " 2- MIN_UPLOAD_MTU = 40 "
  echo " 3- MAX_UPLOAD_MTU = 120 "
  echo " 2- MIN_DOWNLOAD_MTU = 500 "
  echo " 2- MAX_DOWNLOAD_MTU = 900 "
  echo "----------------------------------------------------------------------------------------------------"
  echo ""

  *)
    ;;
    echo "Master DNS VPN Toolkit , run with help for more info "
    echo "MDNS_Toolkit.sh help"
    echo
    echo "| sa | s file | st [IP]"
    ;;

esac

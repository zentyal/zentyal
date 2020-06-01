#!/bin/bash -x

# If the server is already registered and the token exists...
if [ -f /var/lib/zentyal/ucp-server_data ] && [ -f /var/lib/zentyal/ucp-token ] && [ -f /var/lib/zentyal/.license ]; then
    # Doing the call 25 times with a 2 seconds delay
    for i in {1..10};
    do 
        # Preparing the request vars' data, some of these vars could be outside the loop, but I prefer to put them innside to get a cleaner code
        ID=$(cat /var/lib/zentyal/ucp-server_id)
        NOW=$(date +"%Y-%m-%d %H:%M:%S")
        TOKEN=$(cat /var/lib/zentyal/ucp-token)

        HOSTNAME=$(hostname)
        MEMORY=$(free -m | awk 'NR==2{printf "%.2f\n", $3*100/$2}')

        DISK_ROOT_SIZE=$(df -hm / --output=size | awk '{if(NR>1)print}'| sed 's/ //g')
        DISK_ROOT_AVAILABLE=$(df -hm / --output=avail | awk '{if(NR>1)print}'| sed 's/ //g')
        DISK_ROOT_USED=$(df -hm / --output=used | awk '{if(NR>1)print}'| sed 's/ //g')
        DISK_ROOT_USED_PERCENT=$(df -hm / --output=pcent | awk '{if(NR>1)print}'| sed 's/ //g')

        DISK_BOOT_SIZE=$(df -hm /boot --output=size | awk '{if(NR>1)print}'| sed 's/ //g')
        DISK_BOOT_AVAILABLE=$(df -hm /boot --output=avail | awk '{if(NR>1)print}'| sed 's/ //g')
        DISK_BOOT_USED=$(df -hm /boot --output=used | awk '{if(NR>1)print}'| sed 's/ //g')
        DISK_BOOT_USED_PERCENT=$(df -hm /boot --output=pcent | awk '{if(NR>1)print}'| sed 's/ //g')

        CPU_LOAD_LAST=$(cut -d' ' -f1 /proc/loadavg)
        CPU_LOAD_LAST_P=$( echo | awk "{print ${CPU_LOAD_LAST} * 100 }")
        CPU_LOAD_LAST_V=$(cut -d' ' -f2 /proc/loadavg)
        CPU_LOAD_LAST_V_P=$( echo | awk "{print ${CPU_LOAD_LAST_V} * 100 }")
        CPU_LOAD_LAST_X=$(cut -d' ' -f3 /proc/loadavg)
        CPU_LOAD_LAST_X_P=$( echo | awk "{print ${CPU_LOAD_LAST_X} * 100 }")

        # Preparing the data with JSON encoding
        JSON_STRING=$( jq -n \
                            --arg h "$HOSTNAME" \
                            --arg l "$NOW" \
                            --arg m "$MEMORY" \
                            --arg drs "$DISK_ROOT_SIZE" \
                            --arg dra "$DISK_ROOT_AVAILABLE" \
                            --arg dru "$DISK_ROOT_USED" \
                            --arg drup "$DISK_ROOT_USED_PERCENT" \
                            --arg dbs "$DISK_BOOT_SIZE" \
                            --arg dba "$DISK_BOOT_AVAILABLE" \
                            --arg dbu "$DISK_BOOT_USED" \
                            --arg dbup "$DISK_BOOT_USED_PERCENT" \
                            --arg cpul "$CPU_LOAD_LAST_P" \
                            --arg cpulv "$CPU_LOAD_LAST_V_P" \
                            --arg cpulx "$CPU_LOAD_LAST_X_P" \
                            '{
                                hostname: $h,
                                last_connection: $l,
                                memory: $m,
                                disk_root_size : $drs,
                                disk_root_available : $dra,
                                disk_root_used : $dru,
                                disk_root_used_percent : $drup,
                                disk_boot_size : $dbs,
                                disk_boot_available : $dba,
                                disk_boot_used : $dbu,
                                disk_boot_used_percent : $dbup,
                                cpu_last : $cpul,
                                cpu_last_v : $cpulv,
                                cpu_last_x : $cpulx,
                            }'
                    )

        # Run the request to update the server
        REQUEST=$(/usr/bin/curl --silent -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "$JSON_STRING" http://192.168.1.122/api/servers/$ID -o /dev/null -w "%{http_code}")
        if [ $REQUEST -ne "200" ]; then
            logger UCP[$$] WARNING: The update server\'s status request failed
        else 
            sleep 5;
        fi
    done
fi

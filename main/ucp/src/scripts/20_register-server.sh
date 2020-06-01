#!/bin/bash

# If the server isn't already registered, it's a commercial edition and the token exists...
if [ ! -f /var/lib/zentyal/ucp-server_data ] && [ -f /var/lib/zentyal/ucp-token ] && [ -f /var/lib/zentyal/.license ]; then

    touch /var/lib/zentyal/.uuid
    U_UUID=$(uuid) 
    echo $U_UUID > /var/lib/zentyal/.uuid 

    # Preparing request vars
    HOSTNAME=$(hostname)
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    UUID=$(cat /sys/class/dmi/id/product_uuid)
    USER_UUID=$(cat /var/lib/zentyal/.uuid)
    LK=$(cat /var/lib/zentyal/.license)
    TOKEN=$(cat /var/lib/zentyal/ucp-token)
    TMP_DATA_FILE=$(mktemp /tmp/XXXXXXX)

    # Preparing the data with JSON encoding
    JSON_STRING=$( jq -n \
                    --arg h "$HOSTNAME" \
                    --arg l "$NOW" \
                    --arg u "$UUID" \
                    --arg uu "$USER_UUID" \
                    --arg lk "$LK" \
                    '{
                        hostname: $h, 
                        last_connection: $l,
                        uuid: $u,
                        user_uuid: $uu,
                        license_key: $lk
                    }' 
                )

    . /etc/ucp.conf
    
    # Run the request to register the machine in the API's backend and save locally the server's data
    REQUEST=$(/usr/bin/curl --silent -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "$JSON_STRING" $destination/api/servers  -w "%{http_code}" -o $TMP_DATA_FILE)

    if [ $REQUEST -eq "200" ]; then
        # Save server data
        SERVER_DATA=$(cat $TMP_DATA_FILE | jq -r ".data")
        SERVER_ID=$(cat $TMP_DATA_FILE | jq -r ".data.id")
        SERVER_PORT=$(cat $TMP_DATA_FILE | jq -r ".data.port")

        # Persists the server's data in several files, this file is also used to check if the server is already registered in the API backend
        echo "$SERVER_DATA" > /var/lib/zentyal/ucp-server_data
        # Persists the server's ID in order to use it later to make the iterative updates
        echo "$SERVER_ID" > /var/lib/zentyal/ucp-server_id
        # The remote port where Zentyal is going to be forwarded
        echo "$SERVER_PORT" > /var/lib/zentyal/.port
    else
        logger UCP[$$] WARNING: The register server request failed
    fi

    rm $TMP_DATA_FILE
fi

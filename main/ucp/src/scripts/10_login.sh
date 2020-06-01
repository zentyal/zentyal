#!/bin/bash

# Preparing request vars
USER=$(/usr/share/zentyal/shell '$global->modInstance("ucp")->model("Settings")->email')
PASS=$(/usr/share/zentyal/shell '$global->modInstance("ucp")->model("Settings")->password')
GRANT_TYPE='password' 
CLIENT_ID=$(/usr/share/zentyal/shell '$global->modInstance("ucp")->model("Settings")->apiId')
CLIENT_SECRET=$(/usr/share/zentyal/shell '$global->modInstance("ucp")->model("Settings")->apiKey')
TMP_TOKEN_FILE=$(mktemp /tmp/XXXXXXX)

# Preparing the data with JSON encoding
JSON_STRING=$( jq -n \
                  --arg u "$USER" \
                  --arg p "$PASS" \
                  --arg g "$GRANT_TYPE" \
                  --arg i "$CLIENT_ID" \
                  --arg s "$CLIENT_SECRET" \
                  '{
                      username: $u, 
                      password: $p, 
                      grant_type: $g, 
                      client_id: $i, 
                      client_secret: $s
                    }' 
            )

. /etc/ucp.conf

# Run the request
REQUEST=$(/usr/bin/curl --silent -X POST -H "Content-Type: application/json" -d "$JSON_STRING" $destination/oauth/token -w "%{http_code}" -o $TMP_TOKEN_FILE)

# Check if the request was 200 OK
if [ $REQUEST -eq "200" ]; then
    # Get the token
    TOKEN=$(cat $TMP_TOKEN_FILE| jq -r ".access_token")
    # Persist the token
    echo $TOKEN > /var/lib/zentyal/ucp-token
else
    logger UCP[$$] WARNING: Error obtaining the UCP token
fi

rm $TMP_TOKEN_FILE
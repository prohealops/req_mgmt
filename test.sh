# Define variables
INSTANCE="dev303944.service-now.com"
USERNAME="admin"
PASSWORD="msZkE*-Z7Xq9"
REQUEST_NUMBER="REQ0010001"

# Step 1: First get the sys_id of the request
SYS_ID=$(curl -s -X GET \
     -u "$USERNAME":"$PASSWORD" \
     -H "Accept: application/json" \
     "https://$INSTANCE/api/now/table/sc_request?sysparm_query=number=$REQUEST_NUMBER&sysparm_fields=sys_id" \
     | grep -o '"sys_id":"[^"]*' | cut -d'"' -f4)

echo $SYS_ID

# Step 2: Update the request using PUT with the sys_id
curl -X PUT \
     -u "$USERNAME":"$PASSWORD" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d '{"state":4,"close_code":"Completed Successfully","close_notes":"Automated closure: task completed successfully","request_state": "closed_complete"}' \
     "https://$INSTANCE/api/now/table/sc_request/$SYS_ID"


```markdown
# Update ServiceNow Request Status to "In Progress"

To update the status of a ServiceNow request from "New" to "In Progress," you can use the following `curl` command:

```bash
curl -X PUT \
  https://<your-instance>.service-now.com/api/now/table/<table_name>/<sys_id> \
  --header "Content-Type: application/json" \
  --header "Accept: application/json" \
  --user '<username>:<password>' \
  --data '{
    "state": "In Progress"
  }'
```

## Explanation:
- Replace `<your-instance>` with your ServiceNow instance URL.
- Replace `<table_name>` with the name of the table (e.g., `incident` or `change_request`).
- Replace `<sys_id>` with the unique ID of the record you want to update.
- Replace `<username>` and `<password>` with your ServiceNow credentials.
- The `state` field is updated to "In Progress."

### Example:
```bash
curl -X PUT \
  https://dev12345.service-now.com/api/now/table/incident/1234567890abcdef \
  --header "Content-Type: application/json" \
  --header "Accept: application/json" \
  --user 'admin:password123' \
  --data '{
    "state": "In Progress"
  }'
```

> **Note:** Ensure you have the necessary permissions and API access enabled in your ServiceNow instance.
```
(function executeLocalTest() {
  try {
    // Hard-coded test payload
    var payload = {
      ritm: "RITM0001234",
      requestNumber: "REQ0001234",
      catalogName: "Test Catalog Item",
      status: "new",   
      variables: {
        "var1": "value1",
        "var2": "value2"
      }
    };

    console.log("Using test payload:", JSON.stringify(payload));

    // Step 1: Get oauthCode
    var accessKey = "YTZIPMUCE0HGVLQD1KWS";
    var secretKey = "nnvOrq9Rg91TTpsztcYmcCX9CYTlZDxDLa5tIkQY";
    var state = "random-string";

    var loginUrl = "http://ankchef360.success.chef.co:31000/platform/user-accounts/v1/user/api-token/login";
    var loginPayload = JSON.stringify({
      accessKey: accessKey,
      secretKey: secretKey,
      state: state
    });

    // For local testing, use native fetch instead of ServiceNow's RESTMessageV2
    fetch(loginUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: loginPayload
    })
    .then(response => response.json())
    .then(loginResponseBody => {
      if (loginResponseBody.code !== 200 || !loginResponseBody.item.oauthCode) {
        console.error("Failed to fetch oauthCode:", JSON.stringify(loginResponseBody));
        return;
      }

      console.log("Successfully obtained oauthCode");
      var oauthCode = loginResponseBody.item.oauthCode;

      // Step 2: Get accessToken using oauthCode
      var jwtUrl = "http://ankchef360.success.chef.co:31000/platform/user-accounts/v1/user/api-token/jwt";
      var jwtPayload = JSON.stringify({
        oauthCode: oauthCode,
        state: state
      });

      return fetch(jwtUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: jwtPayload
      });
    })
    .then(response => response.json())
    .then(jwtResponseBody => {
      if (!jwtResponseBody.item || !jwtResponseBody.item.accessToken) {
        console.error("Failed to fetch accessToken:", JSON.stringify(jwtResponseBody));
        return;
      }

      console.log("Successfully obtained accessToken");
      var accessToken = jwtResponseBody.item.accessToken;

      // Step 3: Execute the final API request using accessToken
      var schedulerUrl = "http://ankchef360.success.chef.co:31000/courier/scheduler-api/v1/jobs";
      var schedulerPayload = JSON.stringify({
        "name": `${payload.requestNumber}_Received`,
        "description": "Identifies the vulnerabilities on the servers",
        "scheduleRule": "immediate",
        "exceptionRules": [],
        "target": {
          "executionType": "parallel",
          "groups": [
            {
              "timeoutSeconds": 600,
              "batchSize": { "type": "number", "value": 5 },
              "distributionMethod": "batching",
              "successCriteria": [{ "numRuns": { "type": "percent", "value": 100 }, "status": "success" }],
              "nodeListType": "nodes",
              "nodeIdentifiers": ["b975a3d2-d5ae-461f-b6a2-cf2f0885096f"]
            }
          ]
        },
        "actions": {
          "accessMode": "agent",
          "steps": [
            {
              "name": "Execute Compliance Run",
              "interpreter": { "skill": { "minVersion": "1.0.0", "maxVersion": "2.9.9" }, "name": "chef-platform/shell-interpreter" },
              "command": {
                "linux": [
                  `echo '${JSON.stringify(payload)}' > /tmp/${payload.requestNumber}.json`,
                  `[ ! -f /home/ubuntu/master_solution.sh ] || sudo rm -f /home/ubuntu/master_solution.sh`,
                  `sudo wget -P /home/ubuntu/ https://raw.githubusercontent.com/prohealops/req_mgmt/refs/heads/main/lib/master_solution.sh`,
                  `sudo chmod +x /home/ubuntu/master_solution.sh`,
                  `sudo /home/ubuntu/master_solution.sh ${payload.requestNumber}`
                ]
              },
              "inputs": {},
              "expectedInputs": {},
              "outputFieldRules": {},
              "retryCount": 1,
              "failureBehavior": { "action": "retryThenIgnore", "retryBackoffStrategy": { "type": "linear", "delaySeconds": 1, "arguments": [1, 3, 5] } },
              "limits": {},
              "conditions": []
            }
          ]
        }
      });

      return fetch(schedulerUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + accessToken
        },
        body: schedulerPayload
      });
    })
    .then(response => response.json())
    .then(schedulerResponse => {
      console.log("Scheduler API Response:", JSON.stringify(schedulerResponse));
      if (schedulerResponse.id) {
        console.log("Job successfully created with ID:", schedulerResponse.id);
      } else {
        console.error("Job creation failed:", schedulerResponse);
      }
    })
    .catch(error => {
      console.error('Error during API execution:', error);
    });

  } catch (error) {
    console.error('Error in script execution:', error);
  }
})();
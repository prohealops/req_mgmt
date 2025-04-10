(function executeRITMFormFetchAndCallAPI(current, gScripting) {
  try {
    // Ensure the current record is a RITM
    if (current.getTableName() !== 'sc_req_item') {
      gScripting.addErrorMessage('This script should only be run on RITM records.');
      return;
    }

    // Fetch all variables associated with the RITM
    var variables = {};
    var grVariables = new GlideRecord('sc_item_option_mtom');
    grVariables.addQuery('request_item', current.sys_id);
    grVariables.query();

    while (grVariables.next()) {
      var variableName = grVariables.sc_item_option.item_option_new.name.toString();
      var variableValue = grVariables.sc_item_option.value.toString();
      variables[variableName] = variableValue;
    }

    // Prepare the JSON payload
    var payload = {
      ritm: current.number.toString(),
      requestNumber: current.request.number.toString(), // Add REQUEST number (starting with REQ)
      catalogName: current.cat_item.name.toString(),
      status: "new",   
      variables: variables
    };

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

    var loginRequest = new sn_ws.RESTMessageV2();
    loginRequest.setEndpoint(loginUrl);
    loginRequest.setHttpMethod("POST");
    loginRequest.setRequestHeader("Content-Type", "application/json");
    loginRequest.setRequestBody(loginPayload);

    var loginResponse = loginRequest.execute();
    var loginResponseBody = JSON.parse(loginResponse.getBody());

    if (loginResponseBody.code !== 200 || !loginResponseBody.item.oauthCode) {
      gs.error("Failed to fetch oauthCode: " + loginResponse.getBody());
      return;
    }

    var oauthCode = loginResponseBody.item.oauthCode;

    // Step 2: Get accessToken using oauthCode
    var jwtUrl = "http://ankchef360.success.chef.co:31000/platform/user-accounts/v1/user/api-token/jwt";
    var jwtPayload = JSON.stringify({
      oauthCode: oauthCode,
      state: state
    });

    var jwtRequest = new sn_ws.RESTMessageV2();
    jwtRequest.setEndpoint(jwtUrl);
    jwtRequest.setHttpMethod("POST");
    jwtRequest.setRequestHeader("Content-Type", "application/json");
    jwtRequest.setRequestBody(jwtPayload);

    var jwtResponse = jwtRequest.execute();
    var jwtResponseBody = JSON.parse(jwtResponse.getBody());

    if (!jwtResponseBody.item || !jwtResponseBody.item.accessToken) {
      gs.error("Failed to fetch accessToken: " + jwtResponse.getBody());
      return;
    }

    var accessToken = jwtResponseBody.item.accessToken;

    // Step 3: Execute the final API request using accessToken
    var schedulerUrl = "http://ankchef360.success.chef.co:31000/courier/scheduler-api/v1/jobs";
    var schedulerPayload = JSON.stringify({
      "name": payload.requestNumber,
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
            "nodeIdentifiers": ["10235e29-46de-4664-b669-b8d37dfa8691"]
          }
        ]
      },
      "actions": {
        "accessMode": "agent",
        "steps": [
          {
            "name": "Execute Compliance Run",
            "interpreter": { "skill": { "minVersion": "1.0.0" }, "name": "chef-platform/shell-interpreter" },
            "command": { "linux": [`echo '${JSON.stringify(payload)}' > /tmp/${payload.requestNumber}.json`] },
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

    var schedulerRequest = new sn_ws.RESTMessageV2();
    schedulerRequest.setEndpoint(schedulerUrl);
    schedulerRequest.setHttpMethod("POST");
    schedulerRequest.setRequestHeader("Content-Type", "application/json");
    schedulerRequest.setRequestHeader("Authorization", "Bearer " + accessToken);
    schedulerRequest.setRequestBody(schedulerPayload);

    var schedulerResponse = schedulerRequest.execute();
    gs.info("Scheduler API Response: " + schedulerResponse.getBody());

  } catch (error) {
    gScripting.addErrorMessage('Error fetching RITM variables or sending data: ' + error.message);
  }
})(current, gs);
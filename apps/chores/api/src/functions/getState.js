const { app } = require("@azure/functions");
const { getTableClient, PARTITION_KEY, ROW_KEY } = require("../lib/tableClient");
const { checkPin } = require("../lib/auth");

app.http("getState", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "state",
  handler: async (request, context) => {
    if (!checkPin(request)) {
      return { status: 401, jsonBody: { error: "Invalid or missing household PIN." } };
    }

    const client = getTableClient();
    try {
      const entity = await client.getEntity(PARTITION_KEY, ROW_KEY);
      return {
        status: 200,
        jsonBody: { state: JSON.parse(entity.stateJson), version: entity.etag },
      };
    } catch (err) {
      if (err.statusCode === 404) {
        // No state saved yet — the client seeds it with defaults and POSTs.
        return { status: 200, jsonBody: { state: null, version: null } };
      }
      context.error("getState failed", err);
      return { status: 500, jsonBody: { error: "Could not read state." } };
    }
  },
});

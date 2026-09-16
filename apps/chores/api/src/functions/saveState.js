const { app } = require("@azure/functions");
const { getTableClient, PARTITION_KEY, ROW_KEY } = require("../lib/tableClient");
const { checkPin } = require("../lib/auth");

app.http("saveState", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "state",
  handler: async (request, context) => {
    if (!checkPin(request)) {
      return { status: 401, jsonBody: { error: "Invalid or missing household PIN." } };
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return { status: 400, jsonBody: { error: "Body must be JSON." } };
    }
    if (!body || typeof body.state !== "object" || body.state === null) {
      return { status: 400, jsonBody: { error: '"state" is required.' } };
    }

    const client = getTableClient();
    const entity = {
      partitionKey: PARTITION_KEY,
      rowKey: ROW_KEY,
      stateJson: JSON.stringify(body.state),
    };

    try {
      if (body.version) {
        // Optimistic concurrency: only overwrite if nobody else has written
        // since the client last read the state.
        try {
          await client.updateEntity(entity, "Replace", { etag: body.version });
        } catch (err) {
          if (err.statusCode === 404) {
            await client.upsertEntity(entity, "Replace");
          } else {
            throw err;
          }
        }
      } else {
        await client.upsertEntity(entity, "Replace");
      }
    } catch (err) {
      if (err.statusCode === 412 || err.statusCode === 409) {
        // Someone else saved in between — hand back the current state so the
        // client can refetch and reapply rather than losing either write.
        try {
          const current = await client.getEntity(PARTITION_KEY, ROW_KEY);
          return {
            status: 409,
            jsonBody: { state: JSON.parse(current.stateJson), version: current.etag },
          };
        } catch (inner) {
          context.error("saveState conflict re-read failed", inner);
        }
        return { status: 409, jsonBody: { error: "Conflict; refetch and retry." } };
      }
      context.error("saveState failed", err);
      return { status: 500, jsonBody: { error: "Could not save state." } };
    }

    const saved = await client.getEntity(PARTITION_KEY, ROW_KEY);
    return {
      status: 200,
      jsonBody: { state: JSON.parse(saved.stateJson), version: saved.etag },
    };
  },
});

const { TableClient } = require("@azure/data-tables");

// The whole app state lives in a single Table Storage entity, addressed by
// this fixed partition/row key — a poor-man's document store, same idea as
// Star Squad's single localStorage blob, just moved server-side so both
// phones can read/write it.
const PARTITION_KEY = "chorewars";
const ROW_KEY = "state";

let client;
function getTableClient() {
  if (!client) {
    const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;
    const tableName = process.env.STATE_TABLE_NAME || "chorestate";
    client = TableClient.fromConnectionString(connectionString, tableName);
  }
  return client;
}

module.exports = { getTableClient, PARTITION_KEY, ROW_KEY };

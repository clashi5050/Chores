// Shared household PIN check. There are no user accounts — the whole app is
// gated by one PIN (Terraform-generated, set as the HOUSEHOLD_PIN app
// setting) that both of you enter once per device and that the frontend
// sends back on every request as the x-household-pin header.
function checkPin(request) {
  const expected = process.env.HOUSEHOLD_PIN;
  if (!expected) {
    // Misconfigured deployment (app setting missing) — fail closed rather
    // than silently accepting any request.
    return false;
  }
  const provided = request.headers.get("x-household-pin");
  return typeof provided === "string" && provided === expected;
}

module.exports = { checkPin };

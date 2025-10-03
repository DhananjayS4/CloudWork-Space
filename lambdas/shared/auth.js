function getUserIdFromEvent(event) {
  try {
    const claims = event?.requestContext?.authorizer?.jwt?.claims || event?.requestContext?.authorizer?.claims;
    if (claims?.sub) return claims.sub;

    // Fallback (not verified): parse JWT payload to read sub
    const auth = event?.headers?.authorization || event?.headers?.Authorization;
    if (auth && auth.startsWith("Bearer ")) {
      const token = auth.slice("Bearer ".length);
      const parts = token.split(".");
      if (parts.length === 3) {
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString("utf8"));
        if (payload?.sub) return payload.sub;
      }
    }
  } catch {}
  return null;
}

module.exports = { getUserIdFromEvent };

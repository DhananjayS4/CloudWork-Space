const allowedOrigin = process.env.ALLOWED_ORIGIN || "*";

function response(statusCode, bodyObj) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": allowedOrigin,
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    },
    body: JSON.stringify(bodyObj ?? {}),
  };
}

module.exports = {
  ok: (data) => response(200, data),
  created: (data) => response(201, data),
  noContent: () => ({
    statusCode: 204,
    headers: {
      "Access-Control-Allow-Origin": allowedOrigin,
      "Access-Control-Allow-Credentials": "true",
    },
    body: "",
  }),
  badRequest: (message) => response(400, { message }),
  unauthorized: (message = "Unauthorized") => response(401, { message }),
  notFound: (message = "Not Found") => response(404, { message }),
  serverError: (message = "Internal Server Error") => response(500, { message }),
};

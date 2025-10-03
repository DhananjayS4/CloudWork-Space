const { GetCommand } = require("@aws-sdk/lib-dynamodb");
const { docClient, tableName } = require("../shared/ddb");
const { ok, unauthorized, notFound, serverError } = require("../shared/http");
const { getUserIdFromEvent } = require("../shared/auth");

exports.handler = async (event) => {
  try {
    const userId = getUserIdFromEvent(event);
    if (!userId) return unauthorized();

    const noteId = event?.pathParameters?.id;
    if (!noteId) return notFound("Missing id");

    const result = await docClient.send(new GetCommand({ TableName: tableName, Key: { userId, noteId } }));
    if (!result.Item) return notFound("Note not found");

    return ok(result.Item);
  } catch (err) {
    console.error(err);
    return serverError();
  }
};

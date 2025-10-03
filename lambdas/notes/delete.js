const { DeleteCommand } = require("@aws-sdk/lib-dynamodb");
const { docClient, tableName } = require("../shared/ddb");
const { noContent, unauthorized, badRequest, serverError } = require("../shared/http");
const { getUserIdFromEvent } = require("../shared/auth");

exports.handler = async (event) => {
  try {
    const userId = getUserIdFromEvent(event);
    if (!userId) return unauthorized();

    const noteId = event?.pathParameters?.id;
    if (!noteId) return badRequest("Missing id");

    await docClient.send(new DeleteCommand({ TableName: tableName, Key: { userId, noteId } }));
    return noContent();
  } catch (err) {
    console.error(err);
    return serverError();
  }
};

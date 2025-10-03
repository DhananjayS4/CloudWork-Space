const { UpdateCommand } = require("@aws-sdk/lib-dynamodb");
const { docClient, tableName } = require("../shared/ddb");
const { ok, unauthorized, badRequest, serverError } = require("../shared/http");
const { getUserIdFromEvent } = require("../shared/auth");

exports.handler = async (event) => {
  try {
    const userId = getUserIdFromEvent(event);
    if (!userId) return unauthorized();

    const noteId = event?.pathParameters?.id;
    if (!noteId) return badRequest("Missing id");

    const body = event?.body ? JSON.parse(event.body) : {};
    const fields = {};
    if (typeof body.title === "string") fields.title = body.title;
    if (typeof body.content === "string") fields.content = body.content;
    if (Array.isArray(body.attachments)) fields.attachments = body.attachments;

    const now = new Date().toISOString();

    const updateExpressions = [];
    const expressionValues = { ":updatedAt": now };
    const expressionNames = {};

    Object.entries(fields).forEach(([key, value], index) => {
      const nameKey = `#k${index}`;
      const valueKey = `:v${index}`;
      expressionNames[nameKey] = key;
      expressionValues[valueKey] = value;
      updateExpressions.push(`${nameKey} = ${valueKey}`);
    });
    updateExpressions.push("updatedAt = :updatedAt");

    if (updateExpressions.length === 0) return badRequest("No updatable fields provided");

    const result = await docClient.send(new UpdateCommand({
      TableName: tableName,
      Key: { userId, noteId },
      UpdateExpression: `SET ${updateExpressions.join(", ")}`,
      ExpressionAttributeNames: expressionNames,
      ExpressionAttributeValues: expressionValues,
      ReturnValues: "ALL_NEW",
    }));

    return ok(result.Attributes || {});
  } catch (err) {
    console.error(err);
    return serverError();
  }
};

const { QueryCommand } = require("@aws-sdk/lib-dynamodb");
const { docClient, tableName } = require("../shared/ddb");
const { ok, unauthorized, serverError } = require("../shared/http");
const { getUserIdFromEvent } = require("../shared/auth");

exports.handler = async (event) => {
  try {
    const userId = getUserIdFromEvent(event);
    if (!userId) return unauthorized();

    const result = await docClient.send(new QueryCommand({
      TableName: tableName,
      KeyConditionExpression: "userId = :uid",
      ExpressionAttributeValues: { ":uid": userId },
      ScanIndexForward: false,
    }));

    return ok({ items: result.Items || [] });
  } catch (err) {
    console.error(err);
    return serverError();
  }
};

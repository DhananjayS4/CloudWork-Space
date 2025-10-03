const { PutCommand } = require("@aws-sdk/lib-dynamodb");
const { v4: uuidv4 } = require("uuid");
const { docClient, tableName } = require("../shared/ddb");
const { ok, created, badRequest, unauthorized, serverError } = require("../shared/http");
const { getUserIdFromEvent } = require("../shared/auth");

exports.handler = async (event) => {
  try {
    const userId = getUserIdFromEvent(event);
    if (!userId) return unauthorized();

    const body = event?.body ? JSON.parse(event.body) : {};
    const { title, content, attachments } = body;
    if (!title) return badRequest("title is required");

    const now = new Date().toISOString();
    const noteId = uuidv4();
    const item = {
      userId,
      noteId,
      title,
      content: content || "",
      attachments: Array.isArray(attachments) ? attachments : [],
      createdAt: now,
      updatedAt: now,
    };

    await docClient.send(new PutCommand({ TableName: tableName, Item: item, ConditionExpression: "attribute_not_exists(userId) AND attribute_not_exists(noteId)" }));
    return created(item);
  } catch (err) {
    console.error(err);
    return serverError();
  }
};

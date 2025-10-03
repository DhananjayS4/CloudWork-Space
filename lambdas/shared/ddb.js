const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient } = require("@aws-sdk/lib-dynamodb");

const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "us-east-1";
const tableName = process.env.TABLE_NAME;

const ddbClient = new DynamoDBClient({ region });
const docClient = DynamoDBDocumentClient.from(ddbClient, {
  marshallOptions: { removeUndefinedValues: true },
});

module.exports = { docClient, tableName };

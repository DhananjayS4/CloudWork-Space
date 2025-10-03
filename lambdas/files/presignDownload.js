const { S3Client, GetObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { unauthorized, badRequest, ok, serverError } = require("../shared/http");
const { getUserIdFromEvent } = require("../shared/auth");

const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "us-east-1";
const bucket = process.env.BUCKET_NAME;

const s3 = new S3Client({ region });

exports.handler = async (event) => {
  try {
    const userId = getUserIdFromEvent(event);
    if (!userId) return unauthorized();

    const key = event?.queryStringParameters?.key;
    if (!key) return badRequest("key is required");

    // Optional: enforce user path
    if (!key.startsWith(`${userId}/`)) return unauthorized();

    const command = new GetObjectCommand({ Bucket: bucket, Key: key });
    const url = await getSignedUrl(s3, command, { expiresIn: 900 });

    return ok({ url });
  } catch (err) {
    console.error(err);
    return serverError();
  }
};

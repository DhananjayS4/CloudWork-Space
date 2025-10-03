const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
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

    const body = event?.body ? JSON.parse(event.body) : {};
    const { filename, contentType } = body;
    if (!filename || !contentType) return badRequest("filename and contentType are required");

    const key = `${userId}/${Date.now()}_${filename}`;

    const command = new PutObjectCommand({ Bucket: bucket, Key: key, ContentType: contentType, Metadata: { userId } });
    const url = await getSignedUrl(s3, command, { expiresIn: 900 });

    return ok({ url, key });
  } catch (err) {
    console.error(err);
    return serverError();
  }
};

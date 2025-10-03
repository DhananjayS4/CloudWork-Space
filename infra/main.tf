locals {
  name = "${var.project}-${terraform.workspace}"
}

resource "random_id" "suffix" { byte_length = 4 }

# S3 bucket for attachments
resource "aws_s3_bucket" "media" {
  bucket = "${local.name}-media-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket encryption and versioning
resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Enabled" }
}

# DynamoDB table for notes
resource "aws_dynamodb_table" "notes" {
  name         = "${local.name}-notes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "noteId"

  attribute { name = "userId" type = "S" }
  attribute { name = "noteId" type = "S" }
  point_in_time_recovery { enabled = true }
}

# Cognito User Pool and App Client
resource "aws_cognito_user_pool" "this" {
  name = "${local.name}-users"
}

# Cognito Hosted UI domain
resource "aws_cognito_user_pool_domain" "this" {
  domain       = replace(lower(local.name), "_", "-")
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_pool_client" "this" {
  name                         = "${local.name}-client"
  user_pool_id                 = aws_cognito_user_pool.this.id
  allowed_oauth_flows          = ["code"]
  allowed_oauth_scopes         = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls                = ["http://localhost:3000/callback"]
  logout_urls                  = ["http://localhost:3000/"]
  supported_identity_providers = ["COGNITO"]
  generate_secret              = false
  explicit_auth_flows          = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

# IAM role for Lambdas
resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["lambda.amazonaws.com"] }
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.name}-lambda-policy"
  role = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_inline.json
}

data "aws_iam_policy_document" "lambda_inline" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.notes.arn]
  }
  statement {
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.media.arn}/*"]
  }
}

# Archive Lambda code
data "archive_file" "notes_create" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas"
  output_path = "${path.module}/.dist/notes_create.zip"
}

# Separate archives via source content filters is cumbersome; for simplicity, reuse same zip and set handler paths
locals {
  lambda_env = {
    TABLE_NAME     = aws_dynamodb_table.notes.name
    BUCKET_NAME    = aws_s3_bucket.media.bucket
    ALLOWED_ORIGIN = var.allowed_origin
  }
}

resource "aws_lambda_function" "notes_create" {
  function_name = "${local.name}-notes-create"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "notes/create.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.notes_create.output_path
  source_code_hash = data.archive_file.notes_create.output_base64sha256
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "notes_list" {
  function_name = "${local.name}-notes-list"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "notes/list.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.notes_create.output_path
  source_code_hash = data.archive_file.notes_create.output_base64sha256
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "notes_get" {
  function_name = "${local.name}-notes-get"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "notes/get.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.notes_create.output_path
  source_code_hash = data.archive_file.notes_create.output_base64sha256
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "notes_update" {
  function_name = "${local.name}-notes-update"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "notes/update.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.notes_create.output_path
  source_code_hash = data.archive_file.notes_create.output_base64sha256
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "notes_delete" {
  function_name = "${local.name}-notes-delete"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "notes/delete.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.notes_create.output_path
  source_code_hash = data.archive_file.notes_create.output_base64sha256
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "presign_upload" {
  function_name = "${local.name}-presign-upload"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "files/presignUpload.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.notes_create.output_path
  source_code_hash = data.archive_file.notes_create.output_base64sha256
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "presign_download" {
  function_name = "${local.name}-presign-download"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "files/presignDownload.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.notes_create.output_path
  source_code_hash = data.archive_file.notes_create.output_base64sha256
  environment { variables = local.lambda_env }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_credentials = true
    allow_headers     = ["Authorization", "Content-Type"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins     = [var.allowed_origin]
    max_age           = 3600
  }
}

# Cognito JWT authorizer for HTTP API
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.http.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt"
  jwt_configuration {
    audience = [aws_cognito_user_pool_client.this.id]
    issuer   = "https://${aws_cognito_user_pool.this.endpoint}"
  }
}

# Lambda integrations
resource "aws_apigatewayv2_integration" "notes_create" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.notes_create.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "notes_list" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.notes_list.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "notes_get" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.notes_get.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "notes_update" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.notes_update.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "notes_delete" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.notes_delete.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "presign_upload" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.presign_upload.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "presign_download" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.presign_download.invoke_arn
  payload_format_version = "2.0"
}

# Routes (secured by authorizer)
resource "aws_apigatewayv2_route" "notes_post" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /notes"
  target    = "integrations/${aws_apigatewayv2_integration.notes_create.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "notes_get_list" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /notes"
  target    = "integrations/${aws_apigatewayv2_integration.notes_list.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "notes_get_one" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /notes/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.notes_get.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "notes_put" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "PUT /notes/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.notes_update.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "notes_delete" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "DELETE /notes/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.notes_delete.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "presign_upload" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /files/presign-upload"
  target    = "integrations/${aws_apigatewayv2_integration.presign_upload.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "presign_download" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /files/presign-download"
  target    = "integrations/${aws_apigatewayv2_integration.presign_download.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

# Permissions for API to invoke Lambdas
resource "aws_lambda_permission" "api_invoke" {
  for_each = {
    notes_create    = aws_lambda_function.notes_create.function_name
    notes_list      = aws_lambda_function.notes_list.function_name
    notes_get       = aws_lambda_function.notes_get.function_name
    notes_update    = aws_lambda_function.notes_update.function_name
    notes_delete    = aws_lambda_function.notes_delete.function_name
    presign_upload  = aws_lambda_function.presign_upload.function_name
    presign_download= aws_lambda_function.presign_download.function_name
  }
  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id = aws_apigatewayv2_api.http.id
  name   = "prod"
  auto_deploy = true
}

output "api_url" { value = aws_apigatewayv2_stage.prod.invoke_url }
output "bucket_name" { value = aws_s3_bucket.media.bucket }
output "table_name" { value = aws_dynamodb_table.notes.name }
output "user_pool_id" { value = aws_cognito_user_pool.this.id }
output "user_pool_client_id" { value = aws_cognito_user_pool_client.this.id }
output "cognito_domain" { value = aws_cognito_user_pool_domain.this.domain }

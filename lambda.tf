terraform {
  required_version = "~> 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.65.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#--------------------
# Data source
#--------------------

data "aws_s3_object" "lambda_function_archive" {
  depends_on = [null_resource.deploy_lambda]

  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "lambda_function.py.zip"
}

data "aws_s3_object" "lambda_function_archive_hash" {
  depends_on = [null_resource.deploy_lambda]

  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "lambda_function.py.zip.base64sha256.txt"
}

data "aws_s3_object" "lambda_layer_archive" {
  depends_on = [null_resource.deploy_lambda_layer]

  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "lambda_layer.zip"
}

data "aws_s3_object" "lambda_layer_archive_hash" {
  depends_on = [null_resource.deploy_lambda_layer]

  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "lambda_layer.zip.base64sha256"
}

#--------------------
# Deploy Lambda Function
#--------------------
resource "null_resource" "deploy_lambda" {
  depends_on = [aws_s3_bucket.lambda_bucket]

  triggers = {
    "code_diff" = filebase64("./lambda/lambda_function.py")
  }

  provisioner "local-exec" {
    command = "zip -j ./lambda_function.py.zip ./lambda/lambda_function.py"
  }

  provisioner "local-exec" {
    command = "aws s3 cp ./lambda_function.py.zip s3://${aws_s3_bucket.lambda_bucket.id}/lambda_function.py.zip"
  }

  provisioner "local-exec" {
    command = "openssl dgst -sha256 -binary ./lambda_function.py.zip | openssl enc -base64 | tr -d \"\n\" > ./lambda_function.py.zip.base64sha256"
  }

  provisioner "local-exec" {
    command = "aws s3 cp ./lambda_function.py.zip.base64sha256 s3://${aws_s3_bucket.lambda_bucket.id}/lambda_function.py.zip.base64sha256.txt --content-type \"text/plain\""
  }
}

resource "null_resource" "deploy_lambda_layer" {
  depends_on = [aws_s3_bucket.lambda_bucket]

  provisioner "local-exec" {
    command = "pip3 install -r ./lambda/requirements.txt -t ./python"
  }

  provisioner "local-exec" {
    command = "zip -r ./lambda_layer.zip ./python"
  }

  provisioner "local-exec" {
    command = "aws s3 cp ./lambda_layer.zip s3://${aws_s3_bucket.lambda_bucket.id}/lambda_layer.zip"
  }

  provisioner "local-exec" {
    command = "openssl dgst -sha256 -binary ./lambda_layer.zip | openssl enc -base64 | tr -d \"\n\" > ./lambda_layer.zip.base64sha256"
  }

  provisioner "local-exec" {
    command = "aws s3 cp ./lambda_layer.zip.base64sha256 s3://${aws_s3_bucket.lambda_bucket.id}/lambda_layer.zip.base64sha256"
  }

}

#--------------------
# S3 Bucket
#--------------------
resource "aws_s3_bucket" "lambda_bucket" {
  bucket        = "yosuk-comment-lambda"
  force_destroy = true
}

# resource "aws_s3_bucket_acl" "deployer" {
#   bucket = aws_s3_bucket.lambda_bucket.id
#   acl    = "private"
# }

resource "aws_s3_bucket_ownership_controls" "ownership_control" {
  bucket = aws_s3_bucket.lambda_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }

}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.lambda_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


#--------------------
# IAM
#--------------------
data "aws_iam_policy" "aws_lambda_basic_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "lambda" {
  managed_policy_arns = [data.aws_iam_policy.aws_lambda_basic_execution_role.arn]
  assume_role_policy  = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
  EOF
}

resource "aws_lambda_function" "comment_function" {
  function_name = "comment-lambda"
  description   = "Lambda function for comment server"

  role          = aws_iam_role.lambda.arn
  architectures = ["x86_64"]
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"

  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = data.aws_s3_object.lambda_function_archive.key
  source_code_hash = data.aws_s3_object.lambda_function_archive_hash.body

  layers = [aws_lambda_layer_version.comment_layer.arn]

  memory_size = 256
  timeout     = 3
}

resource "aws_lambda_layer_version" "comment_layer" {
  layer_name       = "comment-layer"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = data.aws_s3_object.lambda_layer_archive.key
  source_code_hash = data.aws_s3_object.lambda_layer_archive_hash.body

  compatible_runtimes = ["python3.8"]
}

resource "aws_lambda_permission" "lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.comment_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.comment_api.execution_arn}/*/*/*"
}

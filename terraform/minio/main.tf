data "sops_file" "minio_secrets" {
  source_file = "secret.sops.yaml"
}

# Create bucket
resource "minio_s3_bucket" "bucket" {
  bucket = data.sops_file.minio_secrets.data["bucket_name"]
  acl    = "private"  # Options: public-read, public-read-write, private
}

# Create IAM user
resource "minio_iam_user" "user" {
  name = data.sops_file.minio_secrets.data["user_name"]
  secret = data.sops_file.minio_secrets.data["user_secret"]
}

# Create bucket policy
resource "minio_iam_policy" "policy" {
  name   = "${data.sops_file.minio_secrets.data["bucket_name"]}-policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${data.sops_file.minio_secrets.data["bucket_name"]}",
                "arn:aws:s3:::${data.sops_file.minio_secrets.data["bucket_name"]}/*"
            ],
            "Sid": ""
        }
    ]
}
EOF
}
# Attach policy to bucket user
resource "minio_iam_user_policy_attachment" "attachment" {
  user_name   = minio_iam_user.user.id
  policy_name = minio_iam_policy.policy.id
}

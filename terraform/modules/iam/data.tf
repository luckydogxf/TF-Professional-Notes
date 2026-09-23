data "aws_iam_roles" "sso_admin" {
  name_regex = "AWSReservedSSO_Administrator_.*"
}

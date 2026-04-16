# Use the account’s existing GitHub Actions OIDC identity provider instead of creating one.
# Only one provider per issuer URL is allowed per AWS account; this data source resolves it
# so the IAM role in main.tf can trust it via data.aws_iam_openid_connect_provider.github.arn.
#
# If you previously ran apply with resource aws_iam_openid_connect_provider.github in state,
# remove it before the next apply:
#   terraform state rm aws_iam_openid_connect_provider.github

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

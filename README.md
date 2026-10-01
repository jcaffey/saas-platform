# README

```sh
aws sso login --profile saas-learning &&
eval "$(aws configure export-credentials \
  --profile saas-learning \
  --format env)"
```

```sh
PGPASSWORD="$(
  aws secretsmanager get-secret-value \
    --secret-id 'arn:aws:secretsmanager:us-east-1:388260576957:secret:rds!cluster-23e4a8b8-d76f-45a9-a6c1-85f5fb5ecba7-esagbT' \
    --query SecretString \
    --output text | jq -r '.password'
)" \
$(brew --prefix libpq)/bin/psql \
  -h saas-platform-dev.cluster-cc3wkysy2a09.us-east-1.rds.amazonaws.com \
  -U postgres \
  -d postgres
```

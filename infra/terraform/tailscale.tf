data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "tailscale_router" {
  name        = "saas-platform-dev-tailscale-router"
  description = "Tailscale subnet router"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "saas-platform-dev-tailscale-router"
  }
}

resource "aws_iam_role_policy" "tailscale_secrets" {
  name = "tailscale-auth-secret"
  role = aws_iam_role.tailscale_router.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = "arn:aws:secretsmanager:us-east-1:388260576957:secret:saas-platform/dev/tailscale-auth-key-*"
      }
    ]
  })
}

resource "aws_instance" "tailscale_router" {
  depends_on = [
    aws_iam_role_policy.tailscale_secrets
  ]

  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.tailscale_router.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.tailscale_router.name

  # This machine is intentionally acting as a router.
  source_dest_check = false
  user_data         = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    curl -fsSL https://tailscale.com/install.sh | sh

    cat >/etc/sysctl.d/99-tailscale.conf <<SYSCTL
    net.ipv4.ip_forward = 1
    net.ipv6.conf.all.forwarding = 1
    SYSCTL

    sysctl -p /etc/sysctl.d/99-tailscale.conf

    # Don't print secret-handling commands/values to the bootstrap log.
    set +x

    TAILSCALE_AUTH_KEY="$(
      aws secretsmanager get-secret-value \
        --secret-id saas-platform/dev/tailscale-auth-key \
        --query SecretString \
        --output text \
        --region us-east-1
    )"

    tailscale up \
      --auth-key="$TAILSCALE_AUTH_KEY" \
      --advertise-routes=10.0.0.0/16

    unset TAILSCALE_AUTH_KEY

    set -x
  EOF

  user_data_replace_on_change = true

  tags = {
    Name        = "saas-platform-dev-tailscale-router"
    Environment = "dev"
  }
}

resource "aws_iam_role" "tailscale_router" {
  name = "saas-platform-dev-tailscale-router"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "tailscale_router_ssm" {
  role       = aws_iam_role.tailscale_router.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "tailscale_router" {
  name = "saas-platform-dev-tailscale-router"
  role = aws_iam_role.tailscale_router.name
}

output "tailscale_router_instance_id" {
  value = aws_instance.tailscale_router.id
}

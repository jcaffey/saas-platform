resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "saas-platform-dev-nat"
    Environment = "dev"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name        = "saas-platform-dev"
    Environment = "dev"
  }

  depends_on = [aws_internet_gateway.main]
}

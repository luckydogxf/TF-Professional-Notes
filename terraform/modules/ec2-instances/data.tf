data "aws_ami" "amazon_linux" {
  owners = ["amazon"]

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

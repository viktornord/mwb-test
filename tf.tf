provider "aws" {
  profile = "default"
  region = "eu-west-1"
}

resource "aws_security_group" "my_security_group" {
  name = "mwb-test security group"
  description = "test group"

  ingress {
    description = "SSH access"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }
  ingress {
    description = "HTTP access"
    from_port = 3000
    to_port = 3000
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }
}

resource "aws_launch_configuration" "aws_linux" {
  name = "mwb-test auto scaling launch configuration"
  instance_type = "t2.micro"
  image_id = "ami-0ca15f9db3b8695b8"
  security_groups = [aws_security_group.my_security_group.name]
  key_name = "my-ec2"
  iam_instance_profile = aws_iam_instance_profile.my_instance_profile.name
//  user_data = file("./user_data_public.sh")
}

resource "aws_iam_instance_profile" "my_instance_profile" {
  name = "mwb-test"
  role = aws_iam_role.my_iam_role.name
}
resource "aws_autoscaling_group" "my_auto_scaling_group" {
  launch_configuration = aws_launch_configuration.aws_linux.name
  availability_zones = ["eu-west-1a"]
  max_size = 1 // this can be extended
  min_size = 1
}


resource "aws_iam_role" "my_iam_role" {
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ec2_to_read_s3_role_policy_attach" {
  policy_arn = aws_iam_policy.ec2_to_read_s3_role_policy.arn
  role = aws_iam_role.my_iam_role.name
}
resource "aws_iam_role_policy_attachment" "ec2_to_access_dynamo_role_policy_attach" {
  policy_arn = aws_iam_policy.ec2_to_access_dynamo_role_policy.arn
  role = aws_iam_role.my_iam_role.name
}

resource "aws_iam_policy" "ec2_to_read_s3_role_policy" {
  name = "ec2_to_read_s3"
  policy = data.aws_iam_policy_document.ec2_s3_read_policy.json
}

resource "aws_iam_policy" "ec2_to_access_dynamo_role_policy" {
  name = "ec2_to_access_dynamo"
  policy = data.aws_iam_policy_document.ec2_to_access_dynamo_policy.json
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2_s3_read_policy" {
  statement {
    effect = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::mwb--test/*"]
  }
  statement {
    effect = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::mwb--test"]
  }
}

data "aws_iam_policy_document" "ec2_to_access_dynamo_policy" {
  statement {
    effect = "Allow"
    actions   = ["dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchWriteItem"]
    resources = ["arn:aws:dynamodb:us-east-1:*:table/mwb-test"]
  }
  statement {
    effect = "Allow"
    actions   = ["dynamodb:ListTables"]
    resources = ["arn:aws:dynamodb:us-east-1:*:*"]
  }
}

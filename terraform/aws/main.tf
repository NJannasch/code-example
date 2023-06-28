resource "aws_instance" "web_host" {
  # checkov:skip=BC_AWS_GENERAL_31: Ignore usage of IMDSv2
  # ec2 have plain text secrets in user data
  ami           = "${var.ami}"
  instance_type = "t2.nano"

  vpc_security_group_ids = [
    "${aws_security_group.web-node.id}"
  ]
  subnet_id = "${aws_subnet.web_subnet.id}"
  user_data = <<EOF
#! /bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMAAA
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMAAAKEYcheckov -d terraform -o cli --quiet
export AWS_DEFAULT_REGION=us-west-2
echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
EOF
  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-ec2"
      }, {
      yor_trace = "4d2aa26a-789b-4b95-aae7-4623d7d6a080"
  })

  # root_block_device {
  #   encrypted = true
  # }

  # metadata_options {
  #   http_endpoint = "disabled"
  # }
  # ebs_optimized = true
  # monitoring = true
  associate_public_ip_address = true
  monitoring                  = true
}



resource "aws_ebs_volume" "web_host_storage" {
  # unencrypted volume
  availability_zone = "${var.region}a"
  encrypted         = true
  kms_key_id        = aws_kms_key.dummy.arn
  size              = 1
  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-ebs"
      }, {
      yor_trace = "579b2349-a85a-48fe-a363-31eaa277dc2e"
  })
}

resource "aws_ebs_snapshot" "example_snapshot" {
  # ebs snapshot without encryption
  volume_id   = "${aws_ebs_volume.web_host_storage.id}"
  description = "${local.resource_prefix.value}-ebs-snapshot"
  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-ebs-snapshot"
      }, {
      yor_trace = "e7bc7496-8b61-4bf5-82f6-dad91d8ca853"
  })
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.web_host_storage.id}"
  instance_id = "${aws_instance.web_host.id}"
}

resource "aws_security_group" "web-node" {
  # checkov:skip=BC_AWS_NETWORKING_1: I know what i am doing
  # security group is open to the world in SSH port
  name        = "${local.resource_prefix.value}-sg"
  description = "${local.resource_prefix.value} Security Group"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    description = "Allow http traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
  ingress {
    description = "Allow ssh traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
  egress {
    description = "Allow everything outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
  depends_on = [aws_vpc.web_vpc]
  tags = {
    yor_trace = "a0437ff4-9f12-488e-a59e-97023cbc86f9"
  }
}

resource "aws_vpc" "web_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-vpc"
      }, {
      yor_trace = "e5d933d3-0849-46eb-9778-6de8732632ec"
  })
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.web_vpc.id
  tags = {
    yor_trace = "dce0531e-3eda-4d9d-bd13-abfd230adaa1"
  }
}

resource "aws_subnet" "web_subnet" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "172.16.10.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false

  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-subnet"
      }, {
      yor_trace = "a0d30491-4f52-4768-98ac-773ec74865f6"
  })
}

resource "aws_subnet" "web_subnet2" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "172.16.11.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false

  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-subnet2"
      }, {
      yor_trace = "4527fb19-4579-4b61-9579-3545ce3debce"
  })
}


resource "aws_internet_gateway" "web_igw" {
  vpc_id = aws_vpc.web_vpc.id

  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-igw"
      }, {
      yor_trace = "8ff94eff-6d63-4612-a4bf-9c51e33d221c"
  })
}

resource "aws_route_table" "web_rtb" {
  vpc_id = aws_vpc.web_vpc.id

  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-rtb"
      }, {
      yor_trace = "f683d81d-ea2c-42fb-878f-4ec912b1bc0b"
  })
}

resource "aws_route_table_association" "rtbassoc" {
  subnet_id      = aws_subnet.web_subnet.id
  route_table_id = aws_route_table.web_rtb.id
}

resource "aws_route_table_association" "rtbassoc2" {
  subnet_id      = aws_subnet.web_subnet2.id
  route_table_id = aws_route_table.web_rtb.id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.web_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.web_igw.id

  timeouts {
    create = "5m"
  }
}

resource "aws_network_interface" "web-eni" {
  subnet_id   = aws_subnet.web_subnet.id
  private_ips = ["172.16.10.100"]

  tags = merge(
    local.env_tags,
    {
      Name = "${local.resource_prefix.value}-primary_network_interface"
      }, {
      yor_trace = "74134434-9c2a-4143-bb38-a8e83c420348"
  })
}

# VPC Flow Logs to S3
resource "aws_flow_log" "vpcflowlogs" {
  log_destination      = aws_s3_bucket.flowbucket.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.web_vpc.id

  tags = merge(
    local.env_tags,
    {
      Name        = "${local.resource_prefix.value}-flowlogs"
      Environment = local.resource_prefix.value
      }, {
      yor_trace = "03c37259-de6a-4fbc-8154-c7d63c4cfbc5"
  })
}

resource "aws_s3_bucket" "flowbucket" {
  # checkov:skip=BC_AWS_GENERAL_56: Disable KMS
  # checkov:skip=BC_AWS_GENERAL_72: Skip cross region replication
  bucket        = "${local.resource_prefix.value}-flowlogs"
  force_destroy = true

  tags = merge(
    local.env_tags,
    {
      Name        = "${local.resource_prefix.value}-flowlogs"
      Environment = local.resource_prefix.value
      }, {
      yor_trace = "a316fe47-5412-4ff4-93f2-74ef355d7c8b"
  })
}

resource "aws_s3_bucket_versioning" "flowbucket" {
  bucket = aws_s3_bucket.flowbucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "flowbucket" {
  bucket = aws_s3_bucket.flowbucket.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "dummy" {
  description             = "KMS key 1"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags = {
    yor_trace = "06d74ce6-d3aa-43b8-97fc-2fbe0274a566"
  }
}

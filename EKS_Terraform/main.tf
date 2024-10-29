resource "aws_vpc" "cluster_vpc" {
  cidr_block = var.cluster_vpc_info.vpc_cidr

  tags = {
    Name = var.cluster_vpc_info.vpc_name
  }
}

resource "aws_subnet" "cluster_subnets" {
  count                   = length(var.cluster_vpc_info.subnet_names)
  vpc_id                  = aws_vpc.cluster_vpc.id
  cidr_block              = cidrsubnet(var.cluster_vpc_info.vpc_cidr, 8, count.index)
  availability_zone       = "${var.region}${var.cluster_vpc_info.availability_zone[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = var.cluster_vpc_info.subnet_names[count.index]
  }

  depends_on = [aws_vpc.cluster_vpc]
}

resource "aws_internet_gateway" "cluster_igw" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = var.cluster_vpc_info.igw_name
  }

  depends_on = [aws_vpc.cluster_vpc]
}

resource "aws_route_table" "cluster_route_table" {
  vpc_id = aws_vpc.cluster_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster_igw.id
  }

  tags = {
    Name = var.cluster_vpc_info.route_table_name
  }

  depends_on = [aws_vpc.cluster_vpc]
}

resource "aws_route_table_association" "association" {
  count          = length(var.cluster_vpc_info.subnet_names)
  subnet_id      = aws_subnet.cluster_subnets[count.index].id
  route_table_id = aws_route_table.cluster_route_table.id

  depends_on = [aws_subnet.cluster_subnets]
}

resource "aws_security_group" "cluster_sg" {
  name   = var.security_group.cluster_sg_name
  vpc_id = aws_vpc.cluster_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group.cluster_sg_name
  }

  depends_on = [aws_vpc.cluster_vpc]
}

resource "aws_security_group" "node_sg" {
  name   = var.security_group.node_sg_name
  vpc_id = aws_vpc.cluster_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group.node_sg_name
  }

  depends_on = [aws_vpc.cluster_vpc]
}

resource "aws_iam_role" "cluster_role" {
  name = "cluster_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cluster_role_policy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" #Policy ARN
}

resource "aws_eks_cluster" "cluster" {
  name     = "cluster"
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.cluster_subnets[*].id
    security_group_ids = [aws_security_group.cluster_sg.id]
  }

  depends_on = [aws_iam_role.cluster_role]
}

resource "aws_iam_role" "node_group_role" {
  name = "node_group_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "node_group_role_policy" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" #Policy ARN
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" #Policy ARN
}

resource "aws_iam_role_policy_attachment" "node_group_registry_policy" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" #Policy ARN
}

resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "node_group"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = aws_subnet.cluster_subnets[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key               = var.node_ssh_keyname
    source_security_group_ids = [aws_security_group.node_sg.id]
  }
}
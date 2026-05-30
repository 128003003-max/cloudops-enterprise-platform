# ==========================================
# 1. PROVIDER & NETWORK CONFIGURATION (VPC)
# ==========================================
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "cloudops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "cloudops-vpc"
  }
}

# Public Subnet (For Web Server / EC2)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.cloudops_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "cloudops-public-subnet"
  }
}

# Private Subnet (For Database / RDS)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.cloudops_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "cloudops-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.cloudops_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "cloudops-private-subnet-2"
  }
}

# Internet Gateway & Routing
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cloudops_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cloudops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# 2. FIREWALLS & SECURITY GROUPS
# ==========================================
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.cloudops_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "database-sg"
  vpc_id = aws_vpc.cloudops_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Only allowed from Web Server
  }
}

# ==========================================
# 3. COMPUTE LAYER (EC2 VIRTUAL MACHINE)
# ==========================================
resource "aws_instance" "web_server" {
  ami                    = "ami-051f7e7f6c2f40dc1" # Amazon Linux 2023 AMI
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "cloudopss-key"

  tags = {
    Name = "nginx-server"
  }
}

# ==========================================
# 4. DATA LAYER (STORAGE & RDS DATABASE)
# ==========================================
resource "aws_s3_bucket" "storage_bucket" {
  bucket        = "cloudops-storage-data-abinaya"
  force_destroy = true
}

resource "aws_db_subnet_group" "db_subnets" {
  name       = "cloudops-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

resource "aws_db_instance" "postgres_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  db_name                = "cloudopsdb"
  username               = "dbadmin"
  password               = "SecurePassword123!" # Replace with environment variables in production
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}
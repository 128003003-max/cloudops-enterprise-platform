# =========================================================================
# CLOUDOPS ENTERPRISE PLATFORM - FULL INFRASTRUCTURE BLUEPRINT (MAIN.TF)
# =========================================================================

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
    Name        = "cloudops-vpc"
    Environment = "Production"
  }
}

# Public Subnet (For Web Server / EC2 / Ingress Proxy)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.cloudops_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "cloudops-public-subnet"
  }
}

# Private Subnet 1 (For Database / RDS / Analytical Storage Isolation)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.cloudops_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  
  tags = {
    Name = "cloudops-private-subnet-1"
  }
}

# Private Subnet 2 (For Database Multi-AZ Resiliency Support)
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.cloudops_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"
  
  tags = {
    Name = "cloudops-private-subnet-2"
  }
}

# Internet Gateway & Routing Infrastructure
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cloudops_vpc.id
  
  tags = {
    Name = "cloudops-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cloudops_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "cloudops-public-route-table"
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
  description = "Allow HTTP and SSH public traffic ingress"
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
  
  tags = {
    Name = "cloudops-web-security-group"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "database-sg"
  description = "Enforce isolation layer for persistence tier"
  vpc_id      = aws_vpc.cloudops_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Enforces Least Privilege access mapping
  }
  
  tags = {
    Name = "cloudops-database-security-group"
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
  key_name               = "cloudopss-key" # Exact asymmetric administrative SSH key pair

  tags = {
    Name        = "nginx-server"
    Application = "CloudOps-Front-Tier"
  }
}


# ==========================================
# 4. DATA LAYER (STORAGE & RDS DATABASE)
# ==========================================
resource "aws_s3_bucket" "storage_bucket" {
  bucket        = "cloudops-storage-data-abinaya" # Explicit bucket identification
  force_destroy = true
  
  tags = {
    Name        = "cloudops-data-lake"
    DataClass   = "Telemetry-Archive"
  }
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
  username               = "dbadmin"            # Exact custom database administrator user
  password               = "SecurePassword123!" # Exact secure administrative entry token
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}


# ==========================================
# 5. SERVERLESS ACCESS PREPARATION (IAM)
# ==========================================
resource "aws_iam_role" "lambda_execution_role" {
  name = "CloudOpsLambdaLeastPrivilegeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com", "sagemaker.amazonaws.com"]
        }
      }
    ]
  })
}


# ==========================================
# 6. BIG DATA, AI & STREAM PROCESSING SUITE
# ==========================================

# 6.1 Real-Time Data Ingest Engine (Amazon Kinesis)
resource "aws_kinesis_stream" "telemetry_stream" {
  name             = "cloudops-realtime-telemetry-stream"
  shard_count      = 1
  retention_period = 24

  tags = {
    Environment = "Production"
    Application = "CloudOps-Analytics"
  }
}

# 6.2 Enterprise Cloud Data Warehouse (Amazon Redshift)
resource "aws_redshift_cluster" "analytics_warehouse" {
  cluster_identifier  = "cloudops-enterprise-warehouse"
  database_name       = "analytics_db"
  master_username     = "dbadmin"            # Unified to match your specific DB master access
  master_password     = "SecurePassword123!" # Unified to match your explicit access string
  node_type           = "dc2.large"
  cluster_type        = "single-node"
  skip_final_snapshot = true

  tags = {
    Environment = "Production"
    Type        = "Data-Warehouse"
  }
}

# 6.3 Automated Machine Learning Model Instance (Amazon SageMaker)
resource "aws_sagemaker_model" "inference_model" {
  name               = "cloudops-predictive-inference-model"
  execution_role_arn = aws_iam_role.lambda_execution_role.arn

  primary_container {
    image = "683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-scikit-learn:0.23-1-cpu-py3"
  }
}

# 6.4 SageMaker Serverless Inference Endpoint Configuration
resource "aws_sagemaker_endpoint_configuration" "ml_endpoint_config" {
  name = "cloudops-ml-endpoint-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.inference_model.name
    initial_instance_count = 1
    instance_type          = "ml.t2.medium"
  }
}

resource "aws_sagemaker_endpoint" "ml_inference_serving" {
  name                 = "cloudops-predictive-serving-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.ml_endpoint_config.name
}
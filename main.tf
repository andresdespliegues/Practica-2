terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}


# Create a VPC
resource "aws_vpc" "cooperativa_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "cooperativa_vpc"
  }
}

#Ip Elastica
resource "aws_eip" "cooperativa_eip" {
    public_ipv4_pool = "amazon"

    tags={
        Name="cooperativa_eip"
    }
}

# Subnet Publica

resource "aws_subnet" "cooperativa_subnet_publica" {
        vpc_id     = aws_vpc.cooperativa_vpc.id
        cidr_block = "10.0.100.0/24" //cuando es publica envez de 1, 100
        map_public_ip_on_launch = true

        tags = {
            Name = "cooperativa_subnet_publica"
        }
}

#Subnet Privada
resource "aws_subnet" "cooperativa_subnet_privada" {
  vpc_id     = aws_vpc.cooperativa_vpc.id
  cidr_block = "10.0.1.0/24" //cuando es publica envez de 1, 100

  tags = {
    Name = "cooperativa_subnet_privada"
  }
} 

#crear un aws internet gateway (puerta de enlace a internet)
resource "aws_internet_gateway" "cooperativa_internet_gateway" {
  vpc_id = aws_vpc.cooperativa_vpc.id

  tags = {
    Name = "cooperativa_internet_gateway"
  }
}

resource "aws_nat_gateway" "cooperativa_nat_gateway" {
  allocation_id = aws_eip.cooperativa_eip.id
  connectivity_type = "public"
  subnet_id     = aws_subnet.cooperativa_subnet_publica.id

  tags = {
    Name = "cooperativa_nat_gateway"
  }
}


resource "aws_route_table" "cooperativa_route_table" {
  vpc_id = aws_vpc.cooperativa_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cooperativa_internet_gateway.id
  }

  tags = {
    Name = "cooperativa_route_table"
  }
}

resource "aws_route_table_association" "cooperativa_route_table_association" {
  subnet_id      = aws_subnet.cooperativa_subnet_publica.id
  route_table_id = aws_route_table.cooperativa_route_table.id
}

//Variables de configuracion

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id"{
  default = "ami-064519b8c76274859"
}

resource "aws_key_pair" "cooperativa_key" {
  
  key_name   = "cooperativa_key"
  public_key = file("nginx-server.key.pub")  
}

# Grupo de seguridad para permitir HTTP y SSH
resource "aws_security_group" "security" {
  vpc_id      = aws_vpc.cooperativa_vpc.id
  name        = "security"
  description = "Allow HTTP on port 80 and SSH on port 22"

  # Regla para permitir tráfico HTTP (puerto 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Permitir desde cualquier IP
  }

  # Regla para permitir tráfico SSH (puerto 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Permitir desde cualquier IP (puedes restringirlo a una IP específica por seguridad)
  }

  # Regla para permitir todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_instance" "debian_instance" {
  ami           = var.ami_id  # Selecciona una AMI que soporte Ubuntu o Amazon Linux
  instance_type = var.instance_type  # Tipo de instancia
   # Configuración de las llaves de acceso
  key_name = aws_key_pair.cooperativa_key.key_name  
  security_groups = [aws_security_group.security.id]


  # Script para instalar Nginx
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y nginx
              sudo systemctl enable nginx
              sudo systemctl start nginx
              EOF

  # Configuración de la red
  subnet_id = aws_subnet.cooperativa_subnet_publica.id 
  associate_public_ip_address = true

 
  # Tags (opcional)
  tags = {
    Name = "debian_instance"
  }
}


//Bucket 


//Creamos el bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "aopdebianbucket1"
  force_destroy = true //este parámetro fuerza la eliminacion del bucket incluso si hay datos almacenados (objetos)
  lifecycle {
    prevent_destroy = false //terraform no evitará la destruccion del recurso 
  }

  website {
    index_document = "index.html"  # Página principal del sitio web
    error_document = "error.html"  # Página de error personalizada
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.bucket.id   # Referencia al bucket andrescooperativa

  # Desactiva todas las restricciones de acceso público
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.bucket.id

  policy = jsonencode({
   "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutBucketPolicy",
      "Resource": "arn:aws:s3:::aopdebianbucket1"
    }
    ]
  })
  }

resource "aws_s3_bucket_object" "index_html" {
  bucket = aws_s3_bucket.bucket.id
  key    = "index.html" # Nombre en el bucket
  source = "${path.module}/index.html" # Ruta al archivo
}

resource "aws_s3_bucket_object" "script_js" {
  bucket = aws_s3_bucket.bucket.id
  key    = "script.js" # Nombre en el bucket
  source = "${path.module}/script.js" # Ruta al archivo
}

resource "aws_s3_bucket_object" "estilos_css" {
  bucket = aws_s3_bucket.bucket.id
  key    = "estilos.css" # Nombre en el bucket
  source = "${path.module}/estilos.css" # Ruta al archivo
}




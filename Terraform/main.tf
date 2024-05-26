resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"

}

resource "aws_iam_policy" "ec2_volume_management" {
  name        = "EC2VolumeManagement"
  description = "Allow EC2 volume management operations"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DeleteVolume",
          "ec2:CreateTags"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_group_volume_management" {
  role       = aws_iam_role.eks_node_role.name #"eks-teste-app-eks-node-group-20240523194757240100000002"  # Substitua pelo nome correto da role
  policy_arn = aws_iam_policy.ec2_volume_management.arn
}







#------------------------------- recurso novo acima


data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  map_public_ip_on_launch = true
  enable_nat_gateway      = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "cluster-teste-devops"
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.public_subnets, module.vpc.private_subnets)

  eks_managed_node_groups = {
    eks-teste-app = {
      use_custom_launch_template = false
      disk_size                  = 100
      min_size                   = 2
      max_size                   = 3
      desired_size               = 3

      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"
      iam_role_arn   = aws_iam_role.eks_node_role.arn #
    }
  }

  enable_cluster_creator_admin_permissions = true


  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
#----------------------------


# provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/config" # Caminho para o arquivo de configuração do kubectl
#   }
# }

# resource "helm_release" "ebs_csi_driver" {
#   name       = "aws-ebs-csi-driver"
#   repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver/"
#   chart      = "aws-ebs-csi-driver"
#   namespace  = "kube-system"

#   set {
#     name  = "enableVolumeScheduling"
#     value = "true"
#   }

#   set {
#     name  = "enableVolumeResizing"
#     value = "true"
#   }

#   set {
#     name  = "enableVolumeSnapshot"
#     value = "true"
#   }
# }

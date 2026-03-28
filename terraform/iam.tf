# cria um grupo para o user terraform
resource "aws_iam_group" "terraform_group" {
  name = "terraform-provisioners-group"
}

# define as politicas minimas de grupo para EC2 + SG
resource "aws_iam_policy" "ec2_minimal" {
  name        = "terraform-ec2-minimal"
  description = "Permissões mínimas para EC2 + SG"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2BasicManagement"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateRouteTable",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:AssociateRouteTable"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityGroupManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress"
        ]
        Resource = "*"
      },
      {
        Sid    = "KeyPairManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateKeyPair",
          "ec2:DeleteKeyPair",
          "ec2:ImportKeyPair"
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyNonFreeTierInstances"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "*"
        "Condition" : {
          StringNotEquals : {
            "ec2:InstanceType" : "t4g.micro"
          }
        }
      }
    ]
  })
}

# atribui as politicas de gruop (ec2 + sg)
resource "aws_iam_group_policy_attachment" "ec2_minimal_attach" {
  group      = aws_iam_group.terraform_group.name
  policy_arn = aws_iam_policy.ec2_minimal.arn
}


# cria o user terraform
# NOTA: Este recurso documenta o usuário operacional boa pratica substituir no futuro
#       por IAM Identity Center + SSO.
resource "aws_iam_user" "terraform_user" {
  name = "terraform-operator"
}

# add terraform user to terraform group
resource "aws_iam_group_membership" "terraform_team" {
  name = "terraform-membership"

  users = [
    aws_iam_user.terraform_user.name
  ]

  group = aws_iam_group.terraform_group.name
}


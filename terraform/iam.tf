# cria um grupo para o user terraform
resource "aws_iam_group" "terraform_group" {
  name = "terraform-provisioners-group"
}

# define as politicas minimas de grupo para EC2 + SG + IAM
resource "aws_iam_policy" "ec2_minimal" {
  name        = "terraform-ec2-minimal"
  description = "Permissões mínimas para EC2 + SG + IAM (apply e destroy)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Management"
        Effect = "Allow"
        Action = [
          # instancia
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          # vpc
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          # subnet
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          # routing
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          # gateway
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          # tags
          "ec2:CreateTags",
          "ec2:DeleteTags"
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
        Sid    = "IAMManagement"
        Effect = "Allow"
        Action = [
          # grupo
          "iam:CreateGroup",
          "iam:DeleteGroup",
          "iam:GetGroup",
          # policy
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          # usuario
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:GetUser",
          "iam:TagUser",
          "iam:UntagUser",
          # membership
          "iam:AddUserToGroup",
          "iam:RemoveUserFromGroup",
          "iam:ListGroupsForUser",
          # attachment
          "iam:AttachGroupPolicy",
          "iam:DetachGroupPolicy",
          "iam:ListAttachedGroupPolicies"
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyNonFreeTierInstances"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotEquals = {
            "ec2:InstanceType" = "t4g.micro"
          }
        }
      }
    ]
  })
}

# atribui as politicas de gruop
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


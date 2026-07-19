terraform {
backend "s3" {
region = "eu-north-1"
bucket = "krishna.143.flm.bucket"
key = "prod/terraform.tfstate"
}
}

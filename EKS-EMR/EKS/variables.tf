variable "project_name" {
    type = "string"
    default = "EKSTEST"
}
variable region {
    default = "us-east-1"
}
variable environment {
    type = "string"
    default = "non-prod"
}
variable team_name {
    type = "string"
    default = "testteam"
}
variable vpc_id {
    default ="vpc-08e5c60e3c6921176"

}
variable public_subnet_ids {
    default = ["subnet-0733eef8ee5047f4e","subnet-0c44797a86bd8524e"]
}
variable private_subnet_ids {
    type = "list"
    default = ["subnet-0c644f7d33c6e8f58","subnet-0f550f3ca539dad03"]
}
variable instance_type {
    default = "t2.micro"
}
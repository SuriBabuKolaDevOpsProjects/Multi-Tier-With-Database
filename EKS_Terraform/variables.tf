variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_vpc_info" {
  type = object({
    vpc_name          = string
    vpc_cidr          = string
    subnet_names      = list(string)
    availability_zone = list(string)
    igw_name          = string
    route_table_name  = string
  })
  default = {
    vpc_name          = "cluster_vpc"
    vpc_cidr          = "198.162.0.0/16"
    subnet_names      = ["app1", "app2"]
    availability_zone = ["a", "b"]
    igw_name          = "cluster_igw"
    route_table_name  = "cluster_route_table"
  }
}

variable "security_group" {
  type = object({
    cluster_sg_name = string
    node_sg_name    = string
  })
  default = {
    cluster_sg_name = "cluster_sg"
    node_sg_name    = "node_sg"
  }
}

variable "node_ssh_keyname" {
  type    = string
  default = "BankApp"
}
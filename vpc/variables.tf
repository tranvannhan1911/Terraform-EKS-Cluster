variable "region" {
}
variable "cidr_block" {
}
variable "cidr_block_public_subnet" {
  # validation {
  #     condition     = length(var.cidr_block_public_subnet) == length(data.az.available)
  #     error_message = "the size of the cidr_block_public_subnet must be equals the number of az in the region ${var.region}: ${length(data.az.available)}"
  # }
}
# variable "cidr_block_private_subnet" {
#   default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
#   # validation {
#   #     condition     = length(var.cidr_block_private_subnet) == length(data.az.available)
#   #     error_message = "the size of the cidr_block_private_subnet must be equals the number of az in the region ${var.region}: ${length(data.az.available)}"
#   # }
# }
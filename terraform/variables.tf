variable "region" {
  description = "AWS Region for the lab."
  type        = string
  default     = "ap-south-1"
}

variable "student_name" {
  description = "Student tag value."
  type        = string
  default     = "Student"
}

variable "admin_cidr" {
  description = "Your current public IPv4 CIDR allowed to SSH to the bastion (must be /32)."
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.admin_cidr))
    error_message = "admin_cidr must be one IPv4 address with /32."
  }
}

variable "public_key_path" {
  description = "Local path to your SSH public key (.pub). The private key is never uploaded."
  type        = string
}

variable "instance_type" {
  description = "Small x86 EC2 instance type approved for your lab account."
  type        = string
  default     = "t3.micro"
}

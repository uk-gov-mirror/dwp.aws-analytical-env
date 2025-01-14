variable "assume_role" {
  type    = string
  default = "ci"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "costcode" {
  type    = string
  default = "PRJ0022507"
}

variable "aws_analytical_env_emr_launcher_zip" {
  type = map(string)

  default = {
    base_path = ""
    version   = ""
  }
}

variable "manage_mysql_user_lambda_zip" {
  type = map(string)

  default = {
    base_path = ""
    version   = ""
  }
}

variable "emr_core_instance_count" {
  default = {
    development = "1"
    qa          = "1"
    integration = "1"
    preprod     = "1"
    production  = "10"
  }
}

variable "emr_instance_type_master" {
  default = {
    development = "m5.2xlarge"
    qa          = "m5.2xlarge"
    integration = "m5.2xlarge"
    preprod     = "m5.2xlarge"
    production  = "m5.12xlarge"
  }
}

variable "emr_instance_type_core_one" {
  default = {
    development = "m5.2xlarge"
    qa          = "m5.2xlarge"
    integration = "m5.2xlarge"
    preprod     = "m5.2xlarge"
    production  = "m5.12xlarge"
  }
}
variable "emr_instance_type_core_two" {
  default = {
    development = "m5a.2xlarge"
    qa          = "m5a.2xlarge"
    integration = "m5a.2xlarge"
    preprod     = "m5a.2xlarge"
    production  = "m5a.12xlarge"
  }
}

variable "emr_instance_type_core_three" {
  default = {
    development = "m5d.2xlarge"
    qa          = "m5d.2xlarge"
    integration = "m5d.2xlarge"
    preprod     = "m5d.2xlarge"
    production  = "m5d.12xlarge"
  }
}

variable "emr_al2_ami_id" {
  description = "ID of AMI to be used for EMR clusters"
}

variable "emr_hive_compaction_threads" {
  default = {
    development = "1"
    qa          = "1"
    integration = "1"
    preprod     = "1"
    production  = "1"
  }
}

variable "emr_hive_tez_sessions_per_queue" {
  default = {
    development = "10"
    qa          = "10"
    integration = "10"
    preprod     = "20"
    production  = "20"
  }
}

variable "emr_hive_max_reducers" {
  default = {
    development = "1099"
    qa          = "1099"
    integration = "1099"
    preprod     = "1099"
    production  = "1099"
  }
}

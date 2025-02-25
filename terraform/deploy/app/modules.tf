data "aws_secretsmanager_secret_version" "hive_metastore_password_secret" {
  provider  = aws
  secret_id = "metadata-store-v2-analytical-env"
}

module "emr" {
  source = "../../modules/emr"

  common_tags = local.common_tags

  role_arn = {
    management = "arn:aws:iam::${local.account[local.management_account[local.environment]]}:role/${var.assume_role}"
  }

  log_bucket = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id

  ami_id                  = var.emr_al2_ami_id
  emr_release_label       = "emr-6.2.0"
  cognito_user_pool_id    = data.terraform_remote_state.cognito.outputs.cognito.user_pool_id
  dks_sg_id               = data.terraform_remote_state.crypto.outputs.dks_sg_id[local.environment]
  dks_subnet              = data.terraform_remote_state.crypto.outputs.dks_subnet
  dks_endpoint            = data.terraform_remote_state.crypto.outputs.dks_endpoint[local.environment]
  interface_vpce_sg_id    = data.terraform_remote_state.aws_analytical_environment_infra.outputs.interface_vpce_sg_id
  s3_prefix_list_id       = data.terraform_remote_state.aws_analytical_environment_infra.outputs.s3_prefix_list_id
  dynamodb_prefix_list_id = data.terraform_remote_state.aws_analytical_environment_infra.outputs.dynamodb_prefix_list_id
  internet_proxy_dns_name = data.terraform_remote_state.aws_analytical_environment_infra.outputs.internet_proxy_dns_name
  internet_proxy_sg_id    = data.terraform_remote_state.aws_analytical_environment_infra.outputs.internet_proxy_sg
  parent_domain_name      = local.parent_domain_name[local.environment]
  root_dns_name           = local.root_dns_name[local.environment]
  cert_authority_arn      = data.terraform_remote_state.certificate_authority.outputs.root_ca.arn
  vpc                     = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc
  env_certificate_bucket  = local.env_certificate_bucket
  mgmt_certificate_bucket = local.mgmt_certificate_bucket
  dataset_glue_db         = data.terraform_remote_state.aws-analytical-dataset-generation.outputs.analytical_dataset_generation.job_name
  security_configuration_groups = {
    UC_DataScience_PII     = ["HiveDataUCDataSciencePII", "AnalyticalDatasetCrownReadOnly", "ReadPDMPiiAndNonPii", "readwriteprocessedpublishedbuckets"],
    UC_DataScience_Non_PII = ["HiveDataUCDataScienceNonPII", "AnalyticalDatasetCrownReadOnlyNonPii", "ReadPDMNonPiiOnly"]
  }
  security_configuration_user_roles = module.user_roles.output.users
  monitoring_sns_topic_arn          = data.terraform_remote_state.security-tools.outputs.sns_topic_london_monitoring.arn
  logging_bucket                    = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id
  name_prefix                       = local.name


  use_mysql_hive_metastore     = local.use_mysql_hive_metastore[local.environment]
  hive_metastore_endpoint      = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.rds_cluster.endpoint
  hive_metastore_database_name = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.rds_cluster.database_name
  hive_metastore_password      = jsondecode(data.aws_secretsmanager_secret_version.hive_metastore_password_secret.secret_string)["password"]
  hive_metastore_username      = jsondecode(data.aws_secretsmanager_secret_version.hive_metastore_password_secret.secret_string)["username"]
  hive_metastore_sg_id         = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.security_group.id

  s3_tagger_job_definition = data.terraform_remote_state.aws_s3_object_tagger.outputs.pdm_object_tagger_batch.job_definition.arn
  s3_tagger_job_queue      = data.terraform_remote_state.aws_s3_object_tagger.outputs.pdm_object_tagger_batch.job_queue.arn

  artefact_bucket = {
    id      = data.terraform_remote_state.management_artefacts.outputs.artefact_bucket.id
    kms_arn = data.terraform_remote_state.management_artefacts.outputs.artefact_bucket.cmk_arn
  }
  region      = var.region
  account     = local.account[local.environment]
  environment = local.environment

  truststore_certs         = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
  truststore_aliases       = "dataworks_root_ca,dataworks_mgt_root_ca"
  config_bucket_arn        = data.terraform_remote_state.common.outputs.config_bucket.arn
  config_bucket_cmk        = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn
  config_bucket_id         = data.terraform_remote_state.common.outputs.config_bucket.id
  dataset_s3               = data.terraform_remote_state.common.outputs.published_bucket
  published_bucket_cmk     = data.terraform_remote_state.common.outputs.published_bucket_cmk.arn
  processed_bucket_arn     = data.terraform_remote_state.common.outputs.processed_bucket.arn
  processed_bucket_cmk     = data.terraform_remote_state.common.outputs.processed_bucket_cmk.arn
  processed_bucket_id      = data.terraform_remote_state.common.outputs.processed_bucket.bucket
  rbac_version             = local.rbac_version[local.environment]
  pipeline_metadata_table  = "arn:aws:dynamodb:${var.region}:${local.account[local.environment]}:table/${data.terraform_remote_state.internal_compute.outputs.data_pipeline_metadata_dynamo.name}"
  sns_monitoring_queue_arn = data.terraform_remote_state.security-tools.outputs.sns_topic_london_monitoring.arn

  jupyterhub_bucket = {
    id      = data.terraform_remote_state.orchestration-service.outputs.s3fs_bucket_id
    cmk_arn = data.terraform_remote_state.orchestration-service.outputs.s3fs_bucket_kms_arn
  }
}

module "pushgateway" {
  source = "../../modules/pushgateway"

  name_prefix = "analytical-env-pushgateway"

  container_name       = "prom-pushgateway"
  image_ecr_repository = data.terraform_remote_state.management.outputs.ecr_pushgateway_url

  subnets              = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_subnets_private[*].id
  vpc_id               = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_vpc.id
  interface_vpce_sg_id = data.terraform_remote_state.aws_analytical_environment_infra.outputs.interface_vpce_sg_id
  s3_prefixlist_id     = data.terraform_remote_state.aws_analytical_environment_infra.outputs.s3_prefix_list_id
  logging_bucket       = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id

  management_role_arn = "arn:aws:iam::${local.account[local.management_account[local.environment]]}:role/${var.assume_role}"

  common_tags = local.common_tags

  cert_authority_arn = data.terraform_remote_state.certificate_authority.outputs.root_ca.arn
  parent_domain_name = local.parent_domain_name[local.environment]
  root_dns_suffix    = local.root_dns_name[local.environment]
}

module "livy_proxy" {
  source = "../../modules/livy-proxy"

  ecs_cluster_name = "orchestration-service-user-host"

  base64_keystore_data = base64encode(data.http.keystore_data.body)
  livy_dns_name        = module.emr.emr_cluster_cname

  image_ecr_repository = data.terraform_remote_state.management.outputs.ecr_livy-proxy_url
  log_bucket_id        = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id

  management_role_arn = "arn:aws:iam::${local.account[local.management_account[local.environment]]}:role/${var.assume_role}"

  cert_authority_arn = data.terraform_remote_state.certificate_authority.outputs.root_ca.arn
  parent_domain_name = local.parent_domain_name[local.environment]
  root_dns_suffix    = local.root_dns_name[local.environment]

  vpc_id               = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_vpc.id
  subnet_ids           = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_subnets_private[*].id
  s3_prefix_list_id    = data.terraform_remote_state.aws_analytical_environment_infra.outputs.s3_prefix_list_id
  interface_vpce_sg_id = data.terraform_remote_state.aws_analytical_environment_infra.outputs.interface_vpce_sg_id
  livy_sg_id           = module.emr.emr_security_group_id

  common_tags = local.common_tags

}

module "codecommit" {
  source = "../../modules/codecommit"

  common_tags = local.common_tags

  repository_name        = "Data_Science-${local.environment}"
  repository_description = "This is the repository for Data Science"

}


module launcher {
  source = "../../modules/emr-launcher"

  emr_bucket                            = module.emr.emr_bucket
  config_bucket                         = data.terraform_remote_state.common.outputs.config_bucket
  config_bucket_cmk                     = data.terraform_remote_state.common.outputs.config_bucket_cmk
  aws_analytical_env_emr_launcher_zip   = var.aws_analytical_env_emr_launcher_zip
  ami                                   = var.emr_al2_ami_id
  log_bucket                            = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id
  account                               = local.account[local.environment]
  analytical_env_security_configuration = module.emr.analytical_env_security_configuration
  costcode                              = var.costcode
  release_version                       = "6.2.0"
  common_security_group                 = module.emr.common_security_group
  master_security_group                 = module.emr.master_security_group
  slave_security_group                  = module.emr.slave_security_group
  service_security_group                = module.emr.service_security_group
  proxy_host                            = data.terraform_remote_state.aws_analytical_environment_infra.outputs.internet_proxy_dns_name
  full_no_proxy                         = module.emr.full_no_proxy
  common_tags                           = local.common_tags
  name_prefix                           = local.name
  hive_metastore_endpoint               = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.rds_cluster.endpoint
  hive_metastore_database_name          = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.rds_cluster.database_name
  hive_metastore_username               = jsondecode(data.aws_secretsmanager_secret_version.hive_metastore_password_secret.secret_string)["username"]
  hive_metastore_secret_id              = data.aws_secretsmanager_secret_version.hive_metastore_password_secret.secret_id
  batch_security_configuration          = module.emr.batch_security_configuration
  hive_metastore_arn                    = data.aws_secretsmanager_secret_version.hive_metastore_password_secret.arn
  subnet_ids                            = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_subnets_private.*.id
  core_instance_count                   = var.emr_core_instance_count[local.environment]
  environment                           = local.environment
  instance_type_master                  = var.emr_instance_type_master[local.environment]
  instance_type_core_one                = var.emr_instance_type_core_one[local.environment]
  instance_type_core_two                = var.emr_instance_type_core_two[local.environment]
  instance_type_core_three              = var.emr_instance_type_core_three[local.environment]
  hive_compaction_threads               = var.emr_hive_compaction_threads[local.environment]
  hive_tez_sessions_per_queue           = var.emr_hive_tez_sessions_per_queue[local.environment]
  hive_max_reducers                     = var.emr_hive_max_reducers[local.environment]
}

module "emrfs_lambda" {
  source = "../../modules/emrfs-lambda"

  emrfs_iam_assume_role_json = module.emr.emrfs_iam_assume_role_json
  account                    = local.account[local.environment]
  aws_subnets_private        = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_subnets_private[*].id
  common_tags                = local.common_tags
  name_prefix                = "analytical-env-emrfs-lambda"
  region                     = var.region
  vpc_id                     = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_vpc.id
  internet_proxy_sg_id       = data.terraform_remote_state.aws_analytical_environment_infra.outputs.internet_proxy_sg
  db_client_secret_arn       = module.rbac_db.secrets.client_credentials["emrfs-lambda"].arn
  db_cluster_arn             = module.rbac_db.rds_cluster.arn
  db_name                    = module.rbac_db.db_name
  cognito_user_pool_id       = data.terraform_remote_state.cognito.outputs.cognito.user_pool_id
  mgmt_account               = local.account[local.management_account[local.environment]]
  management_role_arn        = "arn:aws:iam::${local.account[local.management_account[local.environment]]}:role/${var.assume_role}"
  environment                = local.environment
  s3fs_bucket_id             = data.terraform_remote_state.orchestration-service.outputs.s3fs_bucket_id
  s3fs_kms_arn               = data.terraform_remote_state.orchestration-service.outputs.s3fs_bucket_kms_arn
}

module "rbac_db" {
  source = "../../modules/aurora_db"

  name_prefix = "analytical-env-rbac"

  config_bucket = {
    id      = data.terraform_remote_state.common.outputs.config_bucket.id
    cmk_arn = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn
  }
  init_db_sql_path = "${path.module}/rbac-db-init.ddl.sql"

  vpc_id               = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_vpc.id
  subnet_ids           = data.terraform_remote_state.aws_analytical_environment_infra.outputs.vpc.aws_subnets_private[*].id
  interface_vpce_sg_id = data.terraform_remote_state.aws_analytical_environment_infra.outputs.interface_vpce_sg_id


  manage_mysql_user_lambda_zip = {
    base_path = var.manage_mysql_user_lambda_zip.base_path
    version   = var.manage_mysql_user_lambda_zip.version
  }

  clients = {
    "emrfs-lambda"           = "SELECT, INSERT, UPDATE",
    "analytical_env_support" = "ALL",
    "orchestration_service"  = "SELECT, INSERT"
  }

  ci_role = "arn:aws:iam::${local.account[local.environment]}:role/ci"

  common_tags = local.common_tags
}

module "user_roles" {
  source         = "../../modules/data_user_roles"
  user_pool_id   = data.terraform_remote_state.cognito.outputs.cognito.user_pool_id
  target_account = local.account[local.environment]

  providers = {
    aws = aws.management
  }
}

output "data" {
  value = module.user_roles.output
}

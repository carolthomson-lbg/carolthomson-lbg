################################################################################
##                                                                            ##
##   ----==| C R E A T E   P O S T G R E S Q L   I N S T A N C E |==----      ##
##                                                                            ##
################################################################################

resource "google_sql_database_instance" "analytics" {

  count = var.create_database ? 1 : 0

  name                = var.analytics_database_instance_name
  database_version    = "POSTGRES_14"
  region              = var.region
  deletion_protection = true
  settings {
    tier              = "db-custom-1-3840"
    activation_policy = "ALWAYS"

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = data.google_compute_network.project_vpc.id
      require_ssl                                   = true
      enable_private_path_for_google_cloud_services = true
    }
  }
}

resource "google_sql_database_instance" "read_replica" {

  count = var.create_database ? 1 : 0

  name                 = "analytics-replica"
  master_instance_name = google_sql_database_instance.analytics[count.index].name
  region               = "europe-west1"
  database_version     = "POSTGRES_14"
  deletion_protection  = true

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = "db-custom-1-3840"
    activation_policy = "ALWAYS"

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = data.google_compute_network.project_vpc.id
      require_ssl                                   = true
      enable_private_path_for_google_cloud_services = true
    }
  }
}

##----------------------------------------------------------------
## Create a uam database
##----------------------------------------------------------------

resource "google_sql_database" "analytics_uam" {

  count = var.create_database ? 1 : 0

  name     = "uam"
  instance = google_sql_database_instance.analytics[count.index].name
}

##----------------------------------------------------------------
## Add Cloud IAM SQL Users
##----------------------------------------------------------------

# There appears to be a limitation with this where the service account domain has to be trunked
# This is the service account's email without the .gserviceaccount.com domain suffix.
# https://cloud.google.com/sql/docs/postgres/iam-logins#log-in-with-automatic

resource "google_sql_user" "analytics_database_sa_sql" {

  count = var.create_database ? 1 : 0

  name     = "sql-${data.google_project.project.number}@${var.project_id}.iam"
  instance = google_sql_database_instance.analytics[count.index].name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_sql_user" "analytics_database_sa_cloudrun_uam" {

  count = var.create_database ? 1 : 0

  name     = "cloudrun-uam-${data.google_project.project.number}@${var.project_id}.iam"
  instance = google_sql_database_instance.analytics[count.index].name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

##----------------------------------------------------------------
## Add Cloud Built In SQL Users
##----------------------------------------------------------------

resource "random_password" "analytics_database_password" {

  count = var.create_database ? 1 : 0

  length           = 20
  special          = true
  override_special = "_%@"
}

resource "google_sql_user" "analytics_database_user" {

  count = var.create_database ? 1 : 0

  name     = var.analytics_database_instance_name
  instance = google_sql_database_instance.analytics[count.index].name
  password = random_password.analytics_database_password[count.index].result
}

resource "google_secret_manager_secret" "analytics_database_password_secret" {

  count = var.create_database ? 1 : 0

  secret_id = var.analytics_database_instance_name

  replication {
    user_managed {
      replicas {
        location = var.region_replica
      }
    }
  }
}

resource "google_secret_manager_secret_version" "analytics_database_password_secret_version" {

  count = var.create_database ? 1 : 0

  secret      = google_secret_manager_secret.analytics_database_password_secret[count.index].id
  secret_data = random_password.analytics_database_password[count.index].result
}

resource "google_compute_firewall" "allow-serverless-egress" {
  name      = "allow-serverless-egress"
  network   = var.vpc_name
  priority  = 2000
  direction = "EGRESS"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
  destination_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["443", "80"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  target_tags = ["vpc-connector-europe-west2-vpc-con"]
}

resource "google_compute_firewall" "allow-postgres-egress" { # This rule is required to permit the Serverless services to talk to the state-database
  name      = "allow-postgres-egress"
  network   = var.vpc_name
  priority  = 2000
  direction = "EGRESS"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
  destination_ranges = [var.postgres_destination_ranges]
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
  allow {
    protocol = "udp"
    ports    = ["5432"]
  }
}

# route to reach Qualys using the NAT
resource "google_compute_route" "network-route-qualysapi" {
  name             = "network-route-qualysapi"
  dest_range       = "64.39.106.226/32"
  network          = var.vpc_name
  priority         = 0
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "network-route-qualys-gateway" {
  name             = "network-route-qualys-gateway"
  dest_range       = "64.39.106.241/32"
  network          = var.vpc_name
  priority         = 0
  next_hop_gateway = "default-internet-gateway"
}

################################################################################
##                                                                            ##
##       ----==| R O U T E   I N T E R N E T   O V E R   N A T |==----        ##
##                                                                            ##
################################################################################

resource "google_compute_route" "network-route-internet-egress" {
  name             = "network-route-internet-egress"
  dest_range       = "0.0.0.0/0"
  network          = var.vpc_name
  priority         = 65000
  next_hop_gateway = "default-internet-gateway"
}

################################################################################
##                                                                            ##
##  ----==| S S H   I A P   F I R E W A L L   S Q L   C O M P U T E |==----   ##
##                                                                            ##
################################################################################

resource "google_compute_firewall" "findings_database_ssh_over_iap" {
  name      = "${var.findings_database_instance_name}-ssh-over-iap"
  direction = "INGRESS"
  network   = var.vpc_name
  priority  = 150

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]

  target_tags = [var.findings_database_instance_name,
  var.analytics_database_instance_name]
}


################################################################################
##                                                                            ##
## ----==| C L O U D   S Q L   A U T H   P R O X Y   F I R E W A L L |==----  ##
##                                                                            ##
################################################################################

resource "google_compute_firewall" "allow_cloud_sql_auth_proxy" {

  count = var.create_database ? 1 : 0

  name      = "${var.findings_database_instance_name}-allow-cloud-sql-auth-proxy"
  direction = "EGRESS"
  network   = var.vpc_name
  priority  = 2000


  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  allow {
    protocol = "tcp"
    ports    = ["3307"] # Use the custom port you specified when you set up the Cloud SQL Auth proxy.
  }


  # Use the output from the compute engines output step as the source range
  destination_ranges = [google_sql_database_instance.findings_database[count.index].private_ip_address]

  # Use the tag specified in the Compute Engine instance resource
  target_tags = [var.findings_database_instance_name, "vpc-connector-${var.region}-vpc-con"]
}


resource "google_compute_firewall" "allow_cloud_sql_auth_proxy_analytics" {

  count = var.create_database ? 1 : 0

  name      = "${var.analytics_database_instance_name}-allow-cloud-sql-auth-proxy"
  direction = "EGRESS"
  network   = var.vpc_name
  priority  = 2000


  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  allow {
    protocol = "tcp"
    ports    = ["3307"] # Use the custom port you specified when you set up the Cloud SQL Auth proxy.
  }


  # Use the output from the compute engines output step as the source range
  destination_ranges = [google_sql_database_instance.analytics[count.index].private_ip_address]

  # Use the tag specified in the Compute Engine instance resource
  target_tags = [var.analytics_database_instance_name, "vpc-connector-${var.region}-vpc-con"]
}

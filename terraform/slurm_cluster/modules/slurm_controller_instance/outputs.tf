/**
 * Copyright (C) SchedMD LLC.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

############
# INSTANCE #
############

output "slurm_controller_instance" {
  description = "Controller instance module."
  value       = module.slurm_controller_instance
}

output "slurm_controller_instances" {
  description = "Controller instance resource."
  value       = module.slurm_controller_instance.slurm_instances
}

output "instances_self_links" {
  description = "Controller instance resource."
  value       = module.slurm_controller_instance.instances_self_links
}

#########
# SLURM #
#########

output "slurm_cluster_name" {
  description = "Cluster name for resource naming and slurm accounting."
  value       = var.slurm_cluster_name
}

output "partitions" {
  description = "Cluster partitions."
  value       = local.partitions
}

output "compute_list" {
  description = "Cluster compute list."
  value       = local.compute_list
}

##########
# GOOGLE #
##########

output "cloud_logging_filter" {
  description = "Cloud Logging filter to find startup errors."
  value       = <<-EOT
  resource.type="gce_instance"
  logName=("projects/${var.project_id}/logs/slurm_resume" OR "projects/${var.project_id}/logs/slurm_suspend" OR "projects/${var.project_id}/logs/slurm_sync" OR "projects/${var.project_id}/logs/slurmctld" OR "projects/${var.project_id}/logs/slurmd" OR "projects/${var.project_id}/logs/slurmdbd" OR "projects/${var.project_id}/logs/slurmeventd") OR (logName=("projects/${var.project_id}/logs/syslog") AND jsonPayload.message=~"google_metadata_script_runner")
  EOT
}

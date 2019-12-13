module "blueprint_networking" {
  source = "github.com/aztfmod/blueprints?ref=1912-networking/blueprint_networking"
  
  prefix                  = local.prefix
  tags                    = local.tags
  networking_object       = var.blueprint_networking.networking_object
  log_analytics_workspace = local.log_analytics_workspace
  diagnostics_map         = local.diagnostics_map
}


module "blueprint_container_registry" {
  source = "github.com/aztfmod/blueprints?ref=1912-container-registry/blueprint_container_registry"
  
  prefix                  = local.prefix
  tags                    = local.tags
  log_analytics_workspace = local.log_analytics_workspace
  diagnostics_map         = local.diagnostics_map
  acr_object              = var.blueprint_container_registry.acr_object
  subnet_id               = module.blueprint_networking.subnet_id_by_name["devopsAgent"]
}

module "blueprint_devops_self_hosted_agent" {
  source = "github.com/aztfmod/blueprints?ref=1912-vm/blueprint_virtual_machine"
  
  prefix                  = local.prefix
  tags                    = local.tags
  log_analytics_workspace = local.log_analytics_workspace
  diagnostics_map         = local.diagnostics_map
  vm_object               = var.blueprint_devops_self_hosted_agent.vm_object
  subnet_id               = lookup(module.blueprint_networking.subnet_id_by_name, "devopsAgent")
  acr_object              = module.blueprint_container_registry.object
}


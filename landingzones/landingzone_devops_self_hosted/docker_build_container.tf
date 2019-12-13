
locals {
    docker_build_command = <<EOT
        docker build -t devops -f ./scripts/Docker/devops_agent.Dockerfile ./scripts/Docker

        docker tag devops ${module.blueprint_container_registry.object.login_server}/devops

        docker push ${module.blueprint_container_registry.object.login_server}/devops
    EOT

    ## This command saves on the local rover volume the private ssh key required to allow the rover to login the docker host in the self hosted agent
    ssh_config_update = <<EOT
        chmod 600 ~/.ssh/${module.blueprint_devops_self_hosted_agent.object.host_connection}.private
        echo "" >> ~/.ssh/config
        echo "Host ${module.blueprint_devops_self_hosted_agent.object.host_connection}" >> ~/.ssh/config
        echo "    IdentityFile ~/.ssh/${module.blueprint_devops_self_hosted_agent.object.host_connection}.private" >> ~/.ssh/config
        echo "    StrictHostKeyChecking no" >> ~/.ssh/config
    EOT

    docker_ssh_command = <<EOT
        ssh -l ${module.blueprint_devops_self_hosted_agent.object.admin_username} ${module.blueprint_devops_self_hosted_agent.object.host_connection} << EOF
            az login --identity
            az acr login --name ${module.blueprint_container_registry.object.admin_username}
            docker pull ${module.blueprint_container_registry.object.login_server}/devops
    EOT

    login_azure_container_registry_command = "pwd=${module.blueprint_container_registry.object.admin_password} printenv pwd | docker login -u ${module.blueprint_container_registry.object.admin_username} --password-stdin ${module.blueprint_container_registry.object.login_server}"
}

###
##   1 - Loging the Azure container registry
###
resource "null_resource" "login_azure_container_registry" {
    provisioner "local-exec" {
        command = local.login_azure_container_registry_command
    }

    triggers = {
        command = sha256(local.login_azure_container_registry_command)
    }
}

##
#   2 - Build the azure devops image and push to the registry
##
resource "null_resource" "build_docker_image" {
    depends_on = [null_resource.login_azure_container_registry]

    provisioner "local-exec" {
        command = local.docker_build_command
    }

    triggers = {
        docker_build_command    = sha256(local.docker_build_command)
        login                   = sha256(local.login_azure_container_registry_command)
        login_server            = module.blueprint_container_registry.object.login_server
        admin_username          = module.blueprint_container_registry.object.admin_username
        admin_password          = module.blueprint_container_registry.object.admin_password
    }
}

##
#   3 - Register the ssh key of the devops selfhosted server in the ~/.ssh/config
##
resource "null_resource" "ssh_config_update" {
    depends_on = [module.blueprint_devops_self_hosted_agent]

    provisioner "local-exec" {
        command = local.ssh_config_update
    }

    triggers = {
        docker_build_command    = sha256(local.ssh_config_update)
        ssh_key_sha             = sha512(file("~/.ssh/${module.blueprint_devops_self_hosted_agent.object.host_connection}.private"))
    }
}



##
#   4 - Connect to the Azure devops server and pull the devops container from the registry
##
resource "null_resource" "pull_docker_image" {
    depends_on = [
        null_resource.build_docker_image,
        null_resource.ssh_config_update
    ]

    provisioner "local-exec" {
        command = local.docker_ssh_command
    }

    triggers = {
        docker_build_command    = sha256(local.docker_ssh_command)
        login_server            = module.blueprint_container_registry.object.login_server
        admin_username          = module.blueprint_container_registry.object.admin_username
        admin_password          = module.blueprint_container_registry.object.admin_password
    }
}


# Variable for specifying the number of additional Security servers
variable "additional_security_count" {
  description = "Number of additional Security servers to deploy"
  type        = number
  default     = 0  # By default, no additional servers are created
}

# Dynamic Security servers (auto-created)
resource "openstack_networking_port_v2" "auto_security_ports" {
  count = var.additional_security_count

  name               = "port-security-auto-${count.index + 1}"
  network_id         = openstack_networking_network_v2.network.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.microservices_secgroup.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

# VMs for additional Security servers
resource "openstack_compute_instance_v2" "auto_security_vms" {
  count = var.additional_security_count

  name            = "instance-security-auto-${count.index + 1}"
  image_name      = local.image_name
  flavor_name     = local.flavor_name
  key_pair        = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups = [openstack_networking_secgroup_v2.microservices_secgroup.name]

  network {
    port = openstack_networking_port_v2.auto_security_ports[count.index].id
  }

  user_data = <<-EOF
#!/bin/bash

# Add logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data script for auto-security-${count.index + 1}"

# Update system with error suppression
sudo apt-get update || true
sudo apt-get upgrade -y || true

# Install Docker
echo "Installing Docker..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release || true

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || true

# Add Docker repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || true

# Update apt and install docker
sudo apt-get update || true
sudo apt-get install -y docker-ce docker-ce-cli containerd.io || true

# If that fails, try the get.docker.com script
if ! command -v docker &> /dev/null; then
  echo "Standard installation failed, trying get.docker.com script..."
  curl -fsSL https://get.docker.com -o get-docker.sh || true
  sudo sh get-docker.sh || true
fi

# Make sure docker is running
sudo systemctl enable docker || true
sudo systemctl start docker || true

# Verify docker is installed
if command -v docker &> /dev/null; then
  echo "Docker successfully installed: $(docker --version)"
  # Add Docker login
  echo "Logging into Docker registry..."
  sudo docker login -u busuiocegor -p pirat1612 || true
else
  echo "WARNING: Docker installation failed!"
fi

# Get IP address for Eureka registration
INSTANCE_IP=$(hostname -I | awk '{print $1}')
echo "Instance IP address: $INSTANCE_IP"

# Additional pause to ensure Docker starts properly
sleep 10

echo "Starting Security container: auto-security-${count.index + 1}"
sudo docker run -d --name auto-security-${count.index + 1} -p 8080:8080 \
  -e "SPRING_PROFILES_ACTIVE=docker" \
  -e "EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://192.168.254.10:8761/eureka/" \
  -e "EUREKA_INSTANCE_PREFERIPADDRESS=true" \
  -e "EUREKA_INSTANCE_IPADDRESS=$INSTANCE_IP" \
  -e "CUSTOM_SERVER_IP=$INSTANCE_IP" \
  --restart unless-stopped \
  busuiocegor/cloud-project:security-service

echo "Container auto-security-${count.index + 1} started. Checking status..."
sudo docker ps
echo "User data script for auto-security-${count.index + 1} completed."
EOF
}

# Additional output data for new servers
output "additional_security_ips" {
  value = {
    for i, port in openstack_networking_port_v2.auto_security_ports :
      "auto-security-${i + 1}" => port.all_fixed_ips
  }
  description = "IP addresses for additional Security servers"
}
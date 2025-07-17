variable "group_number" {
  type    = string
  default = ""
}

locals {
  auth_url        = "https://10.32.4.29:5000/v3"
  user_name       = "CloudComp7"
  user_password   = ""
  tenant_name     = "CloudComp${var.group_number}"
  router_name     = "CloudComp${var.group_number}-router"
  image_name      = "ubuntu-22.04-jammy-server-cloud-image-amd64"
  flavor_name     = "m1.small"
  region_name     = "RegionOne"
  floating_net    = "ext_net"
  dns_nameservers = ["10.33.16.100"]

  # Используем другой CIDR
  subnet_cidr     = "192.168.254.0/24"

  # Static IP addresses for Eureka and MySQL
  static_instances = {
    eureka = {
      ip          = "192.168.254.10"
      docker_image = "busuiocegor/cloud-project:eureka-service"
      docker_port = 8761
    }
    mysql  = {
      ip          = "192.168.254.20"
      docker_image = "mysql:8.0"
      docker_port = 3306
    }
  }

  # Dynamic Services (без fixed_ip)
  dynamic_instances = {
    gateway1 = {
      docker_image = "busuiocegor/cloud-project:gateway-service"
      docker_port = 8080
      type = "gateway"
    },
    gateway2 = {
      docker_image = "busuiocegor/cloud-project:gateway-service" 
      docker_port = 8080
      type = "gateway"
    },
    security1 = {
      docker_image = "busuiocegor/cloud-project:security-service"
      docker_port = 8083
      type = "security"
    },
    security2 = {
      docker_image = "busuiocegor/cloud-project:security-service"
      docker_port = 8083
      type = "security"
    },
    security3 = {
      docker_image = "busuiocegor/cloud-project:security-service"
      docker_port = 8083
      type = "security"
    },
    notification1 = {
      docker_image = "busuiocegor/cloud-project:notification-service"
      docker_port = 8085
      type = "notification"
    },
    notification2 = {
      docker_image = "busuiocegor/cloud-project:notification-service"
      docker_port = 8085
      type = "notification"
    }
  }
}

terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 2.0.0"
    }
  }
}

provider "openstack" {
  user_name   = local.user_name
  tenant_name = local.tenant_name
  password    = local.user_password
  auth_url    = local.auth_url
  region      = local.region_name
  insecure    = true
}

resource "openstack_compute_keypair_v2" "terraform-keypair" {
  name       = "my-terraform-ietec-key"
  public_key = file("./my-terraform-key.pub")
}

# Create security group
resource "openstack_networking_secgroup_v2" "microservices_secgroup" {
  name        = "microservices-secgroup"
  description = "Security group for microservices"
}

# Allow SSH access
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.microservices_secgroup.id
}

# Allow HTTP access
resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.microservices_secgroup.id
}

# Allow HTTPS access
resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.microservices_secgroup.id
}

# Allow Eureka port
resource "openstack_networking_secgroup_rule_v2" "eureka" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8761
  port_range_max    = 8761
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.microservices_secgroup.id
}

# Allow MySQL port
resource "openstack_networking_secgroup_rule_v2" "mysql" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.microservices_secgroup.id
}

# Allow all microservices ports
resource "openstack_networking_secgroup_rule_v2" "microservices" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8090
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.microservices_secgroup.id
}

# Allow all traffic between instances in this security group
resource "openstack_networking_secgroup_rule_v2" "internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.microservices_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.microservices_secgroup.id
}

resource "openstack_networking_network_v2" "network" {
  name           = "ietec-network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = "ietec-subnet"
  network_id      = openstack_networking_network_v2.network.id
  cidr            = local.subnet_cidr
  ip_version      = 4
  dns_nameservers = local.dns_nameservers
}

# Получаем данные о существующем маршрутизаторе
data "openstack_networking_router_v2" "router" {
  name = local.router_name
}

output "router_external_gateway" {
  value = data.openstack_networking_router_v2.router.external_network_id
  description = "External gateway ID for router"
}

# Присоединяем подсеть к маршрутизатору
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = data.openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

### Ports with static IPs (Eureka and MySQL)
resource "openstack_networking_port_v2" "static_ports" {
  for_each = local.static_instances

  name               = "port-${each.key}"
  network_id         = openstack_networking_network_v2.network.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.microservices_secgroup.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnet.id
    ip_address = each.value.ip
  }
}

### Ports with dynamic IPs (other services)
resource "openstack_networking_port_v2" "dynamic_ports" {
  for_each = local.dynamic_instances

  name               = "port-${each.key}"
  network_id         = openstack_networking_network_v2.network.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.microservices_secgroup.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
    # Не указываем ip_address, OpenStack назначит автоматически
  }
}

### VMs with static ports
resource "openstack_compute_instance_v2" "static_vms" {
  for_each = local.static_instances

  name            = "instance-${each.key}"
  image_name      = local.image_name
  flavor_name     = local.flavor_name
  key_pair        = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups = [openstack_networking_secgroup_v2.microservices_secgroup.name]

  network {
    port = openstack_networking_port_v2.static_ports[each.key].id
  }

  user_data = <<-EOF
#!/bin/bash

# Add logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data script for ${each.key}"

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
else
  echo "WARNING: Docker installation failed!"
fi

# Configure service
SERVICE="${each.key}"
echo "Configuring service: $SERVICE"

if [ "$SERVICE" == "mysql" ]; then
  echo "Starting MySQL container..."
  # MySQL configuration
  sudo docker run -d --name mysql -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_DATABASE=ietecusers \
    -e MYSQL_ROOT_HOST='%' \
    --restart unless-stopped \
    ${each.value.docker_image} \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_unicode_ci \
    --bind-address=0.0.0.0
    
  echo "MySQL container started"
  sudo docker ps
        
elif [ "$SERVICE" == "eureka" ]; then
  echo "Starting Eureka container..."
  # Eureka configuration
  sudo docker run -d --name eureka -p 8761:8761 \
    --restart unless-stopped \
    ${each.value.docker_image}
          
  echo "Eureka container started"
  sudo docker ps
fi
      
echo "User data script for ${each.key} completed."
EOF
}

### VMs with dynamic ports
resource "openstack_compute_instance_v2" "dynamic_vms" {
  for_each = local.dynamic_instances

  name            = "instance-${each.key}"
  image_name      = local.image_name
  flavor_name     = local.flavor_name
  key_pair        = openstack_compute_keypair_v2.terraform-keypair.name
  security_groups = [openstack_networking_secgroup_v2.microservices_secgroup.name]

  network {
    port = openstack_networking_port_v2.dynamic_ports[each.key].id
  }

  user_data = <<-EOF
#!/bin/bash

# Add logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data script for ${each.key}"

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
else
  echo "WARNING: Docker installation failed!"
fi

# Получаем IP-адрес для регистрации в Eureka
INSTANCE_IP=$(hostname -I | awk '{print $1}')
echo "Instance IP address: $INSTANCE_IP"
    
# Определяем тип сервиса и запускаем соответствующий контейнер
SERVICE_TYPE="${each.value.type}"
echo "Service type: $SERVICE_TYPE"

# Дополнительная пауза для гарантированного запуска Docker
sleep 10
    
if [ "$SERVICE_TYPE" == "gateway" ]; then
  echo "Starting Gateway container: ${each.key}"
  sudo docker run -d --name ${each.key} -p ${each.value.docker_port}:${each.value.docker_port} \
    -e "SPRING_PROFILES_ACTIVE=docker" \
    -e "EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://192.168.254.10:8761/eureka/" \
    -e "EUREKA_INSTANCE_PREFERIPADDRESS=true" \
    -e "EUREKA_INSTANCE_IPADDRESS=$INSTANCE_IP" \
    -e "CUSTOM_SERVER_IP=$INSTANCE_IP" \
    --restart unless-stopped \
    ${each.value.docker_image}
    
elif [ "$SERVICE_TYPE" == "security" ]; then
  echo "Starting Security container: ${each.key}"
  echo "Waiting for MySQL to be ready..."
  sleep 60
      
  sudo docker run -d --name ${each.key} -p ${each.value.docker_port}:${each.value.docker_port} \
    -e "SPRING_PROFILES_ACTIVE=docker" \
    -e "EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://192.168.254.10:8761/eureka/" \
    -e "EUREKA_INSTANCE_PREFERIPADDRESS=true" \
    -e "EUREKA_INSTANCE_IPADDRESS=$INSTANCE_IP" \
    -e "CUSTOM_SERVER_IP=$INSTANCE_IP" \
    -e "SPRING_DATASOURCE_URL=jdbc:mysql://192.168.254.20:3306/ietecusers?useSSL=false&allowPublicKeyRetrieval=true&createDatabaseIfNotExist=true" \
    -e "SPRING_DATASOURCE_USERNAME=root" \
    -e "SPRING_DATASOURCE_PASSWORD=root" \
    -e "SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE=10" \
    -e "SPRING_DATASOURCE_HIKARI_CONNECTION_TIMEOUT=60000" \
    --restart unless-stopped \
    ${each.value.docker_image}
    
elif [ "$SERVICE_TYPE" == "notification" ]; then
  echo "Starting Notification container: ${each.key}"
  # Запуск Notification с правильными настройками (без FRONTEND_URL)
  sudo docker run -d --name ${each.key} -p ${each.value.docker_port}:${each.value.docker_port} \
    -e "SPRING_PROFILES_ACTIVE=docker" \
    -e "EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://192.168.254.10:8761/eureka/" \
    -e "EUREKA_INSTANCE_PREFERIPADDRESS=true" \
    -e "EUREKA_INSTANCE_IPADDRESS=$INSTANCE_IP" \
    --restart unless-stopped \
    ${each.value.docker_image}
fi
    
echo "Container ${each.key} started. Checking status..."
sudo docker ps
echo "User data script for ${each.key} completed."
EOF
}

# Floating IP for Load Balancer
resource "openstack_networking_floatingip_v2" "gateway_lb_fip" {
  pool = local.floating_net
}

# Load Balancer for Gateway services
resource "openstack_lb_loadbalancer_v2" "gateway_lb" {
  name           = "gateway-lb"
  vip_subnet_id  = openstack_networking_subnet_v2.subnet.id
  admin_state_up = true
}

# HTTP listener for Load Balancer
resource "openstack_lb_listener_v2" "gateway_listener" {
  name            = "gateway-http-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.gateway_lb.id
  admin_state_up  = true
}

# Pool for Load Balancer
resource "openstack_lb_pool_v2" "gateway_pool" {
  name           = "gateway-pool"
  protocol       = "HTTP"
  lb_method      = "ROUND_ROBIN"
  listener_id    = openstack_lb_listener_v2.gateway_listener.id
  admin_state_up = true
}

# Gateway members для Load Balancer
resource "openstack_lb_member_v2" "gateway1_member" {
  pool_id        = openstack_lb_pool_v2.gateway_pool.id
  address        = openstack_networking_port_v2.dynamic_ports["gateway1"].all_fixed_ips[0]
  protocol_port  = 8080
  subnet_id      = openstack_networking_subnet_v2.subnet.id
  admin_state_up = true

  depends_on = [
    openstack_compute_instance_v2.dynamic_vms["gateway1"],
    openstack_networking_port_v2.dynamic_ports["gateway1"]
  ]
}

resource "openstack_lb_member_v2" "gateway2_member" {
  pool_id        = openstack_lb_pool_v2.gateway_pool.id
  address        = openstack_networking_port_v2.dynamic_ports["gateway2"].all_fixed_ips[0]
  protocol_port  = 8080
  subnet_id      = openstack_networking_subnet_v2.subnet.id
  admin_state_up = true

  depends_on = [
    openstack_compute_instance_v2.dynamic_vms["gateway2"],
    openstack_networking_port_v2.dynamic_ports["gateway2"]
  ]
}

# Health monitor for Load Balancer
resource "openstack_lb_monitor_v2" "gateway_monitor" {
  pool_id        = openstack_lb_pool_v2.gateway_pool.id
  type           = "HTTP"
  delay          = 50
  timeout        = 15
  max_retries    = 8
  url_path       = "/actuator/health"
  http_method    = "GET"
  expected_codes = "200"
  admin_state_up = true
}

# Associate floating IP with Load Balancer
resource "openstack_networking_floatingip_associate_v2" "gateway_lb_fip_associate" {
  floating_ip = openstack_networking_floatingip_v2.gateway_lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.gateway_lb.vip_port_id
}

# Создание Floating IP для Eureka
resource "openstack_networking_floatingip_v2" "eureka_fip" {
  pool = local.floating_net
}

# Правильная привязка Floating IP к порту Eureka
resource "openstack_networking_floatingip_associate_v2" "eureka_fip_associate" {
  floating_ip = openstack_networking_floatingip_v2.eureka_fip.address
  port_id     = openstack_networking_port_v2.static_ports["eureka"].id
}

output "eureka_public_ip" {
  value       = openstack_networking_floatingip_v2.eureka_fip.address
  description = "Public IP address for connecting to the Eureka"
}

# Outputs
output "eureka_ip" {
  value = local.static_instances.eureka.ip
  description = "Static IP address for Eureka service"
}

output "mysql_ip" {
  value = local.static_instances.mysql.ip
  description = "Static IP address for MySQL database"
}

output "gateway_lb_ip" {
  value = openstack_networking_floatingip_v2.gateway_lb_fip.address
  description = "Floating IP address for gateway load balancer"
}

output "service_ips" {
  value = {
    for name, port in openstack_networking_port_v2.dynamic_ports :
      name => port.all_fixed_ips
  }
  description = "IP addresses for dynamic services"
}
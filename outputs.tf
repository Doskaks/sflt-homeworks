output "vm_external_ips" {
  value = {
    for idx, vm in yandex_compute_instance.web_server :
    vm.name => vm.network_interface[0].nat_ip_address
  }
}

output "load_balancer_ip" {
  value = yandex_lb_network_load_balancer.web_balancer.listener[*].external_address_spec[*].address
}

output "target_group_id" {
  value = yandex_lb_target_group.web_target_group.id
}
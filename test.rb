#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'warthog/a10/rest'

hostname = ENV['HOSTNAME']
username = ENV['USERNAME']
password = ENV['PASSWORD']

server_ip = ENV['SERVER_IP']
deployment_name = ENV['DEPLOYMENT_NAME']

health_monitor_xml_to_json = <<EOF
{
  "name": "8080 web",
  "retry": "3",
  "consec_pass_reqd": "1",
  "interval": "5",
  "time_out": "5",
  "strictly_retry": "0",
  "disable_after_down": "0",
  "override_ipv4": null,
  "override_ipv6": null,
  "override_port": null,
  "type": "http",
  "port": "8080",
  "host": null,
  "url": "GET /",
  "user": null,
  "<hidden credential>": null,
  "expect": {
    "pattern": null,
    "maintenance_code": null
  }
}
EOF

service_group_json = <<EOF
{
  "name": "RJG Sandbox",
  "protocol": 2,
  "lb_method": 0,
  "health_monitor": "8080 web",
  "min_active_member": {
    "status": 0,
    "number": 0,
    "priority_set": 0
  },
  "backup_server_event_log_enable": 0,
  "client_reset": 0,
  "stats_data": 1,
  "extended_stats": 0,
  "member_list": [
    {
      "server": "_s_10.0.0.38",
      "port": 8080,
      "template": "default",
      "priority": 1,
      "status": 1,
      "stats_data": 1
    }
  ]
}
EOF

virtual_server_json = <<EOF
{
  "name": "RJG Sandbox",
  "address": "0.0.0.0",
  "status": 1,
  "vrid": 0,
  "arp_status": 1,
  "stats_data": 1,
  "extended_stats": 0,
  "disable_vserver_on_condition": 0,
  "redistribution_flagged": 0,
  "ha_group": {
    "status": 0,
    "ha_group_id": 0,
    "dynamic_server_weight": 0
  },
  "vip_template": "default",
  "pbslb_template": "",
  "vport_list": [
    {
      "protocol": 2,
      "port": 80,
      "name": "",
      "service_group": "RJG Sandbox",
      "connection_limit": {
        "status": 0,
        "connection_limit": 8000000,
        "connection_limit_action": 0,
        "connection_limit_log": 0
      },
      "default_selection": 1,
      "received_hop": 0,
      "status": 1,
      "stats_data": 1,
      "extended_stats": 0,
      "snat_against_vip": 0,
      "vport_template": "default",
      "vport_acl_id": 0,
      "aflex_list": [

      ],
      "send_reset": 0,
      "ha_connection_mirror": 0,
      "direct_server_return": 0,
      "sync_cookie": {
        "sync_cookie": 0,
        "sack": 0
      },
      "source_nat": "",
      "tcp_template": "",
      "source_ip_persistence_template": "",
      "pbslb_template": "",
      "acl_natpool_binding_list": [

      ]
    }
  ]
}
EOF

# You can do these things;
# https://github.com/ericchou-python/A10_Networks/blob/master/AX_aXAPI_Ref_v2-20121010.pdf

# Service Groups
def service_group_delete(a10, name)
  a10.send(:axapi, 'slb.service_group.delete', 'get', {name: name, format: 'json'})
end

def service_group_getAll(a10)
  a10.send(:axapi, 'slb.service_group.getAll', 'get', {format: 'json'})
end

def service_group_getByName(a10, name)
  a10.send(:axapi, 'slb.service_group.getByName', 'get', {name: name, format: 'json'})
end

def service_group_create(a10, options={})
  options.merge!({format: 'json'})
  a10.send(:axapi, 'slb.service_group.create', 'get', options)
end

def service_group_deleteAllMembers(a10, name)
  a10.send(:axapi, 'slb.service_group.deleteAllMembers', 'get', {name: name, format: 'json'})
end

def service_group_update(a10, options={})
  options.merge!({format: 'json'})
  a10.send(:axapi, 'slb.service_group.update', 'get', options)
end

# VIPs
def vip_getAll(a10)
  a10.send(:axapi, 'slb.virtual_server.getAll', 'get', {format: 'json'})
end

def vip_create(a10, options={})
  options.merge!({format: 'json'})
  a10.send(:axapi, 'slb.virtual_server.create', 'get', options)
end

def vip_delete(a10, name, address)
  a10.send(:axapi, 'slb.virtual_server.delete', 'get', {name: name, address: address, format: 'json'})
end

def vip_update(a10, options={})
  options.merge!({format: 'json'})
  a10.send(:axapi, 'slb.virtual_server.update', 'get', options)
end

# Health Monitors

def hm_getAll(a10)
  a10.send(:axapi, 'slb.hm.getAll', 'get')
end

a10 = Warthog::A10::AXDevice.new(hostname,username,password)

a10.class.ssl_version :TLSv1
a10.class.default_options.update(verify: false)

sg_list = JSON.parse(service_group_getAll(a10).body)
puts JSON.pretty_generate(sg_list)
our_sg = sg_list['service_group_list'].select {|g| g['name'] == deployment_name}
#our_sg = sg_list.xpath("//service_group[name='#{deployment_name}']")
unless our_sg.size > 0
  response = service_group_create(a10, {protocol: 2, name: deployment_name})
  create_body = response.body
  puts "Create SG response looks like #{create_body}"
end

vip_list = JSON.parse(vip_getAll(a10).body)
puts JSON.pretty_generate(vip_list)
our_vip = vip_list['virtual_server_list'].select {|s| s['name'] == deployment_name}
#our_vip = vip_list.xpath("//virtual_server[name='#{deployment_name}']")
unless our_vip.size > 0
  response = vip_create(a10, {name: deployment_name, address: '10.0.0.129', status: 1, service_group: deployment_name})
  create_body = response.body
  puts "Create VIP response looks like #{create_body}"
end

hm_list = hm_getAll(a10)
puts JSON.pretty_generate(hm_list)
our_hm = hm_list['health_monitor_list'].select {|s| s['name'] == deployment_name}

#
# Cookbook Name:: debnetwork
# Provider:: default
#
# Copyright (C) 2014 Nephila Graphic
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


action :enable do
  new_resource.updated_by_last_action(
      setup_firewall(new_resource)
  )
end

action :disable do
  new_resource.updated_by_last_action(
      setup_firewall(new_resource)
  )
end

private

def setup_firewall(new_resource)

  firewall 'ufw' do
    action :nothing
  end


  r = service 'ufw' do
    supports  :status => true, :restart => true, :start => true, :stop => true
    action    :nothing
    notifies  :enable, 'firewall[ufw]'
  end

  # OpenVZ requires some fine tuning for UFW
  is_openvz_ve = node['virtualization']['system'] == 'openvz' && node['virtualization']['role'] == 'guest'

  template '/etc/ufw/before.rules' do
    source      node['debnetwork']['before_rules']['template_source']
    cookbook    node['debnetwork']['before_rules']['template_cookbook']
    mode        00640
    variables(
        :is_openvz_ve => is_openvz_ve,
        :postrouting_rules => new_resource.postrouting_rules,
        :forward_rules => new_resource.forward_rules
    )
    notifies    :restart, 'service[ufw]'
  end

  template '/etc/ufw/before6.rules' do
    source      node['debnetwork']['before6_rules']['template_source']
    cookbook    node['debnetwork']['before6_rules']['template_cookbook']
    mode        00640
    variables(
        :is_openvz_ve => is_openvz_ve,
        :postrouting_rules => new_resource.postrouting6_rules,
        :forward_rules => new_resource.forward6_rules
    )
    notifies    :restart, 'service[ufw]'
  end


  template '/etc/ufw/after.rules' do
    source      node['debnetwork']['after_rules']['template_source']
    cookbook    node['debnetwork']['after_rules']['template_cookbook']
    mode        00640
    variables(
        :is_openvz_ve => is_openvz_ve
    )
    notifies    :restart, 'service[ufw]'
  end

  template '/etc/ufw/after6.rules' do
    source      node['debnetwork']['after6_rules']['template_source']
    cookbook    node['debnetwork']['after6_rules']['template_cookbook']
    mode        00640
    variables(
        :is_openvz_ve => is_openvz_ve
    )
    notifies    :restart, 'service[ufw]'
  end


  send_redirects = Array.new
  redirect_value = case new_resource.send_redirects
                     when :enable
                       1
                     when :disable
                       0
                   end

  Dir["/proc/sys/net/ipv4/conf/*/send_redirects"].each do |interface|
    interface.sub!(/^\/proc\/sys\//, '')
    unless redirect_value.nil?
      send_redirects << "#{interface}=#{redirect_value}"
    end
  end

  template '/etc/ufw/sysctl.conf' do
    source      node['debnetwork']['sysctl_conf']['template_source']
    cookbook    node['debnetwork']['sysctl_conf']['template_cookbook']
    mode        00644
    variables(
        :is_openvz_ve => is_openvz_ve,
        :send_redirects => send_redirects
    )
    notifies    :restart, 'service[ufw]'
  end

  # Disable IPv6 on OpenVZ
  template '/etc/default/ufw' do
    source      node['debnetwork']['default_ufw']['template_source']
    cookbook    node['debnetwork']['default_ufw']['template_cookbook']
    mode        00644
    variables(
        :is_openvz_ve => is_openvz_ve,
        :ipv6_enabled => new_resource.ipv6_enabled
    )
    notifies    :restart, 'service[ufw]'
  end

  # Prefer ipv4 in gai.conf since ipv6 is blocked now.
  template '/etc/gai.conf' do
    source      'gai.conf.erb'
    cookbook    'debnetwork'
    variables(
        :ipv4_preferred => new_resource.ipv4_preferred
    )
    mode 00644
  end

  r.updated_by_last_action?
end
Folder Structure
ansible-haproxy-keepalived-final-airgap/
├── group_vars/
├── inventory/
├── playbooks/
├── roles/
├── files/
├── os_packages/ubuntu_22.04/     # will be created
└── pip_packages/ansible/         # you must create & populate
    pip_packages/kubernetes/      # you must create & populate


Prepare Offline Packages
 A. Download .deb files
cd ansible-haproxy-keepalived-final-airgap/playbooks
ansible-playbook download_debs.yml
This creates os_packages/ubuntu_22.04/*.deb locally.

B. Download pip packages (manually)
mkdir -p pip_packages/ansible pip_packages/kubernetes

pip download ansible -d pip_packages/ansible
pip download kubernetes -d pip_packages/kubernetes

3. Upload to Target Machines
Copy .deb files
ansible-playbook -i inventory/hosts.yml playbooks/upload-debs-to-targets.yml

Copy pip packages
ansible-playbook -i inventory/hosts.yml playbooks/upload-pip-packages-to-targets.yml

4. Deploy Services
   HAProxy
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-haproxy.yml

   Keepalived
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-keepalived.yml

5. Validate Installation
   ansible all -i inventory/hosts.yml -m shell -a "systemctl status haproxy || systemctl status keepalived"

6. Test HAProxy Routing
   curl http://192.168.10.200
You should reach one of the backend servers (defined in group_vars/all.yml as 192.168.10.211:80, etc.)

 7. Troubleshooting Tips
    Use journalctl -u haproxy or journalctl -u keepalived on targets.
    Use ip addr to verify VIP presence.
    Ensure backend servers (web1, web2) are up and serving on port 80.


all.yml
haproxy_version: "2.4"
keepalived_version: "2.2"
deb_dir: "/opt/os_packages/ubuntu_22.04"
pip_base_dir: "/opt/pip_packages"
pip_ansible_dir: "{{ pip_base_dir }}/ansible"
pip_kubernetes_dir: "{{ pip_base_dir }}/kubernetes"
haproxy_cfg_src: files/haproxy.cfg
keepalived_interface: "eth0"
keepalived_vip: "192.168.10.200"

backend_servers:
  - ip: 192.168.10.211
    port: 80
  - ip: 192.168.10.212
    port: 80
  deb_dir: /opt/os_packages/ubuntu_22.04   # <--- THIS IS REQUIRED

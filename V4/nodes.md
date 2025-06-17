$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh

ansible-playbook -i inventory/hosts.yml playbooks/setup-prerequisites.yml


HAProxy on Kubernetes (via Helm):

helm install haproxy ./helm/haproxy --namespace haproxy-system --create-namespace

Keepalived on Physical Nodes (via Ansible):
ansible-playbook -i inventory/hosts.yml playbooks/deploy-keepalived.yml


roles/prereqs/tasks/main.yml
- name: Install Helm if not present
  become: yes
  shell: |
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  args:
    creates: /usr/local/bin/helm


****
ansible-playbook -i inventory/hosts.yml playbooks/setup-prerequisites.yml
****

playbooks/setup-prerequisites.yml
- name: Install prerequisites like Helm and kubectl
  hosts: all
  become: yes
  tasks:
    - name: Install required packages
      apt:
        name:
          - curl
          - wget
          - apt-transport-https
          - ca-certificates
          - software-properties-common
        state: present
        update_cache: yes

    - name: Install Helm if not present
      shell: |
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      args:
        creates: /usr/local/bin/helm

    - name: Verify Helm version
      command: helm version
      register: helm_version
      changed_when: false

    - debug:
        msg: "Installed Helm version: {{ helm_version.stdout }}"


Resources Are Not Being Created
check helm actually intalled
helm get manifest haproxy --namespace haproxy-system

Inspect what is running on namespace
kubectl get all -n haproxy-system
kubectl get configmaps -n haproxy-system
If the above returns nothing, Helm may have rendered, but Kubernetes rejected them silently.

kubectl describe deployment -n haproxy-system
kubectl get events -n haproxy-system
Look for errors like "no matches for kind", "invalid fields", etc.

ConfigMap or Volume Errors in Templates
In our HAProxy Helm chart, we use this volume mount:
volumeMounts:
  - name: config
    mountPath: /usr/local/etc/haproxy/haproxy.cfg
    subPath: haproxy.cfg
This must match:
volumes:
  - name: config
    configMap:
      name: {{ include "haproxy.fullname" . }}-config

Suggested Diagnostic Command
helm uninstall haproxy --namespace haproxy-system
helm install haproxy ./helm/haproxy --namespace haproxy-system --create-namespace --debug --dry-run

************************
Uninstall the Helm Release (HAProxy in Kubernetes)
uninstall 
helm uninstall haproxy --namespace haproxy-system

2. Delete the Namespace
kubectl delete namespace haproxy-system

3. Remove Backend Services (if created)
kubectl delete deployment web1 web2 --namespace default
kubectl delete service web1 web2 --namespace default


Helm is designed to deploy applications into Kubernetes clusters only.
ansible-playbook -i inventory/hosts.yml playbooks/deploy-haproxy.yml
ansible-playbook -i inventory/hosts.yml playbooks/deploy-keepalived.yml

Error : role not found
Solution B: Add ansible.cfg to Set Roles Path
In your project root, create a file named ansible.cfg:
[defaults]
roles_path = ./roles
inventory = inventory/hosts.yml
host_key_checking = False
stdout_callback = yaml


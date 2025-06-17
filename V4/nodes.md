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

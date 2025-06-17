HAProxy on Kubernetes (via Helm):

helm install haproxy ./helm/haproxy --namespace haproxy-system --create-namespace

Keepalived on Physical Nodes (via Ansible):
ansible-playbook -i inventory/hosts.yml playbooks/deploy-keepalived.yml

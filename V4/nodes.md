$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh

HAProxy on Kubernetes (via Helm):

helm install haproxy ./helm/haproxy --namespace haproxy-system --create-namespace

Keepalived on Physical Nodes (via Ansible):
ansible-playbook -i inventory/hosts.yml playbooks/deploy-keepalived.yml

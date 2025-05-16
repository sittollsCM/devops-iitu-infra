#1
cd ansible
sudo ansible-playbook -i ./inventory/host/hosts.ini ./playbook.yaml
#2
cd ../terraform
sudo terraform init -upgrade
sudo terraform apply -auto-approve
#3
cd ../
python3 generate_cluster_inventory.py
#4
cd ansible
sudo ansible-playbook -i ./inventory/cluster/hosts.ini ./enable_internet.yaml
#5
sudo ansible-playbook -i ./inventory/cluster/hosts.ini ./k8s-installation.yaml
#6
sudo ansible-galaxy install -r requirements.yaml
sudo ansible-playbook -i ./inventory/cluster/hosts.ini ./argo-installation.yaml

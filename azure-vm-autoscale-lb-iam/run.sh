#/bin/bash

terraform apply -auto-approve
terraform show -json | jq . > /tmp/out.json

jq -r '.values.root_module.resources[].values | select(.algorithm=="RSA") | .private_key_pem_pkcs8' /tmp/out.json | awk 'NF' > /tmp/privkey.pem
chmod 400 /tmp/privkey.pem
echo "[webservers]" > /tmp/hosts && jq -r '.values.root_module.resources[].values | select(.ip_address) | .ip_address' /tmp/out.json | awk 'NF' | tr -d "\"" >> /tmp/hosts

cat << EOF >> /tmp/hosts

[webservers:vars]
ansible_ssh_user=ubuntu
ansible_ssh_private_key_file=/tmp/privkey.pem
EOF

ansible-playbook -i /tmp/hosts play.yaml
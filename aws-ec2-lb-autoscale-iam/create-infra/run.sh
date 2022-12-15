#/bin/bash

terraform apply -auto-approve
terraform show -json | jq . > /tmp/out.json
jq -r '.values.root_module.resources[].values | select(.algorithm=="RSA") | .private_key_pem_pkcs8' /tmp/out.json | awk 'NF' > /tmp/privkey.pem
chmod 400 /tmp/privkey.pem
jq -r '.values.root_module.resources[].values | select(.public_ips) | .public_ips | @csv' /tmp/out.json | awk 'NF' | tr -d "\""

echo "[webservers]" > /tmp/hosts && jq -r '.values.root_module.resources[].values | select(.public_ips) | .public_ips | @csv' /tmp/out.json | awk 'NF' | tr -d "\"" >> /tmp/hosts


cat << EOF >> /tmp/hosts

[webservers:vars]
ansible_ssh_user=ec2-user
ansible_ssh_private_key_file=/tmp/privkey.pem
EOF


export ANSIBLE_HOST_KEY_CHECKING=False
ansible -i /tmp/hosts webservers -m ping

ansible-playbook play.yaml -i /tmp/hosts
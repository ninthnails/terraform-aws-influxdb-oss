#!/bin/bash
/bin/aws --region "${region}" s3 cp --no-progress "${setup_dist}" /root/setup.zip
/bin/unzip -oq /root/setup.zip -d /root
/bin/amazon-linux-extras install -y ansible2
export ANSIBLE_PYTHON_INTERPRETER=$(/bin/command -v python2.7)
/bin/ansible-playbook -c local -i 127.0.0.1, /root/setup.yml \
-e "admin_username=${admin_username}" \
-e "admin_password=${admin_password}" \
-e "aws_region=${region}" \
-e "storage_type=${storage_type}" \
-e "flux_enabled=${flux_enabled}"

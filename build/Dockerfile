FROM quay.io/operator-framework/ansible-operator:v0.16.0

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY collections/ ${HOME}/.ansible/collections/

RUN cp /etc/ansible/ansible.cfg ${HOME}/ansible-profiler.cfg && echo "callback_whitelist = profile_tasks" >> ${HOME}/ansible-profiler.cfg

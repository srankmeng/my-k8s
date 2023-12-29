#!/bin/bash

echo "===== Copy key from host ====="

vagrant scp .vagrant/machines/$2/virtualbox/private_key $1:ssh_key


#!/bin/bash

# Configuration - this should match the values in the ansible virtualenv role
VIRTUALENV_SCRIPT_VERSION="13.1.2"
VIRTUALENV_SCRIPT_CONTAINER="/opt/virtualenv"

VIRTUALENV_CONTAINER="$HOME/venv"

# Ensure we have ansible build dependencies
sudo apt-get update
sudo apt-get install python-dev -y

# Ensure base directories are present
if [ ! -d $VIRTUALENV_SCRIPT_CONTAINER ]; then
  sudo mkdir -p $VIRTUALENV_SCRIPT_CONTAINER
fi
if [ ! -d $VIRTUALENV_CONTAINER ]; then
  mkdir -p $VIRTUALENV_CONTAINER
fi

# Ensure virtualenv script directory has correct permissions
sudo chown root:root $VIRTUALENV_SCRIPT_CONTAINER
sudo chmod 755 $VIRTUALENV_SCRIPT_CONTAINER

# Ensure virtualenv script is present
if [ -d "$VIRTUALENV_SCRIPT_CONTAINER/virtualenv-$VIRTUALENV_SCRIPT_VERSION" ]; then
  echo "virtualenv $VIRTUALENV_SCRIPT_VERSION seems to be already installed."
else
  sudo sh -c "curl -s https://pypi.python.org/packages/source/v/virtualenv/virtualenv-$VIRTUALENV_SCRIPT_VERSION.tar.gz | tar -C $VIRTUALENV_SCRIPT_CONTAINER -xzv"
fi

# Ensure symlinks exists and is pointing to our virtualenv
if [[ -e $VIRTUALENV_SCRIPT_CONTAINER/current || -h $VIRTUALENV_SCRIPT_CONTAINER/current ]]; then
  sudo rm -rf $VIRTUALENV_SCRIPT_CONTAINER/current
fi
sudo ln -s $VIRTUALENV_SCRIPT_CONTAINER/virtualenv-$VIRTUALENV_SCRIPT_VERSION $VIRTUALENV_SCRIPT_CONTAINER/current
sudo chown root:root $VIRTUALENV_SCRIPT_CONTAINER/current

# Ensure virtualenv wrapper script is present
cat <<EOF | sudo tee /usr/local/bin/virtualenv >> /dev/null
#!/bin/bash

/usr/bin/env python $VIRTUALENV_SCRIPT_CONTAINER/current/virtualenv.py \$@
"\$@"/bin/pip install pip --upgrade
EOF

# Ensure virtualenv wrapper script has correct permissions
sudo chown root:root /usr/local/bin/virtualenv
sudo chmod 755 /usr/local/bin/virtualenv

# Ensure python virtual environment with ansible exists
if [ ! -d $VIRTUALENV_CONTAINER/ansible ]; then
  /usr/local/bin/virtualenv $VIRTUALENV_CONTAINER/ansible
  $VIRTUALENV_CONTAINER/ansible/bin/pip install ansible
fi

# ---
# These tasks are not mandatory anymore:

# Ensure we have $HOME/.bash_profile
if [ ! -e $HOME/.bash_profile ]; then
  touch $HOME/.bash_profile
fi
# Ensure path is set correctly
grep -q -F 'export PATH=$HOME/bin:$PATH' $HOME/.bash_profile || echo 'export PATH=$HOME/bin:$PATH' >> $HOME/.bash_profile

# Ensure bin dir is present
if [ ! -d $HOME/bin ]; then
  mkdir $HOME/bin
fi

# Run ansible to provision the machine
cd /vagrant && $VIRTUALENV_CONTAINER/ansible/bin/ansible-playbook admin/ansible/playbook.yml -i admin/ansible/inventory.vagrant

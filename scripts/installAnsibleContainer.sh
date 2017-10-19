set -x
source /opt/rh/python27/enable
if [ ! -d ~/envs ]
then
 mkdir ~/envs
fi
if [ ! -d ~/envs/default ]
then
  virtualenv ~/envs/default
fi
source ~/envs/default/bin/activate
type -t ansible-container
if [ $? != 0 ]
then
  pip install ansible-container[docker]
fi
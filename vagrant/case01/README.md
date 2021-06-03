Vagrant Laboratory

Vagrant Laboratory was created for studies with Docker Swarm.

BASIC COMMANDS

$ vagrant ssh => SSH into virtual machine.

$ vagrant up => Start virtual machine.

$ vagrant reload => restarts vagrant machine, loads new Vagrantfile configuration

$ vagrant status => Outputs status of the vagrant machine

$ vagrant destroy => Stops and deletes all traces of the vagrant machine

$ vagrant destroy -f => Same as above, without confirmation

$ vagrant resume => Resume a suspended machine (vagrant up works just fine for this as well)

$ vagrant halt => Stops the vagrant machine

$ vagrant suspend => Suspends a virtual machine (remembers state)
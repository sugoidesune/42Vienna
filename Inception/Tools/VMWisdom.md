# START
VBoxManage startvm "Your_VM_Name" --type headless
# CLOSE (SAVE STATE)
VBoxManage controlvm "Your_VM_Name" savestate
# SHUTDOWN (ACPI)
VBoxManage controlvm "Your_VM_Name" acpipowerbutton
# POWER OFF
VBoxManage controlvm "Your_VM_Name" poweroff




# PORTS
VBoxManage modifyvm "Your_VM_Name" --natpf1 "rule_name,tcp,host_ip,host_port,guest_ip,guest_port"
# PORT SSH
VBoxManage modifyvm "Your_VM_Name" --natpf1 "ssh-rule,tcp,,2222,,22"
# PORT WEB
VBoxManage modifyvm "Your_VM_Name" --natpf1 "web-rule,tcp,,8080,,80"
# PORT DELETE
VBoxManage modifyvm "Your_VM_Name" --natpf1 delete "rule_name"




# NAUTILUS REMOTE VIEWING (Ctr + l)
sftp://tbatis@localhost:2222



# SSHF MOUNT
sshfs -p 2222 tbatis@localhost:/ ~/core/incepted_vm

# SSHF MOUNT WITH RECONNECT
sshfs -p 2222 tbatis@localhost: ~/core/incepted_vm -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3

# SSH UNMOUNT
fusermount3 -u ~/core/incepted_vm

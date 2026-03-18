#!/bin/bash
name=alma
cores=4
memory=4096
size=20000

bridge=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth|wlan)' | head -1)

vm_folder="/home/$USER/VirtualBox VMs/$name"
if [ -z "$1" ]; then
echo "Please enter path to ISO file as argument!"
exit 1
fi
iso=$1
mkdir "$vm_folder"


LABEL=$(isoinfo -d -i "$iso" | grep -i "volume id" | cut -d: -f2 | tr -d ' ' | tr -d '\n')
cat > ~/ks.cfg << 'EOF'
text
eula --agreed
firstboot --disable
reboot
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts='us'
timezone UTC --utc
network --bootproto=dhcp --device=link --activate



rootpw --plaintext rootpass
user --name=admin --password=1111 --plaintext --groups=wheel --shell=/bin/bash



clearpart --all --initlabel --drives=sda
autopart --type=lvm
bootloader --location=mbr --boot-drive=sda
ignoredisk --only-use=sda
url --mirrorlist="https://mirrors.almalinux.org/mirrorlist/10/baseos"
%packages
@^minimal-environment
openssh-server
%end
%post
systemctl enable sshd
systemctl start sshd
%end
EOF

cd ~
mkdir work
cd work
mkdir {original,extract,new-iso}
sudo mount -o loop "$iso" ./original
sudo cp -rT ./original/ ./extract/
sudo umount ./original

cp ~/ks.cfg ./extract/ks.cfg
sudo sed -i 's/linuxefi \(.*\) quiet/linuxefi \1 inst.ks=cdrom:\/ks.cfg quiet/g' ./extract/EFI/BOOT/grub.cfg
sudo sed -i 's/set timeout=.*/set timeout=3/g' ./extract/EFI/BOOT/grub.cfg
sudo sed -i 's/set default=.*/set default="0"/g' ./extract/EFI/BOOT/grub.cfg

sudo xorriso -as mkisofs \
  -D -r -V "$LABEL" \
  -J -l \
  -e images/efiboot.img \
  -no-emul-boot \
  -o ~/result.iso \
  ./extract/

cd ~
sudo rm -rf ~/work
iso=~/result.iso

if
! vboxmanage createvm --name "$name"  --ostype RedHat10_64 --register; then
echo ERROR: FAILED TO CREATE "$name" 
exit 1
fi

if
! vboxmanage modifyvm "$name"  --cpus "$cores" --memory "$memory" --audio-driver none --usb off --acpi on --boot1 dvd --nic1 bridged --bridgeadapter1 "$bridge"; then
echo ERROR: FAILED TO CONFIGURE "$name" 
vboxmanage unregistervm "$name" --delete 2>/dev/null
exit 1
fi

if
! vboxmanage createhd --filename "$vm_folder"/"$name".vdi -size "$size"; then
echo ERROR: FAILED TO CREATE HDD "$name" 
vboxmanage unregistervm "$name" --delete 2>/dev/null
exit 1
fi

if
! vboxmanage storagectl "$name" --name ide-controller --add ide; then
echo ERROR: FAILED TO ADD CONTROLLER FOR "$name" 
vboxmanage unregistervm "$name" --delete 2>/dev/null
exit 1
fi

if
! vboxmanage storageattach "$name" --storagectl ide-controller --port 0 --device 0 --type hdd --medium "$vm_folder"/"$name".vdi; then
echo ERROR: FAILED TO ATTACH HD FOR "$name" 
vboxmanage unregistervm "$name" --delete 2>/dev/null
exit 1
fi

if
! vboxmanage storageattach "$name" --storagectl ide-controller --port 1 --device 0 --type dvddrive --medium "$iso"; then
echo ERROR: FAILED TO ATTACH HD FOR "$name" 
vboxmanage unregistervm "$name" --delete 2>/dev/null
exit 1
fi

vboxmanage modifyvm "$name" --firmware efi

vboxmanage startvm "$name"





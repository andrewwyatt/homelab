install

rootpw --iscrypted {PUT ROOT HASH HERE}

firewall --disabled
selinux --disabled
authconfig --enableshadow
timezone --utc America/New_York
bootloader --location=mbr


zerombr
clearpart --all
part /boot --asprimary --fstype ext4 --ondisk=/dev/sda --size=300
part pv.3 --asprimary --size=100 --ondisk=/dev/sda --grow
volgroup sysvg --pesize=32768 pv.3


logvol / --fstype ext4 --name=lv_root --vgname=sysvg --size=5000
logvol /var --fstype ext4 --name=lv_var --vgname=sysvg --size=5000 --fsoptions=defaults
logvol /home --fstype ext4 --name=lv_home --vgname=sysvg --size=2000 --fsoptions=defaults
logvol /tmp --fstype ext4 --name=lv_tmp --vgname=sysvg --size=3000 --fsoptions=defaults
logvol swap --fstype swap --name=lv_swap --vgname=sysvg --size=4000


firstboot --disable
keyboard us
lang en_US

%pre
%end

%packages --nobase
@core
%end


%post
%end

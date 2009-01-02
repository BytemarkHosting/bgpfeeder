# Debian packages needed to run tests in the qemu test environment
#
TEST_PACKAGES = %w( ruby1.8 rake qemu tftp-hpa telnet bridge-utils vlan
  iptables iproute quagga )

# kernel modules needed to run tests in the qemu test environment
#
TEST_MODULES = %w( tun 8021q )

# Amount of memory to give to the test environment (megabytes)
#
TEST_MEMORY_SIZE = 128

$kver = `uname -r`.chomp

def xsys(*c)
  raise unless system(c.join(" "))
end

def write_file(filename, contents)
  File.open(filename, "w") do |fh|
    fh.print(contents.gsub(/^\s*/,""))
  end
end

def start_qemu(init, snapshot=true)
  cmd = "qemu -kernel /boot/vmlinuz-#{$kver} -initrd /boot/initrd.img-#{$kver} "+
    "-hda debian_test_img -tftp . "+
    "-append \"root=/dev/sda console=ttyS0 init=/#{init} quiet\" "+
    "-nographic -no-reboot "+
    "-m #{TEST_MEMORY_SIZE} "+
    "-redir tcp:1179::179"
  cmd += " -snapshot" if snapshot
  xsys(cmd)
end

$: << 'lib'

namespace :test do

  desc "Run all tests that will run as an unprivileged user"
  task :run_user do
    require 'rake/runtest'
    Rake.run_tests 'test/u_*.rb'
  end
  desc "Run all tests that run as root"
  task :run_root do
    require 'rake/runtest'
    Rake.run_tests 'test/r_*.rb'
  end
  desc "Run all tests (requires root access)"
  task :run_all => [:run_user, :run_root]
  
  desc "Run all tests inside a virtual machine (no root access needed)"
  task :qemu_run_all => [:syntax, :build_debian_test_img] do
    start_qemu("/startup_test", true)
  end
  
  desc "Start shell in test VM (reboot to quit)"
  task :qemu_shell => [:build_debian_test_img] do
    start_qemu("/startup_shell", true)
  end

  desc "Build debootstrap.tar file as pre-requisite for test virtual machine image"
  task :build_debootstrap do
    if !File.exists?("debootstrap.tar")
      print "Running debootstrap - this may take 15-30 minutes\n"
      Dir.mkdir("debootstrap.tmp")
      begin
        xsys "debootstrap lenny debootstrap.tmp"
        xsys "tar cf debootstrap.tar -C debootstrap.tmp ."
      ensure
        xsys "rm -rf debootstrap.tmp"
      end
    end
  end
  
  desc "Build the image needed for running tests in a virtual machine"
  task :build_debian_test_img => :build_debootstrap do
    
    if !File.exists?("debian_test_img")
      print "Preparing test image - this may take 15-30 minutes\n"
      dir = "debian_test"+".#{$$}"
      File.open("debian_test_img", "w") { |f| f.seek(2 << 30 - 1); f.write("\0") }
      xsys "mkfs.ext3 -q -F debian_test_img"
      Dir.mkdir(dir)
      xsys "mount -o loop debian_test_img #{dir}"
      begin
        xsys "tar xf debootstrap.tar -C #{dir}"
        xsys "cp -a /lib/modules/#{$kver} #{dir}/lib/modules/#{$kver}"
        
        write_file("#{dir}/startup_common", <<-FILE)
          #!/bin/sh
          
          PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin
          mount -n /dev/sda / -o rw,remount
          #{TEST_MODULES.map { |m| "modprobe #{m}\n" }.join}
          ifconfig lo 127.0.0.1/8 up
          dhclient -q eth0
          mkdir -p /test
        FILE
        
        write_file("#{dir}/startup_first", <<-FILE)
          #!/bin/sh
          . /startup_common
          
          DEBIAN_FRONTEND=noninteractive apt-get install --force-yes -y \
            #{TEST_PACKAGES.join(" ")}
          shutdown -r -n now
        FILE
        
        write_file("#{dir}/startup_shell", <<-FILE)
          #!/bin/sh
          . /startup_common
          cd test
          echo "* System is mounted r/w - please leave no footprints, or remember to *"
          echo "* remove debian_test_img when you are finished.                      *"
          /bin/bash
          shutdown -r -n now
        FILE
        
        write_file("#{dir}/startup_test", <<-FILE)
          #!/bin/sh
          . /startup_common
          
          cd test
          tftp  -m binary 10.0.2.2 -c get /bvm.tar
          tar xf bvm.tar
          echo test ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
          rake test:run_all
          echo test "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
          shutdown -r -n now
        FILE
        
        write_file("#{dir}/etc/quagga/bgpd.conf", <<-FILE)
          log stdout debugging
          
          router bgp 65534
           neighbor 10.0.2.2 remote-as 65534
        FILE
        
        File.chmod(0755, "#{dir}/startup_test", "#{dir}/startup_first", "#{dir}/startup_shell")
      ensure
        xsys "umount #{dir}"
        Dir.rmdir(dir)
      end
      
      start_qemu("/startup_first", false)
    end
  end
end

# Use

This is a bare-bones Vivado project for the Red-Pitaya/STEMlab boards.  It is meant to be a starting point for custom designs with the Red Pitaya.  HDL code is written in VHDL, and it includes modules for reading from the ADCs and writing to the DACs as well as a simplified interface for reading/writing to the device via the AXI interface.

Included in the software directory is some Python code that can be run from the command line on the Red Pitaya which will start a simple TCP/IP socket server that can be used to send and receive data from a remote computer.  See the "set up" section for getting things working.

Once the Python server is running, the suite of MATLAB classes can be used to send and receive data.  Create an instance of
```
dev = DeviceControl(ip_addr);
```
where `ip_addr` is the IP address of the Red Pitaya.  You can then fetch data using `dev.fetch` and upload data using `dev.upload`.  Refer to the code to see how this works.

DAC outputs can be written using `dev.dac(<index>).set(<value>).write` where `<index>` is either 1 or 2 and `<value>` is a value in volts between -1 V and 1 V. 

For testing purposes, a block memory element with 256 address spaces and a write/read depth of 32 has been included to show how to write to and read from a memory element.  The C program 'testMemory.c' can be used for this purpose. Copy it to the Red Pitaya, compile it using the command 'gcc -o testMemory testMemory.c', and then run it using './testMemory 10' to write to and then read from 10 addresses in sequence.  You can replace '10' with any integer up to 255.


# Creating the project

When creating the project, make sure to use the correct Vivado version.  The Git version v2020.2 works for Vivado 2020.2, while the version v2023.1 works for Vivado 2023.1.  The TCL script used to create the Vivado projects are unfortunately not interchangeable.

To create the project, clone the repository to a directory on your computer, open Vivado, navigate to the fpga/ directory (use `pwd` in the TCL console to determine your current directory and `cd` to navigate, just like in Bash), and then run `source make-project.tcl` which will create the project files under the directory `basic-project`.  If you want a different file name, open the `make-project.tcl` file and edit the line under the comment `# Set the project name`.  This should create the project with no errors.  It may not correctly assign the AXI addresses, so you will need to open the address editor and assign the `PS7/AXI_Parse_0/s_axi` interface the address range `0x4000_000` to `0x7fff_ffff`.

# Set up

## Starting the Red Pitaya

Connect the Red Pitaya (RP) to power via the USB connector labelled PWR (on the underside of the board), and connect the device to the local network using an ethernet cable.  Log into the device using SSH with the user name `root` and password `root` using the hostname `rp-{MAC}.local` where `{MAC}` is the last 6 characters in the device's MAC address - this will be printed on the ethernet connector of the device.

### First use

Copy over the files in the 'software/' directory ending in '.py', the file 'get_ip.sh', and the file 'saveScanData.c' using either `scp` (from a terminal on your computer) or your favourite GUI (I recommend WinSCP for Windows).  You will also need to copy over the file 'fpga/system_wrapper.bit' which is the device configuration file.  If using `scp` from the command line, navigate to the main project directory on your computer and use
```
scp fpga/system_wrapper.bit software/*.py software/get_ip.sh software/*.c root@rp-{MAC}.local:/root/
```
and give your password as necessary.  You can move these files to a different directory on the RP after they have been copied.

Next, change the execution privileges of `get_ip.sh` using `chmod a+x get_ip.sh`.  Check that running `./get_ip.sh` produces a single IP address (you may need to install dos2unix using `apt install dos2unix` and then run `dos2unix get_ip.sh` to make it work).  If it doesn't, run the command `ip addr` and look for an IP address that isn't `127.0.0.1` (which is the local loopback address).  There may be more than one IP address -- you're looking for one that has tags 'global' and 'dynamic'.  Here is the output from one such device:
```
root@rp-f0919a:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:26:32:f0:91:9a brd ff:ff:ff:ff:ff:ff
    inet 169.254.176.82/16 brd 169.254.255.255 scope link eth0
       valid_lft forever preferred_lft forever
    inet 192.168.1.109/24 brd 192.168.1.255 scope global dynamic eth0
       valid_lft 77723sec preferred_lft 77723sec
3: sit0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1
    link/sit 0.0.0.0 brd 0.0.0.0
```
In this case the one we want is the address `192.168.1.109`.  In this case, `get_ip.sh` will work because it looks for an IP address starting with `192.168`.  If your IP address starts with something else, you will need to edit the `get_ip.sh` file and change the numbers to reflect your particular network.

Finally, compile the C programs `fetchRAM.c` and `fetchFIFO.c` using `gcc -o fetchRAM fetchRAM.c` and `gcc -o fetchFIFO fetchFIFO.c`.  These will automatically be executable.

### After a reboot or power-on

You will need to re-configure the FPGA and start the Python socket server after a reboot.  To re-configure the FPGA run the command
```
cat system_wrapper.bit > /dev/xdevcfg
```

To start the Python socket server run
```
python3 appserver.py &
```
This should print a line telling you the job number and process ID  as, for example, `[1] 5760`, and a line telling you that it is 'Listening on' and then an address and port number.  The program will not block the command line and will run in the background as long as the SSH session is active (The ampersand & at the end tells the shell to run the program in the background).  To stop the server, run the command `fg 1` where `1` is the job number and then hit 'CTRL-C' to send a keyboard interrupt.

### After starting/restarting the SSH session

You will need to check that the socket server is running.  Run the command
```
ps -ef | grep appserver.py
```
This will print out a list of processes that match the pattern `appserver.py`.  One of these might be the `grep` process itself -- not especially useful -- but one might be the socket server.  Here's an example output:
```
root      5768  5738  7 00:59 pts/0    00:00:00 python3 appserver.py
root      5775  5738  0 01:00 pts/0    00:00:00 grep --color=auto appserver.py
```
The first entry is the actual socket server process and the second one is the `grep` process.  If you need to stop the server, and it is not in the jobs list (run using `jobs`), then you can kill the process using `kill -15 5768` where `5768` is the process ID of the process (the first number in the entry above).  

If you want the server to run you don't need to do anything.  If the server is not running, start it using `python3 appserver.py`.  
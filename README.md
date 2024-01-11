# IQ Modulator Bias Control

This project implements a digital bias controller for an IQ modulator running in carrier-suppressed single-sideband (CS-SSB) mode.  It is based on [this paper](http://opg.optica.org/ao/abstract.cfm?uri=ao-62-1-1) which detailed an analog stabilisation scheme using the same technique.  The basic idea is to add a low frequency signal to the main, high frequency signal used for CS-SSB and use the low frequency signal to measure the phase biases in the different Mach-Zehnder interferometers (MZIs) that make up the IQ modulator.  Whereas the original work used purely analog techniques, this project levarages the fast analog input/output capabilities of the Red Pitaya STEMlab 125-14 platform.  

# Software set up

  1. Clone both this repository and the interface repository at [https://github.com/atomlaser-lab/red-pitaya-interface](https://github.com/atomlaser-lab/red-pitaya-interface) to your computer.  

  2. Connect the Red Pitaya (RP) board to an appropriate USB power source (minimum 2 W), and then connect it to the local network using an ethernet cable.  Using SSH (via terminal on Linux/Mac or something like PuTTY on Windows), log into the RP using the hostname `rp-{MAC}.local` where `{MAC}` is the last 6 characters of the RP's MAC address, which is written on the ethernet connector.  Your network may assign its own domain, so `.local` might not be the correct choice.  The default user name and password for RPs is `root`.  Once logged in, create two directories called `iq-bias-control` and `server`.

  3. From this repository, copy over all files in the 'software/' directory ending in '.c' to the `iq-bias-control` directory on the RP using either `scp` (from a terminal on your computer) or using your favourite GUI (I recommend WinSCP for Windows).  Also copy over the file `fpga/iq-bias-control.bit` to the `iq-bias-control` directory.  From the interface repository, copy over all files ending in '.py' and the file 'get_ip.sh' to the `server` directory on the RP.

  4. On the RP and in the `iq-bias-control` directory, compile the C programs.  Compile `saveData.c` using `gcc -o saveData saveData.c` and compile `fetchRAM.c` using `gcc -o fetchRAM fetchRAM.c`.  You may also want to compile the `analyze_biases.c` file using `gcc -o analyze_biases analyze_biases.c -lm`.  

  5. In the `server` directory, change the privileges of `get_ip.sh` using `chmod a+x get_up.sh`.  Check that running `./get_ip.sh` produces a single IP address (you may need to install dos2unix using `apt install dos2unix` and then run `dos2unix get_ip.sh` to make it work).  If it doesn't, run the command `ip addr` and look for an IP address that isn't `127.0.0.1` (which is the local loopback address).  There may be more than one IP address -- you're looking for one that has tags 'global' and 'dynamic'.  Here is the output from one such device:
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
   The IP address we want here is the address `192.168.1.109` as it is labelled with the `global` tag, which is what `get_ip.sh` looks for.  If you have your RP connected directly to your computer it will not work and you will have to specify the IP address manually.

   6. Upload the bitstream to the FPGA by navigating to the `iq-bias-control` directory and running `cat iq-bias-control.bit > /dev/xdevcfg`.

   7. Start the Python server by running `python3 /root/server/appserver.py`.  If you need to specify your IP address run instead `python3 /root/server/appserver.py <ip address>`.  The script will print the IP address it is using on the command line.

   8. On your computer in MATLAB, add the interface repository directory to your MATLAB path.

   9. Navigate to this repository's software directory, and create a new control object using `d = DeviceControl(<ip address>)` where `<ip address>` is the IP address of the RP.  If the FPGA has just been reconfigured, set the default values using `d.setDefaults` and upload them using `d.upload`.

   10. You can control the device using the command line, but you can also use a GUI to do so.  Start the GUI by running the command `IQ_Bias_Control_GUI(d)`.  This will start up the GUI.  You can also run `IQ_Bias_Control_GUI(<ip address>)` if you don't have the `DeviceControl` object in your workspace.

# Hardware set up

Connect the OUT1 and OUT2 signals to the I and Q modulation ports (order doesn't matter) on the IQ modulator.  Make sure that the output voltages/powers are within the specified tolerances of the device.  The OUT1 and OUT2 signals are already 90 degrees out of phase, so they don't need to go through a 90 degree hybrid.  Measure the output laser power using a photodiode of sufficient bandwidth, amplify as necessary, and connect to the IN1 connector.  On the LV setting the IN1 input can only measure +/-1 V.  

Connect the slow analog outputs 0-2 to the IQ modulator's DC biases.  You may need to amplify these signals (maximum output is 1.6 V) to get the right voltage range.  The slow analog outputs are pulse width modulation (PWM) outputs with a 250 MHz clock and 8 bits of resolution, so the PWM frequency is about 1 MHz.  You will likely want additional filtering on the outputs for driving the DC biases.

# Using the GUI

The GUI is best way to control the device.  There are three categories of device settings plus the application settings.

## Acquisition Settings

The idea behind this technique is to generate a low-frequency modulation signal at a few MHz, inject it into the IQ modulator, measure the laser power using a photodetector, and then demodulate that signal at the modulation frequency in both quadratures, and also to demodulate at twice the modulation frequency.  Demodulation is implemented digitally by multiplying the input signal with a sinusoidally varying signal at the correct frequency but with a demodulation phase (1 and 2), and the result is then filtered using a CIC filter with a rate of $2^N$.  So under acquisition settings, the "Modulation Freq" is the modulation frequency output from the RP, "Demod Phase 1" and "Demod Phase 2" are the demodulation phases at the modulation frequency and its second harmonic, "Log2(CIC Rate)" is $N$, and "Log2 of CIC shift" is an additional digital scaling factor that reduces the output signals by $2^M$ where $M$ is the setting that is given.

## PID 1-3

Not implemented yet.

## Manual Control

The voltage biases DC1, DC2, and DC3 adjust the phases of the three MZIs in the IQ modulator and thus allow for CS-SSB as well as all sorts of other, undesired output modes.  Unfortunately, simply by measuring the optical power it is fundamentally impossible to determine what frequency is on the output of the IQ modulator, as all single-frequency operation generates a steady DC value on the photodiode.  The manual control allows the user to get close to CS-SSB operation, and then the PID controllers will ideally keep it in that mode.

DC1, DC2, and DC3 are output voltages from 0 to 1 V that should be connected to the appropriate pins on the IQ modulator.  These values can be changed using the sliders or spinners.  If using the arrows on the spinners, the DC increment can be changed to allow for coarser or finer changes.  Note that the minimum DC increment is 0.0063 V.

## Application Settings

`Upload` uploads all displayed settings to the RP.  `Fetch` grabs the values off of the RP and updates the display.  `Fetch Data` grabs `Acquisition Samples` number of samples after demodulation and displays that on the plot.  Change the display limits using `YLim1`.  

`Auto-Update` uploads the device configuration anytime a parameter is changed.

`Auto-Fetch Data` continuously uploads parameters and fetches demodulated data and displays it on the plot.  The update time is given in `Plot Update Time` in milliseconds.  You can change the parameters as it grabs data in order to optimise the bias values.


# Creating the project

When creating the project, use Vivado 2023.2.

To create the project, clone the repository to a directory on your computer, open Vivado, navigate to the fpga/ directory (use `pwd` in the TCL console to determine your current directory and `cd` to navigate, just like in Bash), and then run `source make-project.tcl` which will create the project files under the directory `basic-project`.  If you want a different file name, open the `make-project.tcl` file and edit the line under the comment `# Set the project name`.  This should create the project with no errors.  It may not correctly assign the AXI addresses, so you will need to open the address editor and assign the `PS7/AXI_Parse_0/s_axi` interface the address range `0x4000_000` to `0x7fff_ffff`.

# TODO
Re-write software to use a PID controller module to simplify handling.

Change read and write software to automatically determine what registers to write?

Add diagnostic outputs to VHDL to see the value computed by the actuator and the output value.

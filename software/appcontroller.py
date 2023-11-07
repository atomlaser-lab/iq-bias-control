# from bitstring import BitArray
# import serial
import time
import types
import subprocess
import warnings

MEM_ADDR = 0x40000000

def write(data,header):
    if ("debug" in header) and (header["debug"]):
        response = {"err":False,"errMsg":"Message received","data":[]}
        return response
        
    data_o = []
    if header["mode"] == "write":
        for i in range(0,len(data),2):
            addr = MEM_ADDR + data[i]
            cmd = ['monitor',format(addr),'0x' + '{:0>8x}'.format(data[i+1])]
            if ("print" in header) and (header["print"]):
                print("Command: ",cmd)
            result = subprocess.run(cmd,stdout=subprocess.PIPE)
            if result.returncode != 0:
                break
            else:
                data_o.append(result.stdout.decode('ascii').rstrip())

    elif header["mode"] == "read":
        for i in range(0,len(data)):
            addr = MEM_ADDR + data[i]
            cmd = ['monitor',format(addr)]
            if ("print" in header) and (header["print"]):
                print("Command: ",cmd)
            result = subprocess.run(cmd,stdout=subprocess.PIPE)
            if result.returncode != 0:
                break
            else:
                data_o.append(result.stdout.decode('ascii').rstrip())

    elif header["mode"] == "get scan data":
        if header["reset"]:
            cmd = ['./saveScanData','-rn',format(header["numSamples"])]
        else:
            cmd = ['./saveScanData','-n',format(header["numSamples"])]

        if ("print" in header) and (header["print"]):
            print("Command: ",cmd)
        result = subprocess.run(cmd,stdout=subprocess.PIPE)

        if result.returncode == 0:
            data_o = result.stdout.decode('ascii').rstrip().split("\n")
    
    
    if result.returncode != 0:
        response = {"err":True,"errMsg":"Bus error","data":[]}
    else:
        response = {"err":False,"errMsg":""}
        if len(result.stdout) > 0:
            response["data"] = data_o
        else:
            response["data"] = []

    return response
        
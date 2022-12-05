#We made use of some existing python code made for the Phone pi app
#The phone pi app uses flask sockets library and can be found on git via the link in the next comment
# https://github.com/priyankark/PhonePi_SampleServer/blob/master/PhonePi.py
#We made some edits to this code 
from flask import Flask 
from flask_sockets import Sockets
import math
import struct


app = Flask(__name__) 
sockets = Sockets(app)
fifo=open("fifo",'wb')

@sockets.route('/accelerometer')  #here we just add the name of our file 
def echo_socket(ws):
	while True:
		message = ws.receive()
		words = message.split(",")#here we split the message received from the accelerometer 
		result = calculate(words)#here we call a method we created to calculate the angle of the maze
		print(result)
		writePipe(result)#We also make use of a pipe which send the python code to a C process
		ws.send(message)
	fifo.close()

	
	#this gives x y z accelerometer values
def calculate(words):
	x,y,z = float(words[0]), float(words[1]), float(words[2])#accelerometer values
	xInt,yInt,zInt = int(x),int(y),int(z)
	res =xInt,yInt,zInt
	return res


@app.route('/') 
def hello(): 
	return 'Hello World!'

	
def writePipe(result):#writing end of pipe stdout
	fifo.write(struct.pack("fff",result[0],result[1],result[2]))
	fifo.flush()

	#error handling from source
if __name__ == "__main__":
	from gevent import pywsgi
	from geventwebsocket.handler import WebSocketHandler
	server = pywsgi.WSGIServer(('0.0.0.0', 5000), app, handler_class=WebSocketHandler)
	server.serve_forever()


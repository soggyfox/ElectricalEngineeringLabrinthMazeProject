This is the code for project group 7 mod 5 EE/CS, which consists of the following members:

Dion Arflyno Chrisdion Ludjen
Boris Gerretzen
Hidde Hoorweg
Tommy Lin
Kevin Singpurwala
Angela van Sprang

Links to sources i.e. code and data sheets, are found within the code

Bigboi.c handles the i2c from accelerometer, 
spi from the raspberry pi to fpga, 
calculations of the angle between the board, 
which is the current angle given through i2c, and phone, 
which is the desired angle, 
given through phone accelerometer through wifi and python, 
makes a pipe to python, 
where python can then send the accelerometer data to C, 
reading the pipe from python, 
sends this through to fpga

Python.py reads data from wifi from the phone accelerometer and sends it to pipe to bigboi.c. 
To run it you need flask & flask_sockets, and an app on your phone to send accelerometer data i.e. PhonePi. 
This needs to use your ipv4 address and port 5000 i.e. 192.137.144.12:5000.

To run the full application, you need to run Bigboi.c then Phone.py.


Then there are a few tests in folder "Test", these are self-explanatory, 
their names indicate what was tested. 
This mainly tests the connections and interfaces in between different devices.
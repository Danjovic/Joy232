# Joy232
Resident routine for serial print using Joystick port on MSX computers.

This program allows you to send your code listing serially through the joystick port of MSX computers by intercepting the LPRINT instruction from the BASIC interpreter.
The data is bitbanged in accordance with RS232 standard and it is possible to use speeds from 1200 to 19200 bauds.
The program is written in assembly and takes less than 100 bytes

Thought the joystick port uses TTL level the conversion to RS232 levels can be performed using a single transistor circuit.

References:
https://hackaday.io/project/18552-joy232

http://hotbit.blogspot.com.br/2008/01/lprint-na-porta-de-joystick-cdigo-em.html

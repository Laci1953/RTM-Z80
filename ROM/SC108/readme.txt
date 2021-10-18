EEPROM structure

	Offset in EEPROM	Type

1.	0000H			RTM v1 + bootstraper
2.	2880H			RTM v2
3.	3E00H			RTM v3
4.	5A00H			RTM v4
5.	6A00H			Watson

#######################################################################

!!! Merge all .hex into one big .hex in this order:

sc108r1.hex sc108r2.hex sc108r3.hex sc108r4.hex sc108rw.hex

dropping the EOF records ...
until the last EOF record ( :00000001FF ) from sc108rw.hex !!!

#######################################################################

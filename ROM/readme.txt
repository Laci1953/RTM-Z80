EEPROM structure

	Offset in EEPROM	Length		Type

1.	0000H			2800H 		RTM v1 + bootstraper
2.	2800H			1500H		RTM v2
3.	3D00H			1B80H		RTM v3
4.	5880H			0F80H		RTM v4
5.	6800H			1800H		Watson

#######################################################################

!!! Merge all .hex 

( romrtm1.hex romrtm2.hex romrtm3.hex romrtm4.hex watson.hex ),

dropping the EOF records from romrtmN.hex 

and using only the last EOF record ( :00000001FF ) from watson.hex !!!

into one big .hex !!!

#######################################################################

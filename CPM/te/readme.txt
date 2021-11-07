Text editor "te" .COM files (in .HEX format) for SC108 128KB RAM (or compatibles) and 512KB RAM + 512KB ROM memory module

Settings:

128KB - 2048 lines, 50x120 screen, VT100 compatible, with WordStar style keyboard
512KB - 8192 lines, 50x120 screen, VT100 compatible, with WordStar style keyboard

Important constraints

1. For the 512KB version, text files up to 350KB can be edited
2. For the 128KB version, text files up to 70KB can be edited
3. The 128KB version will work only for systems provided with 64MB CF
4. The 128KB version will NOT work with the "classic" RC2014's CP/M, the "large TPA CP/M" must be used (CPM/PutSys/SIO_PutSys_CF64_CPM_DA00H.hex)
5. The 128KB version will work only with SC108 boards provided with a SCM version containing the (undocumented) API function $2B (write A to address DE on Upper 64KB RAM)


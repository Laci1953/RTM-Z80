Text editor "te" .COM files (in .HEX format) for SC108 128KB RAM (or compatibles) and 512KB RAM + 512KB ROM memory module

Settings:

128KB - up to 2048 lines, 50x120 screen, VT100 compatible, with WordStar style keyboard
512KB - up to 8192 lines, 50x120 screen, VT100 compatible, with WordStar style keyboard

Design details and some constraints:

1. For the 512KB version: 

To handle the memory allocation requests, a new memory allocator was written. 

How it works:

The 512KB RAM module uses 32 16KB "virtual" RAM pages, mapped to one of 4 "physical" pages 0000-3FFF, 4000-7FFF, 8000-BFFF and C000-FFFF. Any virtual page can be mapped to any physical page.

The memory physical area from 8000H to BFFFH (let's name-it "work area") is used to load one of the 32 "virtual" 16KB pages from the 512KB RAM, and the memory allocator returns a pointer to the available buffer and a byte containing the index of the 16KB page that contains this buffer (let's name-it "page index"). 

When that buffer needs to be accessed for read/write operations, the 16KB RAM page must be first loaded into the "work area", using a function call with the "page index" as parameter.

Of course, to "free" the allocated buffer, this "page index" must be provided too.

Text files up to 350KB can be edited.

The 521KB version can be run on any CP/M version, regardless of its TPA area size.

2. For the 128KB version: 

To handle the memory allocation requests, a new memory allocator was written. 

How it works:

The 128KB RAM is divided into 2 "virtual" 64KB banks: the lower and the upper bank. A port selects which "virtual" 64KB RAM bank is mapped to the physical 64KB RAM.

In order to execute code that switches from the lower to the upper bank (and back...), that piece of code must be present at the same physical address in both of banks (the so called "shadow code)". It is impossible to store shadow code in the upper bank using only programs resident in RAM, for this only ROM-based code may help; my version of SCM contains an API function ( $2B ) which moves a byte to a given address of the upper RAM bank. This API call is not documented (it cannot be found in the SCM manual), I've found-it by browsing through the SCM source code... 

Therefore, by using this $2B SCM API call, the shadow code can be moved to the upper RAM bank.

But, for the memory allocator, we have also another important constraint: the shadow code must be stored in top of the physical 64KB RAM, in order to offer as much possible RAM available to be allocated (storing at the bottom of the physical 64KB RAM is out of question, we have there the 100H BIOS buffers area). There is only one possible solution: storing a small shadow code on top of CP/M's BIOS. My shadow code is less than 40H. 

Now, studying the "classic" RC2014 CP/M that is currently used with 64/128MB CF's, I discovered that the BIOS "eats" practically all the space to FFFF ! There was no room for my shadow code! 

But, I remembered that I built recently a "custom" CP/M for RC2014 systems that use a 64MB CF. This version of CP/M loads its BDOS at DA00, and has also the advantage of having a small "free" RAM area on top of the BIOS (around 40H ! ). This was a perfect match, I stored there (FFA0 - FFFF) the shadow code. This allows also having (almost) 64KB RAM available to be allocated in the upper RAM bank! 

If the usual call to malloc fails, the new allocator accesses the upper 64KB RAM bank and allocates there the buffer. 

Besides the address of the buffer, a byte containing the RAM bank index is returned too (0=lower 64KB RAM, 1=upper 64KB RAM).

To access a buffer reserved in the upper 64KB RAM bank, special functions must be used to read/write a byte, a word, or a string.
 
Text files up to 70KB can be edited. 

But, this comes with a cost: when opening a file to be edited, the editor reads all the text and store this text in the dynamic memory, and this takes time, because every single byte that has to be moved to the upper RAM bank is not simply moved, as in case of the lower bank, but is passed to the shadow code in order to be stored in the upper RAM bank. Also, a buffer for every new text line that is read must be allocated, and this allocation means also accessing the shadow code, in order to manage (read/write) the data structures that handle the available memory pool.  

Once the file is read, the browse/search operations prove to be quick (compared for example with the performance of WordStar), because no more file read operations are needed, all the text is in the memory.

As a conclusion:
 
- The TE editor 128KB version will work only for RC2014 systems provided with 64MB CF
- The TE editor 128KB version will NOT work with the "classic" RC2014's CP/M, my "custom" large TPA CP/M must be used (use CPM/PutSys/SIO_PutSys_CF64_CPM_DA00H.hex)
- The TE editor 128KB version will work only with SC108 boards (or compatible) provided with a SCM version containing the (undocumented) API function $2B (write A to address DE on Upper 64KB RAM). I received my SCM EPROM in July this year, an it contains this function. I hope that also older versions of SCM contain this function.

Comparing the two versions of TE (128KB vs. 512KB), the 512KB version is by far the best. 

First, the size of files that can be edited is larger.
Then, the initial file opening when starting the editor is faster.

But, I consider both versions of the TE editor as a step forward in the right direction, allowing larger files to be edited in memory, with an elegant an efficient user interface.

  

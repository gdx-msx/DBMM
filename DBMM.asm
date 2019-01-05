; Display the Bigger Memory Mapper v0.1 by GDX
;
; Execute DBMMS as following: BLOAD"DBMMS",R
;
; Assembled with zasm cross assembler
; http://sourceforge.net/projects/zasm/

; Main-Rom entries

CALSLT:	equ	001Ch		; Call Slot
MSXVER:	equ	002Dh		; Read MSX version
ENASLT:	equ	0024h		; Slot select
CHPUT:	equ	00A2h		; Print a character
IMULT:	equ	03193h		; HL = HL * DE (DAC = HL)
FOUT:	equ	03425h		; Convert DAC value to characters string

; System variable entries

DISKVE:	equ	0F313h		; Disk-ROM version
RAMAD0:	equ	0F341h		; Main-RAM slot for the bank 0000h~3FFFh
RAMAD1:	equ	0F342h		; Main-RAM slot for the bank 4000h~7FFFh
RAMAD2:	equ	0F343h		; Main-RAM slot for the bank 8000h~BFFFh
RAMAD3:	equ	0F344h		; Main-RAM slot for the bank C000h~FFFFh
KBUF:	equ	0F41Fh		; Crunch Buffer
EXPTBL:	equ	0FCC1h		; Main-ROM Slot
EXTBIO:	equ	0FFCAh		; Extended Bios entry

	org	0D000h-7

	db	0FEh
	dw	PRGstart,PRGend,PRGrun

PRGstart:

Prim_SLT:
	db	0
Sec_SLT:
	db	0
Map_Slot:
	db	0
Segments:
	db	0
TMP_Map_Slt:
	db	0
TMP_Segments:
	db	0

PRGrun:
	ld	a,(MSXVER)
	cp	3
	jr	c,Not_TR	; Jump if not Turbo R
	ld	a,(DISKVE)
	or	a
	jr	z,Not_TR	; Jump if Disk-ROM v1.xx

	ld	d,4
	ld	e,0
	ld	a,(RAMAD2)
	ld	(Map_Slot),a
	ld	b,a
	ld	hl,KBUF
	call	EXTBIO
	ld	a,(KBUF+4)
	ld	(Segments),a
	jp	TurboR

Not_TR:	
	ld	a,(Sec_SLT)
	inc	a
MapSel_loop:
	ld	(Sec_SLT),a

	call	Slt_Num_conv

	ld	h,80h
	call	ENASLT		; Select the slot X-X bank 2 (8000h~bfffh)

	ld	a,0ffh
	ld	(08000h),a
	ld	a,(08000h)
	cp	0ffh
	ld	a,0
	jp	nz,Smaller	; Jump if No Ram
	ld	(08000h),a
	ld	a,(08000h)
	cp	0

	call	z,TST_Mapper_Size	; Call if Ram

	ld	a,(TMP_Segments)
	or	a
	jr	z,Smaller		; Jump if no segment
	ld	b,a
	ld	a,(Segments)
	cp	b
	jr	nc,Smaller

	call	Slt_Num_conv
	
	ld	a,(TMP_Segments)
	ld	(Segments),a
	ld	a,(TMP_Map_Slt)
	ld	(Map_Slot),a
	
Smaller:
	ld	a,(Sec_SLT)
	cp	3
	jr	nz,Not_TR
	xor	a
	ld	(Sec_SLT),a

	ld	a,(Prim_SLT)
	inc	a
	ld	(Prim_SLT),a
	cp	4
	ld	a,0
	jp	nz,MapSel_loop	; Jump if all slots are not scanned

	ld	a,1
	out	(0feh),a

	ld	a,(RAMAD2)
	ld	h,80h
	call	ENASLT		; Restore the Main-RAM on bank 2 (8000h~bfffh)

	ld	hl,KBUF
	ld	de,KBUF+1
	ld	bc,318
	ld	(hl),0
	ldir			; Clear the crunch buffer

	ld	a,(Segments)
	cp	4
	jp	c,NO_Mapper	; Jump if no memory mapper is found

	ld	hl,Bigger_TXT
	call	Print		; Print the text
TurboR:
	ld	hl,MS_TXT
	call	Print		; Print the text

	xor	a
	ld	d,a
	ld	h,a
	ld	a,(Segments)
	ld	b,a		; B = Segments number
	ld	e,a
	cp	255
	jr	nz,M4096
	inc	de
M4096:
	ld	l,16		; Segment size
	call	IMULT		;　HL = HL * DE -> DAC

	ld	bc,0
	call	FOUT		;　Convert DAC value to characters string

	call	Print		; Print the mapper size

	ld	hl,KB_TXT
	call	Print		; Print "kB"

	ld	hl,SLT_TXT
	call	Print		; Print "kB"

	ld	a,(Map_Slot)
	and	3
	add	30h
	call	CHPUT		; Print the primary slot
	ld	a,(Map_Slot)
	and	80h
	ret	z

	ld	a,'-'
	call	CHPUT

	ld	a,(Map_Slot)
	rrca
	rrca
	and	3
	add	30h
	call	CHPUT		; Print the secondary slot

	ld	hl,RET_TXT
	jp	Print		; Go to the next line and back to Basic

NO_Mapper:
	ld	hl,NO_Mapper_TXT
	jp	Print		; Go to the next line 

; Display text pointed by HL

Print:
	ld	a,(hl)
	cp	0
	ret	z
	call	CHPUT
	inc	hl
	jr	Print

Bigger_TXT:
	db	"Bigger ",0
MS_TXT:
	db	"Mapper Size:",0
KB_TXT:
	db	"kB"
RET_TXT:
	db	10,13,0
SLT_TXT:
	db	"Slot: ",0
NO_Mapper_TXT:
	db	"Mapper not found!",10,13,0

; Test Memory Mapper size

TST_Mapper_Size:

	ld	b,255
	ld	hl,KBUF		; Buffer to temporary store the first byte of each segment
	di
Store_Loop:
	ld	a,b
	out	(0feh),a
	ld	a,(08000h)
	ld	(hl),a		; Store the first byte of each page
	inc	hl
	djnz	Store_Loop

	ld	b,255
MM_Size_Loop1:
	ld	a,b
	out	(0feh),a
	ld	(08000h),a
	djnz	MM_Size_Loop1

	ld	b,255
MM_Size_Loop2:
	ld	a,b
	out	(0feh),a
	ld	a,(08000h)
	cp	b
	jr	nc,MM_SIZE	
	djnz	MM_Size_Loop2
	
	xor	a		; No segment

MM_SIZE:
	ld	(TMP_Segments),a

	ld	b,255
	ld	hl,KBUF
Restore_Loop:
	ld	a,b
	out	(0feh),a
	ld	a,(hl)
	ld	(08000h),a	; Restore the first byte of each page
	inc	hl
	djnz	Restore_Loop

	call	Slt_Num_conv
	ld	(TMP_Map_Slt),a	; Store slot number
	ret

; Slot number conversion
; Entry: Prim_SLT, Sec_SLT
; Output: A = Slot number (FxxxPPSS)
; Modify: A, BC, HL

Slt_Num_conv:
	ld	a,(Prim_SLT)
	ld	c,a
	ld	b,0
	ld	hl,EXPTBL
	add	hl,bc
	ld	a,(hl)
	and	80h
	ld	a,c
	ret	z		; Back if primary slot

	ld	a,(Sec_SLT)
	rlca
	rlca
	or	c
	or	080h
	ret

PRGend:
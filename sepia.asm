#	struct {
#		char* filename;		// wskazanie na nazwę pliku
#		unsigned char* hdrData; // wskazanie na bufor nagłówka pliku BMP
#		unsigned char* imgData; // wskazanie na pierwszy piksel obrazu w pamięci
#		int width, height;	// szerokość i wysokość obrazu w pikselach
#		int linebytes;		// rozmiar linii (wiersza) obrazu w bajtach
#	} imgInfo;

.eqv ImgInfo_fname	0
.eqv ImgInfo_hdrdat 	4
.eqv ImgInfo_imdat	8
.eqv ImgInfo_width	12
.eqv ImgInfo_height	16
.eqv ImgInfo_lbytes	20

.eqv MAX_IMG_SIZE 	230400 # 320 x 240 x 3 (piksele)

.eqv BMPHeader_Size 54
.eqv BMPHeader_width 18
.eqv BMPHeader_height 22

.eqv system_OpenFile	1024
.eqv system_ReadFile	63
.eqv system_WriteFile	64
.eqv system_CloseFile	57





	.data
# CONSTANTS
dist:
        .word   230
rSet:
        .word  	200
gSet:
        .word   200
bSet:
        .word  	200


imgInfo: .space	24	# deskryptor obrazu


	.align 2		# wyrównanie do granicy słowa
dummy:		.space 2
bmpHeader:	.space	BMPHeader_Size

	.align 2
imgData: 	.space	MAX_IMG_SIZE

ifname:	.asciz "source.bmp"
ofname: .asciz "result.bmp"











	.text
main:
	# wypełnienie deskryptora obrazu
	la a0, imgInfo
	la t0, ifname
	sw t0, ImgInfo_fname(a0)
	la t0, bmpHeader
	sw t0, ImgInfo_hdrdat(a0)
	la t0, imgData
	sw t0, ImgInfo_imdat(a0)
	jal	read_bmp
	bnez a0, main_failure

	la a0, imgInfo
	jal convert_sepia

	la a0, imgInfo
	la t0, ofname
	sw t0, ImgInfo_fname(a0)
	jal save_bmp
	
main_failure:
	li a7, 10
	ecall
	




read_bmp:
	mv t0, a0	# preserve imgInfo structure pointer
	
	#open file
	li a7, system_OpenFile
   	lw a0, ImgInfo_fname(t0)	#file name 
	li a1, 0					#flags: 0-read file
    	ecall
	
	blt a0, zero, rb_error
	mv t1, a0					# save file handle for the future
	
#read header
	li a7, system_ReadFile
	lw a1, ImgInfo_hdrdat(t0)
	li a2, BMPHeader_Size
	ecall
	
#extract image information from header
	lw a0, BMPHeader_width(a1)
	sw a0, ImgInfo_width(t0)
	
	# compute line size in bytes - bmp line has to be multiple of 4
	add a2, a0, a0
	add a0, a2, a0	# pixelbytes = width * 3 
	addi a0, a0, 3
	srai a0, a0, 2
	slli a0, a0, 2	# linebytes = ((pixelbytes + 3) / 4 ) * 4
	sw a0, ImgInfo_lbytes(t0)
	
	lw a0, BMPHeader_height(a1)
	sw a0, ImgInfo_height(t0)

#read image data
	li a7, system_ReadFile
	mv a0, t1
	lw a1, ImgInfo_imdat(t0)
	li a2, MAX_IMG_SIZE
	ecall

#close file
	li a7, system_CloseFile
	mv a0, t1
    	ecall
	
	mv a0, zero
	jr ra
	
rb_error:
	li a0, 1	# error opening file	
	jr ra







save_bmp:
	mv t0, a0	# preserve imgInfo structure pointer
	
#open file
	li a7, system_OpenFile
    lw a0, ImgInfo_fname(t0)	#file name 
    li a1, 1					#flags: 1-write file
    ecall
	
	blt a0, zero, wb_error
	mv t1, a0					# save file handle for the future
	
#write header
	li a7, system_WriteFile
	lw a1, ImgInfo_hdrdat(t0)
	li a2, BMPHeader_Size
	ecall
	
#write image data
	li a7, system_WriteFile
	mv a0, t1
	# compute image size (linebytes * height)
	lw a2, ImgInfo_lbytes(t0)
	lw a1, ImgInfo_height(t0)
	mul a2, a2, a1
	lw a1, ImgInfo_imdat(t0)
	ecall

#close file
	li a7, system_CloseFile
	mv a0, t1
    	ecall
	
	mv a0, zero
	jr ra
	
wb_error:
	li a0, 2 # error writing file
	jr ra



















# ============================================================================
# set_pixel - sets the color of specified pixel
#arguments:
#	a0 - address of ImgInfo image descriptor
#	a1 - x coordinate
#	a2 - y coordinate - (0,0) - bottom left corner
#	a3 - 0RGB - pixel color
#return value: none
#remarks - a0, a1, a2 values are left unchanged

set_pixel:
	mv t0, zero
	lw t1, ImgInfo_lbytes(a0)
	mul t1, t1, a2  # t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t1  # t0 is offset of the pixel

	lw t1, ImgInfo_imdat(a0) # address of image data
	add t0, t0, t1 	# t0 is address of the pixel
	
	#set new color
	sb   a3,(t0)		#store B
	srli a3, a3, 8
	sb   a3, 1(t0)		#store G
	srli a3, a3, 8
	sb   a3, 2(t0)		#store R

	jr ra

# ============================================================================
# get_pixel- returns color of specified pixel
#arguments:
#	a0 - address of ImgInfo image descriptor
#	a1 - x coordinate
#	a2 - y coordinate - (0,0) - bottom left corner
#return value:
#	a0 - 0RGB - pixel color
#remarks: a1, a2 are preserved

get_pixel:
	lw t1, ImgInfo_lbytes(a0)
	mul t1, t1, a2  # t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t1  # t0 is offset of the pixel

	lw t1, ImgInfo_imdat(a0) # address of image data
	add t0, t0, t1 	# t0 is address of the pixel

	#get color
	lbu a0,(t0)		#load B
	lbu t1,1(t0)		#load G
	slli t1,t1,8
	or a0, a0, t1
	lbu t1,2(t0)		#load R
	slli t1,t1,16
	or a0, a0, t1				
	jr ra
	
convert_sepia:
	#calculate dist**2
	lhu t0, dist
	la a5, dist	
	mul t0, t0, t0
	sw t0, (a5)	# dist = dist * dist
	
	addi sp, sp, -8
	sw ra, 4(sp)		#push ra
	sw s1, 0(sp)		#push s1
	mv s1, a0 		#preserve imgInfo for further use
	
	lw a2, ImgInfo_height(a0)
	addi a2, a2, -1
	
convert_line:
	lw a1, ImgInfo_width(a0)
	addi a1, a1, -1

convert_pixel:
	jal get_pixel
	
	mv t2, zero	#t2 = sum  R-G-B
	lw t3, dist	#t3 = dist*dist

	
	
	#calculate (R-Rset)*(R-Rset)
	mv t0, a0	#copy a0 to t0, a0 cannot be changed here
	li t1, 0x00FF0000 # mask for extract red
	and t0, t0, t1
	srai t0, t0, 16	# t0 = 0x000000RR
	lh t1, rSet
	sub t1, t0, t1	#t0 = R-Rset			
	mul t1, t1, t1 	#t0 = (R-Rset)*(R-Rset)
	#bgt t0, t3, end_convert
	mv t2, t1	#t2 = (R-Rset)*(R-Rset)
	
	#calculate (G-Gset)*(G-Gset)
	mv t4, a0	#copy a0 to t0, a0 cannot be changed here
	li t1, 0x0000FF00 # mask for extract green
	and t4, t4, t1
	srai t4, t4, 8	# t0 = 0x000000GG
	lh t1, gSet
	sub t1, t4, t1	#t0 = G-Gset			
	mul t1, t1, t1 	#t0 = (G-Gset)*(G-Gset)
	add t2, t2, t1	#t2 -= (G-Gset)*(G-Gset)
	#bgt t2, t3, end_convert
	
	#calculate (B-Bset)*(B-Bset)
	mv t5, a0	#copy a0 to t0, a0 cannot be changed here
	li t1, 0x000000FF # mask for extract green
	and t5, t5, t1
	lh t1, bSet
	sub t1, t5, t1	#t0 = B-Bset			
	mul t1, t1, t1 	#t0 = (B-Bset)*(B-Bset)
	add t2, t2, t1	#t2 -= (B-Bset)*(B-Bset)
	bgt t2, t3, end_convert
calculate_red:
	#t0 - red	     0x000000RR	
	#t4 - green	     0x000000GG	
	#t5 - blue	     0x000000BB
	
	#calculate red output
	mv a0, zero
	mv a3, zero
	
	li t2, 393
	mv t1, t0
	mul  t1, t1, t2
	add a0, a0, t1
	
	li t2, 769
	mv t1, t4
	mul t1, t1, t2
	add a0, a0, t1
	
	li t2, 189
	mv t1, t5
	mul t1, t1, t2
	add a0, a0, t1
	
	li t3, 1000
	div a0, a0, t3
	li a5, 255
	ble a0, a5, calculate_green
	mv a0, a5
calculate_green:
	slli a0, a0, 16
	or a3, a3, a0
	mv a0, zero
	
	li t2, 349
	mv t1, t0
	mul  t1, t1, t2
	add a0, a0, t1
	
	li t2, 686
	mv t1, t4
	mul t1, t1, t2
	add a0, a0, t1
	
	li t2, 168
	mv t1, t5
	mul t1, t1, t2
	add a0, a0, t1
	
	div a0, a0, t3
	ble a0, a5, calculate_blue
	mv a0, a5
calculate_blue:
	slli a0, a0, 8
	or a3, a3, a0
	mv a0, zero
	
	li t2, 272
	mv t1, t0
	mul  t1, t1, t2
	add a0, a0, t1
	
	li t2, 534
	mv t1, t4
	mul t1, t1, t2
	add a0, a0, t1
	
	li t2, 131
	mv t1, t5
	mul t1, t1, t2
	add a0, a0, t1
	
	div a0, a0, t3

	ble a0, a5, insert_blue
	mv a0, a5
insert_blue:
	or a3, a3, a0
	mv a0, a3
end_convert:
	mv a3, a0
	mv a0, s1

#	li a3, 0xFF00FF
	jal set_pixel
	
	addi a1, a1, -1
	bge a1, zero, convert_pixel
	
	addi a2, a2, -1
	bge a2, zero, convert_line
	
	lw s1, 0(sp)		#pop s1
	lw ra, 4(sp)		#pop ra
	addi sp, sp, 8
	jr ra

#==========================================
#calculate sepia
#input a0 - 0RGB value of pixel
#return a3 - 0RGB value of converted pixel

%ifndef RASTERIZE_EDGES
%define RASTERIZE_EDGES

; dependency
%include "lib/io/bitmap/set_line.asm"

rasterize_edges:
; void rasterize_edges(void* {rdi}, int {rsi}, int {edx}, int {ecx},
;		 struct* {r8}, struct* {r9});
;	Rasterizes a set of edges described by the structure at {r9} from the
;	perspective described by the structure at {r8} to the {edx}x{ecx} (WxH)
;	image using the color value in the low 32 bits of {rsi} to the bitmap
;	starting at address {rdi}. The 32nd bit of {rsi} indicates the stacking
;	direction of the bitmap rows.

%if 0
.perspective_structure:
	dq 0.00 ; lookFrom_x	
	dq 0.00 ; lookFrom_y	
	dq 0.00 ; lookFrom_z	
	dq 0.00 ; lookAt_x	
	dq 0.00 ; lookAt_y	
	dq 0.00 ; lookAt_z	
	dq 0.00 ; upDir_x	
	dq 0.00 ; upDir_y	
	dq 0.00 ; upDir_z	
	dq 1.00	; zoom
%endif

%if 0
.edge_structure:
	dq 0 ; number of points (N)
	dq 0 ; number of edges (M)
	dq 0 ; starting address of point array (3N elements)
	dq 0 ; starting address of edge array (2M elements)
%endif

	push rax
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15
	sub rsp,144
	movdqu [rsp+0],xmm0
	movdqu [rsp+16],xmm1
	movdqu [rsp+32],xmm2
	movdqu [rsp+48],xmm3
	movdqu [rsp+64],xmm4
	movdqu [rsp+80],xmm5
	movdqu [rsp+96],xmm6
	movdqu [rsp+112],xmm7
	movdqu [rsp+128],xmm8

	; Uy = (upDir)
	; Ux = (upDir)x(lookFrom-lookAt)

	; rasterized pt x = (Pt).(Ux)*zoom*width/2+width/2
	; rasterized pt y = -(Pt).(Uy)*zoom*height/2+height/2

	; precompute Ux*zoom and Uy*zoom

	; upDir
	movsd xmm0,[r8+48]
	movsd xmm1,[r8+56]
	movsd xmm2,[r8+64]

	mulsd xmm0,xmm0
	mulsd xmm1,xmm1
	mulsd xmm2,xmm2

	addsd xmm0,xmm1
	addsd xmm0,xmm2
	sqrtsd xmm0,xmm0
	movsd xmm1,[.one]
	divsd xmm1,xmm0		; 1/magnitude factor

	movsd xmm3,[r8+48]
	movsd xmm4,[r8+56]
	movsd xmm5,[r8+64]

	mulsd xmm3,xmm1
	mulsd xmm4,xmm1
	mulsd xmm5,xmm1		; Uy is now normalized

	movsd xmm6,[r8+0]
	subsd xmm6,[r8+24]
	movsd xmm7,[r8+8]
	subsd xmm7,[r8+32]
	movsd xmm8,[r8+16]
	subsd xmm8,[r8+40]

	; normalize lookFrom-lookAt

	movsd xmm0,xmm6
	movsd xmm1,xmm7
	movsd xmm2,xmm8
	
	mulsd xmm0,xmm0
	mulsd xmm1,xmm1
	mulsd xmm2,xmm2

	addsd xmm0,xmm1
	addsd xmm0,xmm2
	sqrtsd xmm0,xmm0
	movsd xmm1,[.one]
	divsd xmm1,xmm0		; 1/magnitude factor
;	mulsd xmm1,[r8+72]	; zoom factor, can't do this yet. need unit vector

	mulsd xmm6,xmm1
	mulsd xmm7,xmm1
	mulsd xmm8,xmm1		; lookFrom-lookAt now normalized before cross product


	; now compute cross product

	movsd xmm13,xmm4
	mulsd xmm13,xmm8
	movsd xmm10,xmm5
	mulsd xmm10,xmm7
	subsd xmm13,xmm10

	movsd xmm14,xmm5
	mulsd xmm14,xmm6
	movsd xmm10,xmm3
	mulsd xmm10,xmm8
	subsd xmm14,xmm10

	movsd xmm15,xmm3
	mulsd xmm15,xmm7
	movsd xmm10,xmm4
	mulsd xmm10,xmm6
	subsd xmm15,xmm10

	movsd xmm0,xmm13
	movsd xmm1,xmm14
	movsd xmm2,xmm15
	
	mulsd xmm0,xmm0
	mulsd xmm1,xmm1
	mulsd xmm2,xmm2

	addsd xmm0,xmm1
	addsd xmm0,xmm2
	movsd xmm1,[.one]
	divsd xmm1,xmm0		; 1/magnitude factor
	mulsd xmm1,[r8+72]	; zoom factor
	
	cvtsi2sd xmm0,rdx
	cvtsi2sd xmm2,rcx
	divsd xmm2,xmm0
	mulsd xmm1,xmm2		; scale by aspect ratio

	mulsd xmm13,xmm1
	mulsd xmm14,xmm1
	mulsd xmm15,xmm1	; Ux is now normalized and then scaled by zoom

	movsd xmm6,xmm13
	movsd xmm7,xmm14
	movsd xmm8,xmm15

	; scale Uy by zoom	
	mulsd xmm3,[r8+72]
	mulsd xmm4,[r8+72]
	mulsd xmm5,[r8+72]

	; width/2 and height/2
	mov rax,rdx
	shr rax,1
	cvtsi2sd xmm9,rax
	mov rax,rcx
	shr rax,1
	cvtsi2sd xmm10,rax

	mov r15,[r9+8]	; number of edges in r15
	mov rax,[r9+24]
	;loop thru all edges

.loop_edges:

	; grab first point
	
	mov r10,[rax]
	shl r10,3
	imul r10,r10,3	; {r10} points to the x value of the first point
	add r10,[r9+16]
	

	movsd xmm0,[r10]	; Pt_x
	movsd xmm1,[r10+8]	; Pt_y
	movsd xmm2,[r10+16]	; Pt_z
	
	; correct relative to lookAt point
	subsd xmm0,[r8+24]
	subsd xmm1,[r8+32]
	subsd xmm2,[r8+40]

	mulsd xmm0,xmm6		
	mulsd xmm1,xmm7
	mulsd xmm2,xmm8
	addsd xmm0,xmm1
	addsd xmm0,xmm2		; Pt.Ux*zoom in {xmm0}

	addsd xmm0,[.one]
	mulsd xmm0,xmm9

	cvtsd2si r11,xmm0	; {r11} contains pixel 1 x-coord
	
	movsd xmm0,[r10]	; Pt_x
	movsd xmm1,[r10+8]	; Pt_y
	movsd xmm2,[r10+16]	; Pt_z

	; correct relative to lookAt point
	subsd xmm0,[r8+24]
	subsd xmm1,[r8+32]
	subsd xmm2,[r8+40]



	mulsd xmm0,xmm3
	mulsd xmm1,xmm4
	mulsd xmm2,xmm5
	addsd xmm0,xmm1
	addsd xmm0,xmm2		; Pt.Uy*zoom in {xmm0}

	mulsd xmm0,[.neg]
	addsd xmm0,[.one]
	mulsd xmm0,xmm10

	cvtsd2si r12,xmm0	; {r12} contains pixel 1 y-coord
	
	add rax,8
	
	mov r10,[rax]
	shl r10,3
	imul r10,r10,3	; {r10} points to the x value of the second point
	add r10,[r9+16]
	
	movsd xmm0,[r10]	; Pt_x
	movsd xmm1,[r10+8]	; Pt_y
	movsd xmm2,[r10+16]	; Pt_z

	; correct relative to lookAt point
	subsd xmm0,[r8+24]
	subsd xmm1,[r8+32]
	subsd xmm2,[r8+40]

	mulsd xmm0,xmm6		
	mulsd xmm1,xmm7
	mulsd xmm2,xmm8
	addsd xmm0,xmm1
	addsd xmm0,xmm2		; Pt.Ux*zoom in {xmm0}

	addsd xmm0,[.one]
	mulsd xmm0,xmm9

	cvtsd2si r13,xmm0	; {r13} contains pixel 1 x-coord

	movsd xmm0,[r10]	; Pt_x
	movsd xmm1,[r10+8]	; Pt_y
	movsd xmm2,[r10+16]	; Pt_z

	; correct relative to lookAt point
	subsd xmm0,[r8+24]
	subsd xmm1,[r8+32]
	subsd xmm2,[r8+40]

	mulsd xmm0,xmm3
	mulsd xmm1,xmm4
	mulsd xmm2,xmm5
	addsd xmm0,xmm1
	addsd xmm0,xmm2		; Pt.Uy*zoom in {xmm0}

	mulsd xmm0,[.neg]
	addsd xmm0,[.one]
	mulsd xmm0,xmm10

	cvtsd2si r14,xmm0	; {r14} contains pixel 2 y-coord

	add rax,8

	push rax
	push r8
	push r9
	push r10
	push r11
	mov r8,r11
	mov r9,r12
	mov r10,r13
	mov r11,r14
	call set_line
	pop r11
	pop r10
	pop r9
	pop r8
	pop rax


	dec r15
	jnz .loop_edges

	movdqu xmm0,[rsp+0]
	movdqu xmm2,[rsp+32]
	movdqu xmm3,[rsp+48]
	movdqu xmm4,[rsp+64]
	movdqu xmm5,[rsp+80]
	movdqu xmm6,[rsp+96]
	movdqu xmm7,[rsp+112]
	movdqu xmm8,[rsp+128]
	add rsp,144
	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop rax

	ret

.one:
	dq 1.0

.neg:
	dq -1.0

%endif

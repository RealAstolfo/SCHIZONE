%ifndef MATRIX_TRANSPOSE
%define MATRIX_TRANSPOSE

matrix_transpose:
; void matrix_transpose(double* {rdi}, double* {rsi}, uint {rdx}, uint {rcx});
; 	Transposes {rdx}x{rcx} double-precision floating point matrix beginning 
;	at {rsi} into the {rcx}x{rdx} matrix starting at address {rdi}.

;	NOTE: should work on matrices of any 8-byte datatype.

	push rdi
	push rsi
	push rax
	push rbx
	push rcx
	push r8
	push r9

	mov r9,rcx
	imul r9,rdx
	shl r9,3	; {r9} points past the last element of
	add r9,rsi	; the source matrix

	mov r8,rdx	; set row counter in {r8}
	shl rcx,3	; convert {rcx} into byte-width
	mov rbx,rdi	; set {rbx} to start of destination matrix
	
.loop:
	movq rax,[rsi]	; grab element from source matrix
	movq [rbx],rax	; drop element into destination matrix
	add rsi,8	; increment element in source matrix
	add rbx,rcx	; move to next row in destination matrix

	dec r8		; loop until out of rows
	jnz .loop

	cmp rsi,r9	; quit when out of elements
	jge .done

	mov r8,rdx	; reset row counter
	add rdi,8	; move to next column of destination matrix	
	mov rbx,rdi	; set {rsi} to next column of destination matrix
		
	jmp .loop

.done:
	pop r9
	pop r8
	pop rcx
	pop rbx
	pop rax	
	pop rsi
	pop rdi

	ret			; return

%endif

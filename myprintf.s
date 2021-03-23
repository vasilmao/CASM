
section .text

global MyPrintf
extern printf

MyPrintf:

    pop rax
    mov [ret_adress], rax
    xor rax, rax

    push r9
    push r8
    push rcx
    push rdx
    push rsi
    push rdi

    call PrintF

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop r8
    pop r9

    xor rax, rax
    ; call printf

    push qword [ret_adress]

    ret


;===============================================================================
;changes: rax, rsi, rdi, rdx, rcx
;===============================================================================
FlushBuffer:
    cmp qword [BufferSize], 0
    je FlushEnd
    mov rax, 0x01
    mov rsi, OutBuffer
    mov rdi, 1
    mov rdx, [BufferSize]
    syscall
    mov qword [BufferSize], 0
    FlushEnd:
    ret

;===============================================================================
;args: rax - char code of new char
;changes: rcx + FlushBuffer changes
;===============================================================================
WriteCharToBuffer:
    cmp qword [BufferSize], max_buffer_size
    jne AfterFlushing
    push rax
    call FlushBuffer
    pop rax
    AfterFlushing:
    mov rcx, OutBuffer
    add rcx, [BufferSize]
    mov [rcx], rax
    mov rcx, [BufferSize]
    inc rcx
    mov [BufferSize], rcx
    WriteBufferEnd:
    ret

;===============================================================================
;args: rax - string ptr
;changes: r8 + WriteBuffer
;===============================================================================
WriteStringToBuffer:
    mov r8, rax
    BuffStringLoop:
        cmp byte [r8], string_end
        je BuffStingExit
        mov rax, [r8]
        call WriteCharToBuffer
        inc r8
        jmp BuffStringLoop
    BuffStingExit:
    ret

;===============================================================================
;args: rax - digit
;changes: WriteBuffer
;===============================================================================
WriteDigitToBuffer:
    cmp rax, 9
    jg HexDigit
    add rax, '0'
    call WriteCharToBuffer
    jmp DigitExit
    HexDigit:
    sub rax, 10
    add rax, 'A'
    call WriteCharToBuffer
    DigitExit:
    ret

;===============================================================================
;args: rax - num, rbx - base from 2 to 16
;changes: rdx, rdi + WriteDigitToBuffer
;===============================================================================
WriteNumToBuffer:
    xor rdx, rdx
    xor rdi, rdi ; counter
	StackNumLoop:
        div rbx ; rax = res, rdx = mod
		push rdx
		inc rdi
		xor rdx, rdx
		cmp rax, 0
		jne StackNumLoop
	BuffNumLoop:
		pop rax
        call WriteDigitToBuffer
		dec di
		cmp di, 0
		jne BuffNumLoop
	ret

WriteNumToBufferSigned:
    xor rdx, rdx
    xor rdi, rdi ; counter
    cmp eax, 0d
    jl WriteMinus
    jmp AfterMinus
    WriteMinus:
    push rax
    mov rax, '-'
    call WriteCharToBuffer
    pop rax
    neg eax
    AfterMinus:
    call WriteNumToBuffer
	ret

;===============================================================================
;args: rax - num, rbx - base from 1 to 4 (means 2^1, 2^2, 2^3, 2^4)
;changes: rdx, rdi, rcx + WriteDigitToBuffer
;note: shr optimization instead of div
;===============================================================================
WriteNumToBufferBin:
    xor rdi, rdi ; counter
    mov rcx, rbx
	StackNumBinLoop:
        mov rdx, 1
        shl rdx, cl
        dec rdx ; now rdx is 111..1111
        and rdx, rax ; now rdx = mod
        push rdx
        shr rax, cl
		inc rdi
		cmp rax, 0
		jne StackNumBinLoop
	BuffNumBinLoop:
		pop rax
        call WriteDigitToBuffer
		dec di
		cmp di, 0
		jne BuffNumBinLoop
	ret

WriteNumToBufferBinSigned:
    xor rdx, rdx
    xor rdi, rdi ; counter
    cmp eax, 0d
    jl WriteMinusBinSigned
    jmp AfterMinusBinSigned
    WriteMinusBinSigned:
    push rax
    mov rax, '-'
    call WriteCharToBuffer
    pop rax
    neg eax
    AfterMinusBinSigned:
    call WriteNumToBufferBin
    ret

%macro PrintBinNumber 1

    push rbx
    cmp byte [rbx+1], 'u'
    je GoUnsignedBin%1
    mov rbx, %1
    mov rax, [rbp+r9]
    call WriteNumToBufferBinSigned
    jmp EndDecBin%1
    GoUnsignedBin%1:
    mov rbx, %1
    mov rax, [rbp+r9]
    call WriteNumToBufferBin
    inc r8
    EndDecBin%1:
    pop rbx
    add r9, 8
    jmp SymbolPrintEnd
%endmacro

;===============================================================================
;args: from stack
;changes: rbp, r8, r9, rax, rbx rax + WriteCharToBuffer + WriteStringToBuffer +
;         + WriteNumToBuffer + WriteNumToBufferBin
;===============================================================================
PrintF:
    push rbp
    mov rbp, rsp
    add rbp, 16
    xor r8, r8 ; format string iterator
    mov r9, 8  ; argument iterator
    PrintFLoop:
        mov rbx, [rbp]
        add rbx, r8
        cmp byte [rbx], string_end
        je PrintExit

        cmp byte [rbx], '%'
        jne PrintUsualSymbol
        inc r8
        inc rbx
        ; [rbx] - символ
        xor rax, rax
        mov al, [rbx]
        cmp al, 'b'
        jb PrintUsualSymbol
        cmp al, 'x'
        ja PrintUsualSymbol
        sub rax, 'b'
        shl rax, 3
        add rax, SwitchTable
        jmp qword [rax]

        PrintUsualSymbol:
        mov rax, [rbx]
        call WriteCharToBuffer
        jmp SymbolPrintEnd


        PrintProcent:
        mov rax, '%'
        call WriteCharToBuffer
        jmp SymbolPrintEnd


        PrintProcentWithSymbol:
        mov rax, '%'
        call WriteCharToBuffer
        mov rax, [rbx]
        call WriteCharToBuffer
        jmp SymbolPrintEnd


        PrintChar:
        mov rax, [rbp+r9]
        call WriteCharToBuffer
        add r9, 8
        jmp SymbolPrintEnd


        PrintArgString:
        mov rax, [rbp+r9]
        push r8
        call WriteStringToBuffer
        pop r8
        add r9, 8
        jmp SymbolPrintEnd


        PrintBinaryNumber:
        PrintBinNumber 1


        PrintDecimalNumber:
        ;mov rax, [rbp+r9]
        ;add r9, 8
        push rbx
        cmp byte [rbx+1], 'u'
        je GoUnsigned
        mov rbx, 10
        mov rax, [rbp+r9]
        call WriteNumToBufferSigned
        jmp EndDec
        GoUnsigned:
        mov rbx, 10
        mov rax, [rbp+r9]
        call WriteNumToBuffer
        inc r8
        EndDec:
        pop rbx
        add r9, 8
        jmp SymbolPrintEnd


        PrintOctalNumber:
        PrintBinNumber 3


        PrintHexNumber:
        PrintBinNumber 4

        SymbolPrintEnd:
        inc r8
        jmp PrintFLoop

    PrintExit:
    call FlushBuffer
    pop rbp
    ;jmp TrampolineEnd
    ret


SwitchTable:
             dq PrintBinaryNumber
             dq PrintChar
             dq PrintDecimalNumber
    times 10 dq PrintProcentWithSymbol
             dq PrintOctalNumber
    times 3  dq PrintProcentWithSymbol
             dq PrintArgString
    times 4  dq PrintProcentWithSymbol
             dq PrintHexNumber
    times 7  dq PrintProcentWithSymbol

SwitchTable1:
             dq PrintBinaryNumber
             dq PrintChar
             dq PrintDecimalNumber
    times 10 dq PrintProcentWithSymbol
             dq PrintOctalNumber
    times 3  dq PrintProcentWithSymbol
             dq PrintArgString
    times 4  dq PrintProcentWithSymbol
             dq PrintHexNumber

section     .data

string_end      equ 0x00
max_buffer_size equ 512
OutBuffer:  times 512 db  0
BufferSize:           dq  0
ret_adress: dq 0

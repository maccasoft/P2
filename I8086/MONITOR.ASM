                cpu     8086

stat:           equ     0f7h        ; uart status port
data:           equ     0f6h        ; uart data port
rdrf:           equ     01h         ; uart data available bit
tdre:           equ     02h         ; uart transmitter ready bit

buflen:         equ     80
bpmax:          equ     10
regtablen:      equ     14
prompt:         equ     ">"
can:            equ     "@"

                section .bss

; RAM area

brkcnt:         resw    1           ; number of breakpoints
tcount:         resw    1           ; number of steps to trace
bptab:          resw    bpmax       ; breakpoint table
linebuf:        resb    buflen+1    ; line input buffer
                alignb  2
                resw    50          ; working stack area
stack:

; Register save area

axsave:         resw    1
bxsave:         resw    1
cxsave:         resw    1
dxsave:         resw    1
spsave:         resw    1
bpsave:         resw    1
sisave:         resw    1
disave:         resw    1
dssave:         resw    1
essave:         resw    1
rstack:                             ; stack set here so registers can be saved by pushing
sssave:         resw    1
cssave:         resw    1
ipsave:         resw    1
fsave:          resw    1

                section .text

reset:

; One-time initialization

                cli
                cld
                xor     ax, ax
                mov     ss, ax
                mov     ds, ax
                mov     es, ax
                mov     di, axsave
                mov     cx, 14
                rep
                stosw
                or      byte [fsave+1], 2
                mov     cl, 4
                mov     al, 40h
                mov     di, dssave
                rep
                stosw
                mov     byte [spsave+1], 0Ch
                mov     sp, stack

domon:
                mov     si, header
                call    printmes

command:
; Re-establish initial conditions
                cld
                xor     ax, ax
                mov     ss, ax
                mov     ds, ax
                mov     es, ax
                mov     sp, stack
                mov     al, prompt
                call    out
                call    inbuf
                call    scanb
                jz      command
                mov     al, [di]
                sub     al, "B"
                jc      err1
                cmp     al, "T"+1-"B"
                jnc     err1
                inc     di
                shl     al, 1
                cbw
                xchg    bx, ax
                call    [cs:bx+comtab]
                jmp     command

err1:
                jmp     error

inbuf:
                mov     di, linebuf
                xor     cx, cx
getch:          call    in
                cmp     al, 20h
                jc      control
                cmp     al, 7fh
                jz      backsp
                call    out
                cmp     al, can
                jz      kill
                stosb
                inc     cx
                cmp     cx, buflen
                jbe     getch
backsp:
                jcxz    getch
                dec     di
                dec     cx
                call    backup
                jmp     getch
control:
                cmp     al, 8
                jz      backsp
                cmp     al, 13
                jnz     getch
                stosb
                mov     di, linebuf
crlf:
                mov     al, 13
                call    out
                mov     al, 10
                jmp     out

kill:
                call    crlf
                jmp     command

in:
                in      al, stat
                test    al, rdrf
                jz      in
                in      al, data
                and     al, 7fh
                ret
backup:
                mov     al, 8
                call    out
                mov     al, 32
                call    out
                mov     al, 8
                jmp     out

printmes:
                cs
                lodsb
                call    out
                test    ax, 80h
                jz      printmes
                ret

; scan for parameters of a command

scanp:
                call    scanb
                cmp     byte [di], ","
                jne     eolchk
                inc     di

; scan command line for next non-blank character

scanb:
                mov     al, " "
                push    cx
                mov     cl, -1
                repe
                scasb
                dec     di
                pop     cx
eolchk:
                mov     al, [di]
                cmp     byte [di], 13
                ret

outsi:
                mov     dx, ds
                mov     ah, 0
                call    shift4
                add     dx, si
                jmp     outadd

outdi:
                mov     dx, es
                mov     ah, 0
                call    shift4
                add     dx, di
outadd:
                adc     ah, 0
                call    hidigit

out16:
                mov     al, dh
                call    hex
                mov     al, dl
hex:
                mov     ah, al
                shr     al, 1
                shr     al, 1
                shr     al, 1
                shr     al, 1
                call    digit
hidigit:
                mov     al, ah
digit:
                and     al, 0Fh
                add     al, 90h
                daa
                adc     al, 40h
                daa

; console output character in AL

out:
                push    ax
out1:           in      al, stat
                and     al, tdre
                jz      out1
                pop     ax
                out     data, al
                ret

blank:
                mov     al, " "
                jmp     out

tab:
                call    blank
                loop    tab
                ret

comtab:
                dw      perr            ; B
                dw      perr            ; C
                dw      dump            ; D
                dw      perr            ; E
                dw      perr            ; F
                dw      perr            ; G
                dw      perr            ; H
                dw      perr            ; I
                dw      perr            ; J
                dw      perr            ; K
                dw      perr            ; L
                dw      move            ; M
                dw      perr            ; N
                dw      perr            ; O
                dw      perr            ; P
                dw      perr            ; Q
                dw      reg             ; R
                dw      perr            ; S
                dw      perr            ; T

getseg:
                mov     al, dl
                and     al, 0Fh
                call    shift4
                mov     dl, al
                mov     al, dh
                xor     dh, dh
                ret

shift4:
                shl     dx, 1
                rcl     ah, 1
                shl     dx, 1
                rcl     ah, 1
                shl     dx, 1
                rcl     ah, 1
                shl     dx, 1
                rcl     ah, 1
ret2:           ret

range:
                mov     cx, 5
                call    gethex
                push    ax
                push    dx
                call    scanp
                cmp     byte [di], "L"
                je      getlen
                mov     dx, 128
                call    hexin
                jc      rngret
                mov     cx, 5
                call    gethex
                mov     cx, dx
                pop     dx
                pop     bx
                sub     cx, dx
                sbb     ah, bh
                jnz     rngerr
                xchg    ax, bx
                inc     cx
                jmp     rngchk
getlen:
                inc     di
                mov     cx, 4
                call    gethex
rngret:
                mov     cx, dx
                pop     dx
                pop     ax
rngchk:
                mov     bx, dx
                and     bx, 0Fh
                jcxz    maxrng
                add     bx, cx
                jnc     getseg
maxrng:
                jz      getseg
rngerr:
                mov     ax, 4700h+"R"
                jmp     err

; Dump an area of memory in both HEX and ASCII

dump:
                call    range
                push    ax
                call    geteol
                pop     ds
                mov     si, dx
row:
                call    outsi
                push    si
byte0:
                call    blank
byte1:
                lodsb
                call    hex
                pop     dx
                dec     cx
                jz      ascii
                mov     ax, si
                test    al, 0Fh
                jz      endrow
                push    dx
                test    al, 07h
                jnz     byte0
                mov     al, "-"
                call    out
                jmp     byte1
endrow:
                call    ascii
                jmp     row
ascii:
                push    cx
                mov     ax, si
                mov     si, dx
                sub     ax, dx
                mov     bx, ax
                shl     ax, 1
                add     ax, bx
                mov     cx, 51
                sub     cx, ax
                call    tab
                mov     cx, bx
ascdmp:
                lodsb
                and     al, 7Fh
                cmp     al, 7Fh
                jz      noprt
                cmp     al, " "
                jnc     prin
noprt:
                mov     al, "."
prin:
                call    out
                loop    ascdmp
                pop     cx
                jmp     crlf

move:
                call    range
                push    cx
                push    ax
                mov     si, dx
                mov     cx, 5
                call    gethex
                call    geteol
                call    getseg
                mov     di, bx
                pop     bx
                mov     ds, bx
                mov     es, ax
                pop     cx
                cmp     di, si
                sbb     ax, bx
                jb      copylist
                dec     cx
                add     si, cx
                add     di, cx
                std
                inc     cx
copylist:
                movsb
                dec     cx
                rep
                movsb
                ret

geteol:
                call    scanb
                jnz     error
                ret

gethex:
                call    scanp
gethex1:
                xor     dx, dx
                mov     ah, dh
                call    hexin
                jc      error
                mov     dl, al
getlp:
                inc     di
                dec     cx
                call    hexin
                jc      ret
                jcxz    error
                call    shift4
                or      dl, al
                jmp     getlp

hexin:
                mov     al, [di]

hexchk:
                sub     al, "0"
                jc      ret
                cmp     al, 10
                cmc
                jnc     ret
                sub     al, 7
                cmp     al, 10
                jc      ret
                cmp     al, 16
                cmc
ret:            ret

perr:
                dec     di

error:
                sub     di, linebuf-1
                mov     cx, di
                call    tab
                mov     si, synerr
                
print:
                call    printmes
                jmp     command


; Perform register dump

reg:
                call    scanp
                jz      dispreg
                mov     dl, [di]
                inc     di
                mov     dh, [di]
                cmp     dh, 13
                jz      flag
                inc     di
                call    geteol
                cmp     dh, " "
                jz      flag
                mov     di, regtab
                xchg    ax, dx
                push    cs
                pop     es
                mov     cx, regtablen
                repnz
                scasw
                jnz     badreg
                or      cx, cx
                jnz     notpc
                dec     di
                dec     di
                mov     ax, [cs:di-2]
notpc:
                call    out
                mov     al, ah
                call    out
                call    blank
                push    ds
                pop     es
                lea     bx, [di+regdif-2]
                mov     dx, [bx]
                call    out16
                call    crlf
                mov     al, ":"
                call    out
                call    inbuf
                call    scanb
                jz      ret3
                mov     cx, 4
                call    gethex1
                call    geteol
                mov     [bx], dx
ret3:           ret
badreg:
                mov     ax, 5200h+"B"
                jmp     err

dispreg:
                mov     si, regtab
                mov     bx, axsave
                mov     cx, 8
                call    dispregline
                call    crlf
                mov     cx, 5
                call    dispregline
                call    blank
                call    dispflags
                jmp     crlf
flag:
                cmp     dl, "F"
                jnz     badreg
                call    dispflags
                mov     al, "-"
                call    out
                call    inbuf
                call    scanb
                xor     bx,bx
                mov     dx, [fsave]
getflg:
                mov     si, di
                lodsw
                cmp     al, 13
                jz      savchg
                cmp     ah, 13
                jz      flgerr
                mov     di, flgtab
                mov     cx, 32
                push    cs
                pop     es
                repne
                scasw
                jnz     flgerr
                mov     ch, cl
                and     cl, 0Fh
                mov     ax, 1
                rol     ax, cl
                test    ax, bx
                jnz     repflg
                or      bx, ax
                or      dx, ax
                test    ch, 16
                jnz     nexflg
                xor     dx, ax
nexflg:
                mov     di, si
                push    ds
                pop     es
                call    scanp
                jmp     getflg
dispregline:
                cs
                lodsw
                call    out
                mov     al, ah
                call    out
                mov     al, "="
                call    out
                mov     dx, [bx]
                inc     bx
                inc     bx
                call    out16
                call    blank
                call    blank
                loop    dispregline
                ret
repflg:
                mov     ax, 4600h+"D"
ferr:
                call    savchg
err:
                call    out
                mov     al, ah
                call    out
                mov     si, errmes
                jmp     print

savchg:
                mov     [fsave], dx
                ret
                
flgerr:
                mov     ax, 4600h+"B"
                jmp     ferr

dispflags:
                mov     si, flgtab
                mov     cx, 16
                mov     dx, [fsave]
dflags:
                cs
                lodsw
                shl     dx, 1
                jc      flagset
                mov     ax, [cs:si+30]
flagset:
                or      ax, ax
                jz      nextflg
                call    out
                mov     al, ah
                call    out
                call    blank
nextflg:
                loop    dflags
                ret

regtab:
                db      "AXBXCXDXSPBPSIDIDSESSSCSIPPC"
regdif:         equ     axsave-regtab

flgtab:
                dw      0
                dw      0
                dw      0
                dw      0
                db      "OV"
                db      "DN"
                db      "EI"
                dw      0
                db      "NG"
                db      "ZR"
                dw      0
                db      "AC"
                dw      0
                db      "PE"
                dw      0
                db      "CY"
                dw      0
                dw      0
                dw      0
                dw      0
                db      "NV"
                db      "UP"
                db      "DI"
                dw      0
                db      "PL"
                db      "NZ"
                dw      0
                db      "NA"
                dw      0
                db      "PO"
                dw      0
                db      "NC"

header:         db      0Dh, 0Ah, 0Ah, "Simple 8086 P2 Emulator", 0Dh, 8Ah
synerr          db      "^"
errmes:         db      " Error", 13, 10+80h

;               RESET vector

                times   0fff0h - ($-$$) db 90h
                db      0eah
                dw      reset, 0f000h
                times   10000h - ($-$$) db 00h


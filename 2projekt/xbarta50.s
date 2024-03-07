; Autor reseni: Stepan Barta xbarta50

; Projekt 2 - INP 2022
; Vernamova sifra na architekture MIPS64
; xbarta50-r10-r19-r3-r26-r0-r4
; DATA SEGMENT
                .data
login:          .asciiz "xbarta50"  ; sem doplnte vas login
cipher:         .space  17  ; misto pro zapis sifrovaneho loginu

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize "funkce" print_string)

; CODE SEGMENT
                .text
main:           
                addi r3,r0,123
                addi r4,r0,96
                addi r26,r0,0
loopfirst:
                lb r10, login(r26)
                slt  r19,r4,r10
                beq  r19,r0,end
                addi r10,r10,2
                slt r19,r10,r3
                beq  r19,r0,fixfirst
loopsecond:
                sb r10,cipher(r26)
                addi r26,r26,1
                lb r10, login(r26)
                slt  r19,r4,r10
                beq  r19,r0,end
                subu r10,r10,r19
                slt r19,r4,r10
                beq r19,r0,fixsecond
loopthird:
                sb r10,cipher(r26)
                addi r26,r26,1
                b loopfirst
fixfirst:
                addi r19,r0,26
                subu r10,r10,r19
                b loopsecond
fixsecond:      
                addi r10,r10,26
                b loopthird
end:
                addi r26,r26,1
                addi r10,r0,0
                sb r10,cipher(r26)
                daddi r4,r0,cipher
                jal     print_string 
                syscall 0
print_string:   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address

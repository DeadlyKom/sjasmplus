# file opened: mmu.asm
  1   0000              ; DOCS design (happened here, while working on it):
  2   0000              ;
  3   0000              ;     MMU <first slot number> [<last slot number>|<single slot option>], <page number>
  4   0000              ;
  5   0000              ; Maps memory page(s) to slot(s), similar to SLOT + PAGE combination, but allows to set up
  6   0000              ; whole range of consecutive slots (with consecutive memory pages). Or when only single
  7   0000              ; slot is specified, extra option can be used to extend particular slot functionality.
  8   0000              ; The slot behaviour will stay set in the current DEVICE until reset by another MMU
  9   0000              ; specifying same slot (even as part of range, that will clear the option to "default").
 10   0000              ;
 11   0000              ; Single slot option (default state is: no error/warning and no wrap = nothing special):
 12   0000              ;     e = error on writing beyond last byte of slot
 13   0000              ;     w = warning on writing beyond last byte of slot
 14   0000              ;     n = wrap address back to start of slot, map next page
 15   0000              ;
 16   0000
 17   0000                  DEVICE NONE         ; set "none" explicitly, to avoid "global device" feature
mmu.asm(18): warning: MMU is allowed only in real device emulation mode (See DEVICE)
 18   0000                  MMU                 ;; warning about non-device mode
 19   0000                  DEVICE ZXSPECTRUM128
 20   0000
 21   0000                  ;; error messages (parsing test)
mmu.asm(22): error: [MMU] First slot number parsing failed: MMU !
 22   0000                  MMU !
mmu.asm(23): error: [MMU] Second slot number parsing failed: MMU 1
 23   0000                  MMU 1
mmu.asm(24): error: [MMU] Second slot number parsing failed: MMU 1 !
 24   0000                  MMU 1 !
mmu.asm(25): warning: [MMU] Unknown slot option (legal: e, w, n): x 
mmu.asm(25): error: [MMU] Comma and page number expected after slot info: MMU 1 x 
 25   0000                  MMU 1 x ; white space (or comma) after char to detect it as unknown option
mmu.asm(26): warning: [MMU] Unknown slot option (legal: e, w, n): x,
mmu.asm(26): error: [MMU] Page number parsing failed: MMU 1 x,
 26   0000                  MMU 1 x,
mmu.asm(27): error: [MMU] Comma and page number expected after slot info: MMU 1 1
 27   0000                  MMU 1 1
mmu.asm(28): error: [MMU] Page number parsing failed: MMU 0,
 28   0000                  MMU 0,
mmu.asm(29): error: [MMU] Page number parsing failed: MMU 0 1,
 29   0000                  MMU 0 1,
mmu.asm(30): error: [MMU] Page number parsing failed: MMU 0 e,
 30   0000                  MMU 0 e,
mmu.asm(31): error: [MMU] Page number parsing failed: MMU 0 e,!
 31   0000                  MMU 0 e,!
 32   0000
 33   0000                  ;; correct syntax, invalid arguments
mmu.asm(34): error: [MMU] Requested page(s) must be in range 0..7
 34   0000                  MMU 0,8
mmu.asm(35): error: [MMU] Slot number(s) must be in range 0..3 and form a range
 35   0000                  MMU 4,0
mmu.asm(36): error: [MMU] Slot number(s) must be in range 0..3 and form a range
 36   0000                  MMU 3 4,0
mmu.asm(37): error: [MMU] Requested page(s) must be in range 0..7
 37   0000                  MMU 0 0,8
mmu.asm(38): error: [MMU] Slot number(s) must be in range 0..3 and form a range
 38   0000                  MMU 1 0,0
mmu.asm(39): error: [MMU] Requested page(s) must be in range 0..7
 39   0000                  MMU 0 2,6   ; map pages 6, 7, 8 -> 8 is wrong
 40   0000
 41   0000                  ;; test functionality
 42   0000                  ; set init markers in pages 0, 5, 6 and 7
 43   0000 37 37            DB  "77"
 43   0002                ORG 0xC000
 43   C000 30 30          DB "00"
 43   C002                ORG 0xC000, 5
 43   C000 35 35          DB "55"
 43   C002                ORG 0xC000, 6
 43   C000 36 36          DB "66"
 44   C002                  PAGE 7
 44   C002                ASSERT {0xC000} == "77"
 44   C002                PAGE 6
 44   C002                ASSERT {0xC000} == "66"
 45   C002                  PAGE 5
 45   C002                ASSERT {0xC000} == "55"
 45   C002                PAGE 0
 45   C002                ASSERT {0xC000} == "00"
 46   C002
 47   C002                  ; test simple page-in
 48   C002                  MMU 0, 5
 48   C002                ASSERT {0} == "55"
 49   C002                  MMU 1 3, 5
 49   C002                ASSERT {0x4000} == "55"
 49   C002                ASSERT {0x8000} == "66"
 49   C002                ASSERT {0xC000} == "77"
 50   C002
 51   C002                  ;; test slot options (these are confined to single slot only, not to range)
 52   C002                  ; error option (guarding machine code write outside of current slot)
 53   C002                  MMU 1 e, 5
 53   C002                ASSERT {0x4000} == "55"
 54   C002                  ORG 0x7FFF
mmu.asm(54): error: Write outside of memory slot: 32768
 54   7FFF 36 73          ld (hl),'s'   ; should be error, 2B opcode leaving slot memory
 55   8001                  ASSERT {0x8000} == "6s"     ; but damage is done in the virtual memory, that's how it is
 56   8001                  ; while escaping from slot through ORG should be legal
 57   8001                  ORG 0x7FFF
 57   7FFF 00             nop
 57   8000                ORG 0x8000
 57   8000 36 36          DB "66"
 58   8002                  ; changing page within tainted slot will keep the guarding ON
 59   8002                  SLOT 1
 59   8002                PAGE 6
 59   8002                ASSERT {0x4000} == "66"           ; map page 6 also into slot 1
 60   8002                  ORG 0x7FFF
mmu.asm(60): error: Write outside of memory slot: 32768
 60   7FFF 36 73          ld (hl),'s'
 60   8001                ASSERT {0x8000} == "6s" ; error + damage check
 61   8001
 62   8001                  ; verify clearing option by another MMU
 63   8001                  MMU 1, 5
 63   8001                ASSERT {0x4000} == "55"
 64   8001                  ORG 0x7FFF
 64   7FFF 36 36          ld (hl),'6'
 64   8001                ASSERT {0x8000} == "66" ; no error
 65   8001
 66   8001                  ; warning option (guarding machine code write outside of current slot)
 67   8001                  MMU 1 w, 5
 67   8001                ASSERT {0x4000} == "55"
 68   8001                  ORG 0x7FFF
mmu.asm(68): warning: Write outside of memory slot
 68   7FFF 36 73          ld (hl),'s'   ; should be warning, 2B opcode leaving slot memory
 69   8001                  ASSERT {0x8000} == "6s"     ; but damage is done in the virtual memory, that's how it is
 70   8001                  ; while escaping from slot through ORG should be legal
 71   8001                  ORG 0x7FFF
 71   7FFF 00             nop
 71   8000                ORG 0x8000
 71   8000 36 36          DB "66"
 72   8002                  ; changing page within tainted slot will keep the guarding ON
 73   8002                  SLOT 1
 73   8002                PAGE 6
 73   8002                ASSERT {0x4000} == "66"           ; map page 6 also into slot 1
 74   8002                  ORG 0x7FFF
mmu.asm(74): warning: Write outside of memory slot
 74   7FFF 36 73          ld (hl),'s'
 74   8001                ASSERT {0x8000} == "6s" ; warning + damage check
 75   8001
 76   8001                  ; verify clearing option by another MMU when the slot is part of range
 77   8001                  MMU 0 2, 5
 77   8001                ASSERT {0x4000} == "6s"
 78   8001                  ORG 0x7FFF
 78   7FFF 36 37          ld (hl),'7'
 78   8001                ASSERT {0x8000} == "77" ; no warning
 79   8001
 80   8001                  ; next option making the memory wrap, automatically mapping in next page
 81   8001                  MMU 1 n, 2
 82   8001                  ORG 0x4000
 82   4000 6E 6E 6E...    BLOCK 3*16384, 'n' ; fill pages 2, 3 and 4 with 'n'
 83   4000                  ASSERT {0x4000} == "55" && {0x8000} == "77" ; page 5 is mapped in after that block
 84   4000                  SLOT 1                      ; verify the block write
 85   4000                  PAGE 2
 85   4000                ASSERT {0x4000} == "nn"
 86   4000                  PAGE 3
 86   4000                ASSERT {0x4000} == "nn"
 87   4000                  PAGE 4
 87   4000                ASSERT {0x4000} == "nn"
 88   4000
 89   4000                  ; do the wrap-around test with instructions, watch labels land into different pages
 90   4000                  MMU 1 n, 4
 91   4000                     
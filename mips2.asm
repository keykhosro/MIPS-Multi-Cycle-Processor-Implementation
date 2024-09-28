addi $t0,$zero,2
addi $t1,$zero,5
add $t2,$zero,$zero
add $s0,$zero,$zero
addi $s2,$zero,4
addi $s1,$zero,50
loop:
add $t5,$t2,$t1
xor $t6,$t5,$t0

sw $t6,68($s2)
addi $s2,$s2,4
add $t0,$t1,$zero
add $t1,$t2,$zero
add $t2,$t6,$zero
addi $s0,$s0,1
bne $s0,$s1,loop
add $s3,$s2,$s1

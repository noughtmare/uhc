

boolbit :: Bool -> Int
boolbit False = 99
boolbit True  = 37

main = <PRINT_INT> (boolbit (12==15 || 34/=35 || 'A'=='A' || 'C'/='D'))

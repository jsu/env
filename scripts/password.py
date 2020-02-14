# -*- coding: utf-8 -*-
import string
from random import choice, shuffle
# string.printable[:-6] = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~' 

LENGTH = 50
EXCLUDE_USER_DEFINED = ''
EXCLUDE_SIMILAR = 'il1Lo0O'
EXCLUDE_AMBIGUOUS = '{}[]()/\\\'"`~,;:.<>'
EXCLUDE_SYMBOLS = '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~' 

exclude = EXCLUDE_USER_DEFINED
#exclude += EXCLUDE_SIMILAR
#exclude += EXCLUDE_AMBIGUOUS
#exclude += EXCLUDE_SYMBOLS
charset = list(set(string.printable[:-6]) - set(exclude))

for counter in range(10):
    print('---------1----|----2---------3-|-------4---------5')
    password = list(choice(charset) for i in range(LENGTH))
    shuffle(password)
    print(''.join(password))


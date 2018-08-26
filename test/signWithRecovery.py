import sys
import hashlib
import sha3
import binascii
from web3.auto import w3
from web3 import Web3
from eth_account.messages import defunct_hash_message
import time
import sys

# Recovery Address - 0xa66B994Fe08196c894E0d262822ed5538D9292CD;
# Pkey - 0xdf0a2a41ce9b662e3a38d2a6eb4e09d288702ee552f8e120a998e8f2752fed9a

#address = "8f0f50926d9D624Fe6C64cCF27603F0D73fc0C54"
nonce = int(time.time())
address="0x08970fed061e7747cd9a38d680a601510cb659fb"
try:
    address = sys.argv[1]
    print("Using Address: " + address)
except:
    pass
#new_owner_address = bytes.fromhex(address)
new_owner_address = Web3.toChecksumAddress(address)
key = 0xdf0a2a41ce9b662e3a38d2a6eb4e09d288702ee552f8e120a998e8f2752fed9a


s = sha3.keccak_256()
#s.update(new_owner_address)
#s.update(binascii.unhexlify('{:0256x}'.format(nonce)))
#message_hash = s.hexdigest()
message_hash = Web3.toHex(Web3.soliditySha3(['address','uint256'], [new_owner_address,nonce]))
sig = w3.eth.account.signHash(message_hash, key)
print(sig)
#print('"0x' + address + '","0x' + message_hash +'","' + hex(sig['r']) + '","' + hex(sig['s']) + '","' + str(sig['v']) + '"')
print('"' + address + '","' + hex(sig['r']) + '","' + hex(sig['s']) + '","' + str(sig['v']) + '","' + str(Web3.toInt(nonce)) + '"')


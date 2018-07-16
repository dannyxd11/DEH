pragma solidity ^0.4.21;

import "./DEH.sol";

contract MoneyControl{
    
    address internal DEHAddress;
    uint256 internal recoveryActiveTill = 0;
    mapping(address => bool) internal owners;
    // Update with recovery address before deploying
    address internal recovery = 0xa66B994Fe08196c894E0d262822ed5538D9292CD; 

    event Transaction(address recipient, uint value);        
    event Sent(address from, address to, uint amount);
    event HashFailed(bytes32 calculatedHash, bytes32 hash, address addr);
    event PerformingRecovery(address addr); 
    event PrintRecovered(address recovered, address recovery);
    event PreHash(bytes hashval);    
    
    constructor(address _DEHAddress) public{
        DEHAddress = _DEHAddress;
        owners[msg.sender] = true;
    }
    
    modifier recoveryInitCheck(address addr, bytes32 hash, bytes32 r, bytes32 s, uint8 v){
        address recovered = ecrecover(hash, v, r, s);
        emit PrintRecovered(recovered, recovery);
        if(recovered == recovery){
            bytes32 calculatedHash = keccak256(addr);
            emit PreHash(abi.encodePacked("\x19Ethereum Signed Message:\n20", addr));
            if(calculatedHash == hash){
                emit PerformingRecovery(addr);
                _;
            }else{
                emit HashFailed(calculatedHash, hash, addr);
            }
        }
    }
    
    modifier recoveryCheck(){
        require(now < recoveryActiveTill);
        _;
    }
    
    function transferViaDEH(address recipient, uint val) internal returns(bool){
        emit Transaction( recipient, val); 
        //return DEHAddress.call.value(val)(bytes4(keccak256("deposit(address)")), recipient);
        DEH dehInstance = DEH(DEHAddress);
        return dehInstance.deposit.value(val)(recipient);
    }

    function showRecovery() public view returns(address){ // Only owners?
        return recovery;
    }
    
    function isOwner(address query) public view returns(bool){ // Only owners?
        return owners[query];
    }
    
    // Need function to update recovery keys
    // Below abstract instructions to be implemented in child contract
    function failsafe() public returns(bool); 
    function init_recover(address addr, bytes32 hash, bytes32 r, bytes32 s, uint8 v) public recoveryInitCheck(addr, hash, r, s, v) returns (bool);
}


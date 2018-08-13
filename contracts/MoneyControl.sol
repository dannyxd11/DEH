pragma solidity ^0.4.24;

import "./DEH.sol";
import "./Ownable.sol";

contract MoneyControl is Ownable {
    using SafeMath for uint256;
    address internal DEHAddress;
    DEH internal DEHInstance;        
    address internal recovery = 0xa66B994Fe08196c894E0d262822ed5538D9292CD; // Update with recovery address before deploying
    bool private paymentsSuspended = false;
    uint nonce = 1;

    event Transaction(address recipient, uint256 value);        
    event Sent(address from, address to, uint256 amount);
    event HashFailed(bytes32 calculatedHash, bytes32 hash, address addr);
    event PerformingRecovery(address addr); 
    event PrintRecovered(address recovered, address recovery);
    event PreHash(bytes hashval);
    event PaymentsSuspended();
    event PaymentsResumed();    
    event PaymentsCancelled(address[] addr);
    
    constructor(address _DEHAddress, address _ValidatorService, address _RuleSet) Ownable() public{
        DEHAddress = _DEHAddress;    
        DEHInstance = DEH(DEHAddress);    
        DEHInstance.initialise(_ValidatorService, _RuleSet);        
    }
    
    modifier recoveryInitCheck(address addr, bytes32 hash, bytes32 r, bytes32 s, uint8 v, uint _nonce){
        require(_nonce > nonce, "Nonce has been reused");
        nonce = _nonce;
        // address recovered = ecrecover(hash, v, r, s);
        // emit PrintRecovered(recovered, recovery);
        if(ecrecover(hash, v, r, s) == recovery){
            bytes32 calculatedHash = keccak256(abi.encodePacked(toBytes(addr), nonce));            
            emit PreHash(abi.encodePacked("\x19Ethereum Signed Message:\n20", addr));
            if(calculatedHash == hash){
                emit PerformingRecovery(addr);
                _;
            }else{
                emit HashFailed(calculatedHash, hash, addr);
            }
        }
    }

    modifier paymentsAllowed(){
        require(paymentsSuspended == false);
        _;        
    }

    
    function transferViaDEH(address recipient, uint256 val) internal paymentsAllowed() returns(bool){
        emit Transaction(recipient, val);        
        return DEHInstance.deposit.value(val)(recipient);
    }

    function checkPending(address recipient) public view onlyOwner() returns (uint256){        
        return DEHInstance.checkWithdrawableAsContract(recipient);
    }

    function cancelPayment(address recipient) public onlyOwner() returns (bool){        
        return DEHInstance.cancelPayment(recipient);
    }

    function getPendingPayments() public view onlyOwner() returns (address[]){
        return DEHInstance.pendingPayments();
    }

    function showRecovery() public view returns(address){ 
        return recovery;
    }    
    
    // Need function to update recovery keys
    // Below abstract instructions to be implemented in child contract
    function failsafe() public onlyOwner() returns(bool); 
    function recover(address addr, bytes32 hash, bytes32 r, bytes32 s, uint8 v, uint _nonce) public recoveryInitCheck( addr,  hash, r, s, v, _nonce);

    function toBytes(address a) private pure returns (bytes b){
        assembly {
            let m := mload(0x40)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
            mstore(0x40, add(m, 52))
            b := m
        }
        return b;
    }

    function suspendPayments() internal returns (bool){
        paymentsSuspended = true;
        emit PaymentsSuspended();
        return true;
    }

    function resumePayments() internal returns (bool){
        paymentsSuspended = false;
        emit PaymentsResumed();
        return true;
    }

    function () public payable {
        require(msg.sender == DEHAddress, "Payments only accepted from the DEH (Refund/Cancellation)");
    }            

}


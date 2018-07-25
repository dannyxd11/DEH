pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./DEH.sol";
import "./Ownable.sol";

contract MoneyControl is Ownable {
    using SafeMath for uint256;
    address internal DEHAddress;
    DEH internal DEHInstance;
    uint256 internal recoveryActiveTill = 0;    
    // Update with recovery address before deploying
    address internal recovery = 0xa66B994Fe08196c894E0d262822ed5538D9292CD; 
    bool private paymentsSuspended = false;

    event Transaction(address recipient, uint256 value);        
    event Sent(address from, address to, uint256 amount);
    event HashFailed(bytes32 calculatedHash, bytes32 hash, address addr);
    event PerformingRecovery(address addr); 
    event PrintRecovered(address recovered, address recovery);
    event PreHash(bytes hashval);
    event PaymentsSuspended();
    event PaymentsResumed();    
    event PaymentsCancelled(address[] addr);
    
    struct RecoveryParams{
        address addr; 
        bytes32 hash; 
        bytes32 r; 
        bytes32 s; 
        uint8 v;
    }

    constructor(address _DEHAddress) Ownable() public{
        DEHAddress = _DEHAddress;    
        DEHInstance = DEH(DEHAddress);    
    }
    
    modifier recoveryInitCheck(RecoveryParams params){
        address recovered = ecrecover(params.hash, params.v, params.r, params.s);
        emit PrintRecovered(recovered, recovery);
        if(recovered == recovery){
            bytes32 calculatedHash = keccak256(toBytes(params.addr));
            emit PreHash(abi.encodePacked("\x19Ethereum Signed Message:\n20", params.addr));
            if(calculatedHash == params.hash){
                emit PerformingRecovery(params.addr);
                _;
            }else{
                emit HashFailed(calculatedHash, params.hash, params.addr);
            }
        }
    }
    
    modifier recoveryCheck(){
        require(now < recoveryActiveTill);
        _;
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
    function init_recover(RecoveryParams params) public recoveryInitCheck(params) returns (bool);

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

    function () public payable {}            

}


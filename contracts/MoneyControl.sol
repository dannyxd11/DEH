pragma solidity 0.4.24;

import "./DEH.sol";
import "./Ownable.sol";


/*
* @title	Money Control contract to be inheritied by appropriate contracts to use a 
* Decentralised Escape Hatch to send payments in a safe and temporarily reversable manor.
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/
contract MoneyControl is Ownable {
    using SafeMath128 for uint128;
    using SafeMath64 for uint64;        
    DEH internal dehInstance;        
    // Update Recovery Address before deployment
    address internal recovery = 0xa66B994Fe08196c894E0d262822ed5538D9292CD; 
    bool private paymentsSuspended = false;
    uint256 public nonce = 1;

    event Transaction(address recipient, uint256 value);        
    event Sent(address from, address to, uint256 amount);
    event FailedRecovery(bytes32 calculatedHash, uint256 _nonce);
    event PerformingRecovery(address addr);         
    event PaymentsSuspended();
    event PaymentsResumed();    
    event PaymentsCancelled(address[] addr);
    event PartialPaymentsCancelled();
    event PartialRecovery();

    modifier recoveryInitCheck(address addr, bytes32 r, bytes32 s, uint8 v, uint256 _nonce) {
        require(_nonce > nonce, "Nonce has been reused");        
        nonce = _nonce;
        bytes32 calculatedHash = keccak256(abi.encodePacked(addr, _nonce));        
        if (ecrecover(calculatedHash, v, r, s) == recovery) {                                            
            emit PerformingRecovery(addr);            
            _;            
        } else {
            emit FailedRecovery(calculatedHash, nonce);
        }
    }

    modifier paymentsAllowed() {
        require(paymentsSuspended == false, "Payments are suspended");
        _;
    }

    constructor(address _dehAddress, address _validatorService, address _ruleSet) 
    public {          
        dehInstance = DEH(_dehAddress);
        dehInstance.initialise(_validatorService, _ruleSet);
    }

    function () 
    public 
    payable {
        require(msg.sender == address(dehInstance), "Payments only accepted from the DEH (Refund/Cancellation)");
    }   

    function withdrawFromDEH(address contractAddress) 
    public 
    returns(bool) {
        return dehInstance.withdraw(contractAddress);
    } 

    function checkPending(address recipient) 
    public onlyOwner() 
    returns (uint128) { 
        uint128 reward;
        uint128 value;
        (value, reward) = dehInstance.checkWithdrawableAsContract(recipient);
        return value;
    }

    function cancelPayment(address recipient) 
    public onlyOwner() 
    returns (bool) {        
        return dehInstance.cancelPayment(recipient);
    }

    function getPendingPayments() 
    public view 
    onlyOwner() 
    returns (address[]) {
        return dehInstance.pendingPayments();
    }

    function showRecovery() 
    public view 
    returns(address) { 
        return recovery;
    }    
       
    function failsafe() 
    public  onlyOwner() 
    returns(bool); 

    function recover(address addr, bytes32 r, bytes32 s, uint8 v, uint _nonce) 
    public recoveryInitCheck( addr, r, s, v, _nonce) 
    returns(bool);       

    function suspendPayments() 
    internal 
    returns (bool) {
        paymentsSuspended = true;
        emit PaymentsSuspended();
        return true;
    }

    function resumePayments() 
    internal 
    returns (bool) {
        paymentsSuspended = false;
        emit PaymentsResumed();
        return true;
    }

    function transferViaDEH(address recipient, uint256 val) 
    internal paymentsAllowed() 
    returns(bool) {
        emit Transaction(recipient, val);        
        return dehInstance.deposit.value(val)(recipient);
    }

      
    


   

}


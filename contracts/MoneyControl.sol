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
    // Update Recovery Address before deployment!!!
    address public recovery = 0xa66B994Fe08196c894E0d262822ed5538D9292CD; 
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

    /*
     * @notice  Constructor that initialises the DEH contract  
     * @param	addresses for the DEH, Validator Service and Rule Set   
     */
    constructor(address _dehAddress, address _validatorService, address _ruleSet) 
    public {          
        dehInstance = DEH(_dehAddress);
        dehInstance.initialise(_validatorService, _ruleSet);
    }

    /*
     * @notice	Only accepts payments if they are from the DEH. 
     */
    function () 
    public 
    payable {
        require(msg.sender == address(dehInstance), "Payments only accepted from the DEH (Refund/Cancellation)");
    }   

    /*
     * @notice	Used by smart contract to to withdraw any funds pending for it from DEH
     * @dev	    Usually used in a new contract after a recovery scenario described in paper
     * @param	contractADdress - address of smart contract that deposited funds into DEH
     * @return  returns true if DEH withdrawal was successful.
     */
    function withdrawFromDEH(address contractAddress) 
    public 
    returns(bool) {
        return dehInstance.withdraw(contractAddress);
    } 

    /*
     * @notice	Used by smart contract to see how much will be refunded for an account     
     * @param	recipient - address of account to look up.
     * @return  returns value that will be refunded.
     */
    function checkPending(address recipient) 
    public onlyOwner() 
    returns (uint128) { 
        uint128 reward;
        uint128 value;
        (value, reward) = dehInstance.checkWithdrawableAsContract(recipient);
        return value;
    }

    /*
     * @notice	Used by smart contract to cancel a payment in the DEH.
     * @dev	    Only allowed to be called by contract owner (usually in failsafe)
     * @param	recipient - address of account to look up. Smart contract can only look at 
     *          accounts for its own contract
     * @return  returns (value, reward) to the smart contract
     */
    function cancelPayment(address recipient) 
    public onlyOwner() 
    returns (bool) {        
        return dehInstance.cancelPayment(recipient);
    }

    /*
     * @notice	Used by smart contracts to see payments that can be cancelled.
     * @dev	    Only the Owner should be able to trigger this (usually in failsafe)
     * @return  returns address array of accounts to be cancelled.
     */
    function getPendingPayments() 
    public view 
    onlyOwner() 
    returns (address[]) {
        return dehInstance.pendingPayments();
    }
       
    /*
     * @notice	Function signatures for failsafe and recovery
     * @dev	    Expected to be fully implemented in smart contract inheriting from this
     * @param	recovery - accepts address and _nonce along with relevant r, s, v 
     *          from ECDSA signature signed by recovery
     * @return  returns (value, reward) to the smart contract
     */
    function failsafe() 
    public  onlyOwner() 
    returns(bool); 

    function recover(address addr, bytes32 r, bytes32 s, uint8 v, uint _nonce) 
    public recoveryInitCheck( addr, r, s, v, _nonce) 
    returns(bool);       

    /*
     * @notice	Used internally to suspend transactions
     * @dev	    ideally should only be activated inside failsafe function
     * @return  returns true if changed successfully
     */
    function suspendPayments() 
    internal 
    returns (bool) {
        paymentsSuspended = true;
        emit PaymentsSuspended();
        return true;
    }

    /*
     * @notice	Used internally to resume transactions
     * @dev	    Ideally should only be activated inside recovery in some scenarios (avoid misuse)
     * @return  returns true if changed successfully
     */
    function resumePayments() 
    internal 
    returns (bool) {
        paymentsSuspended = false;
        emit PaymentsResumed();
        return true;
    }

    /*
     * @notice	Used by smart contract to send funds to the DEH.     
     * @param	recipient - address of account to send val funds to
     * @return  returns true if accepted by DEH
     */
    function transferViaDEH(address recipient, uint256 val) 
    internal paymentsAllowed() 
    returns(bool) {
        emit Transaction(recipient, val);        
        return dehInstance.deposit.value(val)(recipient);
    }

      
    


   

}


pragma solidity 0.4.24;
import "./MoneyControl.sol";

/*
* @title	Simple coin contract to demonstrate the use of the DEH system.
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/

contract Coin is MoneyControl {

    using SafeMath128 for uint128;
    using SafeMath64 for uint64;
    uint128 public constant TOTAL_SUPPLY = 100000000000000000000000;
    uint128 internal remainingsupply;
    mapping (address => Account) internal balances;
    address[] internal activeAccounts;     
    address internal oldCoin = 0xec5bee2dbb67da8757091ad3d9526ba3ed2e2137;
    
    struct Account {
        uint128 balance;
        uint64 index;
    }

    modifier onlyOld() {require(msg.sender == oldCoin, "Only accesible from old coin"); _;}   

    /*
     * @notice	Used to initialise the DEH with the Validator Service and Rule Set          
     */
    constructor(address _dehAddress, address _validatorService, address _ruleSet)  
    public
    MoneyControl(_dehAddress, _validatorService, _ruleSet) {        
        remainingsupply = TOTAL_SUPPLY;
    }

    /*
     * @notice	Allows balance updates without sending any msg.value
     * @dev	    Uses payable modifier - msg.value is used to update balance     
     * @returns true if balance update is successful
     */
    function allocate(address account, uint128 amount) 
    public onlyOld 
    returns (bool) {
        require(amount <= remainingsupply, "Not enough supply to complete purchase"); 
        if (balances[account].balance == 0) {balances[account].index = uint64(activeAccounts.push(account)).sub(1);}
        balances[account].balance = balances[account].balance.add(amount);        
        remainingsupply = remainingsupply.sub(uint128(amount));
        return true;
    } 

    /*
     * @notice	Buy coins and update state in contract
     * @dev	    Uses payable modifier - msg.value is used to update balance     
     * @returns true if balance update is successful
     */
    function buy() 
    public payable 
    returns(bool) {
        require(msg.value <= remainingsupply, "Not enough supply to complete purchase"); 
        if (balances[msg.sender].balance == 0) { 
            balances[msg.sender].index = uint64(activeAccounts.push(msg.sender) - 1); 
        }
        balances[msg.sender].balance = balances[msg.sender].balance.add(uint128(msg.value));        
        remainingsupply = remainingsupply.sub(uint128(msg.value));
        return true;
    }
    
    /*
     * @notice	Sell the Coins the account has and send value to DEH
     * @dev	    Uses transferViaDEH from the MoneyController
     * @params  Amount of Coins to sell
     * @returns true if Transfer to DEH is successful
     */
    function sell(uint128 amountToSell) 
    public 
    returns(bool) {
        require(balances[msg.sender].balance >= amountToSell, "Insufficient Funds");
        balances[msg.sender].balance = balances[msg.sender].balance.sub(amountToSell);
        if (balances[msg.sender].balance == 0) {deleteAccount(msg.sender);}
        remainingsupply = remainingsupply.add(amountToSell);
        return transferViaDEH(msg.sender, amountToSell);                
    }

     /*
     * @notice	    Returns the remaining supply in the contract
     * @dev	        Used as an invariant sequence
     * @returns     Reamining supply (= TOTAL_SUPPLY - this.balance)
     */
    function checkRemainingSupply() 
    public view 
    returns(uint128) {
        return remainingsupply;
    }

    /*
     * @notice	   Allows an account to check his balance within the contract     
     * @returns    Account balance for msg.sender
     */
    function checkBalance() 
    public view 
    returns(uint128) {
        return balances[msg.sender].balance;
    }

    /*
     * @notice	Transfer balance from one Coin account to another
     * @dev	    Emits 'Sent' event
     * @params  Has recipient and the amount to transfer
     */
    function transfer(address receiver, uint128 amount) 
    public {
        if (balances[msg.sender].balance < amount) return;
        balances[msg.sender].balance = balances[msg.sender].balance.sub(amount);
        if (balances[msg.sender].balance == 0) {deleteAccount(msg.sender);}
        if (balances[receiver].balance == 0) {balances[receiver].index = uint64(activeAccounts.push(receiver)).sub(1);}
        balances[receiver].balance = balances[receiver].balance.add(amount);
        emit Sent(msg.sender, receiver, amount);
    }        
    
    /*
     * @notice	Recovery, transfers contract balance and updates accounts in new account
     * @dev	    Breaks if < 50000 gas ramining to avoid revert     
     * @param   Has addr for new contract, and signature parameters to check signature with ecrecover
     * @return  returns True indicating successful recovery invocation
     */
    function recover(address addr, bytes32 r, bytes32 s, uint8 v, uint nonce) 
    public recoveryInitCheck(addr, r, s, v, nonce) 
    returns(bool) {
        resumePayments();
        transferViaDEH(addr, address(this).balance);        
        suspendPayments();
        for (uint i = 0; i < activeAccounts.length; i++) {
            if (msg.gas < 50000) {emit PartialRecovery(); return false;}
            uint128 amount = balances[activeAccounts[i]].balance;
            balances[activeAccounts[i]].balance = 0;
            Coin(addr).allocate(activeAccounts[i], amount);    
            // deleteAccount(activeAccounts[i]);     
            emit Sent(addr, activeAccounts[i], amount);
            remainingsupply = remainingsupply.add(uint128(amount));
        }
        return true;
    }

     /*
     * @notice	Failsafe, cancels all pending payments in DEH and suspends payments
     * @dev	    Breaks if < 50000 gas ramining to avoid revert     
     * @return  returns True indicating successful failsafe invocation
     */
    function failsafe() 
    public onlyOwner() 
    returns (bool) {
        suspendPayments();
        address[] memory pending = getPendingPayments();             
        for (uint i = 0; i < pending.length; i++) {
            if (msg.gas < 50000) {emit PartialPaymentsCancelled(); return false;}
            address addr = pending[i];            
            uint128 amountRefunded = checkPending(addr);            
            require(cancelPayment(addr));
            if (balances[addr].balance == 0) {balances[addr].index = uint64(activeAccounts.push(addr)).sub(1);}
            balances[addr].balance = balances[addr].balance.add(amountRefunded);            
        }        
        return true;
    }

     /*
     * @notice	Used to check the invariant sequences within the coin contract     
     * @param	Addresses of the smart contract, and account to delete
     * @return  returns True indicating success, or triggers failsafe
     */
    function checkState() 
    public 
    returns (bool) {
        if (TOTAL_SUPPLY != remainingsupply + address(this).balance) { 
            // "Balance of this contract is aberrant with the total supply.");            
            return failsafe();
        } else { 
            uint supply = 0; // Check the balance in all accounts and remaining supply equals total supply
            for (uint i = 0; i < activeAccounts.length; i++) {
                // breaking early will cause next if statement to fail
                if (balances[activeAccounts[i]].balance > TOTAL_SUPPLY) {break;}  
                supply = supply + balances[activeAccounts[i]].balance;
            }
            if (supply + remainingsupply != TOTAL_SUPPLY) {return failsafe();}
        }
        return true;
    }
    

     /*
     * @notice	Used internally to remove accounts from activeAccounts array
     * @dev	    Can end up costing more gas.. so optimisation needed
     * @param	Addresses of the smart contract, and account to delete
     * @return  returns True indicating success
     */
    function deleteAccount(address addr) 
    internal 
    returns(bool) {
        require(balances[addr].balance == 0, "Account not empty before deletion");

        uint64 swapIndex = uint64(activeAccounts.length).sub(1);
        uint64 deleteIndex = balances[addr].index;
        address swapAddress = activeAccounts[swapIndex];

        activeAccounts[deleteIndex] = swapAddress;
        balances[swapAddress].index = deleteIndex;        
        delete activeAccounts[swapIndex];
        delete balances[addr];
        activeAccounts.length = uint64(activeAccounts.length).sub(1);        
        return true;
    }
}

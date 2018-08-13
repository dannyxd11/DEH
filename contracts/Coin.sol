pragma solidity ^0.4.24;
import "./MoneyControl.sol";

// melonport 
// securify
contract Coin is MoneyControl{
    using SafeMath for uint256;    
    uint256 totalsupply;
    uint256 remainingsupply;
    mapping (address => Account) public balances;
    address[] activeAccounts;     
    
    // This is the constructor whose code is
    // run only when the contract is created.
    constructor(address _DEHAddress, address _ValidatorService, address _RuleSet) MoneyControl(_DEHAddress, _ValidatorService, _RuleSet) public {
        totalsupply = 100000000000000000;
        remainingsupply = 100000000000000000;
    }

    struct Account{
        uint256 balance;
        uint256 index;
    }

    function send_to(address account) public payable returns(bool){ // Allocate funds 
        require(msg.value / 10**6 <= remainingsupply, "Not enough supply to complete purchase"); 
        if(balances[account].balance == 0){balances[account].index = activeAccounts.push(account) - 1;}
        balances[account].balance = balances[account].balance.add(msg.value);        
        remainingsupply = remainingsupply - msg.value / 10**6;
        return true;
    }

    function buy() public payable returns(bool){
        require(msg.value / 10**6 <= remainingsupply, "Not enough supply to complete purchase"); 
        if(balances[msg.sender].balance == 0){balances[msg.sender].index = activeAccounts.push(msg.sender) - 1;}
        balances[msg.sender].balance = balances[msg.sender].balance.add(msg.value);        
        remainingsupply = remainingsupply - msg.value / 10**6;
        return true;
    }
    
    function sell(uint256 amountToSell) public returns(bool){
        require(balances[msg.sender].balance >= amountToSell, "Insufficient Funds");
        balances[msg.sender].balance = balances[msg.sender].balance.sub(amountToSell);
        if(balances[msg.sender].balance == 0){deleteAccount(msg.sender);}
        remainingsupply = remainingsupply + amountToSell / 10**6;
        return transferViaDEH(msg.sender, amountToSell);                
    }
    
    function deleteAccount(address addr) internal returns(bool){
        require(balances[addr].balance == 0, "Account not empty before deletion");

        uint256 swapIndex = activeAccounts.length - 1;
        uint256 deleteIndex = balances[addr].index;
        address swapAddress = activeAccounts[swapIndex];

        activeAccounts[deleteIndex] = swapAddress;
        balances[swapAddress].index = deleteIndex;        
        delete activeAccounts[swapIndex];
        delete balances[addr];
        activeAccounts.length = activeAccounts.length - 1;        
        return true;
    }

    function checkTotalSupply() public view returns(uint256){
        return totalsupply;
    }

    function checkRemainingSupply() public view returns(uint256){
        return remainingsupply;
    }

    function checkBalance() public view returns(uint256){
        return balances[msg.sender].balance;
    }

    function transfer(address receiver, uint256 amount) public {
        if (balances[msg.sender].balance < amount) return;
        balances[msg.sender].balance = balances[msg.sender].balance.sub(amount);
        if(balances[msg.sender].balance == 0){deleteAccount(msg.sender);}
        if(balances[receiver].balance == 0){balances[receiver].index = activeAccounts.push(receiver) - 1;}
        balances[receiver].balance = balances[receiver].balance.add(amount);
        emit Sent(msg.sender, receiver, amount);
    }        
    
    function recover(address addr, bytes32 hash, bytes32 r, bytes32 s, uint8 v, uint nonce) public recoveryInitCheck(addr, hash, r , s, v, nonce){
        //DEHInstance.deposit.value(address(this).balance)(addr);
        // for(uint i = 0; i < activeAccounts.length; i++){
        //     uint amount = balances[activeAccounts[i]].balance;
        //     balances[activeAccounts[i]].balance = 0;
        //     Coin(addr).send_to.value(amount)(activeAccounts[i]);    
        //     deleteAccount(activeAccounts[i]);     
        // }
        emit PerformingRecovery(addr);
    }
    
    /*
     * Currently just retrievs pending payments from the DEH and suspends any future withdrawals
     *
     */
    function failsafe() public onlyOwner() returns (bool){
        suspendPayments();
        address[] memory pending = getPendingPayments();        
        for(uint i = 0; i < pending.length; i++){
            address addr = pending[i];            
            uint256 amountRefunded = checkPending(addr);            
            require(cancelPayment(addr));
            if(balances[addr].balance == 0){balances[addr].index = activeAccounts.push(addr) - 1;}
            balances[addr].balance = balances[addr].balance.add(amountRefunded);            
        }
        emit PaymentsCancelled(pending);
        return true;
    }

    function checkState() public onlyOwner() returns (bool){
        if(totalsupply != remainingsupply + address(this).balance / 10**6){ // "Balance of this contract is aberrant with the total supply.");            
            return failsafe();
        }else{ 
            uint supply = 0; // Check the balance in all accounts and remaining supply equals total supply
            for(uint i = 0; i < activeAccounts.length; i++){
                if(balances[activeAccounts[i]].balance > totalsupply){break;}  // breaking early will cause next if statement to fail
                supply = supply + balances[activeAccounts[i]].balance;
            }
            if(supply + remainingsupply != totalsupply ){ return failsafe(); }
        }
        return true;
    }
}
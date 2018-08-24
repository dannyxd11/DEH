pragma solidity ^0.4.24;
import "./MoneyControl.sol";

/*
* @title	Simple coin contract to demonstrate the use of the DEH system.
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/
contract Coin is MoneyControl{
    using SafeMath128 for uint128;
    using SafeMath64 for uint64;
    uint128 totalsupply;
    uint128 remainingsupply;
    mapping (address => Account) public balances;
    address[] activeAccounts;     
    address oldCoin = 0xec5bee2dbb67da8757091ad3d9526ba3ed2e2137;
    
    constructor(address _DEHAddress, address _ValidatorService, address _RuleSet) MoneyControl(_DEHAddress, _ValidatorService, _RuleSet) public {
        totalsupply = 100000000000000000000000;
        remainingsupply = 100000000000000000000000;
    }

    struct Account{
        uint128 balance;
        uint64 index;
    }

    modifier onlyOld(){require(msg.sender == oldCoin, "Only accesible from old coin"); _;}   

    function allocate(address account, uint64 amount) public  returns (bool){
        require(amount <= remainingsupply, "Not enough supply to complete purchase"); 
        if(balances[account].balance == 0){balances[account].index = uint64(activeAccounts.push(account) - 1);}
        balances[account].balance = balances[account].balance.add(uint128(amount));        
        remainingsupply = uint128(remainingsupply - amount);
        return true;
    } 

    function buy() public payable returns(bool){
        require(msg.value <= remainingsupply, "Not enough supply to complete purchase"); 
        if(balances[msg.sender].balance == 0){balances[msg.sender].index = uint64(activeAccounts.push(msg.sender) - 1);}
        balances[msg.sender].balance = balances[msg.sender].balance.add(uint128(msg.value));        
        remainingsupply = uint128(remainingsupply - msg.value);
        return true;
    }
    
    function sell(uint128 amountToSell) public returns(bool){
        require(balances[msg.sender].balance >= amountToSell, "Insufficient Funds");
        balances[msg.sender].balance = balances[msg.sender].balance.sub(amountToSell);
        if(balances[msg.sender].balance == 0){deleteAccount(msg.sender);}
        remainingsupply = remainingsupply + amountToSell;
        return transferViaDEH(msg.sender, amountToSell);                
    }
    
    function deleteAccount(address addr) internal returns(bool){
        require(balances[addr].balance == 0, "Account not empty before deletion");

        uint64 swapIndex = uint64(activeAccounts.length - 1);
        uint64 deleteIndex = balances[addr].index;
        address swapAddress = activeAccounts[swapIndex];

        activeAccounts[deleteIndex] = swapAddress;
        balances[swapAddress].index = deleteIndex;        
        delete activeAccounts[swapIndex];
        delete balances[addr];
        activeAccounts.length = activeAccounts.length - 1;        
        return true;
    }

    function checkTotalSupply() public view returns(uint128){
        return totalsupply;
    }

    function checkRemainingSupply() public view returns(uint128){
        return remainingsupply;
    }

    function checkBalance() public view returns(uint128){
        return balances[msg.sender].balance;
    }

    function transfer(address receiver, uint128 amount) public {
        if (balances[msg.sender].balance < amount) return;
        balances[msg.sender].balance = balances[msg.sender].balance.sub(amount);
        if(balances[msg.sender].balance == 0){deleteAccount(msg.sender);}
        if(balances[receiver].balance == 0){balances[receiver].index = uint64(activeAccounts.push(receiver) - 1);}
        balances[receiver].balance = balances[receiver].balance.add(amount);
        emit Sent(msg.sender, receiver, amount);
    }        
    
    function recover(address addr, bytes32 r, bytes32 s, uint8 v, uint nonce) public recoveryInitCheck(addr, r , s, v, nonce){
        resumePayments();
        transferViaDEH(addr, address(this).balance);        
        suspendPayments();
        for(uint i = 0; i < activeAccounts.length; i++){
            uint amount = balances[activeAccounts[i]].balance;
            balances[activeAccounts[i]].balance = 0;
            Coin(addr).allocate(activeAccounts[i], uint64(amount));    
            deleteAccount(activeAccounts[i]);     
            remainingsupply = uint128(remainingsupply + amount);
        }
    }

    // function approve() public {
    //     //
    // }
    
    /*
     * Currently just retrievs pending payments from the DEH and suspends any future withdrawals
     *
     */
    function failsafe() public onlyOwner() returns (bool){
        suspendPayments();
        address[] memory pending = getPendingPayments();        
        for(uint i = 0; i < pending.length; i++){
            address addr = pending[i];            
            uint128 amountRefunded = checkPending(addr);            
            require(cancelPayment(addr));
            if(balances[addr].balance == 0){balances[addr].index = uint64(activeAccounts.push(addr) - 1);}
            balances[addr].balance = balances[addr].balance.add(amountRefunded);            
        }
        emit PaymentsCancelled(pending);
        return true;
    }

    function checkState() public returns (bool){
        if(totalsupply != remainingsupply + address(this).balance){ // "Balance of this contract is aberrant with the total supply.");            
            return failsafe();
        }else{ 
            uint supply = 0; // Check the balance in all accounts and remaining supply equals total supply
            for(uint i = 0; i < activeAccounts.length; i++){
                if(balances[activeAccounts[i]].balance > totalsupply){break;}  // breaking early will cause next if statement to fail
                supply = supply + balances[activeAccounts[i]].balance;
            }
            if(supply + remainingsupply != totalsupply ){return failsafe();}
        }
        return true;
    }

      

}

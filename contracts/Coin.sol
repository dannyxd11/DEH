pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import "./MoneyControl.sol";

// melonport 
// securify
contract Coin is MoneyControl{
    using SafeMath for uint256;
    address public minter;

    mapping (address => uint256) public balances;        

    // This is the constructor whose code is
    // run only when the contract is created.
    constructor(address _DEHAddress) MoneyControl(_DEHAddress) public {
        minter = msg.sender;        
    }

    function mint(address receiver) public payable returns(bool){
        if (msg.sender != minter) revert();
        balances[receiver] = balances[receiver].add(msg.value);
        return true;
    }
    
    function sell(uint256 ammountToSell) public returns(bool){
        if(ammountToSell <= balances[msg.sender]){
            balances[msg.sender] = balances[msg.sender] - ammountToSell;
            return transferViaDEH(msg.sender, ammountToSell);
        }
        return false;
    }
    
    function checkBalance() public view returns(uint256){
        return balances[msg.sender];
    }

    function transfer(address receiver, uint256 amount) public {
        if (balances[msg.sender] < amount) return;
        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[receiver] = balances[receiver].add(amount);
        emit Sent(msg.sender, receiver, amount);
    }        
    
    function init_recover(RecoveryParams params) public recoveryInitCheck(params) returns (bool){
        recoveryActiveTill = now.add(60*60*2);
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
            balances[addr] = balances[addr].add(amountRefunded);            
        }
        emit PaymentsCancelled(pending);
        return true;
    }
}
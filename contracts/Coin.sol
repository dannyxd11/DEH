pragma solidity ^0.4.21;
import "./MoneyControl.sol";

// melonport 
// securify
contract Coin is MoneyControl{
    
    address public minter;
        
    mapping (address => uint) public balances;    
    bool itworked = false;

    // This is the constructor whose code is
    // run only when the contract is created.
    constructor(address _DEHAddress) MoneyControl(_DEHAddress) public {
        minter = msg.sender;
        owners[0xa66B994Fe08196c894E0d262822ed5538D9292CD] = true;        
    }

    function mint(address receiver) public payable returns(bool){
        if (msg.sender != minter) revert();
        balances[receiver] += msg.value; // Add some 'rate' conversion
        return true;
    }
    
    function sell(uint ammountToSell) public returns(bool){
        if(ammountToSell <= balances[msg.sender]){
            balances[msg.sender] = balances[msg.sender] - ammountToSell;
            return transferViaDEH(msg.sender, ammountToSell);
        }
        return false;
    }
    
    function checkBalance() public view returns(uint){
        return balances[msg.sender];
    }

    function transfer(address receiver, uint amount) public {
        if (balances[msg.sender] < amount) return;
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], amount);
        balances[receiver] = SafeMath.add(balances[receiver], amount);
        emit Sent(msg.sender, receiver, amount);
    }
    
    function getItworked() view public returns(bool) {
        return itworked;
    }
    
    function init_recover(address addr, bytes32 hash, bytes32 r, bytes32 s, uint8 v) public recoveryInitCheck(addr, hash, r, s, v) returns (bool){
        recoveryActiveTill = SafeMath.add(now, 60*60*2);
    }
    
    function failsafe() public returns (bool){
        return true;
    }
}
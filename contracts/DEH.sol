pragma solidity ^0.4.21;

contract DEH {
    mapping(address => mapping(address => Withdrawable)) payouts;
    mapping(address => ContractDelay) delayPeriods;
    
    uint defaultDelayPeriod = 10800;
    
    // todo - method for MC to reset graceperiod after 'panic' mode.
    // todo - method to prevent a single validator from DOSing
    
    event Deposit(address contractAddress, address recipient, uint value);
    event Withdrawal(address contractAddress, address recipient, uint value);
    event DelayTriggered(address contractAddress, uint delayAmount, address validator);
    event EarlyWithdrawalAttempt(address contractAddress, address recipient);
    event PaymentCancelled(address contractAddress, address recipient, uint value);

    struct Withdrawable{
        uint amount;
        uint timestamp;
    }
    
    struct ContractDelay{
        uint period;
        uint resetTime;
    }
    
    modifier onlyValidators(){
        _; // ToDo (Attribute Based Signatures?)
    }
    
    function checkTimeWindow(address contractAddress) private returns(uint){
        if(delayPeriods[contractAddress].period == 0){
            delayPeriods[contractAddress].period = defaultDelayPeriod;
            delayPeriods[contractAddress].resetTime = 0;
        }else if(now > delayPeriods[contractAddress].resetTime && delayPeriods[contractAddress].period != defaultDelayPeriod){
            delayPeriods[contractAddress].period = defaultDelayPeriod;
        }
        return delayPeriods[contractAddress].period;
    }
    
    function withdraw(address contractAddress) public returns(bool){    
        if(payouts[contractAddress][msg.sender].amount > 0){
            if(SafeMath.add(payouts[contractAddress][msg.sender].timestamp,checkTimeWindow(contractAddress)) < now ){                
                uint ammountToTransfer = payouts[contractAddress][msg.sender].amount;
                payouts[contractAddress][msg.sender].amount = 0;
                emit Withdrawal(contractAddress, msg.sender, ammountToTransfer);
                msg.sender.transfer(ammountToTransfer);
                return true;
            } 
        }
        emit EarlyWithdrawalAttempt(contractAddress, msg.sender);
        return false;
    }
    
    function checkWithdrawable(address contractAddress) public view returns(uint){
        return payouts[contractAddress][msg.sender].amount;
    }
    
    function deposit(address recipient) public payable returns(bool){ // Decide if contractAddress is needed here
        payouts[msg.sender][recipient].amount = SafeMath.add(payouts[msg.sender][recipient].amount, msg.value);
        payouts[msg.sender][recipient].timestamp = now;
        emit Deposit(msg.sender, msg.sender, msg.value);
        return true;
    }
    
    function delayPayments(address contractAddress) public onlyValidators returns(bool){
        uint delay = 60*60*24;
        delayPeriods[contractAddress].period = delay;
        delayPeriods[contractAddress].resetTime = SafeMath.add(now, delay);
        emit DelayTriggered(contractAddress, delay, msg.sender);
        return true;
    }
    
    function cancelPayment(address recipient) public returns(bool){
        uint value = payouts[msg.sender][recipient].amount;
        if(value > 0){
            payouts[msg.sender][recipient].amount = 0;
            emit PaymentCancelled(msg.sender, recipient, value);
            msg.sender.transfer(value);
        }
    }

    function () public payable {
        revert();
    }
}

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
        if(ammountToSell < balances[msg.sender]){
            balances[msg.sender] = balances[msg.sender] - ammountToSell;
            return transferViaDEH(msg.sender, ammountToSell);
        }
        return false;
    }
    
    function checkBalance() public view returns(uint){
        return balances[msg.sender];
    }

    function send(address receiver, uint amount) public {
        if (balances[msg.sender] < amount) return;
        balances[msg.sender] -= amount;
        balances[receiver] += amount;
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

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

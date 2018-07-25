pragma solidity ^0.4.21;

import "./SafeMath.sol";

contract DEH {
    mapping(address => PendingPayments) payouts;
    mapping(address => ContractDelay) delayPeriods;
    using SafeMath for uint256;
    uint256 defaultDelayPeriod = 10800;
    
    // todo - method for MC to reset graceperiod after 'panic' mode.
    // todo - method to prevent a single validator from DOSing
    
    event Deposit(address contractAddress, address recipient, uint256 value);
    event Withdrawal(address contractAddress, address recipient, uint256 value);
    event DelayTriggered(address contractAddress, uint256 delayAmount, address validator);
    event EarlyWithdrawalAttempt(address contractAddress, address recipient);
    event PaymentCancelled(address contractAddress, address recipient, uint256 value);
    event Timestamps(uint256 scheduled, uint256 check, uint256 _now);
    
    struct Withdrawable{
        uint256 amount;
        uint256 timestamp;
        uint256 index;
    }
    
    struct ContractDelay{
        uint256 period;
        uint256 resetTime;
    }
    
    struct PendingPayments{
        address[] pendingAddresses;
        mapping(address => Withdrawable) pendingPayments;
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
        if(payouts[contractAddress].pendingPayments[msg.sender].amount > 0){
            if(payouts[contractAddress].pendingPayments[msg.sender].timestamp.add(checkTimeWindow(contractAddress)) < now ){
                emit Timestamps(payouts[contractAddress].pendingPayments[msg.sender].timestamp, checkTimeWindow(contractAddress), now);
                uint256 ammountToTransfer = payouts[contractAddress].pendingPayments[msg.sender].amount;
                emptyAccount(contractAddress, msg.sender);                
                emit Withdrawal(contractAddress, msg.sender, ammountToTransfer);
                msg.sender.transfer(ammountToTransfer);
                return true;
            } 
        }
        emit EarlyWithdrawalAttempt(contractAddress, msg.sender);
        return false;
    }
    
    function checkWithdrawable(address contractAddress) public view returns(uint256){
        return payouts[contractAddress].pendingPayments[msg.sender].amount;
    }

    function checkWithdrawableAsContract(address recipient) public view returns(uint256){
        return payouts[msg.sender].pendingPayments[recipient].amount;
    }

    function pendingPayments() public view returns(address[]){
        return payouts[msg.sender].pendingAddresses;
    }

    
    function deposit(address recipient) public payable returns(bool){ // Decide if contractAddress is needed here
        uint256 index = payouts[msg.sender].pendingAddresses.push(recipient);
        payouts[msg.sender].pendingPayments[recipient].amount = payouts[msg.sender].pendingPayments[recipient].amount.add(msg.value);
        payouts[msg.sender].pendingPayments[recipient].timestamp = now;
        payouts[msg.sender].pendingPayments[recipient].index = index - 1;
        emit Deposit(msg.sender, msg.sender, msg.value);
        return true;
    }
    
    function delayPayments(address contractAddress) public onlyValidators returns(bool){
        uint256 delay = 60*60*24;
        delayPeriods[contractAddress].period = delay;
        delayPeriods[contractAddress].resetTime = now.add(delay);
        emit DelayTriggered(contractAddress, delay, msg.sender);
        return true;
    }
    
    function cancelPayment(address recipient) public returns(bool){
        uint256 value = payouts[msg.sender].pendingPayments[recipient].amount;
        
        
        if(value > 0 && payouts[msg.sender].pendingPayments[recipient].timestamp.add(checkTimeWindow(msg.sender)) >= now ){
            emptyAccount(msg.sender, recipient); 
            msg.sender.transfer(value);
            emit PaymentCancelled(msg.sender, recipient, value);
            return true;
        }
        return false;
    }


    function emptyAccount(address contractAddress, address recipient) internal returns(bool){
        payouts[contractAddress].pendingPayments[recipient].amount = 0;   

        uint256 swapIndex = payouts[contractAddress].pendingAddresses.length - 1;
        uint256 deleteIndex = payouts[contractAddress].pendingPayments[msg.sender].index;
        address swapAddress = payouts[contractAddress].pendingAddresses[swapIndex];

        payouts[contractAddress].pendingAddresses[deleteIndex] = swapAddress;
        payouts[contractAddress].pendingPayments[swapAddress].index = deleteIndex;        
        delete payouts[contractAddress].pendingAddresses[swapIndex];
        delete payouts[contractAddress].pendingPayments[recipient];
        payouts[contractAddress].pendingAddresses.length = payouts[contractAddress].pendingAddresses.length - 1;        
        return true;
    }

    function () public payable {
        revert();
    }
}


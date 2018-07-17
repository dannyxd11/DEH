pragma solidity ^0.4.21;

import "./SafeMath.sol";

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
    event Timestamps(uint scheduled, uint check, uint _now);

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
                emit Timestamps(payouts[contractAddress][msg.sender].timestamp, checkTimeWindow(contractAddress), now);
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


pragma solidity ^0.4.21;

import "./SafeMath.sol";
import "./ValidatorService.sol";
import "./RuleSet.sol";

contract DEH {
    mapping(address => PendingPayments) payouts;
    mapping(address => ContractDelay) delayPeriods;
    mapping(address => ValidatorService) ValidatorServices;    
    mapping(address => RuleSet) RuleSets;

    using SafeMath for uint256;
    uint256 defaultDelayPeriod = 3*60*60;
    uint rewardPercent = 2;
    
    // todo - method for MC to reset graceperiod after 'panic' mode.
    // todo - method to prevent a single validator from DOSing
    
    event Deposit(address contractAddress, address recipient, uint256 value);
    event Withdrawal(address contractAddress, address recipient, uint256 value);
    event DelayTriggered(address contractAddress, uint256 delayAmount, address validator);
    event EarlyWithdrawalAttempt(address contractAddress, address recipient);
    event Timestamps(uint256 scheduled, uint256 check, uint256 _now);    
    event CancellingPayment(uint256 value, uint256 reward, uint256 timestamp, uint256 _now, address recipient);

    struct Withdrawable{
        uint256 amount;
        uint256 timestamp;
        uint256 index;
    }
    
    struct ContractDelay{
        uint256 period;
        uint256 resetTime;        
        int delayId;
    }
    
    struct PendingPayments{
        address[] pendingAddresses;
        mapping(address => Withdrawable) pendingPayments;
    }

    modifier onlyValidators(address contractAddress){
        require(ValidatorServices[contractAddress].isValidator(msg.sender) == true, "Sender is not a validator.");
        _;  
    }
    
    function checkTimeWindow(address contractAddress) private returns(uint){
        if(delayPeriods[contractAddress].period == 0){
            delayPeriods[contractAddress].period = defaultDelayPeriod;
            delayPeriods[contractAddress].resetTime = 0;
        }else if(now > delayPeriods[contractAddress].resetTime && delayPeriods[contractAddress].period != defaultDelayPeriod){
            delayPeriods[contractAddress].period = defaultDelayPeriod;
            delayPeriods[contractAddress].delayId = 0;
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
    
    function initialise(address validatorServiceAddress, address RuleSetAddress) public returns(bool){
        ValidatorServices[msg.sender] = ValidatorService(validatorServiceAddress);
        RuleSets[msg.sender] = RuleSet(RuleSetAddress);
        return true;
    }

    function delayPayments(address contractAddress) public onlyValidators(contractAddress) returns(bool){
        uint256 delay = 60*60*24;

        // Currently already in a delay, so ignore
        if (delayPeriods[contractAddress].period > defaultDelayPeriod && delayPeriods[contractAddress].resetTime > now){
            return false;
        }

        // If previous vote has expired, reset votes
        ValidatorServices[contractAddress].startOrResetVote(contractAddress);

        // Add vote to delay
        ValidatorServices[contractAddress].submitDelayVote(contractAddress, msg.sender);
        int delayId = ValidatorServices[contractAddress].isDelayed(contractAddress);
        if(delayId > 0){        
            delayPeriods[contractAddress].period = delay;
            delayPeriods[contractAddress].resetTime = now.add(delay);
            delayPeriods[contractAddress].delayId = delayId;
            emit DelayTriggered(contractAddress, delay, msg.sender);
        }
        return true;
    }
    
    function cancelPayment(address recipient) public returns(bool){
        uint256 value = payouts[msg.sender].pendingPayments[recipient].amount;
        uint256 _withdrawalTimestamp = payouts[msg.sender].pendingPayments[recipient].timestamp.add(checkTimeWindow(msg.sender));
        uint256 _depositTimestamp = payouts[msg.sender].pendingPayments[recipient].timestamp;
        uint256 reward = 0;
        if(value > 0 && _withdrawalTimestamp >= now ){
            emptyAccount(msg.sender, recipient);
            if(_depositTimestamp.add(defaultDelayPeriod) > now ){ // Is cancellation still in default delay period range?
                msg.sender.transfer(value);        
            }else if(rewardPercent > 0){ // else cancellation is possible due to delay, so reward validators
                reward = value * rewardPercent / 100;
                value = value.sub(reward);                
                msg.sender.transfer(value);
                ValidatorServices[msg.sender].cancellationReward.value(reward)(delayPeriods[msg.sender].delayId);
            }
            emit CancellingPayment(value, reward, _depositTimestamp.add(defaultDelayPeriod), now, recipient);
            return true;
        }
        return true;
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


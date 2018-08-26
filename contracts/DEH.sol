pragma solidity ^0.4.21;

import "./SafeMath.sol";
import "./ValidatorService.sol";
import "./RuleSet.sol";

/*
* @title	Decentralised Escapse Hatch to temporarily esgrow funds between two paries allowing reversal during a certain grace period.
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/
contract DEH {
    mapping(address => Payments) payouts;
    mapping(address => ContractDelay) delayPeriods;
    mapping(address => ValidatorService) ValidatorServices;    
    mapping(address => RuleSet) RuleSets;

    using SafeMath128 for uint128;
    using SafeMath64 for uint64;
    
    // todo - method for MC to reset graceperiod after 'panic' mode.
    // todo - method to prevent a single validator from DOSing
    
    event Deposit(address indexed contractAddress, address indexed recipient, uint128 indexed value);
    event Withdrawal(address contractAddress, address recipient, uint128 value);
    event DelayTriggered(address contractAddress, uint64 delayAmount, address validator);
    event EarlyWithdrawalAttempt(address contractAddress, address recipient);    
    event CancellingPayment(uint128 value, uint128 reward, address recipient);

    struct Withdrawable{
        uint128 amount;
        uint64 timestamp;
        uint64 index;
    }
    
    struct ContractDelay{
        uint64 period;
        uint64 resetTime;        
        int128 delayId;
    }
    
    struct Payments{
        bool initalised;
        address[] pendingAddresses;
        mapping(address => Withdrawable) pendingPayments;
    }

    modifier onlyValidators(address contractAddress){
        require(ValidatorServices[contractAddress].isValidator(msg.sender) == true, "Sender is not a validator.");
        _;  
    }

    modifier onlyInitialised(){
        require(payouts[msg.sender].initalised == true, "Validator Service and Rule Set have not been initialised");
        _;
    }
    
    function checkTimeWindow(address contractAddress) private returns(uint64){
        uint64 temp_delay = RuleSets[contractAddress].defaultDelayPeriod();
        ContractDelay storage temp_SC_delay = delayPeriods[contractAddress];
        if(temp_SC_delay.period == 0 || (now > temp_SC_delay.resetTime && temp_SC_delay.period != temp_delay)){
            temp_SC_delay.period = temp_delay;
            temp_SC_delay.resetTime = 0;
        }
        return temp_SC_delay.period;
    }
    
    function withdraw(address contractAddress) public returns(bool){   
        Withdrawable temp = payouts[contractAddress].pendingPayments[msg.sender]; 
        if(temp.amount > 0 && temp.timestamp.add(checkTimeWindow(contractAddress)) < now ){
            uint128 ammountToTransfer = temp.amount;
            emptyAccount(contractAddress, msg.sender);                
            emit Withdrawal(contractAddress, msg.sender, ammountToTransfer);
            msg.sender.transfer(ammountToTransfer);
            return true;            
        }
        emit EarlyWithdrawalAttempt(contractAddress, msg.sender);
        return false;
    }
    
    function checkWithdrawable(address contractAddress) public view returns(uint128){
        return payouts[contractAddress].pendingPayments[msg.sender].amount;
    }

    function checkWithdrawableAsContract(address recipient) public returns(uint128, uint128){
        uint128 value = payouts[msg.sender].pendingPayments[recipient].amount;
        uint64 _withdrawalTimestamp = payouts[msg.sender].pendingPayments[recipient].timestamp.add(checkTimeWindow(msg.sender));
        uint64 _depositTimestamp = payouts[msg.sender].pendingPayments[recipient].timestamp;
        uint128 reward = 0;
        uint64 rewardPercent = RuleSets[msg.sender].rewardPercent();
        if(value > 0 && _withdrawalTimestamp >= now ){
            if(rewardPercent > 0 && _depositTimestamp.add(RuleSets[msg.sender].defaultDelayPeriod()) <= now ){ 
                reward = value * rewardPercent / 100;
                value = value.sub(reward);                                                
            }            
            return (value, reward);
        }        
        return (0,0);
    }

    function pendingPayments() public view returns(address[]){
        return payouts[msg.sender].pendingAddresses;
    }

    /*
     * @notice	Explain to a user what a function does	contract, interface, function
     * @dev	    Explain to a developer any extra details	contract, interface, function
     * @param	recipient - address of which to allocate the amount sent to allowing withdrawal later.
     * @return  Returns True indicating success
     */
    function deposit(address recipient) public payable onlyInitialised() returns(bool){        
        Withdrawable memory temp_withdrawable = payouts[msg.sender].pendingPayments[recipient];

        if(temp_withdrawable.amount == 0){
            uint index = payouts[msg.sender].pendingAddresses.push(recipient);
            require(index < 2**64, "Pending addresses is too large");
            temp_withdrawable.index = uint64(index).sub(1); 
        }        
        temp_withdrawable = Withdrawable(temp_withdrawable.amount.add(uint128(msg.value)),  uint64(now),  temp_withdrawable.index);

        payouts[msg.sender].pendingPayments[recipient] = temp_withdrawable;
        emit Deposit(msg.sender, msg.sender, uint128(msg.value));
        return true;
    }
    
    function initialise(address validatorServiceAddress, address RuleSetAddress) public returns(bool){
        ValidatorServices[msg.sender] = ValidatorService(validatorServiceAddress);
        RuleSets[msg.sender] = RuleSet(RuleSetAddress);
        ValidatorServices[msg.sender].initialise(msg.sender, RuleSets[msg.sender].validatorServiceParam(), RuleSets[msg.sender].rewardPercent());
        payouts[msg.sender].initalised = true;  
        return true;
    }

    function delayPayments(address contractAddress) public onlyValidators(contractAddress) returns(bool){
        uint64 delay = RuleSets[contractAddress].validatorDelayPeriod();

        // Currently already in a delay, so ignore
        if (delayPeriods[contractAddress].period > RuleSets[contractAddress].defaultDelayPeriod() && delayPeriods[contractAddress].resetTime > now){
            return false;
        }

        // If previous vote has expired, reset votes
        ValidatorServices[contractAddress].startOrResetVote(contractAddress);

        // Add vote to delay
        ValidatorServices[contractAddress].submitVote(contractAddress, msg.sender);
        int128 delayId = ValidatorServices[contractAddress].isDelayed(contractAddress);
        //delayId = -1 if no delay.
        if(delayId > 0){        
            delayPeriods[contractAddress].period = delay;
            delayPeriods[contractAddress].resetTime = uint64(now).add(delay);
            delayPeriods[contractAddress].delayId = delayId;
            emit DelayTriggered(contractAddress, delay, msg.sender);
        }
        return true;
    }
    
    function cancelPayment(address recipient) public returns(bool){
        uint128 value = payouts[msg.sender].pendingPayments[recipient].amount;
        uint64 _withdrawalTimestamp = payouts[msg.sender].pendingPayments[recipient].timestamp.add(checkTimeWindow(msg.sender));
        uint64 _depositTimestamp = payouts[msg.sender].pendingPayments[recipient].timestamp;
        uint128 reward = 0;
        uint64 rewardPercent = RuleSets[msg.sender].rewardPercent();
        if(value > 0 && _withdrawalTimestamp >= now ){
            emptyAccount(msg.sender, recipient);
            if(_depositTimestamp.add(RuleSets[msg.sender].defaultDelayPeriod()) > now ){ // Is cancellation still in default delay period range?
                msg.sender.transfer(value);        
            }else if(rewardPercent > 0 && rewardPercent < 100){ // else cancellation is possible due to delay, so reward validators
                reward = value * rewardPercent / 100;
                value = value.sub(reward);                
                msg.sender.transfer(value);
                ValidatorServices[msg.sender].cancellationReward.value(reward)(delayPeriods[msg.sender].delayId);
            }else{
                return false;
            }
            emit CancellingPayment(value, reward, recipient);            
        }
        return true;
    }

    function emptyAccount(address contractAddress, address recipient) private returns(bool){
        payouts[contractAddress].pendingPayments[recipient].amount = 0;   
        require(payouts[contractAddress].pendingAddresses.length > 0);
        uint64 swapIndex = uint64(payouts[contractAddress].pendingAddresses.length).sub(1);
        uint64 deleteIndex = payouts[contractAddress].pendingPayments[msg.sender].index;
        address swapAddress = payouts[contractAddress].pendingAddresses[swapIndex];

        payouts[contractAddress].pendingAddresses[deleteIndex] = swapAddress;
        payouts[contractAddress].pendingPayments[swapAddress].index = deleteIndex;        
        delete payouts[contractAddress].pendingAddresses[swapIndex];
        delete payouts[contractAddress].pendingPayments[recipient];
        payouts[contractAddress].pendingAddresses.length = uint64(payouts[contractAddress].pendingAddresses.length).sub(1);        
        return true;
    }

    function () public payable {
        revert("Payment made not via deposit function.");
    }
}


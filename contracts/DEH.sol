pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./ValidatorService.sol";
import "./RuleSet.sol";

/*
* @title	Decentralised Escapse Hatch to temporarily esgrow funds between 
*           two paries allowing reversal during a certain grace period.
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/

contract DEH {

    mapping(address => Payments) internal payouts;
    mapping(address => ContractDelay) internal delayPeriods;
    mapping(address => ValidatorService) internal validatorServices;    
    mapping(address => RuleSet) internal ruleSets;

    using SafeMath128 for uint128;
    using SafeMath64 for uint64;

    event Deposit(address indexed contractAddress, address indexed recipient, uint128 indexed value);
    event Withdrawal(address contractAddress, address recipient, uint128 value);
    event DelayTriggered(address contractAddress, uint64 delayAmount, address validator);
    event EarlyWithdrawalAttempt(address contractAddress, address recipient);    
    event CancellingPayment(uint128 value, uint128 reward, address recipient);

    struct Withdrawable {
        uint128 amount;
        uint64 timestamp;
        uint64 index;
    }
    
    struct ContractDelay {
        uint64 period;
        uint64 resetTime;        
        int128 delayId;
    }
    
    struct Payments {
        bool initalised;
        address[] pendingAddresses;
        mapping(address => Withdrawable) pendingPayments;
    }

    modifier onlyValidators(address contractAddress) {
        require(validatorServices[contractAddress].isValidator(msg.sender) == true, "Sender is not a validator.");
        _;  
    }

    modifier onlyInitialised() {
        require(payouts[msg.sender].initalised == true, "Validator Service and Rule Set have not been initialised");
        _;
    }
    
    /*
     * @notice	Only accepts payments via the deposit function, not fallback
     */
    function () 
    public payable {
        revert("Payment made not via deposit function.");
    }

    /*
     * @notice	Used by recipients to withdraw any  pending payments     
     * @param	contractAddress - address of smart contract to retrieve balance from.
     * @return  returns True indicating success, False if early attempt
     */
    function withdraw(address contractAddress) 
    public 
    returns(bool) {   
        Withdrawable temp = payouts[contractAddress].pendingPayments[msg.sender]; 
        if (temp.amount > 0 && temp.timestamp.add(checkTimeWindow(contractAddress)) < now) {
            uint128 ammountToTransfer = temp.amount;
            emptyAccount(contractAddress, msg.sender);                
            emit Withdrawal(contractAddress, msg.sender, ammountToTransfer);
            msg.sender.transfer(ammountToTransfer);
            return true;            
        }
        emit EarlyWithdrawalAttempt(contractAddress, msg.sender);
        return false;
    }

    /*
     * @notice	Used by recipients to see how much they can withdraw from a given smart contract     
     * @param	address of account to look up withdrawable balance for
     * @return  returns uint for value
     */
    function checkWithdrawable(address contractAddress) 
    public view 
    returns(uint128) {
        return payouts[contractAddress].pendingPayments[msg.sender].amount;
    }

    /*
     * @notice	Used by smart contract to see how much will be refunded for an account
     * @dev	    Same as cancel payment, but without updating state/transferring funds
     * @param	recipient - address of account to look up. Smart contract can only look at 
     *          accounts for its own contract
     * @return  returns (value, reward) to the smart contract
     */
    function checkWithdrawableAsContract(address recipient) 
    public 
    returns(uint128, uint128) {
        uint128 value = payouts[msg.sender].pendingPayments[recipient].amount;
        uint64 _withdrawalTimestamp = payouts[msg.sender]
            .pendingPayments[recipient]
            .timestamp.add(checkTimeWindow(msg.sender));
        uint64 _depositTimestamp = payouts[msg.sender].pendingPayments[recipient].timestamp;
        uint128 reward = 0;
        uint64 rewardPercent = ruleSets[msg.sender].REWARD_PERCENT();
        if (value > 0 && _withdrawalTimestamp >= now) {
            if (rewardPercent > 0 && _depositTimestamp.add(ruleSets[msg.sender].DEFAULT_DELAY_PERIOD()) <= now) { 
                reward = value * rewardPercent / 100;
                value = value.sub(reward);                                                
            }            
            return (value, reward);
        }        
        return (0, 0);
    }

    /*
     * @notice	Used by smart contract to see addresses that have not withdrawn funds for msg.sender contract     
     * @return  returns address array of pending accounts
     */
    function pendingPayments() 
    public view 
    returns(address[]) {
        return payouts[msg.sender].pendingAddresses;
    }

    /*
     * @notice	Function used to deposit funds that can be withdrawn by recipient at later time
     * @dev	    Max limit of 2^64 active accounts allowed, 
     *          onlyInitialsed stops unintialised contracts depositing
     * @param	recipient - address of which to allocate the amount sent to, allowing withdrawal later.
     * @return  returns True indicating success
     */
    function deposit(address recipient) 
    public payable onlyInitialised() 
    returns(bool) {        
        Withdrawable memory tempWithdrawable = payouts[msg.sender].pendingPayments[recipient];

        if (tempWithdrawable.amount == 0) {
            uint index = payouts[msg.sender].pendingAddresses.push(recipient);
            require(index < 2**64, "Pending addresses is too large");
            tempWithdrawable.index = uint64(index).sub(1); 
        }        
        tempWithdrawable = Withdrawable(tempWithdrawable.amount.add(uint128(msg.value)), 
            uint64(now), tempWithdrawable.index);

        payouts[msg.sender].pendingPayments[recipient] = tempWithdrawable;
        emit Deposit(msg.sender, msg.sender, uint128(msg.value));
        return true;
    }
    
    /*
     * @notice	Used to initialise the DEH and the Validator service with the ruleSet
     * @dev	    Valiadtor.initialise can only be called from DEH
     * @param	Addresses of the chosen Validator Service and Rule Set 
     * @return  returns True indicating success
     */
    function initialise(address validatorServiceAddress, address ruleSetAddress) 
    public 
    returns(bool) {
        validatorServices[msg.sender] = ValidatorService(validatorServiceAddress);
        ruleSets[msg.sender] = RuleSet(ruleSetAddress);
        validatorServices[msg.sender].initialise(msg.sender, 
            ruleSets[msg.sender].VALIDATOR_SERVICE_PARAM(), 
            ruleSets[msg.sender].REWARD_PERCENT());
        payouts[msg.sender].initalised = true;  
        return true;
    }

    /*
     * @notice	Used by validators to vote on delaying a chosen contract.
     * @dev	    Modifier checks that msg.sender is infact a validator
     * @param	contratAddress - Address of the smart contract the delay vote is for
     * @return  returns True indicating success, False indicating delay in progress.
     */
    function delayPayments(address contractAddress) 
    public onlyValidators(contractAddress) 
    returns(bool) {
        uint64 delay = ruleSets[contractAddress].VALIDATOR_DELAY_PERIOD();

        // Currently already in a delay, so ignore
        if (delayPeriods[contractAddress].period > ruleSets[contractAddress].DEFAULT_DELAY_PERIOD() && 
            delayPeriods[contractAddress].resetTime > now) {
            return false;
        }

        // If previous vote has expired, reset votes
        validatorServices[contractAddress].startOrResetVote(contractAddress);

        // Add vote to delay
        validatorServices[contractAddress].submitVote(contractAddress, msg.sender);
        int128 delayId = validatorServices[contractAddress].isDelayed(contractAddress);
        //delayId = -1 if no delay.
        if (delayId > 0) {        
            delayPeriods[contractAddress].period = delay;
            delayPeriods[contractAddress].resetTime = uint64(now).add(delay);
            delayPeriods[contractAddress].delayId = delayId;
            emit DelayTriggered(contractAddress, delay, msg.sender);
        }
        return true;
    }
    
    /*
     * @notice	Used by application smart contracts to cancel a payment to a address
     * @dev	    Divergence depending on whether cancellation time is within default
     *          delay period of validator extended delay period. 
     * @param	recipient - the address to cancel payments for.
     * @return  returns True indicating success, False indicating other failure.
     */
    function cancelPayment(address recipient) 
    public 
    returns(bool) {
        uint128 value = payouts[msg.sender].pendingPayments[recipient].amount;
        uint64 _withdrawalTimestamp = payouts[msg.sender].pendingPayments[recipient]
            .timestamp.add(checkTimeWindow(msg.sender));
        uint64 _depositTimestamp = payouts[msg.sender].pendingPayments[recipient].timestamp;
        uint128 reward = 0;
        uint64 rewardPercent = ruleSets[msg.sender].REWARD_PERCENT();
        if (value > 0 && _withdrawalTimestamp >= now) {
            emptyAccount(msg.sender, recipient);
            if (_depositTimestamp.add(ruleSets[msg.sender].DEFAULT_DELAY_PERIOD()) > now) {
                msg.sender.transfer(value);        
            } else if (rewardPercent > 0 && rewardPercent < 100) {
                reward = value * rewardPercent / 100;
                value = value.sub(reward);                
                msg.sender.transfer(value);
                validatorServices[msg.sender].cancellationReward.value(reward)(delayPeriods[msg.sender].delayId);
            } else {
                return false;
            }
            emit CancellingPayment(value, reward, recipient);            
        }
        return true;
    }

    /*
     * @notice	Used internally to derive the amount of time to payments are delayed
     *          for a given smart contract (including any validator delays).
     * @param	contractAddress - address to determine delay period for
     * @return  returns the amount of time payments must be delayed by from the deposit time.
     */
    function checkTimeWindow(address contractAddress) 
    private 
    returns(uint64) {
        uint64 tempDelay = ruleSets[contractAddress].DEFAULT_DELAY_PERIOD();
        ContractDelay storage tempSCDelay = delayPeriods[contractAddress];
        if (tempSCDelay.period == 0 || (now > tempSCDelay.resetTime && tempSCDelay.period != tempDelay)) {
            tempSCDelay.period = tempDelay;
            tempSCDelay.resetTime = 0;
        }
        return tempSCDelay.period;
    }
    
    /*
     * @notice	Used internally to remove accounts from pendingAddresses array
     * @dev	    Can end up costing more gas.. so optimisation needed
     * @param	Addresses of the smart contract, and account to delete
     * @return  returns True indicating success
     */
    function emptyAccount(address contractAddress, address recipient) 
    private 
    returns(bool) {
        payouts[contractAddress].pendingPayments[recipient].amount = 0;   
        require(payouts[contractAddress].pendingAddresses.length > 0);
        uint64 swapIndex = uint64(payouts[contractAddress].pendingAddresses.length).sub(1);
        uint64 deleteIndex = payouts[contractAddress].pendingPayments[msg.sender].index;
        address swapAddress = payouts[contractAddress].pendingAddresses[swapIndex];

        payouts[contractAddress].pendingAddresses[deleteIndex] = swapAddress;
        payouts[contractAddress].pendingPayments[swapAddress].index = deleteIndex;        
        delete payouts[contractAddress].pendingAddresses[swapIndex];
        delete payouts[contractAddress].pendingPayments[recipient];
        payouts[contractAddress].pendingAddresses.length = uint64(payouts[contractAddress]
            .pendingAddresses.length).sub(1);        
        return true;
    }
}


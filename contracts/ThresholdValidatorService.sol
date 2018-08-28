pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./ValidatorService.sol";

/*
* @title	Validator service that uses a simple threshold to determine
*           whether a contracts transactions should be delayed.
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/

contract ThresholdValidatorService is ValidatorService {

    using SafeMath128 for uint128;
    using SafeMath64 for uint64;

    mapping(address => SCValidation) internal validatorDetails;

    event NewContract(address scAddress, uint64 threshold, uint64 reward);

    struct SCValidation {        
        uint64 thresholdToDelay;        
        uint64 votes;
        uint64 resetVotesTime;
        uint64 rewardPercent;
        address[] voters;
        mapping(address => bool) voted;
    }

    constructor(address _dehAddress) 
    public ValidatorService(_dehAddress) {}

    /*
     * @notice	Initalises rules based on the Ruleset
     * @dev	    Only allowed to be called from DEH
     * @param	Smart Contract Adddress, threshold of valdiators needed for delay
     *          and reward percentage
     */
    function initialise(address scAddress, uint64 _thresholdToDelay, uint64 _rewardPercent) 
    public onlyDEH() {
        validatorDetails[scAddress].thresholdToDelay = _thresholdToDelay;
        validatorDetails[scAddress].rewardPercent = _rewardPercent;
        emit NewContract(scAddress, _thresholdToDelay, _rewardPercent);
    }

    /*
     * @notice	Used by DEH to submit vote for a valdiator
     * @dev	    Only allowed to be called from DEH
     * @param	address of smart contract to vote on, and validator submitting vote
     * @return  returns true if vote registered successfully
     */
    function submitVote(address scAddress, address validator) 
    public onlyDEH 
    returns (bool) {        
        if (validatorDetails[scAddress].votes == 0) {
            validatorDetails[scAddress].resetVotesTime = uint64(now).add(60*60); // What time should this be
        }
        if (validatorDetails[scAddress].voted[validator] == false) {
            validatorDetails[scAddress].votes = validatorDetails[scAddress].votes.add(1);
            validatorDetails[scAddress].voters.push(validator);
            validatorDetails[scAddress].voted[validator] = true;
            return true;
        } else {
            return false;
        }
    }

    /*
     * @notice	Resets votes collected for any expired ballot for a smart contract     
     * @dev	    Only allowed to be called from DEH
     * @param	address of smart contract to reset ballot for
     * @return  returns true if ballot reset
     */
    function resetVoters(address scAddress) 
    public  onlyDEH 
    returns (bool) {        
        for (uint i = 0; i < validatorDetails[scAddress].voters.length; i++) {
            uint length = validatorDetails[scAddress].voters.length;
            validatorDetails[scAddress].voted[validatorDetails[scAddress].voters[length-1]] = false;
            delete validatorDetails[scAddress].voters[length-1];
            validatorDetails[scAddress].voters.length = uint64(length).sub(1);
        }
        returns true;
    }

    /*
     * @notice	Used by DEH to start a vote if no delay is present 
     *          already and vote has been recevied
     * @dev	    Only allowed to be called from DEH
     * @param	address of smart contract to start vote for
     * @return  returns true if vote started
     */
    function startOrResetVote(address scAddress) 
    public onlyDEH 
    returns (bool) {
        if (validatorDetails[scAddress].resetVotesTime < now) {
            validatorDetails[scAddress].votes = 0;
            return resetVoters(scAddress);
        }
        return true;
    }

    /*
     * @notice	Used by DEH to determine if contract transactions should be delayed
     * @dev	    Only allowed to be called from DEH
     * @param	address of smart contract to check
     * @return  returns delay id if delayed, or -1 if no delay
     */
    function isDelayed(address scAddress) 
    public onlyDEH 
    returns (int128) {            
        if (validatorDetails[scAddress].votes > validatorDetails[scAddress].thresholdToDelay) {
            delayId = delayId + 1;
            delayVoters[uint(delayId)] = validatorDetails[scAddress].voters;
            return delayId;
        }
        return -1;        
    }  

    /*
     * @notice	Used to allocate a reward to a set of validators
     * @dev	    Only allowed to be called from DEH
     * @param	delay ID identifying the group of validators triggering the delay  
     * @return  returns true if recived successfully.
     */
    function cancellationReward(int _delayId) 
    public onlyDEH payable 
    returns (bool) {
        uint numberOfVoters = delayVoters[uint(_delayId)].length;
        require(numberOfVoters > 0);
        uint128 amountPerValidator = uint128(msg.value / numberOfVoters);
        for (uint i = 0; i < numberOfVoters; i++) {
            validatorPayouts[delayVoters[uint(_delayId)][i]] = 
                validatorPayouts[delayVoters[uint(_delayId)][i]].add(amountPerValidator);            
        }
        return true;
    }

    /*
     * @notice	Used to claim validator rewards             
     * @return  returns true if value sent to validator successfully
     */
    function withdrawRewards() 
    public onlyValidator 
    returns (bool) {
        uint value = validatorPayouts[msg.sender];
        if (value > 0) {
            validatorPayouts[msg.sender] = 0;
            msg.sender.transfer(value);
            return true;
        }   
        return false;
    }

    /*
     * @notice	Used to appoint address as validator
     * @dev	    Only used for testing purposes.. not secure in reality
     * @param	address of validator to appoint     
     * @return  returns true if appinted successfully.
     */
    function appointValidator(address validatorAddress) 
    public 
    returns (bool) {
        validators[validatorAddress] = true;
        return true;
    }

    /*
     * @notice	Used to remove validator from service
     * @dev	    Only used for testing purposes.. not secure in reality
     * @param	address of validator to revoke     
     * @return  returns true if removed successfully.
     */
    function revokeValidator(address validatorAddress) 
    public 
    returns (bool) {
        validators[validatorAddress] = false;                
        return true;
    }    

}
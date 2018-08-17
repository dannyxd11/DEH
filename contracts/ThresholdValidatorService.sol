pragma solidity ^0.4.21;

import "./SafeMath.sol";
import "./ValidatorService.sol";

/*
* @title	Validator service that uses a simple threshold to determine whether a contracts transactions should be delayed.
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/
contract ThresholdValidatorService is ValidatorService{
    using SafeMath128 for uint128;
    using SafeMath64 for uint64;
    mapping(address => SCValidation) validatorDetails;

    event NewContract(address scAddress, uint64 threshold, uint64 reward);
    struct SCValidation{        
        uint64 thresholdToDelay;        
        uint64 votes;
        uint64 resetVotesTime;
        uint64 rewardPercent;
        address[] voters;
        mapping(address => bool) voted;
    }

    constructor(address _DEHAddress) public ValidatorService(_DEHAddress){}

    function initialise(address scAddress, uint64 _thresholdToDelay, uint64 _rewardPercent) public onlyDEH() {
        validatorDetails[scAddress].thresholdToDelay = _thresholdToDelay;
        validatorDetails[scAddress].rewardPercent = _rewardPercent;
        emit NewContract(scAddress, _thresholdToDelay, _rewardPercent);
    }

    function submitDelayVote(address scAddress, address validator) public returns (bool){        
        if(validatorDetails[scAddress].votes == 0){
            validatorDetails[scAddress].resetVotesTime = uint64(now).add(60*60); // What time should this be
        }
        if(validatorDetails[scAddress].voted[validator] == false){
            validatorDetails[scAddress].votes = validatorDetails[scAddress].votes.add(1);
            validatorDetails[scAddress].voters.push(validator);
            validatorDetails[scAddress].voted[validator] = true;
            return true;
        }else{
            return false;
        }
    }

    function resetVoters(address scAddress) public returns (bool){        
        for(uint i = 0; i < validatorDetails[scAddress].voters.length; i++ ){
            uint length = validatorDetails[scAddress].voters.length;
            validatorDetails[scAddress].voted[validatorDetails[scAddress].voters[length-1]] = false;
            delete validatorDetails[scAddress].voters[length-1];
            validatorDetails[scAddress].voters.length = length - 1;
        }
    }

    function startOrResetVote(address scAddress) public returns (bool){
        if(validatorDetails[scAddress].resetVotesTime < now){
            validatorDetails[scAddress].votes = 0;
            return resetVoters(scAddress);
        }
        return true;
    }

    function isDelayed(address scAddress) public returns (int128){            
        if (validatorDetails[scAddress].votes > validatorDetails[scAddress].thresholdToDelay){
            delayId = delayId + 1;
            delayVoters[uint(delayId)] = validatorDetails[scAddress].voters;
            return delayId;
        }
        return -1;        
    }    

    function cancellationReward(int _delayId) public payable returns (bool){
        uint numberOfVoters = delayVoters[uint(_delayId)].length;
        require(numberOfVoters > 0);
        uint128 amountPerValidator = uint128(msg.value / numberOfVoters);
        for (uint i = 0; i < numberOfVoters; i++){
            validatorPayouts[delayVoters[uint(_delayId)][i]] = validatorPayouts[delayVoters[uint(_delayId)][i]].add(amountPerValidator);            
        }
        return true;
    }

    function withdrawRewards() public returns (bool){
        uint value = validatorPayouts[msg.sender];
        if(value > 0){
            validatorPayouts[msg.sender] = 0;
            msg.sender.transfer(value);
            return true;
        }   
        return false;
    }

    function appointValidator(address validatorAddress) public returns (bool){
        validators[validatorAddress] = true;
        return true;
    }

    function revokeValidator(address validatorAddress) public returns (bool){
        validators[validatorAddress] = false;                
        return true;
    }    

}
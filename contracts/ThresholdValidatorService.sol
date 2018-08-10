pragma solidity ^0.4.21;

import "./SafeMath.sol";
import "./ValidatorService.sol";

contract ThresholdValidatorService is ValidatorService{
    using SafeMath for uint256;
    mapping(address => SCValidation) validatorDetails;
    
    event Votes(uint votes);
    struct SCValidation{
        uint256 validatorCount;
        uint256 thresholdToDelay;        
        uint256 votes;
        address[] voters;
        mapping(address => bool) voted;
        uint256 resetVotesTime;
    }

    struct Validator{
        uint lastVoteTime;
        bool active;
    }    

    function submitDelayVote(address scAddress, address validator) public returns (bool){
        if(validatorDetails[scAddress].votes == 0){
            validatorDetails[scAddress].resetVotesTime = now.add(60*60);
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

    function isDelayed(address scAddress) public returns (int){        
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
        uint amountPerValidator = msg.value / numberOfVoters;
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
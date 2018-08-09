pragma solidity ^0.4.21;

import "./SafeMath.sol";

contract ValidatorService{
    using SafeMath for uint256;
    
    mapping(address => bool) validators;
    mapping(uint => address[]) delayVoters;
    mapping(address => uint) highestDelayId; 
    mapping(address => uint256) validatorPayouts;
    int delayId = 1;
    

    function isValidator(address validator) public view returns (bool){  return validators[validator]; }
    function submitDelayVote(address scAddress, address validator) public returns (bool);
    function startOrResetVote(address scAddress) public returns (bool);
    function isDelayed(address scAddress) public returns (int);
    function cancellationReward(int _delayId) public payable returns (bool);
    function withdrawRewards() public returns (bool);
}

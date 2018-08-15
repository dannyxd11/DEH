pragma solidity ^0.4.21;

import "./SafeMath.sol";

contract ValidatorService{
    using SafeMath128 for uint128;
    using SafeMath64 for uint64;
    
    mapping(address => bool) validators;
    mapping(uint => address[]) delayVoters;
    mapping(address => uint128) validatorPayouts;
    int128 delayId = 1;
    

    function isValidator(address validator) public view returns (bool){  return validators[validator]; }
    function submitDelayVote(address scAddress, address validator) public returns (bool);
    function startOrResetVote(address scAddress) public returns (bool);
    function isDelayed(address scAddress) public returns (int128);
    function cancellationReward(int _delayId) public payable returns (bool);
    function withdrawRewards() public returns (bool);
}

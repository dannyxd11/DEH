pragma solidity ^0.4.21;

import "./SafeMath.sol";

/*
* @title	Template for Validator Services - Allows different services to hvae different rules and behaviours as long as they follow this interface
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/
contract ValidatorService{
    using SafeMath128 for uint128;
    using SafeMath64 for uint64;
    
    mapping(address => bool) validators;
    mapping(uint => address[]) delayVoters;
    mapping(address => uint128) validatorPayouts;
    int128 delayId = 1;
    
    function initialise(address scAddress, uint64 validatorServiceParam, uint64 rewardPercent) public;
    function isValidator(address validator) public view returns (bool){  return validators[validator]; }
    function submitDelayVote(address scAddress, address validator) public returns (bool);
    function startOrResetVote(address scAddress) public returns (bool);
    function isDelayed(address scAddress) public returns (int128);
    function cancellationReward(int _delayId) public payable returns (bool);
    function withdrawRewards() public returns (bool);
}

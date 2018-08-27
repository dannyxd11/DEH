pragma solidity 0.4.24;

import "./SafeMath.sol";

/*
* @title	Template for Validator Services - Allows different services 
* to hvae different rules and behaviours as long as they follow this interface
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/

contract ValidatorService {

    using SafeMath128 for uint128;
    using SafeMath64 for uint64;
    address internal dehAddress;
    mapping(address => bool) internal validators;
    mapping(uint => address[]) internal delayVoters;
    mapping(address => uint128) internal validatorPayouts;
    int128 internal delayId = 1;
    
    modifier onlyDEH() { require(msg.sender == dehAddress, "This can only be done from the DEH."); _; }
    modifier onlyValidator() { require(isValidator(msg.sender) == true, "Must be a validator to do this."); _; }
    
    constructor(address _dehAddress) public { 
        require(address(0) != _dehAddress, "Must provide DEH address"); 
        dehAddress = _dehAddress; 
    } 
    
    function initialise(address scAddress, uint64 validatorServiceParam, uint64 rewardPercent) public onlyDEH;
    function isValidator(address validator) public view returns (bool) { return validators[validator]; }
    function submitVote(address scAddress, address validator) public returns (bool);
    function startOrResetVote(address scAddress) public onlyDEH returns (bool);
    function isDelayed(address scAddress) public onlyDEH returns (int128);
    function cancellationReward(int _delayId) public onlyDEH payable returns (bool);
    function withdrawRewards() public returns (bool);
}

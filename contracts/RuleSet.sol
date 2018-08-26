pragma solidity ^0.4.24;


/*
* @title	Ruleset that contains constants to be used throughout various conrtacts
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/
contract RuleSet{
    uint64 public constant rateLimitPeriod = uint64(0); 
    uint64 public constant rateLimit = uint64(0);
    uint64 public constant defaultDelayPeriod = 60; //uint64(3*60*60);
    uint64 public constant validatorDelayPeriod = 240; //uint64(24*60*60);
    uint64 public constant rewardPercent = uint64(2);
    uint64 public constant validatorServiceParam = uint64(1);
}
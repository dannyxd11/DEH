pragma solidity 0.4.24;


/*
* @title	Ruleset that contains constants to be used throughout various conrtacts
* @author	Dan Whitehouse - https://github.com/dannyxd11
*/
contract RuleSet {
    // Not yet implemented but future work
    uint64 public constant RATE_LIMIT_PERIOD = 0; 
    uint64 public constant RATE_LIMIT = 0;
    uint64 public constant DEFAULT_DELAY_PERIOD = 3*60*60;
    uint64 public constant VALIDATOR_DELAY_PERIOD = 24*60*60;
    uint64 public constant REWARD_PERCENT = 2;
    uint64 public constant VALIDATOR_SERVICE_PARAM = 0;
}
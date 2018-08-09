pragma solidity ^0.4.21;

contract RuleSet{
    uint256 public rateLimitPeriod = 0; // seconds
    uint256 public rateLimit = 0;
    uint256 public defaultDelayPeriod = 3*60*60;
    uint256 public delayPeriod = 24*60*60;
}
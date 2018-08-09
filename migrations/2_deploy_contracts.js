var DEH = artifacts.require("./DEH.sol");
var Coin = artifacts.require("./Coin.sol");
var ThresholdValidatorService = artifacts.require("./ThresholdValidatorService.sol");
var RuleSet = artifacts.require("./RuleSet.sol");
//var MoneyControl = artifacts.require("./MoneyControl.sol");

module.exports = function(deployer) {
  var _ThresholdValidatorServiceInstance;// = deployer.deploy(ThresholdValidators);
  var _RuleSetInstance;// = deployer.deploy(RuleSet);
  var _DEHInstance;

  deployer.deploy(ThresholdValidatorService)
      .then(() => ThresholdValidatorService.deployed())
      .then(_instance => _ThresholdValidatorServiceInstance = _instance)
    .then( () =>
  deployer.deploy(RuleSet)
      .then(() => RuleSet.deployed())
      .then(_instance => _RuleSetInstance = _instance)
    ).then( () =>
  deployer.deploy(DEH)
    .then(() => DEH.deployed())    
    .then( _instance => deployer.deploy(Coin, _instance.address, _ThresholdValidatorServiceInstance.address, _RuleSetInstance.address))
    )
}

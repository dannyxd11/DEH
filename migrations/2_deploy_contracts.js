var DEH = artifacts.require("./DEH.sol");
var Coin = artifacts.require("./Coin.sol");
var ThresholdValidatorService = artifacts.require("./ThresholdValidatorService.sol");
var RuleSet = artifacts.require("./RuleSet.sol");

module.exports = function(deployer) {
  var _ThresholdValidatorServiceInstance;
  var _RuleSetInstance;
  var _DEHInstance;

  deployer.deploy(RuleSet).then( () => RuleSet.deployed() ).then( _instance => _RuleSetInstance = _instance )
    .then( () =>
      deployer.deploy(DEH).then( () => DEH.deployed() ).then( _instance => _DEHInstance = _instance )      
    ).then( () =>
      deployer.deploy(ThresholdValidatorService, _DEHInstance.address).then( () => ThresholdValidatorService.deployed() ).then( _instance => _ThresholdValidatorServiceInstance = _instance )
    ).then( () => 
      deployer.deploy(Coin, _DEHInstance.address, _ThresholdValidatorServiceInstance.address, _RuleSetInstance.address)
        .then(console.log("DEH: " + _DEHInstance.address))
        .then(console.log("Validator: " + _ThresholdValidatorServiceInstance.address))
        .then(console.log("RuleSet: " + _RuleSetInstance.address))
    )
  
    
}

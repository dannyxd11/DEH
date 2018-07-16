var DEH = artifacts.require("./DEH.sol");
var DEH = artifacts.require("./SafeMath.sol");
var DEH = artifacts.require("./Coin.sol");
var DEH = artifacts.require("./MoneyControl.sol");

module.exports = function(deployer) {
  deployer.deploy(DEH);  
}

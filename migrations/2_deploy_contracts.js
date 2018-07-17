var DEH = artifacts.require("./DEH.sol");
//var DEH = artifacts.require("./SafeMath.sol");
var Coin = artifacts.require("./Coin.sol");
//var MoneyControl = artifacts.require("./MoneyControl.sol");

module.exports = function(deployer) {
  deployer.deploy(DEH)
    .then(() => DEH.deployed())
    .then(_instance => deployer.deploy(Coin, _instance.address));
}

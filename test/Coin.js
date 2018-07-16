var DEH = artifacts.require("DEH");
var Coin = artifacts.require("Coin");

contract('Coin', async (accounts) => {
    const account_owner = accounts[0];
    const account_one = accounts[1];
    const account_two = accounts[2];
    const deh = await DEH.deployed();

    it("Should be able to deploy contract and minter should be able to allocate Coin tokens", async () => {		
        let coin = await Coin.new(deh.address, {from : account_owner});
        let transferAmount = web3.toWei(0.02,'ether');

        let account_one_starting_balance = await coin.checkBalance.call({ from:account_one });
		account_one_starting_balance = account_one_starting_balance.toNumber();

        let resp = await coin.mint(account_one,{from: account_owner, value: transferAmount});
        let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
        
        let account_one_ending_balance = await coin.checkBalance.call({ from:account_one });
		account_one_ending_balance = account_one_ending_balance.toNumber();

        assert.equal(account_one_ending_balance, account_one_starting_balance + parseInt(transferAmount), "Amount was not correctly minted");
    });


    //todo Test to make sure only owner can mint


})

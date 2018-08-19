var DEH = artifacts.require("DEH");
var Coin = artifacts.require('Coin');
var ThresholdValidatorService = artifacts.require('./ThresholdValidatorService.sol');
const truffleAssert = require('truffle-assertions');
const jsonrpc = '2.0'
const id = 0;
const send = (method, params = []) =>  web3.currentProvider.send({ id, jsonrpc, method, params })
const printEvents = false;

contract('Coin', async (accounts) => {	
	
	it("Should be able to deploy contract and should be able to buy Coin tokens", async () => {	
		const account_owner = accounts[0];
		const account_one = accounts[1];
		const account_two = accounts[2];
		const validator = accounts[9];
		const deh = await DEH.deployed();

		let coin = await Coin.deployed();
		let transferAmount = web3.toWei(0.03,'ether');

		let account_one_starting_balance = await coin.checkBalance.call({ from:account_one });
		account_one_starting_balance = account_one_starting_balance.toNumber();

		let resp = await coin.buy({from: account_one, value: transferAmount});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let account_one_ending_balance = await coin.checkBalance.call({ from:account_one });
		account_one_ending_balance = account_one_ending_balance.toNumber();

		assert.equal(account_one_ending_balance, account_one_starting_balance + parseInt(transferAmount), "Amount was not correctly minted");
	});

	it("Should be able to transfer tokens from account one to account two", async () => {	
		const account_owner = accounts[0];
		const account_one = accounts[1];
		const account_two = accounts[2];
		const validator = accounts[9];
		const deh = await DEH.deployed();

		let coin = await Coin.deployed();	        
		let transferAmount = web3.toWei(0.03,'ether');

		let account_one_starting_balance = await coin.checkBalance.call({ from:account_one });
		account_one_starting_balance = account_one_starting_balance.toNumber();
		let account_two_starting_balance = await coin.checkBalance.call({ from:account_two });
		account_two_starting_balance = account_two_starting_balance.toNumber();

		let resp = await coin.transfer(account_two, transferAmount, {from: account_one});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let account_one_ending_balance = await coin.checkBalance.call({ from:account_one });
		account_one_ending_balance = account_one_ending_balance.toNumber();
		let account_two_ending_balance = await coin.checkBalance.call({ from:account_two });
		account_two_ending_balance = account_two_ending_balance.toNumber();

		assert.equal(account_one_ending_balance, account_one_starting_balance - parseInt(transferAmount), "Amount was not correctly deducted from sender");
		assert.equal(account_two_ending_balance, account_two_starting_balance + parseInt(transferAmount), "Amount was not correctly added to recipient");
});

	it("Should be able to sell tokens. Ether will be transfered to the DEH and withdrawn after grace period.", async () => {	
		const account_owner = accounts[0];
		const account_one = accounts[1];
		const account_two = accounts[2];
		const validator = accounts[9];
		const deh = await DEH.deployed();

		let coin = await Coin.deployed();	        
		let transferAmount = web3.toWei(0.01,'ether');

		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();
		let account_two_starting_token_balance = await coin.checkBalance.call({ from:account_two });
		account_two_starting_token_balance = account_two_starting_token_balance.toNumber();
		let deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		let resp = await coin.sell(transferAmount, {from: account_two});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();
		let account_two_ending_token_balance = await coin.checkBalance.call({ from:account_two });
		account_two_ending_token_balance = account_two_ending_token_balance.toNumber();
		let deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount was sent directly to withdrawer, or unexpected transfer costs.");
		assert.equal(account_two_ending_token_balance, account_two_starting_token_balance - parseInt(transferAmount), "Amount was not correctly deducted from token balance");      
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance + parseInt(transferAmount), "Amount was not correctly credited to DEH");

		account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();        
		deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		resp = await deh.withdraw(coin.address, {from: account_two});
		gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();        
		deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount was withdrawn whilst in grace period");        
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance, "Amount was not correctly credited to DEH");
		
		//Forward Time
		await send('evm_increaseTime', [10800]);
		await send('evm_mine');

		account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();        
		deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		resp = await deh.withdraw(coin.address, {from: account_two});
		gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();        
		deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost + parseInt(transferAmount), 20000, "Amount was withdrawn whilst in grace period");        
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance - parseInt(transferAmount), "Amount was not correctly credited to DEH");
		assert.equal(deh_end_withdrawable_balance, 0, "DEH was not emptied on withdraw");	
	}).timeout(40000); 

	it("Should be able to sell tokens. Validators Delay the process", async () => {	
		const account_owner = accounts[0];
		const account_one = accounts[1];
		const account_two = accounts[2];
		const validator = accounts[9];
		const deh = await DEH.deployed();

		let coin = await Coin.deployed();	 
		let thresholdValidatorService = await ThresholdValidatorService.deployed();       
		let transferAmount = web3.toWei(0.01,'ether');

		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();
		let account_two_starting_token_balance = await coin.checkBalance.call({ from:account_two });
		account_two_starting_token_balance = account_two_starting_token_balance.toNumber();
		let deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();        

		let resp = await coin.sell(transferAmount, {from: account_two});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}

		let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();
		let account_two_ending_token_balance = await coin.checkBalance.call({ from:account_two });
		account_two_ending_token_balance = account_two_ending_token_balance.toNumber();
		let deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount was sent directly to withdrawer, or unexpected transfer costs.");
		assert.equal(account_two_ending_token_balance, account_two_starting_token_balance - parseInt(transferAmount), "Amount was not correctly deducted from token balance");      
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance + parseInt(transferAmount), "Amount was not correctly credited to DEH");

		account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();        
		deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		resp = await deh.withdraw(coin.address, {from: account_two});
		gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}

		account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();        
		deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount was withdrawn whilst in grace period");        
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance, "Amount was not correctly credited to DEH");
				
		resp = await thresholdValidatorService.appointValidator(validator);

		// Validator Delay
		resp = await deh.delayPayments(coin.address, {from: validator});
		let val_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}

		// Forward Time To past default delay

		await send('evm_increaseTime', [10800 + 12*60*60]);
		await send('evm_mine');
		
		account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();        
		deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		resp = await deh.withdraw(coin.address, {from: account_two});
		gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}

		account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();        
		deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();
		
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance, "Amount was not correctly credited to DEH");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount was withdrawn whilst in grace period");        
		
		// Forward Time past validator-initated delay

		await send('evm_increaseTime', [14*60*60]);
		await send('evm_mine');

		account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();        
		deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		resp = await deh.withdraw(coin.address, {from: account_two});
		gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();        
		deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost + parseInt(transferAmount), 20000, "Amount was withdrawn whilst in grace period");        
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance - parseInt(transferAmount), "Amount was not correctly credited to DEH");
		assert.equal(deh_end_withdrawable_balance, 0, "DEH was not emptied on withdraw");
		
	}).timeout(40000); 

	it("Owners should be able to initiate a failsafe to cancel pending payments.", async () => {	
		const account_owner = accounts[0];
		const account_one = accounts[1];
		const account_two = accounts[2];
		const validator = accounts[9];
		const deh = await DEH.deployed();

		let coin = await Coin.deployed();	        
		let transferAmount = web3.toWei(0.01,'ether');

		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();
		let account_two_starting_token_balance = await coin.checkBalance.call({ from:account_two });
		account_two_starting_token_balance = account_two_starting_token_balance.toNumber();
		let deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		let resp = await coin.sell(transferAmount, {from: account_two});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();
		let account_two_ending_token_balance = await coin.checkBalance.call({ from:account_two });
		account_two_ending_token_balance = account_two_ending_token_balance.toNumber();
		let deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount was sent directly to withdrawer, or unexpected transfer costs.");
		assert.equal(account_two_ending_token_balance, account_two_starting_token_balance - parseInt(transferAmount), "Amount was not correctly deducted from token balance");      
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance + parseInt(transferAmount), "Amount was not correctly credited to DEH");

		account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();        
		deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		resp = await deh.withdraw(coin.address, {from: account_two});
		gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();        
		deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount was withdrawn whilst in grace period");        
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance, "Amount was not correctly credited to DEH");
		


		account_two_starting_token_balance = await coin.checkBalance.call({ from:account_two });
		account_two_starting_token_balance = account_two_starting_token_balance.toNumber();
		account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();  
		deh_start_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_start_withdrawable_balance = deh_start_withdrawable_balance.toNumber();

		resp = await coin.failsafe({from: account_owner, gas: 800000});
		gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}

		account_two_ending_token_balance = await coin.checkBalance.call({ from:account_two });
		account_two_ending_token_balance = account_two_ending_token_balance.toNumber();
		account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();        
		deh_end_withdrawable_balance = await deh.checkWithdrawable.call(coin.address,{from: account_two});
		deh_end_withdrawable_balance = deh_end_withdrawable_balance.toNumber();

		assert.closeTo(account_two_ending_balance, account_two_starting_balance, 20000, "Amount was incorrectly credited to recipient");    
		assert.equal(deh_end_withdrawable_balance, deh_start_withdrawable_balance - parseInt(transferAmount), "Amount was not correctly debited from DEH accounts");
		assert.equal(account_two_ending_token_balance, account_two_starting_token_balance + parseInt(transferAmount), "Amount was not credited back to coin accounts");            
		assert.equal(deh_end_withdrawable_balance, 0, "DEH was not emptied on withdraw");	
	}).timeout(40000);
  

});
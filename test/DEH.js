var DEH = artifacts.require("DEH");
var Coin = artifacts.require('Coin');
var ThresholdValidatorService = artifacts.require('./ThresholdValidatorService.sol');
var RuleSet = artifacts.require('./RuleSet.sol');
const truffleAssert = require('truffle-assertions');
const jsonrpc = '2.0'
const id = 0;
const send = (method, params = []) =>  web3.currentProvider.send({ id, jsonrpc, method, params })
const printEvents = false;

contract('DEH', async (accounts) => {
	
  it("DEH should be able to accept funds from contract/account", async () => {		
		let account_one = accounts[0];
		let account_two = accounts[1];
		let transferAmount = web3.toWei(0.02,'ether');
		
    let deh = await DEH.deployed();
		let account_one_starting_balance = await web3.eth.getBalance(account_one);
		account_one_starting_balance = account_one_starting_balance.toNumber();
		let account_two_starting_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_starting_balance = account_two_starting_balance.toNumber();

    let resp = await deh.deposit(account_two,{from: account_one, value: transferAmount});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let account_one_ending_balance = await web3.eth.getBalance(account_one);
		account_one_ending_balance = account_one_ending_balance.toNumber();
		let account_two_ending_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_ending_balance = account_two_ending_balance.toNumber();

		//console.log(web3.fromWei(account_one_starting_balance, 'ether') + "\n" + account_two_starting_balance + "\n" + account_one_ending_balance + "\n"+ account_two_ending_balance + "\n" + transferAmount + "\n" + gascost );
    assert.closeTo(account_one_ending_balance, account_one_starting_balance - parseInt(transferAmount) - gascost, 20000,"Amount wasn't correctly taken from the sender");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance + parseInt(transferAmount), 20000, "Amount wasn't correctly sent to the receiver");
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
	});
		
	it("DEH should not allow an account to withdraw funds immediatly after deposit (during grace period)", async () => {
		let account_one = accounts[0];
		let account_two = accounts[1];		

    let deh = await DEH.deployed();
		let deh_starting_balance = await web3.eth.getBalance(deh.address);
		deh_starting_balance = deh_starting_balance.toNumber();
		let deh_account_starting_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		deh_account_starting_balance = deh_account_starting_balance.toNumber();
		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();


    let resp = await deh.withdraw(account_one,{from: account_two});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let deh_ending_balance = await web3.eth.getBalance(deh.address);
		deh_ending_balance = deh_ending_balance.toNumber();
		let deh_account_ending_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		deh_account_ending_balance = deh_account_ending_balance.toNumber();
		let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		//console.log(deh_starting_balance + "\n" + deh_account_starting_balance + "\n"  + account_two_starting_balance + "\n"  + deh_ending_balance + "\n"+ deh_account_ending_balance + "\n" + account_two_ending_balance + "\n" + gascost );
		assert.closeTo(deh_ending_balance, deh_starting_balance, 20000, "Amount wasn't correctly taken from the sender");
		assert.closeTo(deh_account_ending_balance, deh_account_starting_balance, 20000, "Full ammount was not withdrawn");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount wasn't correctly sent to the receiver");

		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
	});
		
	it("DEH should not allow an account to withdraw funds during grace period", async () => {
		let account_one = accounts[0];
		let account_two = accounts[1];		

		await send('evm_increaseTime', [5400])
		await send('evm_mine')

    let deh = await DEH.deployed();
		let deh_starting_balance = await web3.eth.getBalance(deh.address);
		deh_starting_balance = deh_starting_balance.toNumber();
		let deh_account_starting_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		deh_account_starting_balance = deh_account_starting_balance.toNumber();
		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();

    let resp = await deh.withdraw(account_one,{from: account_two});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let deh_ending_balance = await web3.eth.getBalance(deh.address);
		deh_ending_balance = deh_ending_balance.toNumber();
		let deh_account_ending_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		deh_account_ending_balance = deh_account_ending_balance.toNumber();
		let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		//console.log(deh_starting_balance + "\n" + deh_account_starting_balance + "\n"  + account_two_starting_balance + "\n"  + deh_ending_balance + "\n"+ deh_account_ending_balance + "\n" + account_two_ending_balance + "\n" + gascost );
		assert.closeTo(deh_ending_balance, deh_starting_balance, 20000, "Amount wasn't correctly taken from the sender");
		assert.closeTo(deh_account_ending_balance, deh_account_starting_balance, 20000, "Full ammount was not withdrawn");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - gascost, 20000, "Amount wasn't correctly sent to the receiver");
		
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
  });

	
	it("DEH should allow an account to withdraw funds after grace period has expired", async () => {
		let account_one = accounts[0];
		let account_two = accounts[1];
		let transferAmount = web3.toWei(0.02,'ether');

		await send('evm_increaseTime', [5400])
		await send('evm_mine')

    let deh = await DEH.deployed();
		let deh_starting_balance = await web3.eth.getBalance(deh.address);
		deh_starting_balance = deh_starting_balance.toNumber();
		let deh_account_starting_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		deh_account_starting_balance = deh_account_starting_balance.toNumber();
		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();


    let resp = await deh.withdraw(account_one,{from: account_two});
		let gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let deh_ending_balance = await web3.eth.getBalance(deh.address);
		deh_ending_balance = deh_ending_balance.toNumber();
		let deh_account_ending_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		deh_account_ending_balance = deh_account_ending_balance.toNumber();
		let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		//console.log(deh_starting_balance + "\n" + deh_account_starting_balance + "\n"  + account_two_starting_balance + "\n"  + deh_ending_balance + "\n"+ deh_account_ending_balance + "\n" + account_two_ending_balance  + "\n" + gascost );
		assert.closeTo(deh_ending_balance, deh_starting_balance - deh_account_starting_balance, 20000, "Amount wasn't correctly taken from the sender");
		assert.closeTo(deh_account_ending_balance, 0, 20000, "Full ammount was not withdrawn");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance + deh_account_starting_balance - gascost, 20000, "Amount wasn't correctly sent to the receiver");

		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
  });


	it("Validators should be able to delay transaction from contract", async () => {
		// Deposit some ether to the DEH
		let account_one = accounts[0];
		let account_two = accounts[1];
		let validator = accounts[2];
		let transferAmount = web3.toWei(0.02,'ether');

		let deh = await DEH.deployed();
		let thresholdValidatorService = await ThresholdValidatorService.deployed(); 
		

		let account_one_starting_balance = await web3.eth.getBalance(account_one);
		account_one_starting_balance = account_one_starting_balance.toNumber();
		let account_two_withdrawable_balance_start = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_start = account_two_withdrawable_balance_start.toNumber();
		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();

		let resp = await deh.deposit(account_two,{from: account_one, value: transferAmount});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		let acc1_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
	 
		let account_one_ending_balance = await web3.eth.getBalance(account_one);
		account_one_ending_balance = account_one_ending_balance.toNumber();
		let account_two_withdrawable_balance_end = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_end = account_two_withdrawable_balance_end.toNumber();

		assert.closeTo(account_one_ending_balance, account_one_starting_balance - parseInt(transferAmount) - acc1_gascost, 20000, "Amount wasn't correctly taken from the sender");
		assert.closeTo(account_two_withdrawable_balance_end, account_two_withdrawable_balance_start + parseInt(transferAmount), 20000, "Amount wasn't correctly sent to the receiver");

		// Try Withdrawal

		resp = await deh.withdraw(account_one,{from: account_two});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		let acc2_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let account_two_withdrawable_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance = account_two_withdrawable_balance.toNumber();
	  let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		assert.closeTo(account_two_withdrawable_balance, account_two_withdrawable_balance_end, 20000, "Withdrawal has been made (when it shouldn't have proceeded)");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - acc2_gascost, 20000, "Account 2 was incorrectly credited");	
	
		resp = await thresholdValidatorService.appointValidator(validator);
		let ruleSet = await RuleSet.deployed();
		resp = await deh.initialise(thresholdValidatorService.address, ruleSet.address)
		// Validator Delay
		resp = await deh.delayPayments(account_one, {from: validator});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		let val_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		// Forward Time To past Default 

		await send('evm_increaseTime', [10800]);
		await send('evm_mine');

		// Try Withdrawal

		resp = await deh.withdraw(account_one,{from: account_two});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		acc2_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		account_two_withdrawable_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance = account_two_withdrawable_balance.toNumber();
	  account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		assert.closeTo(account_two_withdrawable_balance, account_two_withdrawable_balance_end, 20000, "Withdrawal has been made (when it shouldn't have proceeded) - After default delay period");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - acc2_gascost, 20000, "Account 2 was incorrectly credited - After default delay period");	
	
		// Forward Time past delay 

		await send('evm_increaseTime', [60*60*24]);
		await send('evm_mine');

		// Succeed

		account_two_withdrawable_balance_start = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_start = account_two_withdrawable_balance_start.toNumber();

		resp = await deh.withdraw(account_one,{from: account_two});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		acc2_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		account_two_withdrawable_balance_end = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_end = account_two_withdrawable_balance_end.toNumber();
	  account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		assert.closeTo(account_two_withdrawable_balance_end, 0, 20000, "Was not able to withdraw balance after delay period");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - acc2_gascost + account_two_withdrawable_balance_start, 20000, "Account 2 did not receive funds after delay period");	
	
	});


	it("Contract should be able to cancel a withdrawl during graceperiod", async () => {
		// Deposit some ether to the DEH
		let account_one = accounts[0];
		let account_two = accounts[1];
		let validator = accounts[2];
		let transferAmount = web3.toWei(0.02,'ether');

		let deh = await DEH.deployed();
					

		let account_one_starting_balance = await web3.eth.getBalance(account_one);
		account_one_starting_balance = account_one_starting_balance.toNumber();
		let account_two_withdrawable_balance_start = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_start = account_two_withdrawable_balance_start.toNumber();
		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();

		let resp = await deh.deposit(account_two,{from: account_one, value: transferAmount});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		let acc1_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
	 
		let account_one_ending_balance = await web3.eth.getBalance(account_one);
		account_one_ending_balance = account_one_ending_balance.toNumber();
		let account_two_withdrawable_balance_end = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_end = account_two_withdrawable_balance_end.toNumber();

		assert.closeTo(account_one_ending_balance, account_one_starting_balance - parseInt(transferAmount) - acc1_gascost, 20000, "Amount wasn't correctly taken from the sender");
		assert.closeTo(account_two_withdrawable_balance_end, account_two_withdrawable_balance_start + parseInt(transferAmount), 20000, "Amount wasn't correctly sent to the receiver");

		// Try Withdrawal

		resp = await deh.withdraw(account_one,{from: account_two});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		let acc2_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		let account_two_withdrawable_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance = account_two_withdrawable_balance.toNumber();
	  let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		assert.closeTo(account_two_withdrawable_balance, account_two_withdrawable_balance_end, 20000, "Withdrawal has been made (when it shouldn't have proceeded)");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - acc2_gascost, 20000, "Account 2 was incorrectly credited");	
	

		// Cancellation
		resp = await deh.cancelPayment(account_two, {from: account_one});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		acc1_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		// Forward Time To past Default 

		await send('evm_increaseTime', [10800]);
		await send('evm_mine');

		// Try Withdrawal

		account_two_withdrawable_balance_start = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_start = account_two_withdrawable_balance_start.toNumber();

		resp = await deh.withdraw(account_one,{from: account_two});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		acc2_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		account_two_withdrawable_balance_end = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_end = account_two_withdrawable_balance_end.toNumber();
	  account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		assert.equal(account_two_withdrawable_balance_end, account_two_withdrawable_balance_start, "Withdrawal has been made (when it shouldn't have proceeded) - After default delay period");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - acc2_gascost, 20000, "Account 2 was incorrectly credited - After default delay period");	

		// Succeed

		account_one_ending_balance = await web3.eth.getBalance(account_one);
		account_one_ending_balance = account_one_ending_balance.toNumber();

		assert.closeTo(account_one_ending_balance, account_one_starting_balance - acc1_gascost , 20000, "Was not able to withdraw balance after delay period");	
	});


	it("Contract should be able to cancel a withdrawl during graceperiod which has been extended by validators", async () => {
		// Deposit some ether to the DEH
		let account_one = accounts[0];
		let account_two = accounts[1];
		let validator = accounts[2];
		let transferAmount = web3.toWei(0.02,'ether');

		let deh = await DEH.deployed();
		let thresholdValidatorService = await ThresholdValidatorService.deployed(); 


		let account_one_starting_balance = await web3.eth.getBalance(account_one);
		account_one_starting_balance = account_one_starting_balance.toNumber();
		let account_two_withdrawable_balance_start = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_start = account_two_withdrawable_balance_start.toNumber();
		let account_two_starting_balance = await web3.eth.getBalance(account_two);
		account_two_starting_balance = account_two_starting_balance.toNumber();
		let validator_starting_balance = await web3.eth.getBalance(validator);
		validator_starting_balance = validator_starting_balance.toNumber();


		let resp = await deh.deposit(account_two,{from: account_one, value: transferAmount});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		let acc1_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		let account_one_ending_balance = await web3.eth.getBalance(account_one);
		account_one_ending_balance = account_one_ending_balance.toNumber();
		let account_two_withdrawable_balance_end = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_end = account_two_withdrawable_balance_end.toNumber();

		assert.closeTo(account_one_ending_balance, account_one_starting_balance - parseInt(transferAmount) - acc1_gascost, 20000, "Amount wasn't correctly taken from the sender");
		assert.closeTo(account_two_withdrawable_balance_end, account_two_withdrawable_balance_start + parseInt(transferAmount), 20000, "Amount wasn't correctly sent to the receiver");

		// Try Withdrawal

		resp = await deh.withdraw(account_one,{from: account_two});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		let acc2_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		let account_two_withdrawable_balance = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance = account_two_withdrawable_balance.toNumber();
		let account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		assert.closeTo(account_two_withdrawable_balance, account_two_withdrawable_balance_end, 20000, "Withdrawal has been made (when it shouldn't have proceeded)");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - acc2_gascost, 20000, "Account 2 was incorrectly credited");	

		resp = await thresholdValidatorService.appointValidator(validator, {from: validator});
		let val_gascost = web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		let ruleSet = await RuleSet.deployed();
		resp = await deh.initialise(thresholdValidatorService.address, ruleSet.address, {from: account_one})
		acc1_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		// Validator Delay
		resp = await deh.delayPayments(account_one, {from: validator});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		val_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		// Forward Time To past Default 

		await send('evm_increaseTime', [10800]);
		await send('evm_mine');

		// Cancellation
		resp = await deh.cancelPayment(account_two, {from: account_one});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		acc1_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();

		// Try Withdrawal

		account_two_withdrawable_balance_start = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_start = account_two_withdrawable_balance_start.toNumber();

		resp = await deh.withdraw(account_one,{from: account_two});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		acc2_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		
		account_two_withdrawable_balance_end = await deh.checkWithdrawable.call(account_one,{from: account_two});
		account_two_withdrawable_balance_end = account_two_withdrawable_balance_end.toNumber();
	  account_two_ending_balance = await web3.eth.getBalance(account_two);
		account_two_ending_balance = account_two_ending_balance.toNumber();

		assert.equal(account_two_withdrawable_balance_end, account_two_withdrawable_balance_start, "Withdrawal has been made (when it shouldn't have proceeded) - After default delay period");
		assert.closeTo(account_two_ending_balance, account_two_starting_balance - acc2_gascost, 20000, "Account 2 was incorrectly credited - After default delay period");	

		// Succeed

		account_one_ending_balance = await web3.eth.getBalance(account_one);
		account_one_ending_balance = account_one_ending_balance.toNumber();		

		assert.closeTo(account_one_ending_balance, account_one_starting_balance - acc1_gascost - transferAmount * 0.02, 20000, "Was not able to withdraw balance after delay period");	
		
		resp = await thresholdValidatorService.withdrawRewards({from: validator});
		if(printEvents){truffleAssert.prettyPrintEmittedEvents(resp);}
		val_gascost += web3.eth.getTransaction(resp.tx).gasPrice.mul(web3.eth.getTransactionReceipt(resp.tx).gasUsed).toNumber();
		validator_ending_balance = await web3.eth.getBalance(validator);
		validator_ending_balance = validator_ending_balance.toNumber();
		assert.closeTo(validator_ending_balance, validator_starting_balance - val_gascost + transferAmount * 0.02, 20000, "Validator was not rewarded");
	});

});




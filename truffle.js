/*
 * NB: since truffle-hdwallet-provider 0.0.5 you must wrap HDWallet providers in a 
 * function when declaring them. Failure to do so will cause commands to hang. ex:
 * ```
 * mainnet: {
 *     provider: function() { 
 *       return new HDWalletProvider(mnemonic, 'https://mainnet.infura.io/<infura-key>') 
 *     },
 *     network_id: '1',
 *     gas: 4500000,
 *     gasPrice: 10000000000,
 *   },
 */

 module.exports = {
      networks: {
        development: {
          host: "127.0.0.1",
          port: 7545,          
          network_id: "*", 
          gas: 4500000,
          from: '0xa66B994Fe08196c894E0d262822ed5538D9292CD'
        }
      }
    };
mocha: {
    enableTimeouts: false
}
